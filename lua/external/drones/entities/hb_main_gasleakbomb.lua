AddCSLuaFile()

DEFINE_BASECLASS( "hb_base_advanced" )

local ExploSnds = {}
ExploSnds[1]                         =  "gbombs_5/explosions/medium_bomb/explosion_petrol_small.mp3"
ExploSnds[2]                         =  "gbombs_5/explosions/medium_bomb/explosion_petrol_medium.mp3"
ExploSnds[3]                         =  "gbombs_5/explosions/medium_bomb/explosion_petrol_small2.mp3"
ExploSnds[4]                         =  "gbombs_5/explosions/medium_bomb/explosion_petrol_medium2.mp3"


ENT.Spawnable		            	 =  true         
ENT.AdminSpawnable		             =  true 

ENT.PrintName		                 =  "Gas Bomb"
ENT.Author			                 =  "Business Cat"
ENT.Contact		                     =  "nah"
ENT.Category                         =  "HBOMBS Main"

ENT.Model                            =  "models/props_wasteland/laundry_washer001a.mdl"                      
ENT.Effect                           =  "h_gasbomb"                  
ENT.EffectAir                        =  "h_gasbomb_air"                   
ENT.EffectWater                      =  "h_water_medium"
ENT.ExplosionSound                   =  ""
ENT.ArmSound                         =  "npc/roller/mine/rmine_blip3.wav"            
ENT.ActivationSound                  =  "buttons/button14.wav"     

ENT.ShouldUnweld                     =  true
ENT.ShouldIgnite                     =  false
ENT.ShouldExplodeOnImpact            =  true
ENT.Flamable                         =  false
ENT.UseRandomSounds                  =  false
ENT.UseRandomModels                  =  false
ENT.Timed                            =  false

ENT.ExplosionDamage                  =  750
ENT.PhysForce                        =  600
ENT.ExplosionRadius                  =  950
ENT.SpecialRadius                    =  575
ENT.MaxIgnitionTime                  =  0 
ENT.Life                             =  10                                 
ENT.MaxDelay                         =  2                                 
ENT.TraceLength                      =  300
ENT.ImpactSpeed                      =  350
ENT.Mass                             =  500
ENT.ArmDelay                         =  1 
ENT.Timer                            =  0

ENT.HBOWNER                          =  nil             -- don't you fucking touch this.

function ENT:Explode()
    if !self.Exploded then return end
	if self.Exploding then return end
	local pos = self:LocalToWorld(self:OBBCenter())
	self:SetMoveType( MOVETYPE_NONE )
	
 	local ent = ents.Create("hb_shockwave_sound_lowsh")
	ent:SetPos( pos ) 
	ent:Spawn()
	ent:Activate()
	ent:SetVar("HBOWNER", self.HBOWNER)
	ent:SetVar("MAX_RANGE",50000)
	ent:SetVar("SHOCKWAVE_INCREMENT",100)
	ent:SetVar("DELAY",0.01)
	ent:SetVar("SOUND", "hbombs/gasleak_long.mp3")
	ent:SetVar("Shocktime", self.Shocktime)
	timer.Simple(5, function()
	
	 	local ent = ents.Create("hb_shockwave_sound_lowsh")
		ent:SetPos( pos ) 
		ent:Spawn()
		ent:Activate()
		ent:SetVar("HBOWNER", self.HBOWNER)
		ent:SetVar("MAX_RANGE",50000)
		ent:SetVar("SHOCKWAVE_INCREMENT",100)
		ent:SetVar("DELAY",0.01)
		ent:SetVar("SOUND", "gbombs_5/explosions/light_bomb/mine_explosion.mp3")
		ent:SetVar("Shocktime", self.Shocktime)	
	
		local ent = ents.Create("hb_main_napalm_burning")
		local pos = self:LocalToWorld(self:OBBCenter())
		ent:SetPos( pos )
		ent:Spawn()
		ent:Activate()
		ent:SetVar("HBOWNER",self.HBOWNER)
		
		for k, v in pairs(ents.FindInSphere(pos,750)) do
			if v:IsPlayer() or v:IsNPC() then
				if v:GetClass()=="npc_helicopter" then return end
				v:Ignite(5,0)
			else
				local phys = self:GetPhysicsObject()
				if phys:IsValid() then
					v:Ignite(3,0)
				end
			end
		end
		self:Remove()
	end)
	if(self:WaterLevel() >= 1) then
		local trdata   = {}
		local trlength = Vector(0,0,9000)

		trdata.start   = pos
		trdata.endpos  = trdata.start + trlength
		trdata.filter  = self

		local tr = util.TraceLine(trdata) 
		local trdat2   = {}
		trdat2.start   = tr.HitPos
		trdat2.endpos  = trdata.start - trlength
		trdat2.filter  = self
		trdat2.mask    = MASK_WATER + CONTENTS_TRANSLUCENT

		local tr2 = util.TraceLine(trdat2)

		if tr2.Hit then
			ParticleEffect(self.EffectWater, tr2.HitPos, Angle(0,0,0), nil)
		end
	else
		local tracedata    = {}
		tracedata.start    = pos
		tracedata.endpos   = tracedata.start - Vector(0, 0, self.TraceLength)
		tracedata.filter   = self.Entity

		local trace = util.TraceLine(tracedata)

		if trace.HitWorld then
			local ang = self:GetAngles()
			ParticleEffect(self.Effect,pos,Angle(0,ang.y,0),nil) 

		else 
			ParticleEffect(self.EffectAir,pos,Angle(0,0,0),nil) 
		end
	end
end

function ENT:SpawnFunction( ply, tr )
     if ( !tr.Hit ) then return end
     self.HBOWNER = ply
     local ent = ents.Create( self.ClassName )
     ent:SetPhysicsAttacker(ply)
     ent:SetPos( tr.HitPos + tr.HitNormal * 48 ) 
     ent:Spawn()
     ent:Activate()

     return ent
end