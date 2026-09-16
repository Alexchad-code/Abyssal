--[[
    tools/tests/mock.luau

    A minimal Roblox environment, enough to load and exercise the core modules
    under a standalone Luau interpreter. This is not a Roblox emulator — it
    stubs exactly the surface the hub touches, and nothing more.

    install() must run before any hub module is required, because several
    modules call game:GetService at file scope.
]]

local Mock = {}

Mock.installed = false

local function noop() end

local function makeSignal()
    return {
        Connect = function(_self, _fn)
            return { Disconnect = noop }
        end,
        Wait = noop,
    }
end

local Services = {}

local function registerService(name: string, impl: any)
    Services[name] = impl
end

function Mock.install()
    if Mock.installed then
        return
    end

    -- ---------------------------------------------------------------- task --

    local task = {
        wait = function(duration: number?)
            -- Never actually yield: tests want deterministic ordering, not
            -- real time.
            return duration or 0
        end,
        spawn = function(fn: (...any) -> (), ...: any)
            fn(...)
        end,
        defer = function(fn: (...any) -> (), ...: any)
            fn(...)
        end,
        delay = function(_duration: number, fn: (...any) -> (), ...: any)
            fn(...)
        end,
        cancel = noop,
    }

    -- ------------------------------------------------------------ services --

    registerService("RunService", {
        IsStudio = function()
            return false
        end,
        Heartbeat = makeSignal(),
        PreSimulation = makeSignal(),
        PostSimulation = makeSignal(),
        RenderStepped = makeSignal(),
    })

    registerService("MarketplaceService", {
        GetProductInfo = function()
            return { Name = "Mock Place" }
        end,
    })

    registerService("Players", {
        LocalPlayer = {
            Name = "MockPlayer",
            UserId = 1,
        },
    })

    registerService("TeleportService", {
        TeleportToPlaceInstance = noop,
    })

    registerService("HttpService", {
        JSONDecode = function(_self, body: string)
            -- Enough for the shapes the hub actually parses.
            if body == "[]" then
                return {}
            end
            return { data = {} }
        end,
    })

    registerService("Stats", {
        Network = {
            ServerStatsItem = {
                ["Data Ping"] = {
                    GetValue = function()
                        return 42
                    end,
                },
            },
        },
    })

    registerService("ReplicatedStorage", {
        WaitForChild = function()
            return nil
        end,
    })

    registerService("CollectionService", {})
    registerService("UserInputService", {})

    -- ----------------------------------------------------------------- game --

    local gameTable = {
        PlaceId = 12345,
        GameId = 999,
        JobId = "mock-job-id",
        CreatorId = 1,
        CreatorType = "User",

        IsLoaded = function()
            return true
        end,

        Loaded = { Wait = noop },

        GetService = function(_self, name: string)
            local service = Services[name]

            if service == nil then
                -- Return an empty table rather than erroring, so a service the
                -- hub touches incidentally does not fail the whole harness.
                service = {}
                Services[name] = service
            end

            return service
        end,
    }

    -- -------------------------------------------------------------- globals --

    local globalEnv = getfenv and getfenv(0) or _G

    globalEnv.game = gameTable
    globalEnv.task = task
    globalEnv.workspace = { CurrentCamera = nil }

    if globalEnv.warn == nil then
        globalEnv.warn = function(...: any)
            print("[warn]", ...)
        end
    end

    if globalEnv.getgenv == nil then
        globalEnv.getgenv = function()
            return globalEnv
        end
    end

    if globalEnv.setclipboard == nil then
        globalEnv.setclipboard = noop
    end

    if globalEnv.request == nil then
        globalEnv.request = nil
    end

    if globalEnv.Enum == nil then
        globalEnv.Enum = {
            CreatorType = { User = "User", Group = "Group" },
            InfoType = { Asset = "Asset" },
        }
    end

    -- HttpGet is what core/Http falls back to when request is unavailable.
    globalEnv.game.HttpGet = function()
        return "[]"
    end

    Mock.installed = true
end

return Mock
