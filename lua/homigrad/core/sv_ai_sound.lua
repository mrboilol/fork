hg = hg or {}

function hg.EmitAISound(pos, volume, duration, soundType, owner)
	if IsValid(owner) then
		sound.EmitHint(soundType, pos, volume, duration, owner)
	else
		sound.EmitHint(soundType, pos, volume, duration)
	end
end
