local CLASS = player.RegClass("north")
 
function CLASS.Off(self)
    if CLIENT then return end
end


local models = {
    "models/humans/civilwar/male_01.mdl",
	"models/humans/civilwar/male_02.mdl",
	"models/humans/civilwar/male_03.mdl",
	"models/humans/civilwar/male_04.mdl"
}

 
 
function CLASS.On(self)
    if CLIENT then return end
    ApplyAppearance(self,nil,nil,nil,true)
    local Appearance = self.CurAppearance or hg.Appearance.GetRandomAppearance()
    
    local model = models[math.random(#models)]
    local hasCivilWarModel = util.IsValidModel(model)
    self:SetModel(hasCivilWarModel and model or "models/player/group03/male_01.mdl")
    Appearance.AAttachments = "none"
    self:SetNetVar("Accessories", "none")
    if hasCivilWarModel then self:SetBodygroup(0,9) end
 
    self:SetSubMaterial()
    Appearance.AColthes = ""
self:SetPlayerColor(Color(127,120,255):ToVector())
        
    
    
    self.CurAppearance = Appearance
end
