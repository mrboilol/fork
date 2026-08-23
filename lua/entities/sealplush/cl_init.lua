include("shared.lua")

local function UpdatePickupHint(self)
    local alive = self:GetNW2Bool("SealAlive", true)
    if self.SealPickupHintAlive == alive then return end
    self.SealPickupHintAlive = alive

    if alive then
        local use = string.upper(input.LookupBinding("+use") or "E")
        self.HudHintMarkup = markup.Parse(
            "<font=ZCity_Tiny>Seal Plush</font>\n" ..
            "<font=ZCity_SuperTiny><colour=125,125,125>" .. use .. " to pickup</colour></font>",
            450
        )
    else
        self.HudHintMarkup = markup.Parse("<font=ZCity_Tiny>this seal is dead</font>", 450)
    end
end

function ENT:Initialize()
    UpdatePickupHint(self)
end

function ENT:Think()
    UpdatePickupHint(self)
end

function ENT:Draw()
    self:DrawModel()
end
