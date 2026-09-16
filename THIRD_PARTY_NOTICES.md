# Third-party notices

Software bundled into or vendored by Abyssal, with the attribution and licence
notices it requires.

---

## Obsidian UI Library

- **Upstream:** https://github.com/deividcomsono/Obsidian
- **Fork in use:** https://github.com/Alexchad-code/Obsidian
- **Copyright:** (c) 2025 deividcomsono
- **Licence:** MIT

**Vendored files:** `vendor/obsidian/Library.lua`, `vendor/obsidian/Library.d.luau`,
`vendor/obsidian/addons/SaveManager.lua`, `vendor/obsidian/addons/ThemeManager.lua`.

**How the notice is retained.** MIT requires the copyright notice and permission
notice to be included in all copies or substantial portions. That is satisfied in
four places, so it survives bundling:

1. In full, in `vendor/obsidian/LICENSE`.
2. As a header comment at the top of `vendor/obsidian/Library.lua` — this is the
   file concatenated into the single-file build, so the notice travels with it
   automatically.
3. After the `--!strict` directive in `vendor/obsidian/Library.d.luau` — the
   directive must remain on line 1 for Luau to honour it, so the notice cannot
   be prepended.
4. In the generated bundle header, emitted by `tools/build.py`.

**Rule for bundlers.** Any script that concatenates `Library.lua` into a
single-file build must not strip comments. If a minifier is added, it must
re-emit the MIT notice into the minified output. A single-file `.lua` that
people download *is* the distributed copy, so the notice belongs inside it.

`tools/build.py` enforces this: the build fails if the notice is missing from
the output.

### MIT License

```
MIT License

Copyright (c) 2025 deividcomsono

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Adding third-party code

Before vendoring anything into this repository:

1. **Check the licence.** No licence file means all rights reserved — there is
   no permission to copy, modify, or redistribute, and attribution does not
   create one.
2. **Keep the notice.** Preserve the `LICENSE` file and any copyright headers,
   and add an entry here.
3. **Check compatibility.** This repository is MIT. Code under a copyleft
   licence such as the GPL cannot be bundled into it without changing the
   licence of the whole project.
