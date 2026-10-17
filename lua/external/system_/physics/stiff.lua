RagdollStiffener = {}

function RagdollStiffener.Remove(ent)
    if not IsValid(ent) then return end
    
    if ent.StiffnessConstraints then
        for _, c in pairs(ent.StiffnessConstraints) do
            if IsValid(c) then c:Remove() end
        end
        ent.StiffnessConstraints = nil
    end
end

function RagdollStiffener.Apply(ent, stiffnessAmount)
    if not IsValid(ent) then return end
    
    RagdollStiffener.Remove(ent)
    
    local physCount = ent:GetPhysicsObjectCount()
    if physCount <= 1 then return end
    
    ent.StiffnessConstraints = {}
    
    local minAngle = -230
    local maxAngle = 230
    
    local friction = 0
    
    for i = 1, physCount - 1 do
        local phys = ent:GetPhysicsObjectNum(i)
        
        if IsValid(phys) then
            local bonePos = ent:GetBonePosition(ent:TranslatePhysBoneToBone(i))
            local localPos = ent:WorldToLocal(bonePos)
            
            local constraintEnt = constraint.AdvBallsocket(
                ent, ent,
                0, i,
                Vector(0,0,0), localPos,
                0,
                0,
                minAngle, minAngle, minAngle,
                maxAngle, maxAngle, maxAngle,
                friction, friction, friction,
                0,
                1
            )
            
            if IsValid(constraintEnt) then
                table.insert(ent.StiffnessConstraints, constraintEnt)
            end
            
            phys:SetDamping(0, 0)
            phys:SetMass(phys:GetMass() * 0.5)
        end
    end
end