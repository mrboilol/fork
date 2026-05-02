local hg_showinfo = CreateClientConVar("hg_showinfo", "0", true, true, "Show status info messages")

hg.status_messages = hg.status_messages or {}
local messages = {}

net.Receive("hg_status_message", function()
    local message = net.ReadString()
    local severity = net.ReadUInt(4)

    local entry = {
        text = message,
        severity = severity,
        startTime = CurTime(),
        endTime = CurTime() + 5,
        alpha = 255,
        x = ScrW() / 2,
        y = 50,
        shake = 0
    }

    if severity >= 3 then
        entry.shake = severity * 2
    end

    table.insert(messages, 1, entry)

    if #messages > 5 then
        table.remove(messages, 6)
    end
end)

hook.Add("HUDPaint", "hg_status_messages_paint", function()
    if not hg_showinfo:GetBool() then return end
    local currentTime = CurTime()
    local yPos = 50

    for i, msg in ipairs(messages) do
        if currentTime > msg.endTime then
            msg.alpha = math.max(msg.alpha - FrameTime() * 255, 0)
        end

        if msg.alpha <= 0 then
            table.remove(messages, i)
            continue
        end

        local color = Color(255, 255, 255, msg.alpha)
        if msg.severity == 2 then
            color = Color(255, 255, 0, msg.alpha)
        elseif msg.severity == 3 then
            color = Color(255, 165, 0, msg.alpha)
        elseif msg.severity >= 4 then
            color = Color(255, 0, 0, msg.alpha)
        end

        local x = msg.x
        if msg.shake > 0 then
            x = x + math.random(-msg.shake, msg.shake)
            msg.shake = math.max(msg.shake - FrameTime() * 10, 0)
        end

        surface.CreateFont("StatusFont", {
    font = "Roboto",
    size = 26,
    weight = 500,
})

draw.SimpleText(msg.text, "StatusFont", x, yPos, color, TEXT_ALIGN_CENTER)
        yPos = yPos + 20
    end
end)

-- Add a font for the status messages
-- This should be a more visible font, but for now, we'll use a default one.
-- You can change "HudFontSmall" to any font you have in your game.
-- surface.CreateFont("StatusFont", {
--     font = "Roboto",
--     size = 24,
--     weight = 500,
-- })
