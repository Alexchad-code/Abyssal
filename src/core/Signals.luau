--[[
    core/Signals.luau

    Minimal synchronous event bus.

    Handlers run in registration order. A handler that errors is reported and
    skipped rather than allowed to break the remaining handlers, because a
    failing feature should never take the whole hub down with it.
]]

local Signals = {}
Signals.__index = Signals

export type Handler = (...any) -> ()

export type Connection = {
    Connected: boolean,
    Disconnect: (self: Connection) -> (),
}

export type Signal = typeof(setmetatable(
    {} :: {
        _handlers: { Handler },
        _connections: { Connection },
    },
    Signals
))

function Signals.new(): Signal
    return setmetatable({
        _handlers = {},
        _connections = {},
    }, Signals)
end

function Signals:Connect(handler: Handler): Connection
    assert(type(handler) == "function", "Signals:Connect expects a function")

    -- Captured explicitly. Disconnect is called as connection:Disconnect(), so
    -- inside it `self` is the connection, not the signal — reaching for
    -- self._handlers there would look on the wrong table.
    local signal = self

    local connection: Connection

    connection = {
        Connected = true,
        Disconnect = function(self: Connection)
            if not self.Connected then
                return
            end

            self.Connected = false

            local handlerIndex = table.find(signal._handlers, handler)
            if handlerIndex then
                table.remove(signal._handlers, handlerIndex)
            end

            local connectionIndex = table.find(signal._connections, self)
            if connectionIndex then
                table.remove(signal._connections, connectionIndex)
            end
        end,
    }

    table.insert(self._handlers, handler)
    table.insert(self._connections, connection)

    return connection
end

-- Fires synchronously. Handlers are snapshotted first so that a handler which
-- connects or disconnects during dispatch does not disturb this pass.
function Signals:Fire(...: any)
    local snapshot = table.clone(self._handlers)

    for _, handler in snapshot do
        local ok, err = pcall(handler, ...)

        if not ok then
            warn(("[Abyssal] signal handler error: %s"):format(tostring(err)))
        end
    end
end

-- Same as Fire, but yields to the scheduler first. Use for anything that
-- touches instances or yields, so the caller is never blocked.
function Signals:FireDeferred(...: any)
    local args = table.pack(...)

    task.defer(function()
        self:Fire(table.unpack(args, 1, args.n))
    end)
end

function Signals:DisconnectAll()
    for _, connection in table.clone(self._connections) do
        connection:Disconnect()
    end

    table.clear(self._handlers)
    table.clear(self._connections)
end

function Signals:GetHandlerCount(): number
    return #self._handlers
end

return Signals
