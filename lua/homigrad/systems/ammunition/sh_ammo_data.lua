--
local matPistolAmmo = Material("vgui/hud/bullets/low_caliber.png")
local matRfileAmmo = Material("vgui/hud/bullets/high_caliber.png")
local matShotgunAmmo = Material("vgui/hud/bullets/buck_caliber.png")
hg.ammotypes = {
	["5.56x45mm"] = {
		name = "5.56x45 mm",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 120,
		minsplash = 5,
		maxsplash = 5,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 2,
			TracerLength = 155,
			TracerWidth = 2,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 49,
			Force = 44,
			Penetration = 9.2,
			Shell = "556x45",
			Speed = 980,
			Diameter = 5.56,
			Mass = 3.56,
			Icon = matRfileAmmo
		}
	},
	["5.56x45mmm855"] = {
		name = "5.56x45 mm M855",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 120,
		minsplash = 5,
		maxsplash = 5,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 90,
			TracerLength = 255,
			TracerWidth = 5,
			TracerColor = Color(0, 255, 0),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 38,
			Force = 44,
			Penetration = 13.5,
			Shell = "556x45",
			Speed = 920,
			Diameter = 5.56,
			Mass = 4,
			Icon = matRfileAmmo
		}
	},
	["5.56x45mmm855a1"] = {
		name = "5.56x45 mm M855A1",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 120,
		minsplash = 5,
		maxsplash = 5,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 2,
			TracerLength = 155,
			TracerWidth = 2,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 34,
			Force = 44,
			Penetration = 20.4,
			Shell = "556x45",
			Speed = 940,
			Diameter = 5.56,
			Mass = 4,
			Icon = matRfileAmmo
		}
	},
	["5.56x45mmm995"] = {
		name = "5.56x45 mm M995",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 120,
		minsplash = 5,
		maxsplash = 5,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 2,
			TracerLength = 155,
			TracerWidth = 2,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 29,
			Force = 29,
			Penetration = 21.9,
			Shell = "556x45",
			Speed = 1030,
			Diameter = 5.56,
			Mass = 3.4,
			Icon = matRfileAmmo
		}
	},
	["7.62x39mmsp"] = {
		name = "7.62x39 mm SP",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 127,
		maxcarry = 120,
		minsplash = 8,
		maxsplash = 8,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 2,
			TracerLength = 175,
			TracerWidth = 2,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 57,
			Force = 45,
			Penetration = 8.2,
			Shell = "762x39",
			Speed = 715,
			AirResistMul = 0.00011,
			Diameter = 7.62,
			Mass = 8.1,
			Icon = matRfileAmmo
		}
	},
	["7.62x39mm"] = {
		name = "7.62x39 mm",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 160,
		maxcarry = 120,
		minsplash = 8,
		maxsplash = 8,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 2,
			TracerLength = 175,
			TracerWidth = 2,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 48,
			Force = 50,
			Penetration = 12.9,
			Shell = "762x39",
			Speed = 715,
			AirResistMul = 0.00011,
			Diameter = 7.62,
			Mass = 7.9,
			Icon = matRfileAmmo
		}
	},
	["7.62x39mmbp"] = {
		name = "7.62x39 mm BP gzh",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 160,
		maxcarry = 120,
		minsplash = 8,
		maxsplash = 8,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 2,
			TracerLength = 175,
			TracerWidth = 2,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 47,
			Force = 66,
			Penetration = 18.2,
			Shell = "762x39",
			Speed = 720,
			AirResistMul = 0.00011,
			Diameter = 7.62,
			Mass = 7.9,
			Icon = matRfileAmmo
		}
	},
	[".366tkmfmj"] = {
		name = ".366 TKM",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 160,
		maxcarry = 120,
		minsplash = 8,
		maxsplash = 8,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 2,
			TracerLength = 175,
			TracerWidth = 2,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 50,
			Force = 50,
			Penetration = 11.5,
			Shell = "366tkm",
			Speed = 650,
			AirResistMul = 0.00011,
			Diameter = 9.58,
			Mass = 13.5,
			Icon = matRfileAmmo
		}
	},
	[".366tkmgeksa"] = {
		name = ".366 TKM 'Geksa'",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 160,
		maxcarry = 120,
		minsplash = 8,
		maxsplash = 8,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 3,
			TracerLength = 175,
			TracerWidth = 3,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 84,
			Force = 50,
			Penetration = 7.9,
			Shell = "366tkm",
			Speed = 550,
			AirResistMul = 0.00011,
			Diameter = 9.58,
			Mass = 15.5,
			Icon = matRfileAmmo
		}
	},
	["5.45x39mm"] = {
		name = "5.45x39 mm",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 120,
		minsplash = 5,
		maxsplash = 5,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 2,
			TracerLength = 155,
			TracerWidth = 2,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 37,
			Force = 35,
			Penetration = 10.2,
			Shell = "545x39",
			Speed = 890,
			Diameter = 5.45,
			Mass = 3.4,
			Icon = matRfileAmmo
		}
	},
	["5.45x39mm7n22"] = {
		name = "5.45x39 mm BP 7N22",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 120,
		minsplash = 5,
		maxsplash = 5,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 2,
			TracerLength = 155,
			TracerWidth = 2,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 33,
			Force = 33,
			Penetration = 17.8,
			Shell = "545x39",
			Speed = 890,
			Diameter = 5.45,
			Mass = 3.4,
			Icon = matRfileAmmo
		}
	},
	["5.45x39mm7n39"] = {
		name = "5.45x39 mm PPBS 7N39",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 120,
		minsplash = 5,
		maxsplash = 5,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 2,
			TracerLength = 155,
			TracerWidth = 2,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 26,
			Force = 26,
			Penetration = 21.9,
			Shell = "545x39",
			Speed = 850,
			Diameter = 5.45,
			Mass = 4.1,
			Icon = matRfileAmmo
		}
	},
	["metal_debris"] = {
		name = "Metal Debris",
		dmgtype = DMG_AIRBOAT + DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 350,
		maxcarry = 46,
		minsplash = 15,
		maxsplash = 15,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1,
			TracerLength = 15,
			TracerWidth = 1,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 10000,
			NoSpin = true,
		},
		BulletSettings = {
			Damage = 16,
			Force = 12,
			Penetration = 8,
			NumBullet = 8,
			Shell = "12x70",
			Speed = 700,
			PhysPenetrationMul = 65,
			AirResistMul = 0.001,
			Diameter = 12,
			Mass = 32/8,
		}
	},
	["12/70gauge"] = {
		name = "12/70 gauge",
		allowed = true,
		--dmgtype = DMG_BUCKSHOT,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 350,
		maxcarry = 46,
		minsplash = 15,
		maxsplash = 15,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1,
			TracerLength = 15,
			TracerWidth = 1,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 10000,
			NoSpin = true,
		},
		BulletSettings = {
			Damage = 16,
			Force = 8,
			Penetration = 7.5,
			NumBullet = 8,
			Shell = "12x70",
			Speed = 400,
			AirResistMul = 0.0003,
			Diameter = 12/8,
			Mass = 32/8,
			Icon = matShotgunAmmo,
			ShellColor = Color(255,0,0)
		}
	},
	["12/70beanbag"] = {
		name = "12/70 beanbag",
		allowed = true,
		dmgtype = DMG_CLUB,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 46,
		minsplash = 0,
		maxsplash = 0,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1.5,
			TracerLength = 155,
			TracerWidth = 5,
			TracerColor = Color(70, 78, 36),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 3000,
			NoSpin = true,
		},
		BulletSettings = {
			Damage = 60,
			Force = 150,
			Penetration = 1.1,
			Shell = "12x70beanbag",
			Spread = Vector(0, 0, 0),
			Speed = 90,
			AirResistMul = 0.0003,
			Diameter = 12,
			Mass = 40,
			Icon = matShotgunAmmo,
			ShellColor = Color(122,122,122)
		}
	},
	["12/70slug"] = {
		name = "12/70 Slug",
		allowed = true,
		--dmgtype = DMG_BUCKSHOT,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 250,
		maxcarry = 46,
		minsplash = 15,
		maxsplash = 15,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1.5,
			TracerLength = 25,
			TracerWidth = 3,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 10000,
			NoSpin = true,
		},
		BulletSettings = {
			Damage = 115,
			Force = 120,
			Penetration = 10.1,
			Shell = "12x70slug",
			Spread = Vector(0, 0, 0),
			Speed = 430,
			AirResistMul = 0.00015,
			Diameter = 12,
			Mass = 32,
			Icon = matShotgunAmmo,
			ShellColor = Color(12,75,12)
		}
	},
	["12/70rip"] = {
		name = "12/70 RIP",
		allowed = true,
		--dmgtype = DMG_BUCKSHOT,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 250,
		maxcarry = 46,
		minsplash = 15,
		maxsplash = 15,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1.5,
			TracerLength = 25,
			TracerWidth = 3,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 10000,
			NoSpin = true,
			
		},
		BulletSettings = {
			Damage = 200,
			Force = 90,
			Penetration = 7.2,
			Shell = "12x70slug",
			Spread = Vector(0, 0, 0),
			Speed = 380,
			AirResistMul = 0.00015,
			Diameter = 12,
			Mass = 20,
			Icon = matShotgunAmmo,
			ShellColor = Color(50,110,90)
		}
	},
	["12/70blank"] = {
		name = "12/70 Blank",
		allowed = true,
		--dmgtype = DMG_BUCKSHOT,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 350,
		maxcarry = 46,
		minsplash = 15,
		maxsplash = 15,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1,
			TracerLength = 15,
			TracerWidth = 1,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 10000,
			NoSpin = true,
		},
		BulletSettings = {
			Damage = 16,
			Force = 8,
			Penetration = 1,
			NumBullet = 8,
			Shell = "12x70blank",
			Speed = 400,
			AirResistMul = 0.0003,
			Diameter = 12/8,
			Mass = 32/8,
			Icon = matShotgunAmmo,
			ShellColor = Color(75,75,155),
			IsBlank = true
		}
	},
	["23x75sh10"] = {
		name = "23x75 SH10",
		allowed = true,
		--dmgtype = DMG_BUCKSHOT,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 450,
		maxcarry = 46,
		minsplash = 15,
		maxsplash = 15,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1,
			TracerLength = 15,
			TracerWidth = 1,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 10000,
			NoSpin = true,
		},
		BulletSettings = {
			Damage = 20,
			Force = 6,
			Penetration = 8.1,
			NumBullet = 10,
			Shell = "23x75sh10",
			Speed = 360,
			AirResistMul = 0.0007,
			Diameter = 23/10,
			Mass = 45/10,
			Icon = matShotgunAmmo,
			ShellColor = Color(255,185,0)
		}
	},
	["23x75sh25"] = {
		name = "23x75 SH25",
		allowed = true,
		--dmgtype = DMG_BUCKSHOT,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 450,
		maxcarry = 46,
		minsplash = 15,
		maxsplash = 15,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1,
			TracerLength = 15,
			TracerWidth = 1,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 10000,
			NoSpin = true,
		},
		BulletSettings = {
			Damage = 20,
			Force = 2,
			Penetration = 7.5,
			NumBullet = 25,
			Shell = "23x75sh25",
			Speed = 360,
			AirResistMul = 0.0007,
			Diameter = 23/25,
			Mass = 32/25,
			Icon = matShotgunAmmo,
			ShellColor = Color(130,130,130)
		}
	},
	["23x75barricade"] = {
		name = "23x75 Barricade",
		allowed = true,
		--dmgtype = DMG_BUCKSHOT,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 450,
		maxcarry = 46,
		minsplash = 15,
		maxsplash = 15,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1,
			TracerLength = 15,
			TracerWidth = 1,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 10000,
			NoSpin = true,
		},
		BulletSettings = {
			Damage = 150,
			Force = 100,
			Penetration = 12.4,
			Shell = "23x75barricade",
			Spread = Vector(0, 0, 0),
			Speed = 400,
			AirResistMul = 0.0009,
			Diameter = 23,
			Mass = 55,
			Icon = matShotgunAmmo,
			ShellColor = Color(255,185,0)
		}
	},
	["23x75zvezda"] = {
		name = "23x75 Zvezda",
		allowed = true,
		--dmgtype = DMG_BUCKSHOT,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 350,
		maxcarry = 46,
		minsplash = 15,
		maxsplash = 15,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1,
			TracerLength = 15,
			TracerWidth = 1,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 10000,
			NoSpin = true,
		},
		BulletSettings = {
			Damage = 1,
			Force = 1,
			Penetration = 1,
			NumBullet = 1,
			Shell = "23x75zvezda",
			Speed = 80,
			AirResistMul = 0.0003,
			Diameter = 12/8,
			Mass = 60,
			Icon = matShotgunAmmo,
			ShellColor = Color(255,185,0),
			Distance = 32,
		}
	},
	["23x75waver"] = {
		name = "23x75 Wave R",
		allowed = true,
		--dmgtype = DMG_BUCKSHOT,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 450,
		maxcarry = 46,
		minsplash = 15,
		maxsplash = 15,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1,
			TracerLength = 15,
			TracerWidth = 1,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 10000,
			NoSpin = true,
		},
		BulletSettings = {
			Damage = 80,
			Force = 100,
			Penetration = 2.2,
			Shell = "23x75waver",
			Spread = Vector(0, 0, 0),
			Speed = 120,
			AirResistMul = 0.0008,
			Diameter = 23,
			Mass = 15,
			Icon = matShotgunAmmo,
			ShellColor = Color(255,185,0)
		}
	},
	["20/70gauge"] = { //РїРѕС‚РѕРј РґСЂСѓРіРёРµ РґРѕР±Р°РІР»СЋ
		name = "20/70 gauge",
		allowed = true,
		--dmgtype = DMG_BUCKSHOT,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 370,
		maxcarry = 50,
		minsplash = 15,
		maxsplash = 15,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 0.8,
			TracerLength = 12,
			TracerWidth = 0.8,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 9000,
			NoSpin = true,
		},
		BulletSettings = {
			Damage = 12,
			Force = 6,
			Penetration = 7.6,
			NumBullet = 11,
			Shell = "20/70",
			Speed = 410,
			AirResistMul = 0.00025,
			Diameter = 20/6,
			Mass = 24/6,
			Icon = matShotgunAmmo,
			ShellColor = Color(255,150,0)
		}
	},
	["20/70slug"] = {
		name = "20/70 Slug",
		allowed = true,
		--dmgtype = DMG_BUCKSHOT,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 400,
		maxcarry = 50,
		minsplash = 15,
		maxsplash = 15,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 0.8,
			TracerLength = 12,
			TracerWidth = 0.8,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 9000,
			NoSpin = true,
		},
		BulletSettings = {
			Damage = 120,
			Force = 120,
			Penetration = 9.8,
			Shell = "20/70",
			Spread = Vector(0, 0, 0),
			Speed = 450,
			AirResistMul = 0.00025,
			Diameter = 20,
			Mass = 24,
			Icon = matShotgunAmmo,
			ShellColor = Color(12,75,12)
		}
	},
	["20/70flechette"] = {
		name = "20/70 Flechette",
		allowed = true,
		--dmgtype = DMG_BUCKSHOT,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 350,
		maxcarry = 50,
		minsplash = 15,
		maxsplash = 15,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 0.8,
			TracerLength = 12,
			TracerWidth = 0.8,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 9000,
			NoSpin = true,
		},
		BulletSettings = {
			Damage = 16,
			Force = 6,
			Penetration = 6.1,
			NumBullet = 8,
			Shell = "20/70",
			Speed = 400,
			AirResistMul = 0.00025,
			Diameter = 20/6,
			Mass = 10/6,
			Icon = matShotgunAmmo,
			ShellColor = Color(195,143,0),
		}
	},
	["9x18mm"] = {
		name = "9x18 mm",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 90,
		maxcarry = 80,
		minsplash = 1,
		maxsplash = 1,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1,
			TracerLength = 45,
			TracerWidth = 1,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 15000
		},
		BulletSettings = {
			Damage = 23,
			Force = 24,
			Penetration = 7.9,
			Shell = "9x18",
			Speed = 315,
			Diameter = 9,
			Mass = 6.1,
			Icon = matPistolAmmo
		}
	},
	["9x18mmpbm"] = {
		name = "9x18 mm PBM 7N25",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 90,
		maxcarry = 80,
		minsplash = 1,
		maxsplash = 1,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1,
			TracerLength = 45,
			TracerWidth = 1,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 15000
		},
		BulletSettings = {
			Damage = 23,
			Force = 24,
			Penetration = 8.1,
			Shell = "9x18",
			Speed = 485,
			Diameter = 9,
			Mass = 3.7,
			Icon = matPistolAmmo
		}
	},
	["9x17mm"] = {
		name = "9x17 mm",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 90,
		maxcarry = 80,
		minsplash = 1,
		maxsplash = 1,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1,
			TracerLength = 45,
			TracerWidth = 1,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 15000
		},
		BulletSettings = {
			Damage = 24,
			Force = 24,
			Penetration = 3.1,
			Shell = "9x18",
			Speed = 290,
			Diameter = 9,
			Mass = 4.8,
			Icon = matPistolAmmo
		}
	},
	["9x19mmparabellum"] = {
		name = "9x19 mm Parabellum",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 80,
		minsplash = 1,
		maxsplash = 1,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1,
			TracerLength = 45,
			TracerWidth = 1,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 15000
		},
		BulletSettings = {
			Damage = 25,
			Force = 25,
			Penetration = 3.8,
			Shell = "9x19",
			Speed = 365,
			Diameter = 9,
			Mass = 7.5,
			Icon = matPistolAmmo
		}
	},
	["9x19mmpbp"] = {
		name = "9x19 mm PBP gzh",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 80,
		minsplash = 1,
		maxsplash = 1,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1,
			TracerLength = 45,
			TracerWidth = 1,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 15000
		},
		BulletSettings = {
			Damage = 22,
			Force = 22,
			Penetration = 11.8,
			Shell = "9x19",
			Speed = 535,
			Diameter = 9,
			Mass = 4.1,
			Icon = matPistolAmmo
		}
	},
	["9x19mmqm"] = {
		name = "9x19 mm QuakeMaker",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 80,
		minsplash = 1,
		maxsplash = 1,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1,
			TracerLength = 45,
			TracerWidth = 1,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 15000
		},
		BulletSettings = {
			Damage = 48,
			Force = 27,
			Penetration = 3.6,
			Shell = "9x19",
			Speed = 340,
			Diameter = 9,
			Mass = 6.5,
			Icon = matPistolAmmo
		}
	},
	["7.65x17mm"] = {
		name = "7.65x17 mm",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 95,
		maxcarry = 80,
		minsplash = 1,
		maxsplash = 1,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1,
			TracerLength = 45,
			TracerWidth = 1,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 15000
		},
		BulletSettings = {
			Damage = 21,
			Force = 25,
			Penetration = 3.2,
			Shell = "45acp",
			Speed = 310,
			Diameter = 9,
			Mass = 4.8,
			Icon = matRfileAmmo
		}
	},
	[".40sw"] = {
		name = ".40 SW",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 110,
		maxcarry = 80,
		minsplash = 1,
		maxsplash = 1,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1,
			TracerLength = 45,
			TracerWidth = 1,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 15000
		},
		BulletSettings = {
			Damage = 28,
			Force = 45,
			Penetration = 4.3,
			Shell = "45acp",
			Speed = 350,
			Diameter = 11.18,
			Mass = 10.7,
			Icon = matPistolAmmo
		}
	},
	[".45acp"] = {
		name = ".45 ACP",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 80,
		minsplash = 1,
		maxsplash = 1,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1,
			TracerLength = 45,
			TracerWidth = 1,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 15000
		},
		BulletSettings = {
			Damage = 30,
			Force = 35,
			Penetration = 3.9,
			Shell = "45acp",
			Speed = 260,
			Diameter = 11.19,
			Mass = 14.9,
			Icon = matPistolAmmo
		}
	},
	[".45acpp"] = {
		name = ".45 ACP +P",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 80,
		minsplash = 1,
		maxsplash = 1,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1,
			TracerLength = 45,
			TracerWidth = 1,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 15000
		},
		BulletSettings = {
			Damage = 30,
			Force = 35,
			Penetration = 7.8,
			Shell = "45acp",
			Speed = 330,
			Diameter = 11.19,
			Mass = 12.6,
			Icon = matPistolAmmo
		}
	},
	[".45acphydroshock"] = {
		name = ".45 ACP Hydro Shock",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 80,
		minsplash = 1,
		maxsplash = 1,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1,
			TracerLength = 45,
			TracerWidth = 1,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 15000
		},
		BulletSettings = {
			Damage = 52,
			Force = 50,
			Penetration = 3.3,
			Shell = "45acp",
			Speed = 280,
			Diameter = 11.19,
			Mass = 14.9,
			Icon = matPistolAmmo
		}
	},
	["7.62x25mm"] = {
		name = "7.62x25 mm",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 120,
		maxcarry = 100,
		minsplash = 1,
		maxsplash = 1,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 5,
			TracerLength = 75,
			TracerWidth = 1.5,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 35,
			Force = 35,
			Penetration = 9,
			Shell = "10mm",
			Speed = 376,
			Diameter = 10,
			Mass = 10,
			Icon = matPistolAmmo
		}
	},
	["9x19mmgreentracer"] = {
		name = "9x19 mm Green Tracer",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 80,
		minsplash = 1,
		maxsplash = 1,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 55,
			TracerLength = 85,
			TracerWidth = 5,
			TracerColor = Color(0, 255, 0),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 15000
		},
		BulletSettings = {
			Damage = 25,
			Force = 25,
			Penetration = 3.7,
			Shell = "9x19",
			Speed = 340,
			Diameter = 9,
			Mass = 7.6,
			Icon = matPistolAmmo
		}
	},
	[".45rubber"] = {
		name = ".45 Rubber",
		allowed = true,
		dmgtype = DMG_CLUB,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 80,
		minsplash = 0,
		maxsplash = 0,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1,
			TracerLength = 5,
			TracerWidth = 1,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 6000,
			NoSpin = true,
		},
		BulletSettings = {
			Damage = 30,
			Force = 30,
			Penetration = 0.8,
			Shell = "9x18",
			Speed = 260,
			Diameter = 11.19,
			Mass = 1.5,
			Icon = matPistolAmmo
		}
	},
	["9mmpakblank"] = {
		name = "9mm PAK Blank",
		allowed = true,
		dmgtype = DMG_CLUB,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 80,
		minsplash = 0,
		maxsplash = 0,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1,
			TracerLength = 5,
			TracerWidth = 1,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 6000,
			NoSpin = true,
		},
		BulletSettings = {
			Damage = 8,
			Force = 5,
			Penetration = 0.5,
			Shell = "9x18",
			Speed = 259,
			Diameter = 11.19,
			Distance = 32,
			Mass = 10,
			Icon = matPistolAmmo
		}
	},
	["9mmpakflashdefense"] = {
		name = "9mm PAK Flash Defense",
		allowed = true,
		dmgtype = DMG_CLUB,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 80,
		minsplash = 0,
		maxsplash = 0,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1,
			TracerLength = 5,
			TracerWidth = 1,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 6000,
			NoSpin = true,
		},
		BulletSettings = {
			Damage = 5,
			Force = 5,
			Penetration = 0.5,
			Shell = "9x18",
			Speed = 259,
			Diameter = 11.19,
			Distance = 32,
			Mass = 10,
			Icon = matPistolAmmo
		}
	},
	["18x45mmtraumatic"] = {
		name = "18x45mm Traumatic",
		allowed = true,
		dmgtype = DMG_CLUB,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 80,
		minsplash = 0,
		maxsplash = 0,
		TracerSetings = {
		--[[ -- FLARE AMMO BAZA!!!!!
			TracerBody = Material("particle/particle_glow_05"),
			TracerTail = Material("trails/smoke"),
			TracerHeadSize = 500,
			TracerLength = 350,
			TracerWidth = 60,
			TracerColor = Color(255, 0, 0),
			TracerTPoint1 = 0.1,
			TracerTPoint2 = 0.5,
			TracerSpeed = 2500,
			NoSpin = true,
		]]
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1,
			TracerLength = 5,
			TracerWidth = 1,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 6000,
			NoSpin = true,
		},
		BulletSettings = {
			Damage = 35,
			Force = 32,
			Penetration = 2.3,
			Shell = "50ae",
			Speed = 124,
			Diameter = 18,
			Mass = 11.6,
			Icon = matPistolAmmo
		}
	},
	["18x45mmflashdefense"] = {
		name = "18x45mm Flash Defense",
		allowed = true,
		dmgtype = DMG_CLUB,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 80,
		minsplash = 0,
		maxsplash = 0,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1,
			TracerLength = 5,
			TracerWidth = 1,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 6000,
			NoSpin = true,
		},
		BulletSettings = {
			Damage = 15,
			Force = 10,
			Penetration = 1,
			Shell = "50ae",
			Speed = 250,
			Diameter = 18,
			Distance = 32,
			Mass = 18,
			Icon = matPistolAmmo
		}
	},
	["4.6x30mm"] = {
		name = "4.6x30 mm",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 120,
		minsplash = 4,
		maxsplash = 4,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 2,
			TracerLength = 45,
			TracerWidth = 2.5,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 23,
			Force = 23,
			Penetration = 8.7,
			Shell = "556x45",
			Speed = 620,
			Diameter = 4.6,
			Mass = 2.6,
			Icon = matRfileAmmo
		}
	},
	["4.6x30mmap"] = {
		name = "4.6x30 mm AP SX",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 120,
		minsplash = 4,
		maxsplash = 4,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 2,
			TracerLength = 45,
			TracerWidth = 2.5,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 22,
			Force = 22,
			Penetration = 11.8,
			Shell = "556x45",
			Speed = 675,
			Diameter = 4.6,
			Mass = 2,
			Icon = matRfileAmmo
		}
	},
	["5.7x28mm"] = {
		name = "5.7x28 mm",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 150,
		minsplash = 4,
		maxsplash = 4,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 5,
			TracerLength = 45,
			TracerWidth = 2.5,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 26,
			Force = 26,
			Penetration = 9.1,
			Shell = "556x45",
			Speed = 792,
			Diameter = 5.7,
			Mass = 1.8,
			Icon = matRfileAmmo
		}
	},
	["5.7x28mmap"] = {
		name = "5.7x28 mm SS190",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 150,
		minsplash = 4,
		maxsplash = 4,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 5,
			TracerLength = 45,
			TracerWidth = 2.5,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 23,
			Force = 23,
			Penetration = 11.7,
			Shell = "556x45",
			Speed = 716,
			Diameter = 5.7,
			Mass = 2,
			Icon = matRfileAmmo
		}
	},
	[".44remingtonmagnum"] = {
		name = ".44 Remington Magnum",
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 150,
		minsplash = 3,
		maxsplash = 3,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 5,
			TracerLength = 35,
			TracerWidth = 2.5,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 20000
		},
		BulletSettings = {
			Damage = 40,
			Force = 40,
			Penetration = 9.5,
			Shell = "10mm",
			Speed = 450,
			Diameter = 10.9,
			Mass = 15.6,
			Icon = matPistolAmmo
		}
	},
	[".357magnum"] = {
		name = ".357 Magnum",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 130,
		maxcarry = 150,
		minsplash = 2.5,
		maxsplash = 2.5,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 5,
			TracerLength = 35,
			TracerWidth = 2.5,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 20000
		},
		BulletSettings = {
			Damage = 40,
			Force = 40,
			Penetration = 5.8,
			Shell = "10mm",
			Speed = 440,
			Diameter = 9,
			Mass = 10.2,
			Icon = matPistolAmmo
		}
	},
	[".38special"] = {
		name = ".38 Special",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 110,
		maxcarry = 150,
		minsplash = 2.5,
		maxsplash = 2.5,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 5,
			TracerLength = 35,
			TracerWidth = 2.5,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 20000
		},
		BulletSettings = {
			Damage = 27,
			Force = 27,
			Penetration = 3.5,
			Shell = "10mm",
			Speed = 290,
			Diameter = 9.1,
			Mass = 10.2,
			Icon = matPistolAmmo
		}
	},
	["14.5x114mmb32"] = { -- РЎР°Р»Р°С‚ С‚С‹ Сѓ РЅР°СЃ С‚СѓС‚ Р±Р°Р»Р°РЅСЃРёС‰Рµ, СЃРґРµР»Р°РµС€СЊ РєРѕРЅС„РµС‚РєСѓ 
		name = "14.5x114mm B32",
		dmgtype = DMG_BULLET + DMG_AIRBOAT,
		tracer = TRACER_NONE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 10,
		minsplash = 5,
		maxsplash = 5,
		BulletSettings = {
			Damage = 550,
			Force = 100,
			Penetration = 270.2,
			Shell = "50cal",
			Speed = 1000,
			Diameter = 14.5,
			Mass = 64,
			Icon = matRfileAmmo
		}
	},
	["14.5x114mmbztm"] = { -- СЌС‚Рѕ С‚РѕР¶Рµ СЃР°РјРѕРµ С‡С‚Рѕ Рё РІС‹С€Рµ РїСЂРѕСЃС‚Рѕ СЃ С‚СЂР°СЃРµСЂРѕРј :D
		name = "14.5x114mm BZTM",
		dmgtype = DMG_BULLET + DMG_AIRBOAT,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 100,
		maxcarry = 120,
		minsplash = 5,
		maxsplash = 5,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 100,
			TracerLength = 255,
			TracerWidth = 20,
			TracerColor = Color(255,91,0),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 15000
		},
		BulletSettings = {
			Damage = 550,
			Force = 100,
			Penetration = 270.2,
			Shell = "50cal",
			Speed = 1000,
			Diameter = 14.5,
			Mass = 64,
			Icon = matRfileAmmo
		}
	},
	["9x39mm"] = {
		name = "9x39 mm",
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 150,
		maxcarry = 150,
		minsplash = 5,
		maxsplash = 5,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 5,
			TracerLength = 75,
			TracerWidth = 2.5,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 0.5,
			TracerSpeed = 15000
		},
		BulletSettings = {
			Damage = 52,
			Force = 42,
			Penetration = 10.9,
			Shell = "762x39",
			Speed = 290,
			Diameter = 9,
			Mass = 16,
			Icon = matRfileAmmo
		}
	},
	["9x39mmsp6"] = {
		name = "9x39 mm SP-6",
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 150,
		maxcarry = 150,
		minsplash = 5,
		maxsplash = 5,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 5,
			TracerLength = 75,
			TracerWidth = 2.5,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 0.5,
			TracerSpeed = 15000
		},
		BulletSettings = {
			Damage = 50,
			Force = 42,
			Penetration = 16.8,
			Shell = "762x39",
			Speed = 290,
			Diameter = 9,
			Mass = 16,
			Icon = matRfileAmmo
		}
	},
	[".50actionexpress"] = {
		name = ".50 Action Express",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 150,
		maxcarry = 150,
		minsplash = 6,
		maxsplash = 6,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 5,
			TracerLength = 35,
			TracerWidth = 1.5,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 52,
			Force = 40,
			Penetration = 9.2,
			Shell = "50ae",
			Speed = 450,
			Diameter = 12.7,
			Mass = 21,
			Icon = matPistolAmmo
		}
	},
	[".50actionexpresscopper"] = {
		name = ".50 Action Express Copper Solid",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 150,
		maxcarry = 150,
		minsplash = 6,
		maxsplash = 6,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 5,
			TracerLength = 35,
			TracerWidth = 1.5,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 65,
			Force = 40,
			Penetration = 11.2,
			Shell = "50ae",
			Speed = 470,
			Diameter = 12.7,
			Mass = 20,
			Icon = matPistolAmmo
		}
	},
	[".50actionexpressjhp"] = {
		name = ".50 Action Express JHP",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 150,
		maxcarry = 150,
		minsplash = 6,
		maxsplash = 6,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 5,
			TracerLength = 35,
			TracerWidth = 1.5,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 95,
			Force = 110,
			Penetration = 5.4,
			Shell = "50ae",
			Speed = 440,
			Diameter = 12.7,
			Mass = 19.4,
			Icon = matPistolAmmo
		}
	},
	["7.62x51mm"] = {
		name = "7.62x51 mm",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 250,
		maxcarry = 120,
		minsplash = 10,
		maxsplash = 10,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 5,
			TracerLength = 75,
			TracerWidth = 1.5,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 65,
			Force = 65,
			Penetration = 14.1,
			Shell = "762x51",
			Speed = 850,
			Diameter = 7.62,
			Mass = 9.5,
			Icon = matRfileAmmo
		}
	},
	["7.62x51mmm993"] = {
		name = "7.62x51 mm M993",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 250,
		maxcarry = 120,
		minsplash = 10,
		maxsplash = 10,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 5,
			TracerLength = 75,
			TracerWidth = 1.5,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 74.7,
			Force = 69,
			Penetration = 22.4,
			Shell = "762x51",
			Speed = 910,
			Diameter = 7.62,
			Mass = 8.2,
			Icon = matRfileAmmo
		}
	},
	["7.62x54mm"] = {
		name = "7.62x54 mm",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 250,
		maxcarry = 120,
		minsplash = 11,
		maxsplash = 11,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 5,
			TracerLength = 75,
			TracerWidth = 2,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 70,
			Force = 70,
			Penetration = 12.3,
			Shell = "762x54",
			Speed = 830,
			Diameter = 7.62,
			Mass = 9.6,
			Icon = matRfileAmmo
		}
	},
	["7.62x54mm7n26"] = {
		name = "7.62x54 mm 7N26",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 250,
		maxcarry = 120,
		minsplash = 11,
		maxsplash = 11,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 5,
			TracerLength = 75,
			TracerWidth = 2,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 68,
			Force = 68,
			Penetration = 19.3,
			Shell = "762x54",
			Speed = 825,
			Diameter = 7.62,
			Mass = 9.9,
			Icon = matRfileAmmo
		}
	},
	[".338lapuamagnum"] = {
		name = ".338 Lapua Magnum",
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 400,
		maxcarry = 120,
		minsplash = 15,
		maxsplash = 15,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 5,
			TracerLength = 105,
			TracerWidth = 5,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 180,
			Force = 60,
			Penetration = 32.2,
			Shell = ".338Lapua",
			Speed = 910,
			Diameter = 8.6,
			Mass = 16.2,
			Icon = matRfileAmmo
		}
	},
	[".22longrifle"] = {
		name = ".22 Long Rifle",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 70,
		maxcarry = 120,
		minsplash = 1,
		maxsplash = 1,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = .5,
			TracerLength = 55,
			TracerWidth = .5,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 10000
		},
		BulletSettings = {
			Damage = 16,
			Force = 20,
			Penetration = 2.4,
			Shell = ".22lr",
			Speed = 330,
			Diameter = 5.72,
			Mass = 2.6,
			Icon = matPistolAmmo
		}
	},
	["rpg-7projectile"] = {
		name = "RPG-7 Projectile",
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 5000,
		maxcarry = 120,
		minsplash = 10,
		maxsplash = 5
	},
	["12.7x108mm"] = {
		name = "12.7x108 mm",
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 550,
		maxcarry = 120,
		minsplash = 20,
		maxsplash = 20,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 5,
			TracerLength = 150,
			TracerWidth = 8.5,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 45000
		},
		BulletSettings = {
			Damage = 150,
			Force = 40,
			Penetration = 60.4,
			Shell = "50cal",
			Speed = 820,
			Diameter = 12.7,
			Mass = 48,
			Icon = matRfileAmmo
		}
	},
	["12.7x55mm"] = {
		name = "12.7x55 mm",
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 96.8,
		npcdmg = 96.8,
		force = 180,
		maxcarry = 120,
		minsplash = 20,
		maxsplash = 20,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 5,
			TracerLength = 150,
			TracerWidth = 8.5,
			TracerColor = Color(255, 237, 155),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 45000
		},
		BulletSettings = {
			Damage = 255,
			Force = 40,
			Penetration = 21.5,
			Shell = "50cal",
			Speed = 295, --asha it's subsonic rifle... deka you are stupid
			Diameter = 12.7,
			Mass = 48,
			Icon = matRfileAmmo
		}
	},
	["nails"] = {
		name = "Nails",
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 50,
		maxcarry = 120,
		minsplash = 10,
		maxsplash = 5
	},
	["armature"] = {
		name = "Armature",
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 150,
		maxcarry = 90,
		minsplash = 10,
		maxsplash = 5,
		TracerSetings = {
			MaxPathPoints = 5,
		},
		BulletSettings = {
			Mass = 200,
			Icon = matRfileAmmo,
			Damage = 256.8,
			Force = 30.9,
			Penetration = 50,
		},
		FunctionInfo = {
			Model = "models/crossbow_bolt.mdl",
			--DesiredSilks = {	--; WARNING POINTER
			--	{SegmentsDesiredAmt = 5, SegmentsDesiredWidth = 1, SegmentsDesiredLength = 3, EntityOffset = Vector(2, 0, 0)},
			--	{SegmentsDesiredAmt = 6, SegmentsDesiredWidth = 1, SegmentsDesiredLength = 3, EntityOffset = Vector(2.1, 0, 0)},
			--	{SegmentsDesiredAmt = 10, SegmentsDesiredWidth = 1, SegmentsDesiredLength = 3, EntityOffset = Vector(2, 0, 0)},
			--},
			Ent = "crossbow_projectile",
		},
		BulletFunctions = {
			-- Draw = draw_silk,
			OnStopped = onstopped_silk,
			--PreRemove = preremove_silk,
			--PostRemove = postremove_silk,
		},
	},
	["arrow"] = {
		name = "Arrow",
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 5,
		maxcarry = 40,
		minsplash = 10,
		maxsplash = 5,
		TracerSetings = {
			MaxPathPoints = 4,
			TracerWidth = 5,
			TracerColor = Color(15, 15, 15),
		},
		BulletSettings = {
			Mass = 40,
			Icon = matRfileAmmo,
			Damage = 35,
			Speed = 5,
			PhysPenetrationMul = 0.0,
		},
		FunctionInfo = {
			Model = "models/z_city/nmrih/items/arrow/ammo_arrow_single.mdl",
			--DesiredSilks = {	--; WARNING POINTER
			--	{SegmentsDesiredAmt = 5, SegmentsDesiredWidth = 1, SegmentsDesiredLength = 3, EntityOffset = Vector(2, 0, 0)},
			--	{SegmentsDesiredAmt = 6, SegmentsDesiredWidth = 1, SegmentsDesiredLength = 3, EntityOffset = Vector(2.1, 0, 0)},
			--	{SegmentsDesiredAmt = 10, SegmentsDesiredWidth = 1, SegmentsDesiredLength = 3, EntityOffset = Vector(2, 0, 0)},
			--},
			Ent = "arrow_projectile",
		},
		BulletFunctions = {
			-- Draw = draw_silk,
			OnStopped = arrow_hit,
			--PreRemove = preremove_silk,
			--PostRemove = postremove_silk,
		},
	},
	["grenade_30x29mm"] = {
		name = "Grenade 30x29mm",
		dmgtype = DMG_CLUB,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 150,
		maxcarry = 120,
		minsplash = 10,
		maxsplash = 5,
		TracerSetings = {
			MaxPathPoints = 5,
		},
		BulletSettings = {
			Mass = 200,
			PhysPenetrationMul = 0.0,
			-- Speed = 185,
			Speed = 55,	--; Comically slow
			LifeTime = 15,
			Shell = "12guage",
			Icon = matRfileAmmo
		},
		FunctionInfo = {
			Model = "models/Items/AR2_Grenade.mdl",
			-- Ent = "crossbow_projectile",
		},
		BulletFunctions = {
			Draw = draw_explosive,
			OnStopped = onstopped_explosive,
			PreRemove = preremove_explosive,
		},
	},
	["pulse"] = {
		name = "Pulse",
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 120,
		maxcarry = 120,
		minsplash = 16,
		maxsplash = 16,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 25,
			TracerLength = 150,
			TracerWidth = 1.5,
			TracerColor = Color(155, 232, 255),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 58,
			Force = 50,
			Penetration = 23.6,
			Shell = "Pulse",
			Speed = 1000,
			Diameter = 10,
			Mass = 10,
			Icon = matRfileAmmo,
			noricochet = true,
		}
	},
	["blood"] = {
		name = "Blood",
		dmgtype = DMG_CLUB,
		tracer = TRACER_LINE,
		noentity = true,
		plydmg = 0,
		npcdmg = 0,
		force = 120,
		maxcarry = 120,
		minsplash = 16,
		maxsplash = 16,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 25,
			TracerLength = 150,
			MaxPathPoints = 10,
			TracerWidth = 4.5,
			TracerColor = Color(255, 0, 0),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
		BulletSettings = {
			Damage = 0,
			Force = 50,
			Penetration = 17,
			-- Shell = "Pulse",
			Speed = 1000,
			Diameter = 10,
			Mass = 10,
			Icon = matRfileAmmo
		},
		BulletFunctions = {
			-- Hit = hit_blood,
			OnStopped = onstopped_blood,
			PostRicochet = postricochet_blood,
			PostPenetration = postpenetration_blood,
		}
	},
	["tasercartridge"] = {
		name = "Taser Cartridge",
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 120,
		maxcarry = 120,
		minsplash = 16,
		maxsplash = 16,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 25,
			TracerLength = 150,
			TracerWidth = 1.5,
			TracerColor = Color(155, 232, 255),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 25000
		},
	},
	["20mm"] = {
		name = "20mm",
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 230,
		maxcarry = 20,
		minsplash = 8,
		maxsplash = 10,
		TracerSetings = {
			TracerBody = Material("effects/scotchmuzzleflashw"),
			TracerTail = Material("effects/fas_bullet"),
			TracerHeadSize = 80,
			TracerLength = 128,
			TracerWidth = 32,
			TracerColor = Color(120, 120, 120),
			TracerTPoint1 = 0.8,
			TracerTPoint2 = 1,
			TracerSpeed = 6000
		},
		BulletSettings = {
			Damage = 100,
			Force = 120,
			Penetration = 1,
			Shell = "",
			Speed = 170,
			Diameter = 20,
			Mass = 50,
			Icon = matShotgunAmmo
		}
	},
	["tranquilizerdarts"] = {
		name = "Tranquilizer Darts",
		dmgtype = DMG_CLUB,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 50,
		maxcarry = 30,
		minsplash = 0,
		maxsplash = 0,
		TracerSetings = {
			TracerBody = Material("particle/fire"),
			TracerTail = Material("effects/laser_tracer"),
			TracerHeadSize = 1.5,
			TracerLength = 155,
			TracerWidth = 5,
			TracerColor = Color(37, 78, 36),
			TracerTPoint1 = 0.25,
			TracerTPoint2 = 1,
			TracerSpeed = 3000,
			NoSpin = true,
		},
		BulletSettings = {
			Damage = 5,
			Force = 10,
			Penetration = 0,
			Shell = "9x19",
			Spread = Vector(0, 0, 0),
			Speed = 650,
			AirResistMul = 0.0002,
			Diameter = 9,
			Mass = 18,
			Icon = matPistolAmmo,
			tranquilizer = true,
		}
	},
	["9x21mm"] = {
		name = "9x21 mm",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 110,
		maxcarry = 80,
		minsplash = 1,
		maxsplash = 1,
		BulletSettings = {
			Damage = 31,
			Force = 31,
			Penetration = 11,
			Shell = "9x21",
			Speed = 410,
			Diameter = 9,
			Mass = 6.7,
			Icon = matPistolAmmo
		}
	},
	[".366tkm_bpm"] = {
		name = ".366 TKM BP-M",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 160,
		maxcarry = 120,
		minsplash = 8,
		maxsplash = 8,
		BulletSettings = {
			Damage = 60,
			Force = 55,
			Penetration = 8,
			Shell = "366tkm",
			Speed = 730,
			Diameter = 9.58,
			Mass = 12,
			Icon = matRfileAmmo
		}
	},
	["6.8x51fmj"] = {
		name = "6.8x51 mm FMJ",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 250,
		maxcarry = 120,
		minsplash = 10,
		maxsplash = 10,
		BulletSettings = {
			Damage = 72,
			Force = 70,
			Penetration = 22,
			Shell = "762x51",
			Speed = 914,
			Diameter = 6.8,
			Mass = 9.5,
			Icon = matRfileAmmo
		}
	},
	[".300blk"] = {
		name = ".300 Blackout",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 180,
		maxcarry = 120,
		minsplash = 8,
		maxsplash = 8,
		BulletSettings = {
			Damage = 55,
			Force = 50,
			Penetration = 12,
			Shell = "762x39",
			Speed = 720,
			Diameter = 7.62,
			Mass = 12.5,
			Icon = matRfileAmmo
		}
	},
	[".50bmgslap"] = {
		name = ".50 BMG Slap",
		allowed = true,
		dmgtype = DMG_BULLET + DMG_AIRBOAT,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 500,
		maxcarry = 60,
		minsplash = 20,
		maxsplash = 20,
		BulletSettings = {
			Damage = 350,
			Force = 200,
			Penetration = 80,
			Shell = "50cal",
			Speed = 1100,
			Diameter = 12.7,
			Mass = 50,
			Icon = matRfileAmmo
		}
	},
	["grenade_40x381"] = {
		name = "40mm Grenade M381",
		dmgtype = DMG_BLAST,
		tracer = TRACER_NONE,
		plydmg = 0,
		npcdmg = 0,
		force = 150,
		maxcarry = 20,
		minsplash = 10,
		maxsplash = 5
	},
	["dihbattery"] = {
		name = "D.I.H Battery",
		allowed = true,
		dmgtype = DMG_BULLET,
		tracer = TRACER_NONE,
		plydmg = 0,
		npcdmg = 0,
		force = 0,
		maxcarry = 5,
		minsplash = 0,
		maxsplash = 0,
	},
}
local ammotypes = hg.ammotypes
local ammoents = {
	["9x21mm"] = {
		Icon = "vgui/hud/hmcd_round_9x19",
		Material = "models/hmcd_ammobox_9",
		Scale = 1
	},
	[".366tkm_bpm"] = {
		Icon = "vgui/hud/366fmj.png",
		Model = "models/items/ammo_76239.mdl",
		Scale = 1
	},
	["6.8x51fmj"] = {
		Icon = "vgui/hud/hmcd_round_556",
		Material = "models/hmcd_ammobox_556",
		Scale = 1
	},
	[".300blk"] = {
		Icon = "vgui/hud/545zcity",
		Material = "models/hmcd_ammobox_556",
		Scale = 1
	},
	[".50bmgslap"] = {
		Material = "models/hmcd_ammobox_792",
		Scale = 1.6,
		Color = Color(155, 122, 75),
		Count = 10
	},
	["grenade_40x381"] = {
		Model = "models/items/ar2_grenade.mdl",
		Scale = 1,
		Count = 5
	},
	["5.56x45mm"] = {
		Icon = "vgui/hud/556fmj.png",
		Material = "models/hmcd_ammobox_556",
		Scale = 1
	},
	["5.56x45mmm855"] = {
		Icon = "vgui/hud/m855.png",
		Material = "models/hmcd_ammobox_556",
		Scale = 1
	},
	["5.56x45mmm855a1"] = {
		Icon = "vgui/hud/m855a1.png",
		Material = "models/hmcd_ammobox_556",
		Scale = 1
	},
	["5.56x45mmm995"] = {
		Icon = "vgui/hud/m995.png",
		Model = "models/zcity/ammo/ammo_556x45_ap.mdl",
		Scale = 1,
	},
	["7.62x39mm"] = {
		Icon = "vgui/hud/ps.png",
		Model = "models/items/ammo_76239.mdl",
		Scale = 1
	},
	["7.62x51mm"] = {  
		Icon = "vgui/hud/m80.png",
		Model = "models/items/ammo_76251.mdl",
		Scale = 1,
		Count = 25,
	},
	["7.62x51mmm993"] = {  
		Icon = "vgui/hud/m993.png",
		Model = "models/items/ammo_76251.mdl",
		Scale = 1,
		Count = 25,
	},
	["7.62x54mm"] = {
		Icon = "vgui/hud/std.png",
		Model = "models/zcity/ammo/ammo_762x54_7h1.mdl",
		Scale = 1,
		Count = 25,
	},
	["7.62x54mm7n26"] = {
		Icon = "vgui/hud/t46m.png",
		Model = "models/zcity/ammo/ammo_762x54_7h1.mdl",
		Scale = 1,
		Count = 25,
	},
	["7.62x39mmsp"] = {
		Icon = "vgui/hud/hp.png",
		Model = "models/zcity/ammo/ammo_762x54_7h1.mdl",
		Scale = 1,
		Count = 25,
		Color = Color(14,54,22)
	},
	["7.62x39mmbp"] = {
		Icon = "vgui/hud/bp.png",
		Model = "models/zcity/ammo/ammo_762x54_7h1.mdl",
		Scale = 1,
		Count = 25,
		Color = Color(14,54,22)
	},
	[".366tkmfmj"] = {
		Icon = "vgui/hud/366fmj.png",
		Model = "models/items/ammo_76239.mdl",
		Scale = 1
	},
	[".366tkmgeksa"] = {
		Icon = "vgui/hud/geksa.png",
		Model = "models/items/ammo_76239.mdl",
		Scale = 1
	},
	["5.45x39mm"] = {
		Icon = "vgui/hud/545ps.png",
		Model = "models/zcity/ammo/ammo_545x39_fmj.mdl",
		Scale = 1,
	},
	["5.45x39mm7n22"] = {
		Icon = "vgui/hud/545bp.png",
		Model = "models/zcity/ammo/ammo_545x39_fmj.mdl",
		Scale = 1,
	},
	["5.45x39mm7n39"] = {
		Icon = "vgui/hud/ppbs.png",
		Model = "models/zcity/ammo/ammo_545x39_fmj.mdl",
		Scale = 1,
	},
	["metal_debris"] = {
		Icon = "vgui/hud/bullets/high_caliber.png",
		Material = "models/hmcd_ammobox_12",
		Scale = 1.1,
		Count = 12,
		Spawnable = false
	},
	["12/70gauge"] = {
		Icon = "vgui/hud/def.png",
		Material = "models/hmcd_ammobox_12",
		Scale = 1.1,
		Count = 12,
	},
	["12/70beanbag"] = {
		Icon = "vgui/hud/hmcd_round_beanbag.vmt",
		Model = "models/ammo/beanbag12_ammo.mdl",
		Scale = 1,
		Count = 12,
	},
	["12/70slug"] = {
		Icon = "vgui/hud/12copper.png",
		Model = "models/zcity/ammo/ammo_12x76_zhekan.mdl",
		Scale = 1.1,
		Count = 12,
		Color = Color(125, 155, 95)
	},
	["12/70rip"] = {
		Icon = "vgui/hud/p3.png",
		Model = "models/zcity/ammo/ammo_12x76_zhekan.mdl",
		Scale = 1.1,
		Count = 12,
		Color = Color(22, 168, 221)
	},
	["12/70blank"] = {
		Icon = "vgui/hud/12_70blankzcity.vmt",
		Model = "models/ammo/beanbag12_ammo.mdl",
		Scale = 1,
		Count = 12,
		Color = Color(22, 168, 221)
	},
	["23x75sh10"] = {
		Icon = "vgui/hud/sh.png",
		Material = "models/hmcd_ammobox_12",
		Scale = 1.2,
		Count = 12,
	},
	["23x75sh25"] = {
		Icon = "vgui/hud/sh25.png",
		Material = "models/hmcd_ammobox_12",
		Scale = 1.2,
		Count = 12,
	},
	["23x75barricade"] = {
		Icon = "vgui/hud/bar.png",
		Material = "models/hmcd_ammobox_12",
		Scale = 1.2,
		Count = 12,
	},
	["23x75zvezda"] = {
		Icon = "vgui/hud/z.png",
		Material = "models/hmcd_ammobox_12",
		Scale = 1.2,
		Count = 12,
	},
	["23x75waver"] = {
		Icon = "vgui/hud/sh.png",
		Material = "models/hmcd_ammobox_12",
		Scale = 1.2,
		Count = 12,
	},
	["20/70gauge"] = {
		Icon = "vgui/hud/20ga_std.png",
		Material = "models/hmcd_ammobox_12",
		Scale = 1.1,
		Count = 12,
		Color = Color(255,150,0)
	},
	["20/70slug"] = {
		Icon = "vgui/hud/20ga_p6u.png",
		Material = "models/hmcd_ammobox_12",
		Scale = 1.1,
		Count = 12,
		Color(0,84,0)
	},
	["20/70flechette"] = {
		Icon = "vgui/hud/20ga_p3.png",
		Material = "models/hmcd_ammobox_12",
		Scale = 1.1,
		Count = 12,
		Color = Color(154,154,154)
	},
	["9x18mm"] = {
		Icon = "vgui/hud/hmcd_round_918.vmt",
		Model = "models/zcity/ammo/ammo_9x18_pmm.mdl",
		Scale = 1
	},
	["9x18mmpbm"] = {
		Icon = "vgui/hud/hmcd_round_918.vmt",
		Model = "models/zcity/ammo/ammo_9x18_pmm.mdl",
		Scale = 1
	},
	["9x17mm"] = {
		Icon = "vgui/hud/hmcd_round_9.vmt",
		Model = "models/zcity/ammo/ammo_9x18_pmm.mdl",
		Scale = 1
	},
	["9x19mmparabellum"] = {
		Icon = "vgui/hud/m882.png",
		Material = "models/hmcd_ammobox_9",
		Scale = 0.8,
	},
	["9x19mmpbp"] = {
		Icon = "vgui/hud/pbpgzh.png",
		Material = "models/hmcd_ammobox_9",
		Scale = 0.8,
	},
	["9x19mmgreentracer"] = {
		Icon = "vgui/hud/tracer.png",
		Color = Color(0, 255, 0),
		Scale = 0.8
	},
	["9x19mmqm"] = {
		Icon = "vgui/hud/quake.png",
		Material = "models/hmcd_ammobox_9",
		Color = Color(0, 26, 255),
		Scale = 0.8
	},
	[".45rubber"] = {
		Icon = "vgui/hud/45rub.png",
		Model = "models/ammo/beanbag9_ammo.mdl",
		Scale = 1
	},
	["9mmpakblank"] = {
		Icon = "vgui/hud/hmcd_round_9.vmt",
		Model = "models/ammo/beanbag9_ammo.mdl",
		Scale = 1
	},
	["9mmpakflashdefense"] = {
		Icon = "vgui/hud/hmcd_round_9.vmt",
		Model = "models/ammo/beanbag9_ammo.mdl",
		Scale = 1
	},
	["18x45mmtraumatic"] = {
		Icon = "vgui/hud/1845t.png",
		Model = "models/zcity/ammo/ammo_12x70_buck.mdl",
		Scale = 0.8,
		Color = Color(87, 110, 82),
		Count = 4,
	},
	["18x45mmflashdefense"] = {
		Icon = "vgui/hud/1845t.png",
		Model = "models/zcity/ammo/ammo_12x76_dart.mdl",
		Scale = 0.8,
		Color = Color(119, 47, 47),
		Count = 4,
	},
	["4.6x30mm"] = {
		Icon = "vgui/hud/47fmj.png",
		Model = "models/4630_ammobox.mdl",
		Scale = 1,
	},
	["4.6x30mmap"] = {
		Icon = "vgui/hud/47ap.png",
		Model = "models/4630_ammobox.mdl",
		Scale = 1,
	},
	[".44remingtonmagnum"] = {
		Icon = "vgui/hud/44hp.png",
		Material = "models/hmcd_ammobox_22",
		Color = Color(125, 155, 95),
		Scale = 0.8,
		Count = 20,
	},
	[".357magnum"] = {
		Icon = "vgui/hud/357fmj.png",
		Model = "models/Items/357ammobox.mdl",
		Scale = 0.5,
		Count = 20,
	},
	[".38special"] = {
		Icon = "vgui/hud/38special.png",
		Material = "models/hmcd_ammobox_38",
		Color = Color(255, 255, 255),
		Scale = 0.8,
		Count = 20,
	},
	["9x39mm"] = {
		Icon = "vgui/hud/sp5.png",
		Model = "models/zcity/ammo/ammo_9x39_sp5.mdl",
		Scale = 1,
		Count = 20,
	},
	["9x39mmsp6"] = {
		Icon = "vgui/hud/sp6.png",
		Model = "models/zcity/ammo/ammo_9x39_sp5.mdl",
		Scale = 1,
		Count = 20,
	},
	["5.7x28mm"] = {
		Icon = "vgui/hud/ss198lf.png",
		Material = "models/hmcd_ammobox_22",
		Scale = 1.2,
		Color = Color(125, 155, 95)
	},
	["5.7x28mmap"] = {
		Icon = "vgui/hud/ss190.png",
		Material = "models/hmcd_ammobox_22",
		Scale = 1.2,
		Color = Color(125, 155, 95)
	},
	[".50actionexpress"] = {
		Icon = "vgui/hud/50fmj.png",
		Material = "models/hmcd_ammobox_22",
		Scale = 1,
		Color = Color(255, 255, 125),
		Count = 20,
	},
	[".50actionexpressjhp"] = {
		Icon = "vgui/hud/50jhp.png",
		Material = "models/hmcd_ammobox_22",
		Scale = 1,
		Color = Color(73, 73, 32),
		Count = 20,
	},
	[".50actionexpresscopper"] = {
		Icon = "vgui/hud/50c.png",
		Material = "models/hmcd_ammobox_22",
		Scale = 1,
		Color = Color(245, 149, 5),
		Count = 20,
	},
	["14.5x114mmbztm"] = {
		Icon = "vgui/hud/bztmzcity.vmt",
		Material = "models/hmcd_ammobox_22",
		Scale = 1,
		Color = Color(246, 129, 5),
		Count = 20,
	},
	["14.5x114mmb32"] = {
		Icon = "vgui/hud/hmcd_round_145.vmt",
		Material = "models/hmcd_ammobox_22",
		Scale = 1,
		Color = Color(55, 55, 2),
		Count = 20,
	},
	[".338lapuamagnum"] = {
		Icon = "vgui/hud/338fmj.png",
		Material = "models/hmcd_ammobox_792",
		Scale = 1,
		Color = Color(125, 255, 125),
		Count = 20,
	},
	["12.7x108mm"] = {
		Icon = "vgui/hud/127108.png",
		Material = "models/hmcd_ammobox_792",
		Scale = 1.6,
		Color = Color(225, 122, 125),
		Count = 20,
	},
	["12.7x55mm"] = {
		Icon = "vgui/hud/ps12.png",
		Material = "models/hmcd_ammobox_792",
		Scale = 1.2,
		Color = Color(204, 241, 140),
		Count = 20,
	},
	[".22longrifle"] = {
		Icon = "vgui/hud/22lr.png",
		Material = "models/hmcd_ammobox_22",
		Scale = 1
	},
	["rpg-7projectile"] = {
		Icon = "vgui/hud/bullets/high_caliber.png",
		Model = "models/weapons/tfa_ins2/w_rpg7_projectile.mdl",
		Count = 1
	},
	["nails"] = {
		Icon = "vgui/hud/hmcd_nail.vmt",
		Material = "models/fello/f_matchboxtex", -- "models/hmcd_nails"
		Scale = 1,
		Count = 3,
	},
	["armature"] = {
		Icon = "vgui/hud/hmcd_crossbow_bolt.vmt",
		Model = "models/Items/CrossbowRounds.mdl",
		Count = 5
	},
	["arrow"] = {
		Icon = "vgui/hud/hmcd_round_arrow.vmt",
		Model = "models/z_city/nmrih/items/arrow/ammo_arrow_box.mdl",
		Count = 5
	},
	["grenade_30x29mm"] = {
		Icon = "vgui/hud/bullets/high_caliber.png",
		Model = "models/Items/BoxMRounds.mdl",
		Count = 15
	},
	["pulse"] = {
		Icon = "vgui/hud/hmcd_energy_charge.vmt",
		Model = "models/Items/combine_rifle_cartridge01.mdl",
		Count = 30
	},
	["tasercartridge"] = {
		Icon = "vgui/hud/hmcd_taser_cartridge.vmt",
		Model = "models/ammo/taser_ammo.mdl",
		Count = 1,
		Material = "models/defcon/taser/taser",
	},
	["dihbattery"] = {
		Icon = "vgui/hud/bullets/low_caliber.png",
		Model = "models/Items/battery.mdl",
		Scale = 0.75,
		Count = 1,
	},
	[".45acp"] = {
		Icon = "vgui/hud/45fmj.png",
		Model = "models/zcity/ammo/ammo_1143x23_fmj.mdl"
	},
	[".45acpp"] = {
		Icon = "vgui/hud/45p.png",
		Model = "models/zcity/ammo/ammo_1143x23_fmj.mdl"
	},
	["7.62x25mm"] = {
		Icon = "vgui/hud/akbs.png",
		Material = "models/hmcd_ammobox_22",
		Color = Color(155, 149, 95)
	},
	[".45acphydroshock"] = {
		Icon = "vgui/hud/hydra.png",
		Model = "models/zcity/ammo/ammo_1143x23_hydro.mdl"
	},
	["7.65x17mm"] = {
		Icon = "vgui/hud/bullets/low_caliber.png",
		Model = "models/zcity/ammo/ammo_1143x23_fmj.mdl"
	},
	[".40sw"] = {
		Icon = "vgui/hud/40sw.png",
		Model = "models/zcity/ammo/ammo_1143x23_hydro.mdl"
	},
	["20mm"] = {
		Icon = "vgui/hud/musketballzcity.vmt",
		Material = "models/props_c17/paper01",
		Scale = 0.8,
		Count = 4,
	},
	["tranquilizerdarts"] = {
		Icon = "vgui/hud/bullets/low_caliber.png",
		Material = "models/hmcd_ammobox_9",
		Scale = 0.8,
	},
}

hg.ammoents = ammoents

local defaultAmmoIconPaths = {
	low = "vgui/hud/bullets/low_caliber.png",
	high = "vgui/hud/bullets/high_caliber.png",
	buck = "vgui/hud/bullets/buck_caliber.png"
}

local function normalizeAmmoLookupName(value)
	return string.lower(string.gsub(tostring(value or ""), "[^%w]", ""))
end

local function getAmmoKey(ammoName)
	if isnumber(ammoName) then ammoName = game.GetAmmoName(ammoName) end
	if not isstring(ammoName) then return end
	if ammotypes[ammoName] then return ammoName end

	local normalized = normalizeAmmoLookupName(ammoName)
	for key, ammoData in pairs(ammotypes) do
		if normalizeAmmoLookupName(key) == normalized or normalizeAmmoLookupName(ammoData.name) == normalized then
			return key
		end
	end
end

local function getExistingAmmoIconPath(path)
	if not isstring(path) or path == "" then return end
	path = string.Replace(path, "\\", "/")
	path = string.gsub(path, "^materials/", "")
	if file.Exists("materials/" .. path, "GAME") then return path end
end

function hg.GetAmmoCaliberClass(ammoName)
	local key = getAmmoKey(ammoName)
	local ammoData = key and ammotypes[key]
	local bulletSettings = ammoData and ammoData.BulletSettings or {}
	local lowerName = string.lower((ammoData and ammoData.name) or tostring(ammoName or ""))

	if (bulletSettings.NumBullet or 1) > 1
		or string.find(lowerName, "gauge", 1, true)
		or string.find(lowerName, "buck", 1, true)
		or string.find(lowerName, "shot", 1, true)
		or string.find(lowerName, "slug", 1, true)
		or string.find(lowerName, "beanbag", 1, true)
		or string.find(lowerName, "12/70", 1, true)
		or string.find(lowerName, "20/70", 1, true)
		or string.find(lowerName, "23x75", 1, true) then
		return "buck"
	end

	local diameter = tonumber(bulletSettings.Diameter) or 0
	local damage = tonumber(bulletSettings.Damage) or 0
	if damage >= 40 or diameter >= 12
		or string.find(lowerName, "5.45", 1, true)
		or string.find(lowerName, "5.56", 1, true)
		or string.find(lowerName, "7.62", 1, true)
		or string.find(lowerName, "12.7", 1, true)
		or string.find(lowerName, "14.5", 1, true)
		or string.find(lowerName, ".338", 1, true)
		or string.find(lowerName, "rpg", 1, true)
		or string.find(lowerName, "rocket", 1, true)
		or string.find(lowerName, "grenade", 1, true) then
		return "high"
	end

	return "low"
end

function hg.GetAmmoIconPath(ammoName)
	local key = getAmmoKey(ammoName)
	local ammoEntityData = key and ammoents[key]
	local exactPath = ammoEntityData and getExistingAmmoIconPath(ammoEntityData.Icon)
	if exactPath then return exactPath end
	if ammoEntityData and ammoEntityData.Icon == matPistolAmmo then return defaultAmmoIconPaths.low end
	if ammoEntityData and ammoEntityData.Icon == matRfileAmmo then return defaultAmmoIconPaths.high end
	if ammoEntityData and ammoEntityData.Icon == matShotgunAmmo then return defaultAmmoIconPaths.buck end

	local ammoData = key and ammotypes[key]
	exactPath = ammoData and ammoData.BulletSettings and getExistingAmmoIconPath(ammoData.BulletSettings.Icon)
	if exactPath then return exactPath end
	if ammoData and ammoData.BulletSettings and ammoData.BulletSettings.Icon == matPistolAmmo then return defaultAmmoIconPaths.low end
	if ammoData and ammoData.BulletSettings and ammoData.BulletSettings.Icon == matRfileAmmo then return defaultAmmoIconPaths.high end
	if ammoData and ammoData.BulletSettings and ammoData.BulletSettings.Icon == matShotgunAmmo then return defaultAmmoIconPaths.buck end

	return defaultAmmoIconPaths[hg.GetAmmoCaliberClass(ammoName)] or defaultAmmoIconPaths.low
end

if CLIENT then
	local ammoIconMaterials = {}
	function hg.GetAmmoIconMaterial(ammoName)
		local path = hg.GetAmmoIconPath(ammoName)
		ammoIconMaterials[path] = ammoIconMaterials[path] or Material(path)
		return ammoIconMaterials[path]
	end
end

local function addAmmoTypes()
	for name, tbl in pairs(ammotypes) do
		game.AddAmmoType(tbl)
		
		if(!tbl.noentity)then
			if CLIENT then language.Add(tbl.name .. "_ammo", tbl.name) end
			local ammoent = {}
			ammoent.Base = "ammo_base"
			ammoent.PrintName = tbl.name
			ammoent.Category = "ZCity Ammo"
			ammoent.Spawnable = (tbl.Spawnable and tbl.Spawnable ~= nil) and tbl.Spawnable or true
			ammoent.AmmoCount = ammoents[name].Count or 30
			ammoent.AmmoType = tbl.name
			ammoent.Model = ammoents[name].Model or "models/props_lab/box01a.mdl"
			ammoent.ModelMaterial = ammoents[name].Material or ""
			ammoent.ModelScale = ammoents[name].Scale or 1
			ammoent.Color = ammoents[name].Color or Color(255, 255, 255)
			local iconPath = hg.GetAmmoIconPath(name)
			ammoent.IconOverride = iconPath
			ammoent.IconTexture = iconPath
			scripted_ents.Register(ammoent, "ent_ammo_" .. name)
		end
	end

	game.BuildAmmoTypes()
	--PrintTable(game.GetAmmoTypes())
end

if CLIENT then
	local function applyAmmoIconsToRegisteredEntities()
		for className, entData in pairs(scripted_ents.GetList() or {}) do
			local entTable = entData and entData.t
			if not entTable then continue end
			if not string.StartWith(className, "ent_ammo_") then continue end
			local ammoName = entTable.AmmoType or string.sub(className, 10)
			local iconPath = hg.GetAmmoIconPath(ammoName)
			if iconPath then
				entTable.IconOverride = iconPath
				entTable.IconTexture = iconPath
			end
		end
	end

	hook.Add("Initialize", "hg-ammo-apply-icons", applyAmmoIconsToRegisteredEntities)
	hook.Add("OnReloaded", "hg-ammo-apply-icons", applyAmmoIconsToRegisteredEntities)
	hook.Add("SpawnMenuOpen", "hg-ammo-apply-icons", applyAmmoIconsToRegisteredEntities)
end

addAmmoTypes()
hook.Add("Initialize", "init-ammo", addAmmoTypes)

--РєРѕСЌС„С„РёС†РёРµРЅС‚ Р»РѕР±РѕРІРѕРіРѕ СЃРѕРїСЂРѕС‚РёРІР»РµРЅРёСЏ С‚Р°РєР¶Рµ РјРѕР¶РЅРѕ СЂР°СЃСЃС‡РёС‚Р°С‚СЊ РјР°С‚РµРјР°С‚РёС‡РµСЃРєРё
--11300 - РїР»РѕС‚РЅРѕСЃС‚СЊ СЃРІРёРЅС†Р° РІ РєРі/Рј3

local ammotypeshuy = {}
for i,tbl in pairs(table.Copy(ammotypes)) do
	ammotypeshuy[tbl.name] = tbl
	ammotypeshuy[tbl.name].name = i
end

hg.ammotypeshuy = ammotypeshuy

local ammotypesallowed = {}
for i,tbl in pairs(table.Copy(ammotypeshuy)) do
	if not tbl.allowed then continue end
	ammotypesallowed[i] = tbl
end

hg.ammotypesallowed = ammotypesallowed

for i,tbl in pairs(hg.ammotypes) do
	if not tbl.BulletSettings or not tbl.BulletSettings.Diameter or not tbl.BulletSettings.Speed then continue end
	local coef = 8 / (1.2255 * (tbl.BulletSettings.Speed^2) * math.pi * ((tbl.BulletSettings.Diameter / 1000)^2))
	tbl.BulletSettings.AirResistanceCoef = coef
end
