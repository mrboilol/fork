ZCityScopeZeroing = ZCityScopeZeroing or {}

util.AddNetworkString(ZCityScopeZeroing.NetMessage)

-- Получение сетевых поправок оружия от клиента
net.Receive(ZCityScopeZeroing.NetMessage, function(_, ply)
	if not IsValid(ply) or not ply:Alive() then return end

	local wep = net.ReadEntity()
	local clicksX = net.ReadInt(16)
	local clicksY = net.ReadInt(16)
	
	if not IsValid(wep) or not wep.IsWeapon or not wep:IsWeapon() then return end
	if wep:GetOwner() ~= ply or ply:GetActiveWeapon() ~= wep then return end
	
	local foundatt = ZCityScopeZeroing.GetActiveOpticAttachment(wep)
	if not ZCityScopeZeroing.HasScopeReticle(wep, foundatt) then return end

	local clickLimit = ZCityScopeZeroing.GetScopeClickLimit(wep, foundatt)
	wep.ReticleClicksX = ZCityScopeZeroing.ClampClickCount(clicksX, clickLimit)
	wep.ReticleClicksY = ZCityScopeZeroing.ClampClickCount(clicksY, clickLimit)

	-- Сохраняем значения в сетевые переменные оружия, чтобы другие клиенты могли их синхронизировать или запрашивать
	wep:SetNWInt("ZCityScopeClicksX", wep.ReticleClicksX)
	wep:SetNWInt("ZCityScopeClicksY", wep.ReticleClicksY)
end)
