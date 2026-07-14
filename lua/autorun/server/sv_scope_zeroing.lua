-- Добавляем клиентские и общие файлы для скачивания клиентами
AddCSLuaFile("z_city_scope_zeroing/sh_zeroing.lua")
AddCSLuaFile("z_city_scope_zeroing/cl_render.lua")
AddCSLuaFile("z_city_scope_zeroing/cl_input.lua")
AddCSLuaFile("z_city_scope_zeroing/cl_debug.lua")
AddCSLuaFile("z_city_scope_zeroing/cl_hud.lua")

-- Подключаем файлы на сервере
include("z_city_scope_zeroing/sh_zeroing.lua")
include("z_city_scope_zeroing/sv_zeroing.lua")
