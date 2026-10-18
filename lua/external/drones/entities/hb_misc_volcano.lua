AddCSLuaFile()

DEFINE_BASECLASS( "hb_base_advanced" )

ENT.Spawnable 						 =  true
ENT.AdminSpawnable					 =  true

ENT.AdminOnly 						 =  true

ENT.PrintName		                 =  "Volcano Bomb"
ENT.Author			                 =  "Business Cat"
ENT.Contact		                     =  "nah"
ENT.Category                         =  "HBOMBS Main"

ENT.Model                            =  "models/chappi/cookie.mdl"                      
ENT.Effect                           =  "h_volcano"                  
ENT.EffectAir                        =  "h_volcano"                   
ENT.EffectWater                      =  "h_volcano"
ENT.ExplosionSound                   =  "gbombs_5/explosions/medium/howitzer_fire2.mp3"
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
ENT.ExplosionRadius                  =  2000
ENT.SpecialRadius                    =  3000
ENT.MaxIgnitionTime                  =  0
ENT.Life                             =  25                                  
ENT.MaxDelay                         =  2                                 
ENT.TraceLength                      =  3000
ENT.ImpactSpeed                      =  700
ENT.Mass                             =  5000
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
function ENT:Explode()
    if !self.Exploded then return end
	if self.Exploding then return end
	
	local pos = self:LocalToWorld(self:OBBCenter())
	self:SetModel("models/gibs/scanner_gib02.mdl")
	self.Exploding = true
	constraint.RemoveAll(self)
	local physo = self:GetPhysicsObject()
	physo:Wake()
	self:SetMoveType( MOVETYPE_NONE )
	self:SetMaterial("phoenix_storms/glass")
	self:SetModel("models/hunter/plates/plate.mdl")
	timer.Simple(0.5, function()
		if !self:IsValid() then return end
		
		local ent = ents.Create("hb_shockwave_sound_lowsh")
		ent:SetPos( pos ) 
		ent:Spawn()
		ent:Activate()
		ent:SetVar("HBOWNER", self.HBOWNER)
		ent:SetVar("MAX_RANGE",50000)
		ent:SetVar("SHOCKWAVE_INCREMENT",200)
		ent:SetVar("DELAY",0.01)
		ent:SetVar("SOUND", "gbombs_5/explosions/heavy_bomb/explosion_big_4.mp3")
		ent:SetVar("Shocktime",5)
		
		local ent = ents.Create("hb_shockwave_ent_nondmg")
		ent:SetPos( pos ) 
		ent:Spawn()
		ent:Activate()
		ent:SetVar("DEFAULT_PHYSFORCE", 100)
		ent:SetVar("DEFAULT_PHYSFORCE_PLYAIR", 1)
		ent:SetVar("DEFAULT_PHYSFORCE_PLYGROUND", 1)
		ent:SetVar("HBOWNER", self.HBOWNER)
		ent:SetVar("MAX_RANGE",6000)
		ent:SetVar("SHOCKWAVE_INCREMENT",200)
		ent:SetVar("DELAY",0.01)
		
		local ent = ents.Create("hb_misc_volcano_lava_dmg")
		local pos = self:GetPos()
		ent:SetPos( pos )
		ent:Spawn()
		ent:Activate()
		ent:SetVar("HBOWNER",self.HBOWNER)		
	end)
	
	timer.Simple(2, function()
	
		local ent = ents.Create("hb_shockwave_sound_lowsh")
		ent:SetPos( pos ) 
		ent:Spawn()
		ent:Activate()
		ent:SetVar("HBOWNER", self.HBOWNER)
		ent:SetVar("MAX_RANGE",50000)
		ent:SetVar("SHOCKWAVE_INCREMENT",200)
		ent:SetVar("DELAY",0.01)
		ent:SetVar("SOUND", "gbombs_5/explosions/misc/pyroclasticflow.mp3")
		ent:SetVar("Shocktime",5)

		if !self:IsValid() then return end
		local ent = ents.Create("hb_shockwave_ash")
		ent:SetPos( pos ) 
		ent:Spawn()
		ent:Activate()
		ent:SetVar("DEFAULT_PHYSFORCE", 0)
		ent:SetVar("DEFAULT_PHYSFORCE_PLYAIR", 0)
		ent:SetVar("DEFAULT_PHYSFORCE_PLYGROUND", 0)
		ent:SetVar("HBOWNER", self.HBOWNER)
		ent:SetVar("MAX_RANGE",5000)
		ent:SetVar("SHOCKWAVE_INCREMENT",20)
		ent:SetVar("DELAY",0.01)
	end)

	timer.Simple(4, function()
		if !self:IsValid() then return end
		local ent = ents.Create("hb_shockwave_ent_reducedamage")
		ent:SetPos( pos ) 
		ent:Spawn()
		ent:Activate()
		ent:SetVar("DEFAULT_PHYSFORCE", 250)
		ent:SetVar("DEFAULT_PHYSFORCE_PLYAIR", 50)
		ent:SetVar("DEFAULT_PHYSFORCE_PLYGROUND", 25)
		ent:SetVar("HBOWNER", self.HBOWNER)
		ent:SetVar("MAX_RANGE",5000)
		ent:SetVar("SHOCKWAVE_INCREMENT",10)
		ent:SetVar("DELAY",0.01)
	end)
	


	timer.Simple(6, function()
		if !self:IsValid() then return end
		local ent = ents.Create("hb_shockwave_ash")
		ent:SetPos( pos ) 
		ent:Spawn()
		ent:Activate()
		ent:SetVar("DEFAULT_PHYSFORCE", 0)
		ent:SetVar("DEFAULT_PHYSFORCE_PLYAIR", 0)
		ent:SetVar("DEFAULT_PHYSFORCE_PLYGROUND", 0)
		ent:SetVar("HBOWNER", self.HBOWNER)
		ent:SetVar("MAX_RANGE",15000)
		ent:SetVar("SHOCKWAVE_INCREMENT",25)
		ent:SetVar("DELAY",0.01)	
	
		local ent = ents.Create("hb_shockwave_ent_reducedamage")
		ent:SetPos( pos ) 
		ent:Spawn()
		ent:Activate()
		ent:SetVar("DEFAULT_PHYSFORCE", 50)
		ent:SetVar("DEFAULT_PHYSFORCE_PLYAIR", 10)
		ent:SetVar("DEFAULT_PHYSFORCE_PLYGROUND", 2)
		ent:SetVar("HBOWNER", self.HBOWNER)
		ent:SetVar("MAX_RANGE",15000)
		ent:SetVar("SHOCKWAVE_INCREMENT",20)
		ent:SetVar("DELAY",0.01)
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
			ParticleEffect("h_volcano",pos,Angle(0,0,0),nil)	
		else 
			ParticleEffect("h_volcano",pos,Angle(0,0,0),nil) 

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