AddCSLuaFile()

DEFINE_BASECLASS( "hb_base_advanced" )

ENT.Spawnable		            	 =  true         
ENT.AdminSpawnable		             =  true 

ENT.PrintName		                 =  "Space nuke"
ENT.Author			                 =  "Natsu"
ENT.Contact		                     =  ""
ENT.Category                         =  "HBOMBS Nukes"

ENT.Model                            =  "models/failure/spacenuke/spacenuke.mdl"                      
ENT.Effect                           =  "h_spacenuke"                  
ENT.EffectAir                        =  "h_spacenuke"                   
ENT.EffectWater                      =  "h_spacenuke"
ENT.ExplosionSound                   =  "gbombs/fab/fab_explo.wav"
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
ENT.ExplosionRadius                  =  3000
ENT.SpecialRadius                    =  5000
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
	timer.Simple(0.25, function()
		if !self:IsValid() then return end
		local ent = ents.Create("hb_shockwave_sound_lowsh")
		ent:SetPos( pos ) 
		ent:Spawn()
		ent:Activate()
		ent:SetVar("HBOWNER", self.HBOWNER)
		ent:SetVar("MAX_RANGE",50000)
		ent:SetVar("SHOCKWAVE_INCREMENT",200)
		ent:SetVar("DELAY",0.01)
		ent:SetVar("Shocktime",12)
		ent:SetVar("SOUND", "ambient/explosions/explode_9.wav")
		
		local ent = ents.Create("hb_shockwave_ent")
		ent:SetPos( pos ) 
		ent:Spawn()
		ent:Activate()
		ent:SetVar("DEFAULT_PHYSFORCE", 155)
		ent:SetVar("DEFAULT_PHYSFORCE_PLYAIR", 155)
		ent:SetVar("DEFAULT_PHYSFORCE_PLYGROUND", 15)
		ent:SetVar("HBOWNER", self.HBOWNER)
		ent:SetVar("MAX_RANGE",7000)
		ent:SetVar("SHOCKWAVE_INCREMENT",200)
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
			ParticleEffect("h_spacenuke",pos,self:GetAngles(),nil)	
			timer.Simple(0.1, function()
				if !self:IsValid() then return end 
					ParticleEffect("",trace.HitPos,Angle(0,0,0),nil)	
			end)	
		else 
			ParticleEffect("h_spacenuke",pos,Angle(0,0,0),nil) 

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