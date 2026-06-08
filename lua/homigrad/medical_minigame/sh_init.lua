if SERVER then
    util.AddNetworkString("hg_medical_minigame_start")
    util.AddNetworkString("hg_medical_minigame_progress")
    util.AddNetworkString("hg_medical_minigame_finish")
    util.AddNetworkString("hg_medical_minigame_cancel")
    util.AddNetworkString("hg_medical_minigame_request_amputation")
    util.AddNetworkString("hg_medical_minigame_tourniquet_pain")
    util.AddNetworkString("hg_medical_minigame_dislocation_pain")
end

hg.MedicalMinigame = hg.MedicalMinigame or {}
hg.MedicalMinigame.RequiredTurns = 6 -- Increased for a longer minigame
