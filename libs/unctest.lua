--[[
    libs/unctest.lua

    Executor capability probe.

    Roblox executors do not implement the same API. The community agreed on a
    naming standard (UNC — Unified Naming Convention) so scripts can target one
    set of names, but compliance is voluntary and varies wildly: one executor
    has a full filesystem and no signal support, the next is the reverse.

    This script finds out what the executor you are running in actually
    provides, so a feature can check before it calls something rather than
    erroring halfway through.

    ─── Run it ───────────────────────────────────────────────────────────────

        loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/Alexchad-code/Abyssal/main/libs/unctest.lua"
        ))()

    It prints a report and returns the capability table.

    ─── Use it ───────────────────────────────────────────────────────────────

        local unc = ctx.LoadFile("libs/unctest.lua")

        if unc.Has("setclipboard") then
            setclipboard(text)
        else
            ctx.Warn("this executor cannot copy to the clipboard")
        end

        -- Or get a clear reason to show the user:
        local fn, why = unc.Get("hookfunction")
        if not fn then ctx.Warn(why) end

    ─── Output ───────────────────────────────────────────────────────────────

    A function counts as present if it is a callable global. That is a
    presence check, not a behaviour check — an executor can declare a function
    that throws when called. Where that distinction matters (hookfunction,
    request), the report flags it as "declared" so you know to test it yourself.
]]

local UNC = {}

UNC.Version = "1.0.0"

--[[
    The surface, grouped the way you would actually reason about it.

    A function is listed under its UNC name. Some executors only provide an
    alias (`http_request` for `request`, `base64_encode` for `base64encode`),
    so the check treats a group of aliases as satisfied if any one is present —
    see ALIASES below.
]]
local CATEGORIES = {
    Environment = {
        "getgenv", "getrenv", "getreg", "getgc", "getgcinfo",
    },

    Instances = {
        "getinstances", "getnilinstances", "getloadedmodules",
        "cloneref", "compareinstances", "isvalid", "iscached",
        "fireclickdetector", "fireproximityprompt", "firetouchinterest",
    },

    Hooking = {
        "getrawmetatable", "setrawmetatable", "hookmetamethod", "hookfunction",
        "restorefunction", "replaceclosure", "clonefunction",
        "newcclosure", "newlclosure", "iscclosure", "islclosure",
        "checkclosure", "isexecutorclosure",
        "getnamecallmethod", "setnamecallmethod", "getcallingscript",
    },

    Scripts = {
        "getscriptbytecode", "getscripthash", "getscriptclosure",
        "getscripts", "getrunningscripts", "decompile",
    },

    Closures = {
        "getupvalue", "setupvalue", "getupvalues", "getconstants", "getprotos",
    },

    Filesystem = {
        "readfile", "writefile", "appendfile", "isfile", "isfolder",
        "listfiles", "makefolder", "delfile", "delfolder", "loadfile", "dofile",
    },

    Clipboard = {
        "setclipboard", "getclipboard",
    },

    Network = {
        "request", "http_request", "HttpGet", "HttpPost",
    },

    Gui = {
        "gethui", "protectgui", "unprotectgui", "getcustomasset",
        "cleardrawcache",
    },

    Signals = {
        "getconnections", "firesignal", "getcallbackvalue",
    },

    Crypto = {
        "crypt", "base64_encode", "base64_decode", "sha256", "hmac",
    },

    Threads = {
        "setthreadidentity", "getthreadidentity", "getidentity",
    },

    Misc = {
        "identifyexecutor", "getexecutorname", "getversion",
        "setfpscap", "getfpscap", "queue_on_teleport",
    },
}

--[[
    Functions where presence does not imply function.

    These are the ones executors most often stub out or partially implement, so
    a bare presence check would be misleading. The report marks them separately.
]]
local UNRELIABLE = {
    hookfunction = true,
    hookmetamethod = true,
    request = true,
    http_request = true,
    firetouchinterest = true,
    decompile = true,
    getscriptbytecode = true,
}

--[[
    Aliases. If any name in a group is present, the group counts as satisfied
    and the report names which one you should call.
]]
local ALIASES = {
    { "request", "http_request" },
    { "base64_encode", "base64encode" },
    { "base64_decode", "base64decode" },
    { "getidentity", "getthreadidentity" },
    { "HttpGet", "httpget" },
    { "HttpPost", "httppost" },
}

-- ────────────────────────────────────────────────────────────────────── probe

--[[
    Direct references, not env[name].

    There is no portable way to index "the globals" by name in a Roblox
    executor. getgenv() is not guaranteed to exist — some executors only have
    _G — Luau has no getfenv at all, and _G is readonly in some contexts. Every
    one of those approaches silently returns nil for a function that is
    actually present, which would make this report lie.

    A direct reference resolves in whatever environment this script is running
    in, which is the one that matters. Reading an undefined global evaluates to
    nil rather than erroring, so that is exactly the check being made.

    Built at scan time rather than load time so that Invalidate() and re-scan
    pick up anything defined in between.
]]
local function buildLookup(): { [string]: any }
    return {
        -- Environment
        getgenv = getgenv,
        getrenv = getrenv,
        getreg = getreg,
        getgc = getgc,
        getgcinfo = getgcinfo,

        -- Instances
        getinstances = getinstances,
        getnilinstances = getnilinstances,
        getloadedmodules = getloadedmodules,
        cloneref = cloneref,
        compareinstances = compareinstances,
        isvalid = isvalid,
        iscached = iscached,
        fireclickdetector = fireclickdetector,
        fireproximityprompt = fireproximityprompt,
        firetouchinterest = firetouchinterest,

        -- Hooking
        getrawmetatable = getrawmetatable,
        setrawmetatable = setrawmetatable,
        hookmetamethod = hookmetamethod,
        hookfunction = hookfunction,
        restorefunction = restorefunction,
        replaceclosure = replaceclosure,
        clonefunction = clonefunction,
        newcclosure = newcclosure,
        newlclosure = newlclosure,
        iscclosure = iscclosure,
        islclosure = islclosure,
        checkclosure = checkclosure,
        isexecutorclosure = isexecutorclosure,
        getnamecallmethod = getnamecallmethod,
        setnamecallmethod = setnamecallmethod,
        getcallingscript = getcallingscript,

        -- Scripts
        getscriptbytecode = getscriptbytecode,
        getscripthash = getscripthash,
        getscriptclosure = getscriptclosure,
        getscripts = getscripts,
        getrunningscripts = getrunningscripts,
        decompile = decompile,

        -- Closures
        getupvalue = getupvalue,
        setupvalue = setupvalue,
        getupvalues = getupvalues,
        getconstants = getconstants,
        getprotos = getprotos,

        -- Filesystem
        readfile = readfile,
        writefile = writefile,
        appendfile = appendfile,
        isfile = isfile,
        isfolder = isfolder,
        listfiles = listfiles,
        makefolder = makefolder,
        delfile = delfile,
        delfolder = delfolder,
        loadfile = loadfile,
        dofile = dofile,

        -- Clipboard
        setclipboard = setclipboard,
        getclipboard = getclipboard,

        -- Network (these two are globals; HttpGet/HttpPost live on `game`)
        request = request,
        http_request = http_request,

        -- Gui
        gethui = gethui,
        protectgui = protectgui,
        unprotectgui = unprotectgui,
        getcustomasset = getcustomasset,
        cleardrawcache = cleardrawcache,

        -- Signals
        getconnections = getconnections,
        firesignal = firesignal,
        getcallbackvalue = getcallbackvalue,

        -- Crypto
        crypt = crypt,
        base64_encode = base64_encode,
        base64_decode = base64_decode,
        sha256 = sha256,
        hmac = hmac,

        -- Threads
        setthreadidentity = setthreadidentity,
        getthreadidentity = getthreadidentity,
        getidentity = getidentity,

        -- Misc
        identifyexecutor = identifyexecutor,
        getexecutorname = getexecutorname,
        getversion = getversion,
        setfpscap = setfpscap,
        getfpscap = getfpscap,
        queue_on_teleport = queue_on_teleport,
    }
end

local lookup: { [string]: any } = {}

local function resolve(name: string): any
    local direct = lookup[name]

    if direct ~= nil then
        return direct
    end

    -- A couple of these live on `game` rather than in the global environment.
    if name == "HttpGet" or name == "HttpPost" then
        local ok, method = pcall(function()
            return (game :: any)[name]
        end)

        if ok then
            return method
        end
    end

    return nil
end

local function callable(value: any): boolean
    return type(value) == "function"
end

-- Resolves alias groups, so a script can call whichever name the executor uses.
local function buildAliasMap(): { [string]: string }
    local map = {}

    for _, group in ALIASES do
        for _, name in group do
            for _, candidate in group do
                if callable(resolve(candidate)) then
                    map[name] = candidate
                    break
                end
            end
        end
    end

    return map
end

-- ─────────────────────────────────────────────────────────────────────── scan

export type Report = {
    executor: string,
    total: number,
    supported: number,
    percent: number,
    categories: { [string]: { name: string, supported: boolean, unreliable: boolean } },
    missing: { string },
    aliases: { [string]: string },
}

function UNC.Scan(): Report
    -- Refresh first: the lookup is built here rather than at load so a
    -- re-scan after Invalidate() sees anything defined in the meantime.
    lookup = buildLookup()

    local aliases = buildAliasMap()
    local categories = {}
    local missing = {}
    local total, supported = 0, 0

    for category, names in CATEGORIES do
        local entries = {}

        for _, name in names do
            total += 1

            -- An alias group is satisfied by whichever member exists.
            local target = aliases[name] or name
            local present = callable(resolve(target))

            if present then
                supported += 1
            else
                table.insert(missing, name)
            end

            table.insert(entries, {
                name = name,
                supported = present,
                unreliable = UNRELIABLE[name] == true,
            })
        end

        categories[category] = entries
    end

    -- Executor name, best effort.
    local executor = "unknown"

    for _, name in { "identifyexecutor", "getexecutorname" } do
        local fn = resolve(name)

        if callable(fn) then
            local ok, value = pcall(fn)

            if ok and type(value) == "string" and value ~= "" then
                executor = value
                break
            end
        end
    end

    return {
        executor = executor,
        total = total,
        supported = supported,
        percent = total > 0 and math.floor(supported / total * 100) or 0,
        categories = categories,
        missing = missing,
        aliases = aliases,
    }
end

-- ────────────────────────────────────────────────────────────────── helpers

local report: Report? = nil

local function current(): Report
    if report == nil then
        report = UNC.Scan()
    end

    return report
end

function UNC.Has(name: string): boolean
    return callable(resolve(current().aliases[name] or name))
end

-- Returns the function, or nil plus a reason suitable for showing a user.
function UNC.Get(name: string): (any, string?)
    local target = current().aliases[name] or name
    local fn = resolve(target)

    if callable(fn) then
        return fn
    end

    return nil, `{name} is not available in {current().executor}`
end

function UNC.Missing(): { string }
    return current().missing
end

function UNC.Executor(): string
    return current().executor
end

-- The categories this executor has in full. Useful for deciding which features
-- to show at all, rather than showing them and failing on click.
function UNC.CompleteCategories(): { string }
    local complete = {}

    for category, entries in current().categories do
        local allPresent = true

        for _, entry in entries do
            if not entry.supported then
                allPresent = false
                break
            end
        end

        if allPresent then
            table.insert(complete, category)
        end
    end

    table.sort(complete)
    return complete
end

function UNC.Invalidate()
    report = nil
end

-- ─────────────────────────────────────────────────────────────────── report

local function line(text: string)
    print(text)
end

function UNC.Print(target: Report?)
    local data = target or current()

    line("")
    line("  Abyssal - executor capability report")
    line(`  executor: {data.executor}   unctest v{UNC.Version}`)
    line(`  {data.supported}/{data.total} functions present ({data.percent}%)`)
    line("  " .. string.rep("-", 54))

    -- Sort categories so output is stable between runs; Lua table order is not.
    local names = {}

    for category in data.categories do
        table.insert(names, category)
    end

    table.sort(names)

    for _, category in names do
        local entries = data.categories[category]
        local have = 0

        for _, entry in entries do
            if entry.supported then
                have += 1
            end
        end

        line(`  {category}  ({have}/{#entries})`)

        for _, entry in entries do
            local mark = entry.supported and "yes" or "NO "

            -- Flag the ones where a presence check is not a promise.
            local note = ""

            if entry.supported and entry.unreliable then
                note = "   <- declared; behaviour unverified"
            end

            local alias = data.aliases[entry.name]

            if alias and alias ~= entry.name then
                note = `   <- provided as {alias}`
            end

            line(`    [{mark}] {entry.name}{note}`)
        end

        line("")
    end

    if #data.missing > 0 then
        line(`  Missing ({#data.missing}): {table.concat(data.missing, ", ")}`)
    else
        line("  Everything in the list is present.")
    end

    line("")
    line("  Presence is not behaviour. Anything marked 'declared' can still throw")
    line("  when called - test it before relying on it.")
    line("")
end

-- ───────────────────────────────────────────────────────────────────── main

UNC.Print()

return UNC
