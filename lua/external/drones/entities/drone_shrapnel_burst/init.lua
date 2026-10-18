AddCSLuaFile("shared.lua")
include('shared.lua')

function ENT:Initialize()

	--We need to init physics properties even though this entity isn't physically simulated
	self.Entity:SetMoveType( MOVETYPE_NONE )
	self.Entity:DrawShadow( false )
	self.Entity:SetNoDraw(true)
	
	self.Entity:SetCollisionBounds( Vector( -20, -20, -10 ), Vector( 20, 20, 10 ) )
	self.Entity:PhysicsInitBox( Vector( -20, -20, -10 ), Vector( 20, 20, 10 ) )
	
	local phys=self.Entity:GetPhysicsObject()
	if(phys:IsValid())then
		phys:EnableCollisions( false )		
	end

	self.Entity:SetNotSolid( true )

	self.Entity:Fire("kill","",0.25)

	/*-------------- Here we go, boy --------------*/
	
	local SelfPos=self:GetPos()
	local Radius=700
	local Parent=nil
	local Power=10
	


	
	for key,object in pairs(ents.FindInSphere(SelfPos,50))do
		local Phys=object:GetPhysicsObject()
		if((IsValid(Phys))and not(object.NoSMineTarget))then
			if(Phys:GetMass()<200)then constraint.RemoveAll(object);object:Fire("enablemotion","",0) end
		end
	end
	
	timer.Simple(.075,function()
		for key,object in pairs(ents.FindInSphere(SelfPos,Radius))do
						if(((IsValid(object:GetPhysicsObject()))or(object:IsPlayer())or(object:IsNPC()))and not((object:IsWorld())or(object:GetClass()=="ent_jack_spoon")or(object==self)or(object:GetClass()=="ent_jack_fraggrenade")or(object.NoSMineTarget)))then
				self:FireShrapnel((object:LocalToWorld(object:OBBCenter())-SelfPos):GetNormalized())

			end




			if(((IsValid())or(object:IsPlayer())or(object:IsNPC()))and not((object:IsWorld())or(object:GetClass()=="tfa_bombf1")or(object==self)or(object:GetClass()=="tfa_bombf1")or(object.NoSMineTarget)))then
				self:FireShrapnel2((object:LocalToWorld(object:OBBCenter())-SelfPos):GetNormalized())

			end









		end
		
		for i=1,25 do
			local Spray={
				Attacker=self.Owner,
				Damage=0,
				Force=1,
				Num=10,
				Tracer=0,
				Dir=VectorRand(),
				Spread=Vector(3,3,3),
				Src=self:GetPos()
			}
			self:FireBullets(Spray)
		end
	end)


	

end



function ENT:FireShrapnel2(dir)
	local SelfPos=self:GetPos()
	local Spread=Vector(.3,.3,.3)
	if(self.FromSMine)then Spread=Vector(.2,.2,.2) end
	local Bellit={
		Attacker=self.Owner,
		Damage=22,
		Force=0,
		Num=30,
		Tracer=0,
		Dir=dir,
		Spread=Spread,
		Src=SelfPos
	}
	self:FireBullets(Bellit)
end











function ENT:FireShrapnel(dir)
	local SelfPos=self:GetPos()
	local Spread=Vector(.3,.3,.3)
	if(self.FromSMine)then Spread=Vector(.2,.2,.2) end
	local Bellit={
		Attacker=self.Owner,
		Damage=0,
		Force=0,
		Num=30,
		Tracer=0,
		Dir=dir,
		Spread=Spread,
		Src=SelfPos
	}
	self:FireBullets(Bellit)
end