AddCSLuaFile()

DEFINE_BASECLASS( "hb_base_advanced_nuke" )

ENT.Spawnable		            	 =  true         
ENT.AdminSpawnable		             =  true 

ENT.PrintName		                 =  "Ion Bomb"
ENT.Author			                 =  "Business Cat"
ENT.Contact		                     =  "nah"
ENT.Category                         =  "HBOMBS Nukes"

ENT.Model                            =  "models/thedoctor/antimatter_canister.mdl"                      
ENT.Effect                           =  "h_ionbomb"                  
ENT.EffectAir                        =  "h_ionbomb_air"                   
ENT.EffectWater                      =  "h_ionbomb_air"
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
ENT.ExplosionRadius                  =  9000
ENT.SpecialRadius                    =  2500
ENT.MaxIgnitionTime                  =  0
ENT.Life                             =  30                                 
ENT.MaxDelay                         =  2                                 
ENT.TraceLength                      =  100
ENT.ImpactSpeed                      =  700
ENT.Mass                             =  500
ENT.ArmDelay                         =  1   
ENT.Timer                            =  0

ENT.HBOWNER                          =  nil             -- don't you fucking touch this.

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

function ENT:Arm()
     if(!self:IsValid()) then return end
	 if(self.Exploded) then return end
	 if(self.Armed) then return end
	 self.Arming = true
	 self.Used = true
	 timer.Simple(self.ArmDelay, function()
	     if !self:IsValid() then return end 
	     self.Armed = true
		 self.Arming = false
		 self:EmitSound(self.ArmSound)
		 self:StopParticles()
		 if(self.Timed) then
	         timer.Simple(self.Timer, function()
	             if !self:IsValid() then return end 
				 timer.Simple(math.Rand(0,self.MaxDelay),function()
			         if !self:IsValid() then return end 
			         self.Exploded = true
			         self:Explode()
				 end)
	         end)
	     end
	 end)
end	 

function ENT:Explode()
	if !self.Exploded then return end
	if self.Exploding then return end
	local pos = self:LocalToWorld(self:OBBCenter())
	self:SetMoveType( MOVETYPE_NONE )
	self:SetMaterial("phoenix_storms/glass")
	self:SetModel("models/hunter/plates/plate.mdl")
	timer.Simple(0.1, function()
		
		local ent = ents.Create("hb_shockwave_sound_lowsh")
		ent:SetPos( pos ) 
		ent:Spawn()
		ent:Activate()
		ent:SetVar("HBOWNER", self.HBOWNER)
		ent:SetVar("MAX_RANGE",500000)
		ent:SetVar("SHOCKWAVE_INCREMENT",140)
		ent:SetVar("DELAY",0.01)
		ent:SetVar("SOUND", "gbombs_5/explosions/special/photon_torpedo.mp3")
		
		local ent = ents.Create("hb_shockwave_ent")
		ent:SetPos( pos ) 
		ent:Spawn()
		ent:Activate()
		ent:SetVar("DEFAULT_PHYSFORCE", self.DEFAULT_PHYSFORCE)
		ent:SetVar("DEFAULT_PHYSFORCE_PLYAIR", self.DEFAULT_PHYSFORCE_PLYAIR)
		ent:SetVar("DEFAULT_PHYSFORCE_PLYGROUND", self.DEFAULT_PHYSFORCE_PLYGROUND)
		ent:SetVar("HBOWNER", self.HBOWNER)
		ent:SetVar("MAX_RANGE",10000)
		ent:SetVar("SHOCKWAVE_INCREMENT",140)
		ent:SetVar("DELAY",0.01)
		self:SetModel("models/gibs/scanner_gib02.mdl")
		ent.trace=self.TraceLength
		ent.decal=self.Decal
	end)
	
	timer.Simple(15, function()	
		if !self:IsValid() then return end
		local ent = ents.Create("hb_shockwave_ent")
		ent:SetPos( pos ) 
		ent:Spawn()
		ent:Activate()
		ent:SetVar("DEFAULT_PHYSFORCE", self.DEFAULT_PHYSFORCE)
		ent:SetVar("DEFAULT_PHYSFORCE_PLYAIR", self.DEFAULT_PHYSFORCE_PLYAIR)
		ent:SetVar("DEFAULT_PHYSFORCE_PLYGROUND", self.DEFAULT_PHYSFORCE_PLYGROUND)
		ent:SetVar("HBOWNER", self.HBOWNER)
		ent:SetVar("MAX_RANGE",15000)
		ent:SetVar("SHOCKWAVE_INCREMENT",150)
		ent:SetVar("DELAY",0.01)
		self:SetModel("models/gibs/scanner_gib02.mdl")
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
		ent:SetVar("SOUND", "gbombs_5/explosions/special/explosion_1.mp3")
		ent:SetVar("Shocktime",5)
	end)

	
	
	
	
	 
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
			 timer.Simple(20, function()
				 if !self:IsValid() then return end 	
				 self:Remove()
		 end)	
		 else 
			 ParticleEffect(self.EffectAir,pos,Angle(0,0,0),nil) 
			 timer.Simple(20, function()
				 if !self:IsValid() then return end 	
				 self:Remove()
			end)	
		 end
	 end
end

function ENT:SpawnFunction( ply, tr )
     if ( !tr.Hit ) then return end
	 self.HBOWNER = ply
     local ent = ents.Create( self.ClassName )
	 ent:SetPhysicsAttacker(ply)
     ent:SetPos( tr.HitPos + tr.HitNormal * 40 ) 
     ent:Spawn()
     ent:Activate()

     return ent
end