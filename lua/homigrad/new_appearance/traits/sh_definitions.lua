local Traits = hg.Traits

local function Register(id, data)
	Traits.Register(id, data)
end

Register("apathetic", {Name = "Apathetic", Description = "You dont feel the need to panic or be stressed.", Category = "positive", Points = 2, SortOrder = 10, Modifiers = {panic_gain = 0.35, pain_tolerance = 1.15}})
Register("adrenaline_junkie", {Name = "Adrenaline Junkie", Description = "Minor danger lost its luster, but you get a better grip when on a fight or flight response.", Category = "positive", Points = 2, SortOrder = 20, Modifiers = {trivial_adrenaline = 0.35, combat_adrenaline = 1.8, pain_tolerance = 1.15}})
Register("sprinter", {Name = "Sprinter", Description = "You move much faster and get less tired from it.", Category = "positive", Points = 3, SortOrder = 30, Modifiers = {sprint_stamina_cost = 0.45, movement_speed = 1.28, headbob = 1.4}, AmputationLimbPool = {"larm", "rarm"}})
Register("endurant", {Name = "Endurant", Description = "You are naturally more tolerant to exhausting tasks and pain.", Category = "positive", Points = 3, SortOrder = 40, Modifiers = {stamina_cost = 0.72, pain_received = 0.8, pain_tolerance = 1.25, trauma_resistance = 1.2, bone_damage = 0.82}})
Register("strong", {Name = "Strong", Description = "You are naturally stronger than others. You could wrestle hunters if you wanted to.", Category = "positive", Points = 3, SortOrder = 50, Modifiers = {melee_damage = 1.35, weapon_handling = 0.88, pain_tolerance = 1.15, kick_force = 1.3}})
Register("hunter", {Name = "Hunter", Description = "You have more experience with weapons and tracking.", Category = "positive", Points = 3, SortOrder = 60, Modifiers = {weapon_handling = 0.78, reload_speed = 0.82, gun_accuracy = 0.82}})
Register("biologically_efficient", {Name = "Biologically Efficient", Description = "Your body handles trauma and regenerating much more better than others.", Category = "positive", Points = 3, SortOrder = 70, Modifiers = {clotting = 1.4, bleeding = 0.82, blood_regeneration = 1.35, internal_bleed = 0.7, internal_bleed_recovery = 1.5, organ_damage = 0.82, trauma_resistance = 1.2}})
Register("prepared", {Name = "Prepared", Description = "Spawn with three random things.", Category = "positive", Points = 2, SortOrder = 80})
Register("skin_and_bones", {Name = "Thick Skinned", Description = "You are more resistant to damage, both internally and externally.", Category = "positive", Points = 2, SortOrder = 90, Modifiers = {organ_damage = 0.78, internal_bleed = 0.82, bleeding = 0.8}})
Register("vibrams", {Name = "vibram ones", Description = "Your excellent outsole provides superior traction and balance.", Category = "positive", Points = 3, SortOrder = 100, Modifiers = {slip_chance = 0.2, terrain_trip_chance = 0.42, collision_trip_chance = 0.5, climb_stamina_cost = 0.62, climb_force = 1.22}})

Register("paraplegic", {Name = "Paraplegic", Description = "You cant move your legs.", Category = "negative", Points = 5, SortOrder = 10, AmputationLimbPool = {"larm", "rarm"}})
Register("blind", {Name = "Blind", Description = "You cant see, but you got used to it.", Category = "negative", Points = 4, SortOrder = 20})
Register("anemic", {Name = "Anemic", Description = "You naturally have less red blood cells.", Category = "negative", Points = 2, SortOrder = 30, Bonuses = {blood_capacity = -1000}})
Register("stormtrooper", {Name = "Stormtrooper", Description = "You have ass aim.", Category = "negative", Points = 2, SortOrder = 40, Modifiers = {weapon_handling = 1.75, gun_accuracy = 2.2}})
Register("kirk", {Name = "Kirk", Description = "Your neck is weak.", Category = "negative", Points = 3, SortOrder = 50, Modifiers = {artery_damage = 1.75}})
Register("hemolytic_anemia", {Name = "Hemolytic Anemia", Description = "Your blood cells break down faster than your body can replace them.", Category = "negative", Points = 3, SortOrder = 60})
Register("clumsy", {Name = "Clumsy", Description = "just a silly gubby", Category = "negative", Points = 4, SortOrder = 70, Modifiers = {weapon_handling = 1.8}})
Register("deaf", {Name = "Deaf", Description = "You cannot hear sounds or speech.", Category = "negative", Points = 2, SortOrder = 80})
Register("pushover", {Name = "Pushover", Description = "You let people push you around too easily.", Category = "negative", Points = 2, SortOrder = 90})
Register("wimp", {Name = "Wimp", Description = "You are more prone to pain.", Category = "negative", Points = 3, SortOrder = 100, Modifiers = {pain_received = 1.75, trauma_resistance = 0.72}})
Register("amputee", {Name = "Amputee", Description = "Spawn without one limb.", Category = "negative", Points = 3, SortOrder = 110})
Register("frail", {Name = "Frail", Description = "You are easily wounded.", Category = "negative", Points = 3, SortOrder = 120, Modifiers = {bone_damage = 1.4, bleeding = 1.3}})
Register("weak", {Name = "Weak", Description = "You are physically weak.", Category = "negative", Points = 2, SortOrder = 130, Modifiers = {melee_damage = 0.7, weapon_handling = 1.25}})
Register("slow", {Name = "Slow", Description = "You walk, jog, and run more slowly.", Category = "negative", Points = 2, SortOrder = 140, Modifiers = {movement_speed = 0.74}})
Register("naturally_hypertensive", {Name = "Naturally Hypertensive", Description = "You are more prone to heart and brain problems when stressed.", Category = "negative", Points = 3, SortOrder = 150})
Register("john", {Name = "John", Description = "old homigrad trauma health system experience", Category = "negative", Points = 12, SortOrder = 160, Bonuses = {blood_capacity = -1000}, Modifiers = {melee_damage = 0.7, weapon_handling = 1.75, pain_received = 1.75, trauma_resistance = 0.72, bone_damage = 1.4, bleeding = 1.3, movement_speed = 0.74, trivial_adrenaline = 1.15, panic_gain = 1.5, gun_accuracy = 2.2}})

if CLIENT then
	hook.Add("EntityEmitSound", "HGTraitsDeaf", function(data)
		local ply = LocalPlayer()
		if IsValid(ply) and ply:HasTrait("deaf") then return false end
		if IsValid(ply) and ply:HasTrait("john") then data.Volume = (data.Volume or 1) * 0.3 end
	end)

	hook.Add("RenderScreenspaceEffects", "HGTraitsJohnVision", function()
		local ply = LocalPlayer()
		if IsValid(ply) and ply:Alive() and ply:HasTrait("john") and not ply:HasTrait("blind") then DrawMotionBlur(0.05, 0.08, 0.01) end
	end)
end
