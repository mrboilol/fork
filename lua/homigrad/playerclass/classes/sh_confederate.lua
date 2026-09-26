local CLASS = player.RegClass("confederate")

function CLASS.Off(self)
    if CLIENT then return end
end


local models = {
    "models/humans/civilwar/male_06.mdl",
    "models/humans/civilwar/male_07.mdl",
    "models/humans/civilwar/male_08.mdl",
    "models/humans/civilwar/male_09.mdl"
}



function CLASS.On(self)
    if CLIENT then return end
    ApplyAppearance(self,nil,nil,nil,true)
    local Appearance = self.CurAppearance or hg.Appearance.GetRandomAppearance()

    local model = models[math.random(#models)]
    local hasCivilWarModel = util.IsValidModel(model)
    self:SetModel(hasCivilWarModel and model or "models/player/group03/male_06.mdl")
    Appearance.AAttachments = "none"
    self:SetNetVar("Accessories", "none")
    if hasCivilWarModel then self:SetBodygroup(0,9) end

    self:SetSubMaterial()
    Appearance.AColthes = ""
self:SetPlayerColor(Color(184, 31, 31):ToVector())



    self.CurAppearance = Appearance
end
