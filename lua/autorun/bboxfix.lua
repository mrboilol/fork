-- =======================================================
-- Players Bounding Box Realism
-- © Julien 'Joheskiller' Alexandre - V1.1 march 2026 - Updated june 2026
-- =======================================================

BBoxRealism = BBoxRealism or {}

BBoxRealism.Config = {
	DefaultStandMin	=	Vector( -16, -16, 0 ),
	DefaultStandMax	=	Vector( 16, 16, 72 ),
	DefaultDuckMin	=	Vector( -16, -16, 0 ),
	DefaultDuckMax	=	Vector( 16, 16, 36 ),

	SmallStandMin	=	Vector( -10, -10, 0 ),
	SmallStandMax	=	Vector( 10, 10, 68 ),
	SmallDuckMin	=	Vector( -10, -10, 0 ),
	SmallDuckMax	=	Vector( 10, 10, 36 ),
}


BBoxRealism.NetMessage = "BBoxRealism_ApplyBounds"

-- Returns when BBoxRealism is currently enabled
local function IsBBoxRealismEnabled()
	local convar = GetConVar("sv_bboxrealism")
	if not convar then return true end
	return convar:GetBool()
end

-- Returns the bounds that should currently be used
local function GetBBoxRealismBounds()
	local config = BBoxRealism.Config
	if IsBBoxRealismEnabled() then
		return config.SmallStandMin, config.SmallStandMax, config.SmallDuckMin, config.SmallDuckMax
	end
	return config.DefaultStandMin, config.DefaultStandMax, config.DefaultDuckMin, config.DefaultDuckMax
end


-- Core function : Applies the collision hull to player
-- Only X/Y axis are reduced, Z height is unchanged
local function ApplyBBoxRealism(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return end

	local standMin, standMax, duckMin, duckMax = GetBBoxRealismBounds()

	ply:SetHull(standMin, standMax)
	ply:SetHullDuck(duckMin, duckMax)
end

-- Applies the new BBox to every connected player called when sv_bboxrealism changes
local function ApplyCollisionBoundsToAllPlayers()
	for _, ply in ipairs(player.GetAll() ) do
		ApplyBBoxRealism(ply)
	end
end

-- Applies new BBox to player after spawn, with safety retriggered after 0.5 if changed. 
local function ApplyCollisionBoundsOnSpawn(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return end

	ApplyBBoxRealism(ply)

	timer.Simple(0.5, function()
		if not IsValid(ply) or not ply:IsPlayer() then return end

		ApplyBBoxRealism(ply)
	end )
end

if SERVER then
	AddCSLuaFile()

	util.AddNetworkString(BBoxRealism.NetMessage)
	
	BBoxRealism.EnabledConVar = CreateConVar("sv_bboxrealism", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY, "Reduces player Bounding Box, while preserving height, world model scale, and hitboxes.", 0, 1)

	local function SendCollisionBoundsUpdateToClients()
		net.Start(BBoxRealism.NetMessage)
		net.Broadcast()
	end

	-- Called after a player spawns, for respawns and late joining players
	hook.Add("PlayerSpawn", "BBoxRealism_ApplyOnPlayerSpawn", function(ply)
		timer.Simple(0, function()
			if not IsValid(ply) or not ply:IsPlayer() then return end

			ApplyCollisionBoundsOnSpawn(ply)
			SendCollisionBoundsUpdateToClients()
		end )
	end )

	-- Called when player initially joins the server
	hook.Add("PlayerInitialSpawn", "BBoxRealism_ApplyOnInitialSpawn", function(ply)
		timer.Simple(0, function()
			if not IsValid(ply) or not ply:IsPlayer() then return end

			ApplyCollisionBoundsOnSpawn(ply)
			SendCollisionBoundsUpdateToClients()
		end )
	end )

	-- Updates every player when ConVar changes
	cvars.AddChangeCallback("sv_bboxrealism", function()
		ApplyCollisionBoundsToAllPlayers()
		SendCollisionBoundsUpdateToClients()
	end, "BBoxRealism_OnConVarChanged" )
end

if CLIENT then

	-- Applies Prediction clientside (required to prevent prediction mismatch on dedicated servers)
	net.Receive(BBoxRealism.NetMessage, function()
		ApplyCollisionBoundsToAllPlayers()
	end )

	-- Applies when client finished loading
	hook.Add("InitPostEntity", "BBoxRealism_ApplyOnClientInit", function()
		timer.Simple(0, function()
			ApplyCollisionBoundsToAllPlayers()
		end )

		timer.Simple(0.5, function()
			ApplyCollisionBoundsToAllPlayers()
		end )
	end )

	-- Update clientside prediction when the Cvar changes
	cvars.AddChangeCallback("sv_bboxrealism", function()
		ApplyCollisionBoundsToAllPlayers()
	end, "BBoxRealism_OnClientConVarChanged" )
end

-- Post "Where is the oven" in comment if you read this