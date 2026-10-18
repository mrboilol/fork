AddCSLuaFile()

DEFINE_BASECLASS( "hb_nuclear_fission_rad_base" )


ENT.Spawnable		            	 =  false
ENT.AdminSpawnable		             =  false     

ENT.PrintName		                 =  "Radiation"        
ENT.Author			                 =  ""      
ENT.Contact			                 =  ""      

ENT.HBOWNER                          =  nil            
ENT.DAMAGE_MUL = 1

function ENT:Initialize()
	 if (SERVER) then
		 self:SetModel("models/props_junk/watermelon01_chunk02c.mdl")
		 self:SetSolid( SOLID_NONE )
		 self:SetMoveType( MOVETYPE_NONE )
		 self:SetUseType( ONOFF_USE ) 
		 self.Bursts = 0
		 self.HBOWNER = self:GetVar("HBOWNER")
	 end
end


function ENT:Think()
     if (SERVER) then
     if !self:IsValid() then return end
	 local pos = self:GetPos()
	 local dmg = DamageInfo()
	 dmg:SetDamage(math.random(1,8))
	 dmg:SetDamageType(DMG_BURN)
	 if self.HBOWNER == nil then
		self.HBOWNER = table.Random(player.GetAll())
	 end
	 if !self.HBOWNER:IsValid() then
		self.HBOWNER = table.Random(player.GetAll())
	 end
	 dmg:SetAttacker(self.HBOWNER)
	 for k, v in pairs(ents.FindInSphere(pos,750)) do
         if (v:IsPlayer() && v:IsOnGround() && v:Alive()) or v:IsNPC() then
			if v:GetClass()=="helicopter" then return end
		    v:TakeDamageInfo(dmg)
			v:EmitSound("player/pl_burnpain3.wav")
		 end
	 end
	 self.Bursts = self.Bursts + 1
	 if (self.Bursts >= 15) then
	     self:Remove()
	 end
	 self:NextThink(CurTime() + 0.5)
	 return true
	 end
end

function ENT:Draw()
     return false
end