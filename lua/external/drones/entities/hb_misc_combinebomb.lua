AddCSLuaFile()

DEFINE_BASECLASS( "hb_base_advanced_nuke" )

ENT.Spawnable		            	 =  true         
ENT.AdminSpawnable		             =  true 

ENT.PrintName		                 =  "Combine Bomb"
ENT.Author			                 =  "Business Cat"
ENT.Contact		                     =  "nah"
ENT.Category                         =  "HBOMBS Main"

ENT.Model                            =  "models/bomb_tiny/bomb_tiny.mdl"                      
ENT.Effect                           =  "combine_explo"                  
ENT.EffectAir                        =  "combine_explo"                   
ENT.EffectWater                      =  "combine_explo"
ENT.ArmSound                         =  "npc/roller/mine/rmine_blip3.wav"            
ENT.ActivationSound                  =  "buttons/button14.wav"     

ENT.ShouldUnweld                     =  true
ENT.ShouldIgnite                     =  false
ENT.ShouldExplodeOnImpact            =  true
ENT.Flamable                         =  false
ENT.UseRandomSounds                  =  false
ENT.Timed                            =  false

ENT.ExplosionDamage                  =  500
ENT.PhysForce                        =  2500
ENT.ExplosionRadius                  =  8000
ENT.SpecialRadius                    =  2000
ENT.MaxIgnitionTime                  =  0
ENT.Life                             =  25                                  
ENT.MaxDelay                         =  2                                 
ENT.TraceLength                      =  500
ENT.ImpactSpeed                      =  500
ENT.Mass                             =  255
ENT.ArmDelay                         =  1   
ENT.Timer                            =  0

ENT.DEFAULT_PHYSFORCE                = 255
ENT.DEFAULT_PHYSFORCE_PLYAIR         = 25
ENT.DEFAULT_PHYSFORCE_PLYGROUND         = 2555
ENT.HBOWNER                          =  nil     
ENT.Decal                            = "nuke_small"

function ENT:Initialize()
 if (SERVER) then
     self:SetModel(self.Model)
	 self:PhysicsInit( SOLID_VPHYSICS )
	 self:SetSolid( SOLID_VPHYSICS )
	 self:SetMoveType( MOVETYPE_VPHYSICS )
	 self:SetUseType( ONOFF_USE ) -- doesen't fucking work
	 local phys = self:GetPhysicsObject()
	 if (phys:IsValid()) then
		 phys:SetMass(self.Mass)
		 phys:Wake()
     end 
	 if(self.Dumb) then
	     self.Armed    = true
	 else
	     self.Armed    = false
	 end
	 self.Exploded = false
	 self.Used     = false
	 self.Arming = false
	 self.Exploding = false
	  if !(WireAddon == nil) then self.Inputs   = Wire_CreateInputs(self, { "Arm", "Detonate" }) end
	end
end


if SERVER then
	function ENT:Explode()
		 if !self.Exploded then return end
		 if self.Exploding then return end
		
		 local pos = self:LocalToWorld(self:OBBCenter())
		 self.Exploding = true
	  	 self:SetMaterial("phoenix_storms/glass")
		 self:SetModel("models/hunter/plates/plate.mdl")
		 
		 timer.Simple(2, function()
		 
			local ent = ents.Create("hb_shockwave_ent")
			ent:SetPos( pos ) 
			ent:Spawn()
			ent:Activate()
			ent:SetVar("DEFAULT_PHYSFORCE", 150)
			ent:SetVar("DEFAULT_PHYSFORCE_PLYAIR", 50)
			ent:SetVar("DEFAULT_PHYSFORCE_PLYGROUND", 10)
			ent:SetVar("HBOWNER", self.HBOWNER)
			ent:SetVar("MAX_RANGE",1000)
			ent:SetVar("SHOCKWAVE_INCREMENT", 200)
			ent:SetVar("SHOCKWAVE_DAMAGE", 100)
			ent:SetVar("DELAY",0.01)
			ent:SetVar("SOUND", "gbombs_5/explosions/special/blackhole_effect.mp3")
			ent.trace=self.TraceLength
			ent.decal=self.Decal

			local ent = ents.Create("hb_shockwave_sound_lowsh")
			ent:SetPos( pos ) 
			ent:Spawn()
			ent:Activate()
			ent:SetVar("HBOWNER", self.HBOWNER)
			ent:SetVar("MAX_RANGE",50000)
			ent:SetVar("SHOCKWAVE_INCREMENT", 200)
			ent:SetVar("DELAY",0.01)
			ent:SetVar("shocktime", 4)
			ent:SetVar("SOUND", "gbombs_5/explosions/special/blackhole_effect.mp3")
		 end)
		
		
		
		
		 local physo = self:GetPhysicsObject()
		 physo:Wake()
		 physo:EnableMotion(true)
		 
		 if !self:IsValid() then return end  
		 self:SetModel("models/gibs/scanner_gib02.mdl")
		 self.Exploding = true
		 self:StopParticles()
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
				 timer.Simple(1, function()
					 if !self:IsValid() then return end 
					 self:Remove()
				end)	
			else 
				 ParticleEffect(self.EffectAir,pos,Angle(0,0,0),nil) 
				 self:Remove()
			end
		end
	end
end

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