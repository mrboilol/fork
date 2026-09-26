local B = {}

local function GetRandomDyingAnim()
    return "Dying" .. math.random(1, 6)
end

function B:OnStart(ar)
    if not IsValid(ar.ragdoll) then return end
    
    self.HealthData = DMS_Health.Active[ar.ragdoll]
    
    self.CurrentAnim = GetRandomDyingAnim()
    self.PlaybackRate = math.random(0, 1) == 0 and -0.8 or 0.8 
    self.TransitionDuration = 1.2
    
    ar:PlayAnimation(self.CurrentAnim, self.PlaybackRate, "models/AREAnims/model_anim.mdl")
    
    self.NextAnimChange = CurTime() + math.Rand(3, 6)
    self.BlendStart = CurTime()
    
    ar:SetStrength(5)
end

function B:OnUpdate(ar)
    if not IsValid(ar.ragdoll) or not ar.SetStrength then return end

    local hp = self.HealthData or DMS_Health.Active[ar.ragdoll]
    if not hp or hp.dead then return end

    local now = CurTime()
    
    if now >= self.NextAnimChange then
        self.CurrentAnim = GetRandomDyingAnim()
        self.PlaybackRate = math.Rand(0.7, 1.1) * (math.random(0, 1) == 0 and -1 or 1)
        
        ar:PlayAnimation(self.CurrentAnim, self.PlaybackRate, "models/AREAnims/model_anim.mdl")

        self.NextAnimChange = now + math.Rand(4, 7)
        self.BlendStart = now
    end

    local pulse = 0
    if DMS_Health and DMS_Health.GetProceduralPulse then
        pulse = DMS_Health:GetProceduralPulse(hp.seed, now, hp.vitalityScale)
    end

    local healthPercent = math.Clamp(hp.currentHP / hp.maxHP, 0, 1)
    
    local baseStrength = Lerp(healthPercent, 1.5, 3.35) 
    local targetStrength = baseStrength * (0.7 + (pulse * 0.6))

    local blendProgress = math.Clamp((now - self.BlendStart) / self.TransitionDuration, 0, 1)
    local smoothBlend = 0.5 * (1 - math.cos(blendProgress * math.pi))
    local transitionDip = Lerp(smoothBlend, 0.5, 1.0)
    
    local finalStrength = targetStrength * transitionDip

    if healthPercent < 0.2 then
        local current = ar.Strength or finalStrength
        local twitch = math.sin(now * 25) * 0.8
        ar:SetStrength(current + twitch)
    else
        ar:SetStrength(finalStrength)
    end
end

function B:OnExit(ar)
    if ar.SetStrength then
        ar:SetStrength(2.0)
    end
end

DMS:RegisterBehavior("injured", B)