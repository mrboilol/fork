AddCSLuaFile()

DEFINE_BASECLASS( "base_anim" )


ENT.Spawnable		            	 =  false
ENT.AdminSpawnable		             =  false     

ENT.PrintName		                 =  ""        
ENT.Author			                 =  ""      
ENT.Contact			                 =  ""      

ENT.HBOWNER                          =  nil            
ENT.MAX_RANGE                        = 0
ENT.SHOCKWAVE_INCREMENT              = 0
ENT.DELAY                            = 0
ENT.SOUND                            = ""

function ENT:Initialize()
     if (SERVER) then
		 self.FILTER                           = {}
         self:SetModel("models/props_junk/watermelon01_chunk02c.mdl")
	     self:SetSolid( SOLID_NONE )
	     self:SetMoveType( MOVETYPE_NONE )
	     self:SetUseType( ONOFF_USE ) 
		 self.Bursts = 2
		 self.CURRENTRANGE = 0
		 self.HBOWNER = self:GetVar("HBOWNER")
		 self.SOUND = self:GetVar("SOUND")
		 self.DEFAULT_PHYSFORCE  = self:GetVar("DEFAULT_PHYSFORCE")
		 self.DEFAULT_PHYSFORCE_PLYAIR  = self:GetVar("DEFAULT_PHYSFORCE_PLYAIR")
	     self.DEFAULT_PHYSFORCE_PLYGROUND = self:GetVar("DEFAULT_PHYSFORCE_PLYGROUND")

     end
end

function ENT:Think(ply)		
     if (SERVER) then
     if !self:IsValid() then return end
	 local pos = self:GetPos()
	 self.CURRENTRANGE = self.CURRENTRANGE+self.SHOCKWAVE_INCREMENT
	 for k, v in pairs(ents.FindInSphere(pos,self.CURRENTRANGE)) do
		 if v:IsValid() or v:IsPlayer() then
			 local i = 0
			 while i < v:GetPhysicsObjectCount() do
				 local dmg = DamageInfo()
			         dmg:SetDamage(math.random(0,0))
			         dmg:SetDamageType(DMG_GENERIC)
			         dmg:SetAttacker(self.HBOWNER)
				 phys = v:GetPhysicsObjectNum(i)
				 if v:IsOnFire() then return end
				 
				 local damageables =  {["models/props_junk/wood_crate001a.mdl"]=true, 
				 ["models/props_junk/wood_crate001a_damaged.mdl"]=true, 
				 ["models/props_junk/wood_crate002a.mdl"]=true,
				 ["models/props_c17/furniturecupboard001a.mdl"]=true,
				 ["models/props_c17/furnituredrawer001a.mdl"]=true,
				 ["models/props_c17/furnituredrawer001a_chunk01.mdl"]=true,
				 ["models/props_c17/furnituredrawer001a_chunk02.mdl"]=true,
				 ["models/props_c17/furnituredrawer001a_chunk03.mdl"]=true,
				 ["models/props_c17/furnituredrawer001a_chunk05.mdl"]=true,
				 ["models/props_c17/furnituredrawer001a_chunk06.mdl"]=true,
				 ["models/props_c17/furnituredrawer002a.mdl"]=true,
				 ["models/props_c17/furnituredrawer003a.mdl"]=true,
				 ["models/props_c17/furnituredresser001a.mdl"]=true,
				 ["models/props_c17/furnituretable001a.mdl"]=true,
				 ["models/props_c17/furnituretable002a.mdl"]=true,
				 ["models/props_c17/furnituretable003a.mdl"]=true,
				 ["models/props_c17/shelfunit01a.mdl"]=true,
				 ["models/props_interiors/furniture_desk01a.mdl"]=true,
				 ["models/props_interiors/furniture_shelf01a.mdl"]=true,
				 ["models/props_interiors/furniture_vanity01a.mdl"]=true,
				 ["models/props_junk/cardboard_box001a.mdl"]=true,
				 ["models/props_junk/cardboard_box001a_gib01.mdl"]=true,
				 ["models/props_junk/cardboard_box001b.mdl"]=true,
				 ["models/props_junk/cardboard_box002a.mdl"]=true,
				 ["models/props_junk/cardboard_box002a_gib01.mdl"]=true,
				 ["models/props_junk/cardboard_box002b.mdl"]=true,
				 ["models/props_junk/cardboard_box003a.mdl"]=true,
				 ["models/props_junk/cardboard_box003a_gib01.mdl"]=true,
				 ["models/props_junk/cardboard_box003b.mdl"]=true,
				 ["models/props_junk/cardboard_box003b_gib01.mdl"]=true,
				 ["models/props_phx/construct/wood/wood_boardx1.mdl"]=true,
				 ["models/props_phx/construct/wood/wood_boardx2.mdl"]=true,
				 ["models/props_phx/construct/wood/wood_boardx4.mdl"]=true,
				 ["models/props_phx/construct/wood/wood_panel1x1.mdl"]=true,
				 ["models/props_phx/construct/wood/wood_panel1x2.mdl"]=true,
				 ["models/props_phx/construct/wood/wood_panel2x2.mdl"]=true,
				 ["models/props_phx/construct/wood/wood_panel2x4.mdl"]=true,
				 ["models/props_phx/construct/wood/wood_panel4x4.mdl"]=true,
				 ["models/props_phx/construct/wood/wood_wire1x1.mdl"]=true,
				 ["models/props_phx/construct/wood/wood_wire1x1x1.mdl"]=true,
				 ["models/props_phx/construct/wood/wood_wire1x1x2.mdl"]=true,
				 ["models/props_phx/construct/wood/wood_wire1x1x2b.mdl"]=true,
				 ["models/props_phx/construct/wood/wood_wire1x2.mdl"]=true,
				 ["models/props_phx/construct/wood/wood_wire1x2b.mdl"]=true,
				 ["models/props_phx/construct/wood/wood_wire1x2x2b.mdl"]=true,
				 ["models/props_phx/construct/wood/wood_wire2x2.mdl"]=true,
				 ["models/props_phx/construct/wood/wood_wire2x2b.mdl"]=true,
				 ["models/props_phx/construct/wood/wood_wire2x2x2b.mdl"]=true,
				 ["models/props_junk/wood_pallet001a.mdl"]=true}

				 if damageables[v:GetModel()] then
					ParticleEffectAttach( "h_volcano_impact", PATTACH_POINT_FOLLOW, v, 0 )
					timer.Simple(0.1, function()
						if v:IsValid() then
							v:Remove()
						end
					end)
				 end
				 if (phys:IsValid()) then
					 local mass = phys:GetMass()
					 local F_ang = self.DEFAULT_PHYSFORCE
					 local dist = (pos - v:GetPos()):Length()
					 local relation = math.Clamp((self.CURRENTRANGE - dist) / self.CURRENTRANGE, 0, 1)
					 local F_dir = (v:GetPos() - pos):GetNormalized() * self.DEFAULT_PHYSFORCE 
					 phys:AddAngleVelocity(Vector(F_ang, F_ang, F_ang) * relation)
					 phys:AddVelocity(F_dir)
				 end
				 if (v:IsPlayer()) then
					 local mass = phys:GetMass()
					 local F_ang = self.DEFAULT_PHYSFORCE_PLYAIR
					 local dist = (pos - v:GetPos()):Length()
					 local relation = math.Clamp((self.CURRENTRANGE - dist) / self.CURRENTRANGE, 0, 1)
					 local F_dir = (v:GetPos() - pos):GetNormalized() * self.DEFAULT_PHYSFORCE_PLYAIR
					 v:SetVelocity( F_dir )		
				 end

				 if (v:IsPlayer()) and v:IsOnGround() then
					 local mass = phys:GetMass()
					 local F_ang = self.DEFAULT_PHYSFORCE_PLYGROUND
					 local dist = (pos - v:GetPos()):Length()
					 local relation = math.Clamp((self.CURRENTRANGE - dist) / self.CURRENTRANGE, 0, 1)
					 local F_dir = (v:GetPos() - pos):GetNormalized() * self.DEFAULT_PHYSFORCE_PLYGROUND	 
					 v:SetVelocity( F_dir )		
				 end
				 if (v:IsNPC()) then
					 v:Ignite(1,0)
				 end
			 i = i + 1
			 end
		 end
 	 end
	 self.Bursts = self.Bursts + 1
	 if (self.CURRENTRANGE >= self.MAX_RANGE) then
	     self:Remove()
	 end
	 self:NextThink(CurTime() + self.DELAY)
	 return true
	 end
end

function ENT:Draw()
     return false
end