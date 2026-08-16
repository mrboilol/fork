hook.Add("EntityEmitSound", "NoDecalsOnSeal", function(ent, soundName)
    if IsValid(ent) and ent:GetClass() == "seal_toy" then

    end
end)

hook.Add("EntityTakeDamage", "NoDecalsOnSeal", function(target, dmginfo)
    if IsValid(target) and target:GetClass() == "seal_toy" then

        target:RemoveAllDecals()
    end
end)
