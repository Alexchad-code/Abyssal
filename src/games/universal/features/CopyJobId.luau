--[[
    games/universal/features/CopyJobId.luau

    Copies the current server's JobId to the clipboard.

    The JobId is the only reliable way to get back to a specific server, and
    Roblox does not surface it anywhere in the client UI. Small feature, but
    it is the one people ask for first.
]]

local Action = require("core/Action")

local CopyJobId = Action.new({
    Id = "universal.copyJobId",
    Name = "Copy Job ID",
    Description = "Copy this server's JobId to the clipboard.",
    Tooltip = "JobId identifies this exact server. Useful for rejoining it later.",
    Group = "Server",
    Side = "Left",
})

function CopyJobId:OnClick()
    local ctx = self._ctx
    local jobId = game.JobId

    if jobId == nil or jobId == "" then
        ctx.ui:Notify({
            Title = "Abyssal",
            Text = "JobId is unavailable in this server.",
            Duration = 4,
        })

        return
    end

    local copied = pcall(function()
        setclipboard(jobId)
    end)

    ctx.ui:Notify({
        Title = "Abyssal",
        Text = copied and `Copied JobId: {jobId}` or `JobId: {jobId}`,
        Duration = 5,
    })

    self._log:Info(`job id {jobId}`)
end

return CopyJobId
