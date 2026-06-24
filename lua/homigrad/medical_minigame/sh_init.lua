if SERVER then
    util.AddNetworkString("hg_medical_minigame_start")
    util.AddNetworkString("hg_medical_minigame_progress")
    util.AddNetworkString("hg_medical_minigame_finish")
    util.AddNetworkString("hg_medical_minigame_cancel")
    util.AddNetworkString("hg_medical_minigame_request_amputation")
    util.AddNetworkString("hg_medical_minigame_tourniquet_pain")
    util.AddNetworkString("hg_medical_minigame_dislocation_pain")

    util.AddNetworkString("zcity_delta_laststand")
    util.AddNetworkString("zcity_delta_moodles_extra")
    util.AddNetworkString("zcity_delta_traits_sync")
    util.AddNetworkString("zcity_delta_traits_set")
    util.AddNetworkString("zcity_delta_death_report")
    util.AddNetworkString("zcity_delta_death_respawn")
end

hg.MedicalMinigame = hg.MedicalMinigame or {}
hg.MedicalMinigame.RequiredTurns = 6 -- Increased for a longer minigame
