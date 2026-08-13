if CLIENT then return end

resource.AddFile("sound/zcity_delta/turret-activation.mp3")
resource.AddFile("sound/zcity_delta/turret-shot.mp3")
resource.AddFile("sound/zcity_delta/sonarmegaouch.mp3")
if file.Exists("sound/zcity_delta/aed.mp3", "GAME") then
	resource.AddFile("sound/zcity_delta/aed.mp3")
end
if file.Exists("sound/heartmax.mp3", "GAME") then
	resource.AddFile("sound/heartmax.mp3")
end
