if CLIENT then return end

resource.AddFile("sound/zcity_delta/turret-activation.mp3")
resource.AddFile("sound/zcity_delta/turret-shot.mp3")
resource.AddFile("sound/zcity_delta/sonarmegaouch.ogg")
if file.Exists("sound/zcity_delta/aed.ogg", "GAME") then
	resource.AddFile("sound/zcity_delta/aed.ogg")
end
