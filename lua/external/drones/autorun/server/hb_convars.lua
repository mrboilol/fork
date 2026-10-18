AddCSLuaFile()

if GetConVar("hb_easyuse") == nil then
	CreateConVar("hb_easyuse", "1", { FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY } )
end

if GetConVar("hb_fragility") == nil then
	CreateConVar("hb_fragility", "1", {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY } )
end
if GetConVar("hb_nuclear_emp") == nil then
	CreateConVar("hb_nuclear_emp", "1", { FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY } )
end
if GetConVar("hb_safeemp") == nil then
	CreateConVar("hb_safeemp", "1", { FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY } )
end
if GetConVar("hb_nuclear_vaporisation") == nil then
	CreateConVar("hb_nuclear_vaporisation", "1", { FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY } )
end
if GetConVar("hb_shockwave_unfreeze") == nil then
	CreateConVar("hb_shockwave_unfreeze", "1", { FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY } )
end
if GetConVar("hb_decals") == nil then
	CreateConVar("hb_decals", "1", { FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY } )
end
if GetConVar("hb_realistic_sound") == nil then
	CreateConVar("hb_realistic_sound", "1", { FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY } )
end
if GetConVar("hb_sound_shake") == nil then
	CreateConVar("hb_sound_shake", "1", { FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY } )
end
if GetConVar("hb_nuclear_fallout") == nil then
	CreateConVar("hb_nuclear_fallout", "1", { FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY } )
end