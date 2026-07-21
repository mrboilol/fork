util.AddNetworkString("hg_adrenalinemusic_panic")

CreateConVar(
	"hg_adrenalinemusic",
	"1",
	{FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED},
	"Enable adrenaline combat music for all players.",
	0,
	1
)

function hg.AddAdrenalineMusicPanic(ply, amount)
	net.Start("hg_adrenalinemusic_panic")
		net.WriteFloat(amount)
	net.Send(ply)
end

hook.Add("HomigradDamage", "hg_adrenalinemusic_panic_sv", function(ply, dmgInfo, hitgroup, ent, harm, hitBoxs, inputHole)
	if not IsValid(ply) or not ply:IsPlayer() then return end

	local damageType = dmgInfo:GetDamageType()
	if damageType == DMG_FALL or damageType == DMG_BURN or damageType == DMG_SLOWBURN then return end

	local damage = dmgInfo:GetDamage()
	if damage <= 0 then return end

	hg.AddAdrenalineMusicPanic(ply, damage * 25)

	local attacker = dmgInfo:GetAttacker()
	if IsValid(attacker) and attacker:IsPlayer() then
		hg.AddAdrenalineMusicPanic(attacker, damage * 5)
	end
end)
