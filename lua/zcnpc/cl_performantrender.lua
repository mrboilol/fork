--[[
	Performant Render soft-fix.

	PerformantRender:PerformDerendering() indexes self.m_hPlayerData.tardis every
	PreRender. The proxy is only created once LocalPlayer() is valid
	(InitPostEntity). Until then — and again if the proxy is lost after a reload /
	newproxy quirk — m_hPlayerData is nil and the error spams thousands of times.

	We do not edit that addon. Recreate a safe player-data proxy and bail cleanly
	when the local player is not ready yet.
]]

local function EnsurePlayerData(pr)
	if not istable(pr) then return false end

	local ply = LocalPlayer()
	if not IsValid(ply) then return false end

	pr.g_pPlayer = ply
	pr.m_bPlayerValid = true

	if pr.m_hPlayerData ~= nil then return true end

	local mt = {
		__tostring = function(self)
			return string.format("ZCNPC_PerformantRenderPlayerDataProxy: %p", self)
		end,
		__index = function(_, key)
			local p = pr.g_pPlayer
			if not IsValid(p) then return nil end

			local t = p:GetTable()
			if not t then return nil end

			return t[key]
		end,
	}

	-- Prefer their userdata proxy when newproxy still exists; fall back to a table.
	local proxy
	if isfunction(newproxy) then
		local ok, ud = pcall(newproxy)
		if ok and ud ~= nil then
			proxy = ud
			debug.setmetatable(proxy, mt)
		end
	end

	if proxy == nil then
		proxy = setmetatable({}, mt)
	end

	pr.m_hPlayerData = proxy

	return true
end

local function Patch()
	if not istable(PerformantRender) then return false end
	if PerformantRender.zcnpc_pr_patched then return true end
	if not isfunction(PerformantRender.PerformDerendering) then return false end

	PerformantRender.zcnpc_pr_patched = true

	local old = PerformantRender.PerformDerendering

	function PerformantRender:PerformDerendering()
		if not EnsurePlayerData(self) then
			return
		end

		return old(self)
	end

	-- Heal immediately if we loaded mid-error-spam.
	EnsurePlayerData(PerformantRender)

	return true
end

Patch()
hook.Add("InitPostEntity", "zcnpc_performantrender", function()
	timer.Simple(0, Patch)
end)

-- Workshop / mount order can put PR after us; keep looking until patched.
timer.Create("zcnpc_performantrender_retry", 1, 0, function()
	if Patch() then
		timer.Remove("zcnpc_performantrender_retry")
	end
end)
