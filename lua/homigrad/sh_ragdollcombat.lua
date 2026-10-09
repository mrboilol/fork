local ragdollCombat = GetConVar("hg_ragdollcombat") or CreateConVar(
	"hg_ragdollcombat",
	"0",
	FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED,
	"this is very wip dont turn this on",
	0,
	1
)

function hg.RagdollCombatEnabled()
	return ragdollCombat:GetBool()
end

function hg.RagdollCombatInUse(ply)
	return hg.RagdollCombatEnabled() and IsValid(ply) and IsValid(ply.FakeRagdoll)
end
