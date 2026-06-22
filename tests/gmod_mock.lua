--- GMod API mock layer for unit testing outside of Garry's Mod.
-- Provides stubs for the global functions and objects the production code expects.

-- Type-checking globals used by GMod Lua
function isstring(v) return type(v) == "string" end
function isnumber(v) return type(v) == "number" end
function istable(v) return type(v) == "table" end
function isbool(v) return type(v) == "boolean" end
function isentity(v) return type(v) == "table" and v._isEntity end
function IsEntity(v) return isentity(v) end
function IsValid(v)
    if v == nil or v == false then return false end
    if type(v) == "table" and v.IsValid then return v:IsValid() end
    return v ~= nil
end

-- bit library (LuaJIT-compatible subset via pure Lua fallback)
if not bit then
    bit = {}
    function bit.band(a, b)
        local result, bitval = 0, 1
        while a > 0 and b > 0 do
            if a % 2 == 1 and b % 2 == 1 then
                result = result + bitval
            end
            bitval = bitval * 2
            a = math.floor(a / 2)
            b = math.floor(b / 2)
        end
        return result
    end
    function bit.bor(a, b)
        local result, bitval = 0, 1
        while a > 0 or b > 0 do
            if a % 2 == 1 or b % 2 == 1 then
                result = result + bitval
            end
            bitval = bitval * 2
            a = math.floor(a / 2)
            b = math.floor(b / 2)
        end
        return result
    end
end

-- math extensions used by GMod
if not math.Clamp then
    function math.Clamp(val, low, high)
        return math.min(math.max(val, low), high)
    end
end
if not math.Approach then
    function math.Approach(cur, target, inc)
        inc = math.abs(inc)
        if cur < target then
            return math.min(cur + inc, target)
        elseif cur > target then
            return math.max(cur - inc, target)
        end
        return target
    end
end
if not math.Remap then
    function math.Remap(value, inMin, inMax, outMin, outMax)
        return outMin + (value - inMin) * (outMax - outMin) / (inMax - inMin)
    end
end
if not math.Rand then
    function math.Rand(low, high)
        return low + math.random() * (high - low)
    end
end

-- Round (GMod global)
if not Round then
    function Round(val, decimals)
        decimals = decimals or 0
        local mult = 10 ^ decimals
        return math.floor(val * mult + 0.5) / mult
    end
end

-- Lerp (GMod global)
if not Lerp then
    function Lerp(t, a, b)
        return a + (b - a) * t
    end
end

-- table extensions
if not table.GetKeys then
    function table.GetKeys(t)
        local keys = {}
        for k in pairs(t) do keys[#keys + 1] = k end
        return keys
    end
end
if not table.IsEmpty then
    function table.IsEmpty(t)
        return next(t) == nil
    end
end
if not table.HasValue then
    function table.HasValue(t, val)
        for _, v in pairs(t) do
            if v == val then return true end
        end
        return false
    end
end

-- Minimal Vector stub
local VectorMT = {}
VectorMT.__index = VectorMT
function VectorMT:Set(v) self[1], self[2], self[3] = v[1], v[2], v[3] end
function VectorMT:Sub(v) self[1], self[2], self[3] = self[1]-v[1], self[2]-v[2], self[3]-v[3] end
function VectorMT:Add(v) self[1], self[2], self[3] = self[1]+v[1], self[2]+v[2], self[3]+v[3] end
function VectorMT:Div(n) self[1], self[2], self[3] = self[1]/n, self[2]/n, self[3]/n end
function VectorMT:Length() return math.sqrt(self[1]^2 + self[2]^2 + self[3]^2) end
function VectorMT:LengthSqr() return self[1]^2 + self[2]^2 + self[3]^2 end
function VectorMT:Rotate() end -- no-op for tests
function VectorMT:Dot(v) return self[1]*v[1] + self[2]*v[2] + self[3]*v[3] end
function VectorMT:GetNormalized()
    local l = self:Length()
    if l == 0 then return Vector(0,0,0) end
    return Vector(self[1]/l, self[2]/l, self[3]/l)
end
function VectorMT:Distance(v)
    return math.sqrt((self[1]-v[1])^2 + (self[2]-v[2])^2 + (self[3]-v[3])^2)
end
VectorMT.__add = function(a,b) return Vector(a[1]+b[1], a[2]+b[2], a[3]+b[3]) end
VectorMT.__sub = function(a,b) return Vector(a[1]-b[1], a[2]-b[2], a[3]-b[3]) end
VectorMT.__mul = function(a,b)
    if type(a) == "number" then return Vector(a*b[1], a*b[2], a*b[3]) end
    if type(b) == "number" then return Vector(a[1]*b, a[2]*b, a[3]*b) end
    return Vector(a[1]*b[1], a[2]*b[2], a[3]*b[3])
end
VectorMT.__eq = function(a,b) return a[1]==b[1] and a[2]==b[2] and a[3]==b[3] end

function Vector(x,y,z) return setmetatable({x or 0, y or 0, z or 0}, VectorMT) end
vector_origin = Vector(0,0,0)
function VectorRand(min_val, max_val)
    min_val = min_val or -1
    max_val = max_val or 1
    return Vector(
        math.Rand(min_val, max_val),
        math.Rand(min_val, max_val),
        math.Rand(min_val, max_val)
    )
end

-- Minimal Angle stub
function Angle(p,y,r) return {p or 0, y or 0, r or 0} end

-- Color stub
function Color(r,g,b,a) return {r=r or 255, g=g or 255, b=b or 255, a=a or 255} end

-- CurTime stub (returns a controllable value)
local _curtime = 0
function CurTime() return _curtime end
function _SetCurTime(t) _curtime = t end

-- FrameTime stub
function FrameTime() return 0.015 end

-- Stub network/server globals so modules can be loaded
SERVER = false
CLIENT = false
net = net or {}
function net.Start() end
function net.WriteString() end
function net.WriteUInt() end
function net.WriteData() end
function net.Send() end
function net.SendToServer() end
function net.Receive() end
function net.Broadcast() end
function net.WriteBool() end
function net.WriteTable() end
function net.WriteEntity() end
function net.WriteMatrix() end
function net.WriteVector() end
util = util or {}
function util.AddNetworkString() end
function util.TraceLine() return {} end
function util.IntersectRayWithOBB() end
function util.PointContents() return 0 end
function util.halfValue2(val, range, k)
    if not val or not range or range == 0 then return 0 end
    return math.Clamp(val / range, 0, 1)
end

-- Stub ConVar functions
function CreateConVar(name, default)
    return {
        GetBool = function() return default == "1" or default == 1 end,
        GetFloat = function() return tonumber(default) or 0 end,
        GetInt = function() return tonumber(default) or 0 end,
        GetString = function() return tostring(default) end,
    }
end
function ConVarExists() return false end
function GetConVar() return CreateConVar("dummy", "0") end
function CreateClientConVar(name, default) return CreateConVar(name, default) end

-- AddCSLuaFile stub
function AddCSLuaFile() end

-- hook system stub
hook = hook or {}
local _hooks = {}
function hook.Add(event, name, fn) _hooks[event] = _hooks[event] or {}; _hooks[event][name] = fn end
function hook.Remove(event, name) if _hooks[event] then _hooks[event][name] = nil end end
function hook.Run(event, ...)
    if not _hooks[event] then return end
    for _, fn in pairs(_hooks[event]) do fn(...) end
end

-- timer stub
timer = timer or {}
function timer.Simple(delay, fn) if fn then fn() end end
function timer.Create() end
function timer.Remove() end

-- concommand stub
concommand = concommand or {}
function concommand.Add() end

-- player stub
player = player or {}
function player.GetAll() return {} end
function player.Iterator() return ipairs({}) end

-- game stub
game = game or {}
function game.GetAmmoName() return "" end

-- surface stub
surface = surface or {}
function surface.SetDrawColor() end
function surface.DrawRect() end
function ScrW() return 1920 end
function ScrH() return 1080 end

-- render stub
render = render or {}
function render.DrawWireframeBox() end
function render.DrawWireframeSphere() end

-- FindMetaTable stub
local _metatables = {}
function FindMetaTable(name)
    _metatables[name] = _metatables[name] or {}
    return _metatables[name]
end

-- RecipientFilter stub
function RecipientFilter()
    return {
        AddAllPlayers = function() end,
        AddPVS = function() end,
        RemovePlayer = function() end,
    }
end

-- Entity stub
function Entity(idx) return {} end

-- LocalToWorld stub
function LocalToWorld(pos, ang, refPos, refAng) return pos or Vector(0,0,0), ang or Angle(0,0,0) end

-- ErrorNoHalt stub
function ErrorNoHalt(...) end

-- FCVAR constants
FCVAR_ARCHIVE = 0
FCVAR_REPLICATED = 0
FCVAR_NOTIFY = 0
FCVAR_SERVER_CAN_EXECUTE = 0
FCVAR_HIDDEN = 0
FCVAR_NEVER_AS_STRING = 0

-- IN_ constants
IN_FORWARD = 1
IN_BACK = 2
IN_MOVELEFT = 4
IN_MOVERIGHT = 8
IN_WALK = 16

-- CONTENTS_ constants
CONTENTS_WATER = 32

-- NULL constant
NULL = false

-- pon stub (for netstream)
pon = pon or {}
function pon.encode(t) return "encoded" end
function pon.decode(s) return {} end

-- ThatPlyIsFemale stub
function ThatPlyIsFemale() return false end

-- hg namespace stub
hg = hg or {}
hg.organism = hg.organism or {}
hg.organism.module = hg.organism.module or {}
function hg.lerpFrameTime2(a, b) return a end
function hg.GetCurrentCharacter(ply) return ply end
function hg.StunPlayer() end
function hg.LightStunPlayer() end
function hg.CalculateWeight() return 250 end
hg.internalbleed_phrases = {"placeholder"}
hg.ammotypes = {}

return {
    _SetCurTime = _SetCurTime,
}
