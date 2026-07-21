if SERVER then
    AddCSLuaFile()
    CreateConVar("hg_subrosa", "0", FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED, "Use the bone-only Sub Rosa health indicator.", 0, 1)
end
