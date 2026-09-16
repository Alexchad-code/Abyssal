--[[
    core/Http.luau

    Thin wrapper over the executor's HTTP surface.

    Executors differ in what they expose, so this probes for the best available
    option rather than assuming one. Everything is pcall'd: a hub that cannot
    reach the network should still open its UI and report the failure, not die
    on boot.
]]

local Http = {}
Http.__index = Http

export type Http = typeof(setmetatable(
    {} :: {
        _cache: { [string]: string },
        _timeout: number,
    },
    Http
))

local function isFunction(value: any): boolean
    return type(value) == "function"
end

-- Prefers request() when present, because it reports status codes instead of
-- throwing on a 404 the way HttpGet does.
local function fetch(url: string): (boolean, string)
    if isFunction(request) then
        local ok, response = pcall(request, {
            Url = url,
            Method = "GET",
        })

        if ok and type(response) == "table" and response.StatusCode == 200 then
            return true, response.Body or ""
        end
    end

    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)

    if ok and type(body) == "string" then
        return true, body
    end

    return false, tostring(body)
end

function Http.new(): Http
    return setmetatable({
        _cache = {},
        _timeout = 15,
    }, Http)
end

function Http:Get(url: string, useCache: boolean?): (boolean, string)
    assert(type(url) == "string" and url ~= "", "Http:Get expects a url")

    if useCache ~= false and self._cache[url] ~= nil then
        return true, self._cache[url]
    end

    local ok, body = fetch(url)

    if ok and useCache ~= false then
        self._cache[url] = body
    end

    return ok, body
end

function Http:GetJson(url: string, useCache: boolean?): (boolean, any)
    local ok, body = self:Get(url, useCache)

    if not ok then
        return false, body
    end

    local decodeOk, decoded = pcall(function()
        return game:GetService("HttpService"):JSONDecode(body)
    end)

    if not decodeOk then
        return false, `invalid JSON from {url}: {tostring(decoded)}`
    end

    return true, decoded
end

function Http:ClearCache()
    table.clear(self._cache)
end

return Http
