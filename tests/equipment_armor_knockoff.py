from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'readme NOW/checks/equipment_impact/runtime'))
from lupa.lua54 import LuaRuntime

source = (root / 'lua/homigrad/systems/equipment/sv_equipment.lua').read_text(encoding='utf-8-sig')
source = source.split('function hg.TryKnockOffArmor', 1)[1].split('function hg.GetArmorImpactMitigation', 1)[0]
source = 'function hg.TryKnockOffArmor' + source
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
hg = {}
sound = {Play = function() end}
vector_up = nil
local vector = {}
vector.__index = vector
vector.__add = function(a, b) return setmetatable({}, vector) end
vector.__mul = function(a, b) return setmetatable({}, vector) end
function vector:GetNormalized() return self end
local function vec() return setmetatable({}, vector) end
vector_up = vec()
vector_origin = vec()
function isvector(value) return getmetatable(value) == vector end
function IsValid(value) return type(value) == "table" and value.valid == true end
function math.Clamp(value, low, high) return math.min(math.max(value, low), high) end
function math.Rand() return 0.2 end
function GetEquippedArmorCondition() return 1 end
function IsArmorBreakProtected() return false end
function IsDurabilityArmor(placement) return placement == "head" end
function ApplyHelmetKnockoffTrauma() helmetTrauma = true end
ARMOR_DAMAGE_TAKEN_MUL = 0.5
MIN_KNOCKOFF_DAMAGE = 25
DEFAULT_HELMET_ABSORB_MULTIPLIER = 0.2
DEFAULT_HELMET_DURABILITY_DAMAGE_MUL = 5
DEFAULT_VEST_HEALTH_DAMAGE_MUL = 0.01
DMG_BULLET = 1
DMG_BUCKSHOT = 2
hg.GetArmorItemState = function() return 1 end
hg.GetArmorMaxCondition = function(_, placement) return placement == "head" and 50 or 1.5 end
hg.DropArmorForce = function(owner, armor)
    local placement = owner.armors.head == armor and "head" or "torso"
    local dropped = {valid = true, armorDurability = owner.armors_durability[armor], armorHealth = owner.armors_health[armor]}
    lastDrop = dropped
    owner.armors[placement] = nil
    return dropped
end
function tryImpact(placement, damage)
    helmetTrauma = false
    local armor = placement == "head" and "helmet" or "vest"
    local owner = {
        valid = true, armors = {[placement] = armor},
        armors_durability = {[armor] = 50}, armors_health = {[armor] = 1.5},
        organism = {painadd = 0, hurt = 0},
        IsPlayer = function() return true end,
        GetVelocity = function() return vec() end,
    }
    owner.organism.owner = owner
    local info = {
        GetDamage = function() return damage end,
        IsDamageType = function() return false end,
        GetInflictor = function() return nil end,
        GetDamageForce = function() return vec() end,
    }
    local dropped = hg.TryKnockOffArmor(owner, placement, armor, {mass = placement == "head" and 3 or 8}, info, vec(), nil, vec())
    return dropped, owner, helmetTrauma
end
''')
lua.execute(source)
lua.execute('''
local dropped, owner = tryImpact("head", 20)
assert(not dropped and owner.armors.head == "helmet")
dropped, owner = tryImpact("head", 50)
assert(not dropped and owner.armors.head == "helmet")
local trauma
dropped, owner, trauma = tryImpact("head", 100)
assert(dropped and trauma and owner.armors.head == nil)
assert(lastDrop.armorDurability == 40)
assert(owner.organism.painadd == 12 and owner.organism.hurt == 0.3)
dropped, owner, trauma = tryImpact("torso", 100)
assert(dropped and not trauma and owner.armors.torso == nil)
assert(math.abs(lastDrop.armorHealth - 1.4) < 0.0001)
''')
print('ez')
