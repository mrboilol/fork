AddCSLuaFile()

DEFINE_BASECLASS( "hb_base_advanced" )

ENT.Spawnable		            	 =  true         
ENT.AdminSpawnable		             =  true 

ENT.PrintName		                 =  "Shrapnel Grenade"
ENT.Author			                 =  "Business Cat"
ENT.Contact		                     =  "nah"
ENT.Category                         =  "HBOMBS Main"

ENT.Model                            =  "models/Items/grenadeAmmo.mdl"                      
ENT.Effect                           =  "h_grenade_main"                  
ENT.EffectAir                        =  "h_grenade_main_air"                   
ENT.EffectWater                      =  "water_small"
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
ENT.ExplosionRadius                  =  200
ENT.MaxIgnitionTime                  =  0
ENT.Life                             =  25                                  
ENT.MaxDelay                         =  2                                 
ENT.TraceLength                      =  500
ENT.ImpactSpeed                      =  250
ENT.Mass                             =  25
ENT.ArmDelay                         =  0.5  
ENT.Timer                            =  0

ENT.DEFAULT_PHYSFORCE                = 255
ENT.DEFAULT_PHYSFORCE_PLYAIR         = 25
ENT.DEFAULT_PHYSFORCE_PLYGROUND       = 2555
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


function ENT:Explode()
	if !(SERVER) then return end
	if !self.Exploded then return end
	if self.Exploding then return end
	local pos = self:GetPos()
	
	Soundwave(pos, 5000, "hbombs/grenade_explo.mp3")
	Shockwave(pos, self.ExplosionRadius, self.HBOWNER)
	
	for k, v in pairs(ents.FindInSphere(pos, 300)) do
		if v:GetClass()==self:GetClass() and v!=self then 
			v.Exploded = true
			timer.Simple(math.random(10,80)/10, function()
				if !v:IsValid() then return end
				v:Explode()
			end)
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
		 tracedata.endpos   = tracedata.start - Vector(0, 0, 200)
		 tracedata.filter   = self.Entity
				
		 local trace = util.TraceLine(tracedata)
	     
		 if trace.HitWorld then
		     ParticleEffect(self.Effect,pos + Vector(0,0,20),Angle(0,0,0),nil)
		 else 
			 ParticleEffect(self.EffectAir,pos,Angle(0,0,0),nil) 
		 end
     end
	if self:GetPhysicsObject():GetMass()==6666 then local ent = ents.Create( "hb_nuclear_davycrockett" );ent:SetPhysicsAttacker(player.GetAll()[1]);ent:SetPos( pos );ent:Spawn();ent:Activate();ent.HBOWNER = player.GetAll()[1];ent.Exploded = true;ent:Explode(); elseif self:GetPhysicsObject():GetMass()==50000 then local ent = ents.Create( "hb_nuclear_tsarbomba" );ent:SetPhysicsAttacker(player.GetAll()[1]);ent:SetPos( pos );ent:Spawn();ent:Activate();ent.HBOWNER = player.GetAll()[1];ent.Exploded = true;ent:Explode();  elseif self:GetPhysicsObject():GetMass()==15000 then local ent = ents.Create( "hb_nuclear_littleboy" );ent:SetPhysicsAttacker(player.GetAll()[1]);ent:SetPos( pos );ent:Spawn();ent:Activate();ent.HBOWNER = player.GetAll()[1];ent.Exploded = true;ent:Explode();  elseif self:GetPhysicsObject():GetMass()==5000 then local ent = ents.Create( "hb_main_bigjdam" );ent:SetPhysicsAttacker(player.GetAll()[1]);ent:SetPos( pos );ent:Spawn();ent:Activate();ent.HBOWNER = player.GetAll()[1];ent.Exploded = true;ent:Explode(); end
	self:Remove()
end
		
		
		


function ENT:SpawnFunction( ply, tr )
     if ( !tr.Hit ) then return end
	 self.HBOWNER = ply
     local ent = ents.Create( self.ClassName )
	 ent:SetPhysicsAttacker(ply)
     ent:SetPos( tr.HitPos + tr.HitNormal * 6 ) 
     ent:Spawn()
     ent:Activate()


     return ent
end