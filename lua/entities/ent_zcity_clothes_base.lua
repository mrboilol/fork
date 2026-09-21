-- meow

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "ent_zcity_equipment_base"
ENT.PrintName = "Equipment base"
ENT.Category = "ZCity Equipment"
ENT.Spawnable = false
ENT.Model = "models/props_junk/cardboard_box003a.mdl"
ENT.IconOverride = ""

ENT.SlotOccupation = {
    --[ZC_CLOTHES_SLOT_TORSO] = true,
    --[ZC_CLOTHES_SLOT_PANTS] = true,
    --[ZC_CLOTHES_SLOT_BOOTS] = true,
}

ENT.Male = {}
ENT.Male.Model = ""
ENT.Male.HideSubMaterails = {}
ENT.Male.Skin = 0
ENT.Male.Bodygroups = "0000000000000"

ENT.FeMale = {}
ENT.FeMale.Model = ""
ENT.FeMale.HideSubMaterails = {}
ENT.FeMale.Skin = 0
ENT.FeMale.Bodygroups = "0000000000000"

ENT.PhysicsSounds = true

ENT.NamePos = Vector(12,1.5,4.6)
ENT.NameAng = Angle(0,-90,0)

--\\ Render Equipment
    local vec = Vector(1,1,1)
    function ENT:RenderOnBody(entDrawOn)
        local fem = ThatPlyIsFemale(entDrawOn)

        if !IsValid(self.renderModel) then
            local data = fem and self.FeMale or self.Male
            self.renderModel = ClientsideModel(data.Model, RENDERGROUP_BOTH)

            local model = self.renderModel
            model:SetNoDraw(true)
            model:SetSkin(data.Skin)
            model:SetBodyGroups(data.Bodygroups)
            model:SetParent(entDrawOn)
            model:AddEffects(EF_BONEMERGE)

            if data.ModelSubMaterials then
                for k,v in pairs(data.ModelSubMaterials) do
                    local id = isnumber(k) and k or model:GetSubMaterialIdByName(k)
                    if !id then continue end
                    model:SetSubMaterial(id, v)
                end
            end

            self:CallOnRemove("RemoveEquip",function()
                if IsValid(self.renderModel) then
                    model:Remove()
                    model = nil
                end
            end)
        end

        local model = self.renderModel

        local mdl = string.Split(string.sub(entDrawOn:GetModel(),1,-5),"/")[#string.Split(string.sub(entDrawOn:GetModel(),1,-5),"/")]
        if mdl and model:GetFlexIDByName(mdl) then
            model:SetFlexWeight(model:GetFlexIDByName(mdl),1)
        end

        if model:GetParent() != entDrawOn then model:SetParent(entDrawOn) end

        model:DrawModel()
    end
--//

--\\ Temperature system
    local armorSlotCoverage = {
        [4] = 0.08, [5] = 0.03, [6] = 0.01, [7] = 0.02,
        [8] = 0.30, [9] = 0.06, [10] = 0.05, [11] = 0.06, [12] = 0.05,
        [13] = 0.12, [14] = 0.10, [15] = 0.08, [16] = 0.07, [17] = 0.08, [18] = 0.07
    }
    local armorPlacementCoverage = {
        torso = 0.42,
        head = 0.08,
        face = 0.03,
        ears = 0.02,
        visor = 0.01,
        helmet_jaw = 0.02,
        helmet_ears = 0.02,
        back = 0.12
    }

    local function armorWarmSave(protection, coverage)
        protection = tonumber(protection)
        if !protection or !coverage then return 0 end

        return math.Clamp(coverage * (0.25 + math.Clamp(protection / 20, 0, 1) * 0.75), 0, 0.75)
    end

    local function applyWarmSave(changeRate, MaxWarmMul, warmSave)
        MaxWarmMul = MaxWarmMul + warmSave / 1.5
        changeRate = changeRate * math.max(1 - warmSave, 0.1)

        return changeRate, MaxWarmMul
    end

    hook.Add("ZC_BodyTemperature", "EquipmentSaveTemp", function(ply, org, timeValue, changeRate, MaxWarmMul, warmLoseMul)
        local Equipment = ply:GetNetVar("zc_equipment", {})

        for i = 1, #Equipment do
            local Equip = Entity(Equipment[i])
            if !IsValid(Equip) then continue end

            local warmSave = Equip.WarmSave
            if !warmSave and Equip.Protection then
                local coverage = 0
                for slot in pairs(Equip.SlotOccupation or {}) do
                    coverage = coverage + (armorSlotCoverage[slot] or 0)
                end
                warmSave = armorWarmSave(Equip.Protection, coverage)
            end

            if warmSave and warmSave > 0 then
                changeRate, MaxWarmMul = applyWarmSave(changeRate, MaxWarmMul, warmSave)
            end
        end

        for placement, armor in pairs(ply.armors or {}) do
            local armorData = hg.armor and hg.armor[placement] and hg.armor[placement][armor]
            local warmSave = armorData and armorWarmSave(armorData.protection, armorPlacementCoverage[placement]) or 0
            if warmSave > 0 then
                changeRate, MaxWarmMul = applyWarmSave(changeRate, MaxWarmMul, warmSave)
            end
        end

        return changeRate, MaxWarmMul, warmLoseMul
    end)
--//
