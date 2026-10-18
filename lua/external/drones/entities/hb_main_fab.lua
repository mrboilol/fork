AddCSLuaFile()

DEFINE_BASECLASS( "hb_base_advanced" )

local ExploSnds = {}
ExploSnds[1]                         =  "ambient/explosions/explode_1.wav"
ExploSnds[2]                         =  "ambient/explosions/explode_2.wav"
ExploSnds[3]                         =  "ambient/explosions/explode_3.wav"
ExploSnds[4]                         =  "ambient/explosions/explode_4.wav"
ExploSnds[5]                         =  "ambient/explosions/explode_5.wav"
ExploSnds[6]                         =  "npc/env_headcrabcanister/explosion.wav"

ENT.Spawnable		            	 =  true         
ENT.AdminSpawnable		             =  true 

ENT.PrintName		                 =  "Fuel Air Bomb"
ENT.Author			                 =  "Business Cat"
ENT.Contact		                     =  "nah"
ENT.Category                         =  "HBOMBS Main"

ENT.Model                            =  "models/military2/bomb/bomb_kab.mdl"                      
ENT.Effect                           =  "h_fab"                  
ENT.EffectAir                        =  "h_fab_air"                   
ENT.EffectWater                      =  "h_water_small"
ENT.ExplosionSound                   =  "gbombs_5/explosions/heavy_bomb/ex2.mp3"
ENT.ArmSound                         =  "npc/roller/mine/rmine_blip3.wav"            
ENT.ActivationSound                  =  "buttons/button14.wav"     

ENT.ShouldUnweld                     =  true
ENT.ShouldIgnite                     =  false
ENT.ShouldExplodeOnImpact            =  true
ENT.Flamable                         =  false
ENT.UseRandomSounds                  =  false
ENT.UseRandomModels                  =  false
ENT.Timed                            =  false

ENT.ExplosionDamage                  =  99
ENT.PhysForce                        =  32
ENT.ExplosionRadius                  =  1555
ENT.SpecialRadius                    =  575
ENT.MaxIgnitionTime                  =  0 
ENT.Life                             =  20                                  
ENT.MaxDelay                         =  2                                 
ENT.TraceLength                      =  100
ENT.ImpactSpeed                      =  350
ENT.Mass                             =  890
ENT.ArmDelay                         =  1   
ENT.Timer                            =  0

ENT.Shocktime                        = 4
ENT.HBOWNER                          =  nil             -- don't you fucking touch this.
ENT.Decal                            = "scorch_big_2"

function ENT:SpawnFunction( ply, tr )
     if ( !tr.Hit ) then return end
     self.HBOWNER = ply
     local ent = ents.Create( self.ClassName )
     ent:SetPhysicsAttacker(ply)
     ent:SetPos( tr.HitPos + tr.HitNormal * 16 ) 
     ent:Spawn()
     ent:Activate()

     return ent
end

function ENT:Explode()
     if !self.Exploded then return end
	 local pos = self:LocalToWorld(self:OBBCenter())
	 local owner = self.HBOWNER
   	 local ent = ents.Create("hb_shockwave_ent")
	 ent:SetPos( pos ) 
	 ent:Spawn()
	 ent:Activate()
	 ent:SetVar("DEFAULT_PHYSFORCE", 50)
	 ent:SetVar("DEFAULT_PHYSFORCE_PLYAIR", 50)
	 ent:SetVar("DEFAULT_PHYSFORCE_PLYGROUND", 50)
	 ent:SetVar("HBOWNER", self.HBOWNER)
	 ent:SetVar("MAX_RANGE", 500)
	 ent:SetVar("SHOCKWAVE_INCREMENT",150)
	 ent:SetVar("DELAY",0.01)
	 ent.trace=self.TraceLength
	 ent.decal=self.Decal

	 local ent = ents.Create("hb_shockwave_sound_lowsh")
	 ent:SetPos( pos ) 
	 ent:Spawn()
	 ent:Activate()
	 ent:SetVar("HBOWNER", self.HBOWNER)
	 ent:SetVar("MAX_RANGE",50000)
	 ent:SetVar("SHOCKWAVE_INCREMENT",150)		 
	 ent:SetVar("DELAY",0.01)
	 ent:SetVar("SOUND", "gbombs_5/explosions/fab/fab_initial.wav")
	 ent:SetVar("Shocktime", 3)	 
	 
	 timer.Simple(0.25, function()
			 
		 local ent = ents.Create("hb_shockwave_ent")
		 ent:SetPos( pos ) 
		 ent:Spawn()
		 ent:Activate()
		 ent:SetVar("DEFAULT_PHYSFORCE", 200)
		 ent:SetVar("DEFAULT_PHYSFORCE_PLYAIR", 100)
		 ent:SetVar("DEFAULT_PHYSFORCE_PLYGROUND", 150)
		 ent:SetVar("HBOWNER", owner)
		 ent:SetVar("MAX_RANGE", 3000)
		 ent:SetVar("SHOCKWAVE_INCREMENT",100)
		 ent:SetVar("DELAY",0.01)
		 ent.trace=self.TraceLength
		 ent.decal=self.Decal
		 
		 local ent = ents.Create("hb_shockwave_sound_lowsh")
		 ent:SetPos( pos ) 
		 ent:Spawn()
		 ent:Activate()
		 ent:SetVar("HBOWNER", self.HBOWNER)
		 ent:SetVar("MAX_RANGE",50000)
		 ent:SetVar("SHOCKWAVE_INCREMENT",150)		 
		 ent:SetVar("DELAY",0.01)
		 ent:SetVar("SOUND", "gbombs_5/explosions/fab/fab_explo.wav")
		 ent:SetVar("Shocktime", 3)
	 end)
	 
	 
	 for k, v in pairs(ents.FindInSphere(pos,2000)) do
		 if (v:IsValid() or v:IsPlayer()) then
			if v:IsValid() and v:GetPhysicsObject():IsValid() then
				v:Ignite(4,0)
			end
		 end
	 end


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
		     ParticleEffect(self.Effect,pos,Angle(0,0,0),nil)
		 else 
			 ParticleEffect(self.EffectAir,pos,Angle(0,0,0),nil) 
		 end
     end
	 if self.IsNBC then
	     local nbc = ents.Create(self.NBCEntity)
		 nbc:SetVar("HBOWNER",self.HBOWNER)
		 nbc:SetPos(self:GetPos())
		 nbc:Spawn()
		 nbc:Activate()
	 end
     self:Remove()
end