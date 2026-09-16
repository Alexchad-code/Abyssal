#!/usr/bin/env python3
"""Bundle Abyssal into a single executable Lua file.

Why a bundler instead of Wally: a Roblox hub is delivered as one script via
loadstring. Wally produces a package tree, which is the wrong shape for that.
This resolves the same requires, inlines the vendored Obsidian library, and
emits one file.

Module resolution
-----------------
A require target is looked up in this order, relative to the repo root:

    src/<id>.luau      src/<id>.lua      src/<id>/init.luau      src/<id>/init.lua
    <id>.luau          <id>.lua          <id>/init.luau         <id>/init.lua

so `core/Logger` finds src/core/Logger.luau, and `vendor/obsidian/Library`
finds vendor/obsidian/Library.lua without needing a src/ prefix.

Module ids are repo-relative paths with the `src/` prefix removed and the
extension dropped. That is exactly the string used in require(), which keeps
the mapping trivial to reason about.

Why requires are scanned from stripped source
---------------------------------------------
A regex over raw source picks up requires inside comments. The template files
contain commented-out requires by design, and those do not resolve. So comments
and string literals are blanked out first — length-preserving, so line numbers
in any error still point at the right line.

Usage
-----
    python tools/build.py              # write dist/Abyssal.lua
    python tools/build.py --minify     # strip comments as well
    python tools/build.py --check      # resolve only, write nothing
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_ENTRY_ID = "init"
OUTPUT = ROOT / "dist" / "Abyssal.lua"

REQUIRE_RE = re.compile(r"""require\s*\(\s*["']([^"']+)["']\s*\)""")

BANNER = """\
--[[
    Abyssal Hub
    Generated file — do not edit. Rebuild with: python tools/build.py

    Source: https://github.com/Alexchad-code/Abyssal
]]

--[[
    This build bundles the Obsidian UI Library.
    Obsidian UI Library - https://github.com/deividcomsono/Obsidian
    Copyright (c) 2025 deividcomsono
    Licensed under the MIT License. See LICENSE and THIRD_PARTY_NOTICES.md.
    The full notice is also retained in the bundled library source below.
]]
"""

PRELUDE = """\
local __modules = {}
local __cache = {}

local function __require(id)
    local cached = __cache[id]
    if cached ~= nil then
        return cached
    end

    local loader = __modules[id]
    if loader == nil then
        error("Abyssal: module not found: " .. tostring(id), 2)
    end

    local value = loader()
    if value == nil then
        value = true
    end

    __cache[id] = value
    return value
end
"""

EPILOGUE_TEMPLATE = """\

return __require("{entry}")
"""


# --------------------------------------------------------------------- lexing


def _blank(text: str) -> str:
    """Replace text with spaces, keeping newlines so line numbers survive."""
    return "".join("\n" if ch == "\n" else " " for ch in text)


def _match_long_bracket(src: str, pos: int) -> int | None:
    """If a long bracket opens at pos, return the index just past its close."""
    if pos >= len(src) or src[pos] != "[":
        return None

    cursor = pos + 1
    level = 0
    while cursor < len(src) and src[cursor] == "=":
        level += 1
        cursor += 1

    if cursor >= len(src) or src[cursor] != "[":
        return None

    closing = "]" + "=" * level + "]"
    end = src.find(closing, cursor + 1)
    if end == -1:
        return None

    return end + len(closing)


def _match_quoted(src: str, pos: int) -> int:
    """Return the index just past a quoted string starting at pos."""
    quote = src[pos]
    cursor = pos + 1

    while cursor < len(src):
        ch = src[cursor]
        if ch == "\\":
            cursor += 2
            continue
        if ch == quote:
            return cursor + 1
        if ch == "\n":
            # Unterminated on this line; stop rather than swallow the file.
            return cursor
        cursor += 1

    return len(src)


def remove_comments(src: str) -> str:
    """Delete comments for real, unlike the length-preserving variant.

    Line comments are dropped but their newline is kept, so tokens on either
    side cannot be joined. Block comments collapse to a single space for the
    same reason — `a--[[x]]b` must not become `ab`.

    Line numbers shift, which is fine for a minified artefact and not fine for
    anything you intend to debug.
    """
    out: list[str] = []
    i = 0
    n = len(src)

    while i < n:
        ch = src[i]

        if ch == "-" and i + 1 < n and src[i + 1] == "-":
            end = _match_long_bracket(src, i + 2)
            if end is not None:
                out.append(" ")
                i = end
                continue

            newline = src.find("\n", i + 2)
            if newline == -1:
                i = n
            else:
                i = newline
            continue

        if ch in "\"'":
            end = _match_quoted(src, i)
            out.append(src[i:end])
            i = end
            continue

        if ch == "[":
            end = _match_long_bracket(src, i)
            if end is not None:
                out.append(src[i:end])
                i = end
                continue

        out.append(ch)
        i += 1

    return "".join(out)


# ------------------------------------------------------------------ resolving


def module_id_for(path: Path) -> str:
    relative = path.relative_to(ROOT)
    parts = list(relative.parts)

    if parts[0] == "src":
        parts = parts[1:]

    parts[-1] = Path(parts[-1]).stem
    return "/".join(parts)


def resolve(module_id: str) -> Path | None:
    candidates = [
        ROOT / "src" / f"{module_id}.luau",
        ROOT / "src" / f"{module_id}.lua",
        ROOT / "src" / module_id / "init.luau",
        ROOT / "src" / module_id / "init.lua",
        ROOT / f"{module_id}.luau",
        ROOT / f"{module_id}.lua",
        ROOT / module_id / "init.luau",
        ROOT / module_id / "init.lua",
    ]

    for candidate in candidates:
        if candidate.is_file():
            return candidate

    return None


def _is_ident_char(ch: str) -> bool:
    return ch.isalnum() or ch == "_"


def find_requires(source: str) -> list[str]:
    """Find require("...") targets in code, ignoring comments and strings.

    A regex alone is not enough here. Blanking strings first would destroy the
    module path itself, and not blanking them picks up require() calls that
    only appear inside comments — which the template files contain on purpose.
    So this walks the source, tracking whether it is inside a comment or a
    string, and only reads require() when it is in actual code.
    """
    results: list[str] = []
    i = 0
    n = len(source)

    while i < n:
        ch = source[i]

        if ch == "-" and i + 1 < n and source[i + 1] == "-":
            end = _match_long_bracket(source, i + 2)
            if end is not None:
                i = end
                continue

            newline = source.find("\n", i + 2)
            i = n if newline == -1 else newline
            continue

        if ch in "\"'":
            i = _match_quoted(source, i)
            continue

        if ch == "[":
            end = _match_long_bracket(source, i)
            if end is not None:
                i = end
                continue

        if source.startswith("require", i):
            preceded_by_ident = i > 0 and _is_ident_char(source[i - 1])
            followed_by_ident = i + 7 < n and _is_ident_char(source[i + 7])

            if not preceded_by_ident and not followed_by_ident:
                cursor = i + 7
                while cursor < n and source[cursor] in " \t\r\n":
                    cursor += 1

                if cursor < n and source[cursor] == "(":
                    cursor += 1
                    while cursor < n and source[cursor] in " \t\r\n":
                        cursor += 1

                    if cursor < n and source[cursor] in "\"'":
                        quote = source[cursor]
                        cursor += 1
                        literal: list[str] = []

                        while cursor < n and source[cursor] != quote:
                            if source[cursor] == "\\":
                                cursor += 2
                                continue
                            literal.append(source[cursor])
                            cursor += 1

                        results.append("".join(literal))
                        i = cursor + 1
                        continue

        i += 1

    return results


def collect_graph(entry_id: str) -> tuple[dict[str, Path], list[str]]:
    """Walk requires from the entry point. Returns (id -> path, errors)."""
    modules: dict[str, Path] = {}
    errors: list[str] = []
    queue: list[str] = [entry_id]

    while queue:
        module_id = queue.pop()
        if module_id in modules:
            continue

        path = resolve(module_id)

        if path is None:
            errors.append(f"cannot resolve require(\"{module_id}\")")
            continue

        modules[module_id] = path
        source = path.read_text(encoding="utf-8")

        for dependency in find_requires(source):
            if dependency not in modules:
                queue.append(dependency)

    return modules, errors


# ------------------------------------------------------------------- emitting


def emit(modules: dict[str, Path], minify: bool, entry_id: str) -> str:
    parts = [BANNER, PRELUDE]

    for module_id in sorted(modules):
        path = modules[module_id]
        source = path.read_text(encoding="utf-8")

        if minify:
            source = remove_comments(source)

        # function(...) rather than function(): a bundled chunk may reference
        # `...` at its top level, which is legal in a vararg function and a
        # syntax error otherwise.
        parts.append(f'\n__modules["{module_id}"] = function(...)\n')
        parts.append("    local require = __require\n")
        parts.append(source)
        parts.append("\nend\n")

    parts.append(EPILOGUE_TEMPLATE.format(entry=entry_id))

    return "".join(parts)


def main() -> int:
    parser = argparse.ArgumentParser(description="Bundle Abyssal.")
    parser.add_argument(
        "--minify",
        action="store_true",
        help="remove comments from module bodies (strings are preserved)",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="resolve the graph and report, but write nothing",
    )
    parser.add_argument(
        "--entry",
        default=DEFAULT_ENTRY_ID,
        help="module id to run last (default: init). Used by the test harness.",
    )
    parser.add_argument(
        "--out",
        default=None,
        help="output path, relative to the repo root (default: dist/Abyssal.lua)",
    )
    args = parser.parse_args()

    modules, errors = collect_graph(args.entry)

    if errors:
        print("Build failed:\n", file=sys.stderr)
        for error in sorted(set(errors)):
            print(f"  {error}", file=sys.stderr)
        return 1

    vendored = [m for m in modules if m.startswith("vendor/")]

    print(f"resolved {len(modules)} module(s), {len(vendored)} vendored")
    for module_id in sorted(vendored):
        print(f"  vendored: {module_id}")

    if args.check:
        print("check only; nothing written")
        return 0

    bundle = emit(modules, args.minify, args.entry)

    # Cheap guard: the MIT notice must survive into the output, because the
    # bundled library is a distributed copy of Obsidian. Only enforced when the
    # library is actually bundled — the test harness deliberately excludes it.
    if vendored and "Copyright (c) 2025 deividcomsono" not in bundle:
        print(
            "Build failed: Obsidian's MIT notice is missing from the bundle.",
            file=sys.stderr,
        )
        return 1

    output = ROOT / args.out if args.out else OUTPUT
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(bundle, encoding="utf-8", newline="\n")

    size_kb = len(bundle.encode("utf-8")) / 1024
    print(f"wrote {output.relative_to(ROOT)} ({size_kb:.1f} KB)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
