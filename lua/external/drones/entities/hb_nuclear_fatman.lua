AddCSLuaFile()

DEFINE_BASECLASS( "hb_base_advanced_nuke" )

ENT.Spawnable		            	 =  true         
ENT.AdminSpawnable		             =  true 

ENT.PrintName		                 =  "Fat man"
ENT.Author			                 =  "Business Cat"
ENT.Contact		                     =  "nah"
ENT.Category                         =  "HBOMBS Nukes"

ENT.Model                            =  "models/thedoctor/fatman.mdl"                      
ENT.Effect                           =  "hbomb"                  
ENT.EffectAir                        =  "hbomb_airburst"                   
ENT.EffectWater                      =  "hbomb_underwater"
ENT.ExplosionSound                   =  "gbombs_5/explosions/nuclear/nukeaudio2.mp3"
ENT.ArmSound                         =  "npc/roller/mine/rmine_blip3.wav"            
ENT.ActivationSound                  =  "buttons/button14.wav"     

ENT.ShouldUnweld                     =  true
ENT.ShouldIgnite                     =  false
ENT.ShouldExplodeOnImpact            =  true
ENT.Flamable                         =  false
ENT.UseRandomSounds                  =  false
ENT.Timed                            =  false

ENT.ExplosionDamage                  =  500
ENT.PhysForce                        =  6500
ENT.ExplosionRadius                  =  10000
ENT.SpecialRadius                    =  5000
ENT.MaxIgnitionTime                  =  0
ENT.Life                             =  25                                  
ENT.MaxDelay                         =  2                                 
ENT.TraceLength                      =  1000
ENT.ImpactSpeed                      =  700
ENT.Mass                             =  4000
ENT.ArmDelay                         =  1   
ENT.Timer                            =  0


ENT.DEFAULT_PHYSFORCE                = 255
ENT.DEFAULT_PHYSFORCE_PLYAIR         = 25
ENT.DEFAULT_PHYSFORCE_PLYGROUND         = 2555

ENT.HBOWNER                          =  nil             -- don't you fucking touch this.
ENT.Decal                            = "nuke_medium"
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

function ENT:Explode()
     if !self.Exploded then return end
	 if self.Exploding then return end
	 local pos = self:LocalToWorld(self:OBBCenter())
	 
	 local ent = ents.Create("hb_shockwave_ent")
	 ent:SetPos( pos ) 
	 ent:Spawn()
	 ent:Activate()
	 ent:SetVar("DEFAULT_PHYSFORCE", self.DEFAULT_PHYSFORCE)
	 ent:SetVar("DEFAULT_PHYSFORCE_PLYAIR", self.DEFAULT_PHYSFORCE_PLYAIR)
	 ent:SetVar("DEFAULT_PHYSFORCE_PLYGROUND", 25)
	 ent:SetVar("HBOWNER", self.HBOWNER)
	 ent:SetVar("MAX_RANGE",10000)
	 ent:SetVar("SHOCKWAVE_INCREMENT",130)
	 ent:SetVar("DELAY",0.01)
	 ent:SetVar("SOUND", self.ExplosionSound)
	 self:SetModel("models/gibs/scanner_gib02.mdl")
	 ent.trace=self.TraceLength
	 ent.decal=self.Decal
	 	
	 local ent = ents.Create("hb_shockwave_ent_nounfreeze")
	 ent:SetPos( pos ) 
	 ent:Spawn()
	 ent:Activate()
	 ent:SetVar("DEFAULT_PHYSFORCE",10)
	 ent:SetVar("DEFAULT_PHYSFORCE_PLYAIR",1)
	 ent:SetVar("DEFAULT_PHYSFORCE_PLYGROUND",1)
	 ent:SetVar("HBOWNER", self.HBOWNER)
	 ent:SetVar("MAX_RANGE",25000)
	 ent:SetVar("SHOCKWAVE_INCREMENT",130)
	 ent:SetVar("DELAY",0.01)
	 ent.trace=self.TraceLength
	 ent.decal=self.Decal
	 
	if GetConVar("hb_nuclear_fallout"):GetInt()== 1 then
		local ent = ents.Create("hb_base_radiation_draw_ent")
		ent:SetPos( pos ) 
		ent:Spawn()
		ent:Activate()
		ent.Burst = 25
		ent.RadRadius=10000
		
		local ent = ents.Create("hb_base_radiation_ent")
		ent:SetPos( pos ) 
		ent:Spawn()
		ent:Activate()
		ent.Burst = 25
		ent.RadRadius=10000
	 end	 
	 local ent = ents.Create("hb_shockwave_sound_lowsh")
	 ent:SetPos( pos ) 
	 ent:Spawn()
	 ent:Activate()
	 ent:SetVar("HBOWNER", self.HBOWNER)
	 ent:SetVar("MAX_RANGE",50000)
	 ent:SetVar("SHOCKWAVE_INCREMENT",130)
	 ent:SetVar("DELAY",0.01)
	 ent:SetVar("SOUND", self.ExplosionSound)
	 self:SetModel("models/gibs/scanner_gib02.mdl")

	 self.Exploding = true
	
	 local physo = self:GetPhysicsObject()
	 physo:Wake()
	 physo:EnableMotion(true)
	 for k, v in pairs(ents.FindInSphere(pos,9000)) do
		 if (v:IsValid() or v:IsPlayer()) then
			if v:IsValid() and v:GetPhysicsObject():IsValid() then
				v:Ignite(4,0)
			end
		 end
	 end
	 for k, v in pairs(ents.FindInSphere(pos,self.SpecialRadius)) do
		if (v:IsValid() or v:IsPlayer()) then
			if v:IsPlayer() && !v:IsNPC() then
			    v:SetModel("models/Humans/Charple04.mdl")
				v:Kill()
			end
		 end
	 end
	
  	 timer.Simple(2, function()
	     if !self:IsValid() then return end 
		 constraint.RemoveAll(self)
	
		 self:StopParticles()
		 for k, v in pairs(ents.FindInSphere(pos,self.SpecialRadius*2)) do
			 if self.ShouldUnweld then
			     if v:IsValid() then
				     if v:IsValid() and v:GetPhysicsObject():IsValid() then
				         constraint.RemoveAll(v)
					 end
				 end
			 end
         end
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
			 ParticleEffect(self.Effect,pos,Angle(0,0,0),nil)	
			 timer.Simple(2, function()
				 if !self:IsValid() then return end 
				 ParticleEffect("",trace.HitPos,Angle(0,0,0),nil)	
				 self:Remove()
			end)	
		 else 
			 ParticleEffect(self.EffectAir,pos,Angle(0,0,0),nil) 
			 --Here we do an emp check
			if(GetConVar("hb_nuclear_emp"):GetInt() >= 1) then
				 local ent = ents.Create("hb_emp_entity")
				 ent:SetPos( self:GetPos() ) 
				 ent:Spawn()
				 ent:Activate()	
			 end
		 end
	 end
end

function ENT:SpawnFunction( ply, tr )
     if ( !tr.Hit ) then return end
	 self.HBOWNER = ply
     local ent = ents.Create( self.ClassName )
	 ent:SetPhysicsAttacker(ply)
     ent:SetPos( tr.HitPos + tr.HitNormal * 64 ) 
     ent:Spawn()
     ent:Activate()

     return ent
end