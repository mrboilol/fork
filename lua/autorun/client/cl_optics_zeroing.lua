ZCITY_SCOPE_ZEROING_BUILD = "2026-06-12-modular"

print("[Scope Zeroing] Global Scope Zeroing Initializing... Build: " .. ZCITY_SCOPE_ZEROING_BUILD)

-- Подключаем клиентские и общие модули
include("z_city_scope_zeroing/sh_zeroing.lua")
include("z_city_scope_zeroing/cl_render.lua")
include("z_city_scope_zeroing/cl_input.lua")
include("z_city_scope_zeroing/cl_debug.lua")
include("z_city_scope_zeroing/cl_hud.lua")

-- Применяем оверрайды оружия в хуке Initialize, когда все оружия уже загружены
hook.Add("Initialize", "ZCityGlobalScopeZeroing", function()
	print("[Scope Zeroing] Initializing Zeroing Overrides...")
	ZCityScopeZeroing.ApplyOverrides()
end)
