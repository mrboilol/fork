
--[[
    Created by Homigrad Development Team
    Please do not re-use without asking for permission first.
]]

util.AddNetworkString("damage_flash")
util.AddNetworkString("headtrauma_flash")
util.AddNetworkString("unconscious_effect")

local thoughts = {
    [DMG_BULLET] = {
        [HITGROUP_HEAD] = {
            "JESUS CHRIST- I HAVE A REALLY BAD POUNDING HEADACHE",
            "FUCK I THINK THAT ONE HIT ME BAD",
            "MY HEAD IS ACHING BAD"
        },
        [HITGROUP_CHEST] = {
            "I got shot- I actually got shot...",
            "Its so hot. Why is it so hot when they got me?",
            "That one went straight through..."
        },
        [HITGROUP_STOMACH] = {
            "I think that one hit something important...",
            "This is bad. This is real bad."
        },
        [HITGROUP_LEFTARM] = {
            "My arm got shot- i dont want to die today...",
            "Just calm down... keep shooting..."
        },
        [HITGROUP_RIGHTARM] = {
            "My good arm got shot, i dont even know if its broken or not.",
            "My arms are so shaky, im so scared."
        },
        [HITGROUP_LEFTLEG] = {
            "Theres blood everywhere, so much blood from a tiny bullet...",
            "They got me- they got my leg..."
        },
        [HITGROUP_RIGHTLEG] = {
            "My leg- that fucker actually shot my leg...",
            "My good leg- they got my good leg..."
        }
    },
    [DMG_SLASH] = {
        [0] = {
            "They cut me- they actually cut me...",
            "Stay calm, you can do this..."
        }
    },
    [DMG_CLUB] = {
        [0] = {
            "GOD- WHY DOES IT HURT SO BAD",
            "FUCK... THAT HURT REAL BAD"
        }
    },
    [DMG_FALL] = {
        [0] = {
            "Fuck me- i think i broke something.",
            "I'm surprised I'm still alive."
        }
    },
    [DMG_BLAST] = {
        [0] = {
            "My ears are ringing... I can't hear anything over the noise.",
            "I think something got embedded in me."
        }
    }
}


local thought_cooldown = 5 -- seconds

hook.Add("OnPlayerTakeDamage", "homigrad_damageeffects", function(ply, dmginfo)
    net.Start("damage_flash")
    net.WriteFloat(dmginfo:GetDamage())
    net.Send(ply)

    if (ply.last_thought_time or 0) + thought_cooldown > CurTime() then return end

    local org = ply.organism
    if not org then return end

    -- Player thoughts
    local damageType = dmginfo:GetDamageType()
    local hitgroup = dmginfo:GetHitGroup()

    local thought_to_send

    if thoughts[damageType] then
        local thought_table = thoughts[damageType][hitgroup] or thoughts[damageType][0]
        if thought_table then
            thought_to_send = table.Random(thought_table)
        end
    end

    -- Vitals-based thoughts

    if thought_to_send then
        PlayerThought(ply, thought_to_send)
        ply.last_thought_time = CurTime()
    end
end)

function PlayerThought(ply, text)
    ply:Notify(text)
end