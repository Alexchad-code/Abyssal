local UNC = {}

UNC.Version = "1.0.0"

local CATEGORIES = {
    Environment = {
        "getgenv", "getrenv", "getreg", "getgc", "getgcinfo",
        "getsenv", "getmenv", "getfenv", "setfenv", "loadstring",
    },

    Instances = {
        "getinstances", "getnilinstances", "getloadedmodules",
        "cloneref", "compareinstances", "isvalid", "iscached",
        "fireclickdetector", "fireproximityprompt", "firetouchinterest",
        "isrenderobj", "getrenderproperty", "setrenderproperty",
    },

    Hooking = {
        "getrawmetatable", "setrawmetatable", "hookmetamethod", "hookfunction",
        "restorefunction", "replaceclosure", "clonefunction",
        "newcclosure", "newlclosure", "iscclosure", "islclosure",
        "checkclosure", "isexecutorclosure",
        "getnamecallmethod", "setnamecallmethod", "getcallingscript",
        "setreadonly", "isreadonly", "checkcaller",
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

    Mouse = {
        "mousemoverel", "mousemoveabs",
        "mouse1click", "mouse1press", "mouse1release",
        "mouse2click", "mouse2press", "mouse2release",
    },

    Input = {
        "keypress", "keyrelease", "iskeydown",
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
        "getspecialinfo", "geturl",
    },
}

local UNRELIABLE = {

    hookfunction = true,
    hookmetamethod = true,
    setreadonly = true,

    request = true,
    http_request = true,

    decompile = true,
    getscriptbytecode = true,

    getsenv = true,
    getmenv = true,

    isrenderobj = true,
    getrenderproperty = true,
    setrenderproperty = true,

    mousemoverel = true,
    mousemoveabs = true,
    keypress = true,
    keyrelease = true,

    firetouchinterest = true,

    getspecialinfo = true,
    geturl = true,
}

local ALIASES = {
    { "request", "http_request" },
    { "base64_encode", "base64encode" },
    { "base64_decode", "base64decode" },
    { "getidentity", "getthreadidentity" },
    { "HttpGet", "httpget" },
    { "HttpPost", "httppost" },
}

local function buildLookup(): { [string]: any }
    return {

        getgenv = getgenv,
        getrenv = getrenv,
        getreg = getreg,
        getgc = getgc,
        getgcinfo = getgcinfo,
        getsenv = getsenv,
        getmenv = getmenv,
        getfenv = getfenv,
        setfenv = setfenv,
        loadstring = loadstring,

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
        isrenderobj = isrenderobj,
        getrenderproperty = getrenderproperty,
        setrenderproperty = setrenderproperty,

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
        setreadonly = setreadonly,
        isreadonly = isreadonly,
        checkcaller = checkcaller,

        getscriptbytecode = getscriptbytecode,
        getscripthash = getscripthash,
        getscriptclosure = getscriptclosure,
        getscripts = getscripts,
        getrunningscripts = getrunningscripts,
        decompile = decompile,

        getupvalue = getupvalue,
        setupvalue = setupvalue,
        getupvalues = getupvalues,
        getconstants = getconstants,
        getprotos = getprotos,

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

        setclipboard = setclipboard,
        getclipboard = getclipboard,

        request = request,
        http_request = http_request,

        gethui = gethui,
        protectgui = protectgui,
        unprotectgui = unprotectgui,
        getcustomasset = getcustomasset,
        cleardrawcache = cleardrawcache,

        getconnections = getconnections,
        firesignal = firesignal,
        getcallbackvalue = getcallbackvalue,

        mousemoverel = mousemoverel,
        mousemoveabs = mousemoveabs,
        mouse1click = mouse1click,
        mouse1press = mouse1press,
        mouse1release = mouse1release,
        mouse2click = mouse2click,
        mouse2press = mouse2press,
        mouse2release = mouse2release,

        keypress = keypress,
        keyrelease = keyrelease,
        iskeydown = iskeydown,

        crypt = crypt,
        base64_encode = base64_encode,
        base64_decode = base64_decode,
        sha256 = sha256,
        hmac = hmac,

        setthreadidentity = setthreadidentity,
        getthreadidentity = getthreadidentity,
        getidentity = getidentity,

        identifyexecutor = identifyexecutor,
        getexecutorname = getexecutorname,
        getversion = getversion,
        setfpscap = setfpscap,
        getfpscap = getfpscap,
        queue_on_teleport = queue_on_teleport,
        getspecialinfo = getspecialinfo,
        geturl = geturl,
    }
end

local lookup: { [string]: any } = {}

local function resolve(name: string): any
    local direct = lookup[name]

    if direct ~= nil then
        return direct
    end

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

    lookup = buildLookup()

    local aliases = buildAliasMap()
    local categories = {}
    local missing = {}
    local total, supported = 0, 0

    for category, names in CATEGORIES do
        local entries = {}

        for _, name in names do
            total += 1

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

function UNC.Categories(): { string }
    local names = {}

    for category in current().categories do
        table.insert(names, category)
    end

    table.sort(names)

    return names
end

function UNC.Supports(category: string): boolean
    local entries = current().categories[category]

    if entries == nil then
        return false
    end

    for _, entry in entries do
        if not entry.supported then
            return false
        end
    end

    return true
end

function UNC.CompleteCategories(): { string }
    local complete = {}

    for _, category in UNC.Categories() do
        if UNC.Supports(category) then
            table.insert(complete, category)
        end
    end

    return complete
end

function UNC.Invalidate()
    report = nil
end

local function buildReport(data: Report): { string }
    local lines = {}

    local function add(text: string)
        table.insert(lines, text)
    end

    add("")
    add("  Abyssal - executor capability report")
    add(`  executor: {data.executor}   unctest v{UNC.Version}`)
    add(`  {data.supported}/{data.total} functions present ({data.percent}%)`)
    add("  " .. string.rep("-", 54))

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

        add(`  {category}  ({have}/{#entries})`)

        for _, entry in entries do
            local mark = entry.supported and "yes" or "NO "

            local note = ""

            if entry.supported and entry.unreliable then
                note = "   <- declared; behaviour unverified"
            end

            local alias = data.aliases[entry.name]

            if alias and alias ~= entry.name then
                note = `   <- provided as {alias}`
            end

            add(`    [{mark}] {entry.name}{note}`)
        end

        add("")
    end

    if #data.missing > 0 then
        add(`  Missing ({#data.missing}): {table.concat(data.missing, ", ")}`)
    else
        add("  Everything in the list is present.")
    end

    add("")
    add("  Presence is not behaviour. Anything marked 'declared' can still throw")
    add("  when called - test it before relying on it.")
    add("")

    return lines
end

function UNC.Report(target: Report?): string
    return table.concat(buildReport(target or current()), "\n")
end

function UNC.Summary(): string
    local data = current()

    return `{data.executor}: {data.supported}/{data.total} functions ({data.percent}%)`
end

function UNC.Print(target: Report?)
    print(UNC.Report(target))
end

return UNC
