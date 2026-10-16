-- Network protocol. The server only sends *events* (never droplets, decals or runoff frames):
--   abl_hit      wound impact: body entity, bone, entry/exit in bone space, direction, class, energy,
--                hitgroup
--   abl_rcol     bloody ragdoll collision: ragdoll, bone, contact point/normal, speed
--   abl_persist  late-join snapshot of coarse server-side pool records (sent once per client)
--   abl_req      client -> server: request the persist snapshot after the client is ready
--   abl_zcs      abl_zcity_status: the client asks, the server answers with what its part of the
--                Z-City compatibility has in place (once a second per player at most)
-- Persistent wound state itself is already replicated by Z-City's "wounds"/"arterialwounds" netvars.

ABL.Net = ABL.Net or {}
local N = ABL.Net

N.HIT, N.RCOL, N.PERSIST, N.REQ = "abl_hit", "abl_rcol", "abl_persist", "abl_req"
-- developer only (abl_dev_compare): which model of body blood a character is drawn with
N.DEV = "abl_dev"
N.ZCS = "abl_zcs"

-- damage classes
N.DMG_BULLET, N.DMG_BUCKSHOT, N.DMG_SLASH, N.DMG_CLUB, N.DMG_BLAST, N.DMG_OTHER = 0, 1, 2, 3, 4, 5

if SERVER then
	util.AddNetworkString(N.HIT)
	util.AddNetworkString(N.RCOL)
	util.AddNetworkString(N.PERSIST)
	util.AddNetworkString(N.REQ)
	util.AddNetworkString(N.DEV)
	util.AddNetworkString(N.ZCS)
end

local LOCAL_SCALE = 16 -- bone-local positions: 1/16 unit precision, +-127 units range (Int12)

function N.WriteLocal(v)
	net.WriteInt(math.Clamp(math.Round(v.x * LOCAL_SCALE), -2047, 2047), 12)
	net.WriteInt(math.Clamp(math.Round(v.y * LOCAL_SCALE), -2047, 2047), 12)
	net.WriteInt(math.Clamp(math.Round(v.z * LOCAL_SCALE), -2047, 2047), 12)
end

function N.ReadLocal()
	local x = net.ReadInt(12) / LOCAL_SCALE
	local y = net.ReadInt(12) / LOCAL_SCALE
	local z = net.ReadInt(12) / LOCAL_SCALE
	return Vector(x, y, z)
end

-- Entity index with the engine's edict bit budget.
function N.WriteEnt(ent) net.WriteUInt(IsValid(ent) and ent:EntIndex() or 0, 13) end
function N.ReadEnt() return Entity(net.ReadUInt(13)) end

-- Statistics for the debug HUD (bits sent/received per message name)
N.stats = N.stats or { count = 0, bits = 0 }
function N.Account(bits)
	N.stats.count = N.stats.count + 1
	N.stats.bits = N.stats.bits + (bits or 0)
end
