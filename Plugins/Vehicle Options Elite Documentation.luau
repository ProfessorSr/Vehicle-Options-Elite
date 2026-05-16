--[[
	V O E   P L U G I N Ss Documentation Module
	
	This module provides comprehensive documentation for all 29 plugins
	in the V O E   P L U G I N Ss vehicle system. Each plugin is designed to enhance
	vehicle functionality with realistic features.
	
	Last updated: 2026-03-22
]]

local VOEPlugins = {}

VOEPlugins.Description = [[
	The V O E   P L U G I N Ss system is a comprehensive vehicle enhancement framework
	that provides realistic vehicle features through modular plugins. Each plugin
	operates independently and can be enabled/disabled via configuration.
	
	Plugins use a tag-based system for identifying vehicle parts, making them
	compatible with various vehicle models without requiring specific hierarchies.
]]

VOEPlugins.Categories = {
	Lighting = {
		"Headlights",
		"BrakeLights",
		"TurnSignals",
		"ReverseLights",
		"FogLights",
		"Spotlights",
		"Underglow",
		"PoliceLights",
		"AmbulanceLights",
		"FiretruckLights",
		"DomeLights",
		"PuddleLights",
		"Reflectors",
	},
	Body = {
		"Doors",
		"Windows",
		"Hood",
		"Trunk",
		"Sunroof",
		"Spoiler",
		"TonneauCover",
		"Popups",
		"RunningBoards",
		"PowerSteps",
	},
	Systems = {
		"Engine",
		"Ignition",
		"Fuel",
		"Seatbelt",
		"Wipers",
		"Extras",
	},
}

VOEPlugins.Plugins = {}

-- ============================================================================
-- LIGHTING PLUGINS
-- ============================================================================

VOEPlugins.Plugins.Headlights = {
	Name = "Headlights",
	Category = "Lighting",
	Description = "Multi-mode headlight system with DRL, parking, low beam, and high beam modes",
	Features = {
		"Daytime Running Lights (DRL) - separate toggle",
		"Parking lights - dim amber/white corner lights",
		"Low beam headlights - standard driving mode",
		"High beam headlights - enhanced range and brightness",
		"License plate lights - activate with parking+ modes",
		"Taillights - activate with parking+ modes",
		"Reflector support for low and high beams",
		"Configurable light profiles (brightness, range, angle, color)",
		"Attachment yaw overrides for directional control",
	},
	Keybinds = {
		"L - Toggle headlight modes (Off -> Parking -> Low -> High -> Off)",
		"G - Toggle DRL separately",
	},
	Tags = {
		"VOE_Light_DRL - Daytime Running Lights",
		"VOE_Light_Parking - Parking lights",
		"VOE_Light_Low - Low beam headlights",
		"VOE_Light_High - High beam headlights",
		"VOE_Light_LicensePlate - License plate lights",
		"VOE_Light_Taillight - Taillights",
		"VOE_Reflector_Low - Low beam reflectors",
		"VOE_Reflector_High - High beam reflectors",
	},
	Config = {
		Enabled = true,
		BlinkInterval = 0.5,
		AttachmentYawOverrides = {
			High = 0,
			Low = 0,
			Parking = 0,
			DRL = 0,
			LicensePlate = 180,
			Taillight = 180,
		},
		Lights = {
			DRL = {Brightness = 2.2, Range = 36, Angle = 90, Shadows = false, Color = Color3.fromRGB(255, 245, 230)},
			Parking = {Brightness = 3.2, Range = 14, Angle = 80, Shadows = false, Color = Color3.fromRGB(255, 210, 150)},
			Low = {Brightness = 3.8, Range = 90, Angle = 115, Shadows = true, Color = Color3.fromRGB(255, 244, 214)},
			High = {Brightness = 4.4, Range = 130, Angle = 125, Shadows = true, Color = Color3.fromRGB(255, 244, 214)},
			LicensePlate = {Brightness = 1.8, Range = 6, Angle = 120, Shadows = false, Color = Color3.fromRGB(255, 255, 255)},
			Taillight = {Brightness = 1.6, Range = 12, Angle = 100, Shadows = false, Color = Color3.fromRGB(255, 60, 60)},
		},
	},
}

VOEPlugins.Plugins.BrakeLights = {
	Name = "BrakeLights",
	Category = "Lighting",
	Description = "Brake light system that activates when vehicle brakes are applied",
	Features = {
		"Automatic activation when braking",
		"Red brake lights with configurable brightness",
		"Rear-facing orientation",
		"Configurable light profile",
	},
	Keybinds = {
		"Automatic - activates when brake pedal is pressed",
	},
	Tags = {
		"VOE_Light_Brake - Brake light parts",
	},
	Config = {
		Enabled = true,
		Lights = {
			Brake = {Brightness = 2.2, Range = 22, Angle = 70, Shadows = false, Color = Color3.fromRGB(255, 60, 60)},
		},
		AttachmentYawOverrides = {
			Brake = 180,
		},
	},
}

VOEPlugins.Plugins.TurnSignals = {
	Name = "TurnSignals",
	Category = "Lighting",
	Description = "Turn signal system with left, right, and hazard light modes",
	Features = {
		"Left turn signal blinking",
		"Right turn signal blinking",
		"Hazard lights (both signals blinking)",
		"Configurable blink interval",
		"Amber signal lights",
		"Front and rear signal support",
	},
	Keybinds = {
		"Z - Toggle left turn signal",
		"C - Toggle right turn signal",
		"X - Toggle hazard lights",
	},
	Tags = {
		"VOE_Light_SignalLeft - Left signal lights",
		"VOE_Light_SignalRight - Right signal lights",
	},
	Config = {
		Enabled = true,
		BlinkInterval = 0.5,
		Lights = {
			Signal = {Brightness = 3.5, Range = 24, Angle = 80, Shadows = false, Color = Color3.fromRGB(255, 170, 0)},
		},
		AttachmentYawOverrides = {
			SignalLeftRear = 180,
			SignalRightRear = 180,
		},
		Keybinds = {
			ToggleSignalLeft = Enum.KeyCode.Z,
			ToggleSignalRight = Enum.KeyCode.C,
			ToggleHazard = Enum.KeyCode.X,
		},
	},
}

VOEPlugins.Plugins.ReverseLights = {
	Name = "ReverseLights",
	Category = "Lighting",
	Description = "Reverse light system that activates when vehicle is in reverse gear",
	Features = {
		"Automatic activation when in reverse",
		"White reverse lights",
		"Rear-facing orientation",
		"Configurable light profile",
	},
	Keybinds = {
		"Automatic - activates when reverse gear is selected",
	},
	Tags = {
		"VOE_Light_Reverse - Reverse light parts",
	},
	Config = {
		Enabled = true,
		Lights = {
			Reverse = {Brightness = 2.0, Range = 18, Angle = 90, Shadows = false, Color = Color3.fromRGB(255, 255, 255)},
		},
		AttachmentYawOverrides = {
			Reverse = 180,
		},
	},
}

VOEPlugins.Plugins.FogLights = {
	Name = "FogLights",
	Category = "Lighting",
	Description = "Fog light system for improved visibility in poor weather conditions",
	Features = {
		"Toggle on/off",
		"Warm white light color",
		"Wide beam angle for ground illumination",
		"Configurable brightness and range",
	},
	Keybinds = {
		"K - Toggle fog lights",
	},
	Tags = {
		"VOE_Light_Fog - Fog light parts",
	},
	Config = {
		Enabled = true,
		Lights = {
			Fog = {Brightness = 2.1, Range = 55, Angle = 90, Shadows = false, Color = Color3.fromRGB(255, 237, 181)},
		},
		AttachmentYawOverrides = {
			Fog = 0,
		},
		Keybinds = {
			ToggleFog = Enum.KeyCode.K,
		},
	},
}

VOEPlugins.Plugins.Spotlights = {
	Name = "Spotlights",
	Category = "Lighting",
	Description = "Rotatable spotlight system with arm and lamp control for searchlight functionality",
	Features = {
		"Left and right spotlights",
		"Independent arm rotation (up/down)",
		"Independent lamp rotation (left/right)",
		"Toggle on/off for each spotlight",
		"Configurable rotation step angle",
		"Material change to Neon when active",
	},
	Keybinds = {
		"1 - Toggle left spotlight on/off",
		"2 - Toggle right spotlight on/off",
		"Q - Rotate left arm up/down",
		"E - Rotate left lamp left/right",
		"R - Rotate right arm up/down",
		"T - Rotate right lamp left/right",
	},
	Tags = {
		"VOE_SpotlightLeft_Lamp - Left spotlight lamp parts",
		"VOE_SpotlightRight_Lamp - Right spotlight lamp parts",
		"SpotlightLeft_Arm - Left arm attachment",
		"SpotlightLeft_Lamp - Left lamp attachment",
		"SpotlightRight_Arm - Right arm attachment",
		"SpotlightRight_Lamp - Right lamp attachment",
	},
	Config = {
		Enabled = true,
		Spotlights = {
			Left = {
				armAttachment = "SpotlightLeft_Arm",
				lampAttachment = "SpotlightLeft_Lamp",
				armKey = "Q",
				lampKey = "E",
			},
			Right = {
				armAttachment = "SpotlightRight_Arm",
				lampAttachment = "SpotlightRight_Lamp",
				armKey = "R",
				lampKey = "T",
			},
		},
		ToggleKeys = {
			Left = "One",
			Right = "Two",
		},
	},
}

VOEPlugins.Plugins.Underglow = {
	Name = "Underglow",
	Category = "Lighting",
	Description = "Neon underglow lighting system for vehicle customization",
	Features = {
		"Toggle on/off",
		"Configurable color (default cyan)",
		"Adjustable brightness and range",
		"Ground illumination effect",
	},
	Keybinds = {
		"Configurable - typically bound to a key in vehicle setup",
	},
	Tags = {
		"VOE_Light_Underglow - Underglow light parts",
	},
	Config = {
		Enabled = true,
		Underglow = {
			Color = Color3.fromRGB(0, 255, 255),
			Brightness = 1.2,
			Range = 8,
		},
	},
}

VOEPlugins.Plugins.PoliceLights = {
	Name = "PoliceLights",
	Category = "Lighting",
	Description = "Emergency light system for police vehicles with blue flashing lights",
	Features = {
		"Police blue emergency lights",
		"Configurable blink interval",
		"High brightness for visibility",
		"Wide beam angle",
	},
	Keybinds = {
		"Configurable - typically bound to emergency light controls",
	},
	Tags = {
		"VOE_Light_Emergency - Emergency light parts",
	},
	Config = {
		Enabled = true,
		Lights = {
			Emergency = {
				Brightness = 3.6,
				Range = 30,
				Angle = 95,
				Shadows = false,
				Color = Color3.fromRGB(40, 130, 255),
			},
		},
		BlinkInterval = 0.5,
	},
}

VOEPlugins.Plugins.AmbulanceLights = {
	Name = "AmbulanceLights",
	Category = "Lighting",
	Description = "Emergency light system for ambulance vehicles with red/white flashing lights",
	Features = {
		"Ambulance red/white emergency lights",
		"Configurable blink patterns",
		"High brightness for visibility",
		"Wide beam angle",
	},
	Keybinds = {
		"Configurable - typically bound to emergency light controls",
	},
	Tags = {
		"VOE_Light_Emergency - Emergency light parts",
	},
	Config = {
		Enabled = true,
		Lights = {
			Emergency = {
				Brightness = 3.6,
				Range = 30,
				Angle = 95,
				Shadows = false,
				Color = Color3.fromRGB(255, 40, 40),
			},
		},
		BlinkInterval = 0.5,
	},
}

VOEPlugins.Plugins.FiretruckLights = {
	Name = "FiretruckLights",
	Category = "Lighting",
	Description = "Emergency light system for fire truck vehicles with red flashing lights",
	Features = {
		"Fire truck red emergency lights",
		"Configurable blink patterns",
		"High brightness for visibility",
		"Wide beam angle",
	},
	Keybinds = {
		"Configurable - typically bound to emergency light controls",
	},
	Tags = {
		"VOE_Light_Emergency - Emergency light parts",
	},
	Config = {
		Enabled = true,
		Lights = {
			Emergency = {
				Brightness = 3.6,
				Range = 30,
				Angle = 95,
				Shadows = false,
				Color = Color3.fromRGB(255, 60, 0),
			},
		},
		BlinkInterval = 0.5,
	},
}

VOEPlugins.Plugins.DomeLights = {
	Name = "DomeLights",
	Category = "Lighting",
	Description = "Interior lighting system with dome and map lights",
	Features = {
		"Dome light for main cabin illumination",
		"Left and right map lights",
		"Warm white interior lighting",
		"Configurable brightness and range",
	},
	Keybinds = {
		"Configurable - typically bound to interior light controls",
	},
	Tags = {
		"VOE_Light_Dome - Dome light parts",
		"VOE_Light_MapLeft - Left map light parts",
		"VOE_Light_MapRight - Right map light parts",
	},
	Config = {
		Enabled = true,
		Lights = {
			Dome = {
				Brightness = 1.2,
				Range = 10,
				Angle = 60,
				Shadows = false,
				Color = Color3.fromRGB(255, 240, 210),
			},
			MapLeft = {
				Brightness = 1.0,
				Range = 8,
				Angle = 55,
				Shadows = false,
				Color = Color3.fromRGB(255, 240, 215),
			},
			MapRight = {
				Brightness = 1.0,
				Range = 8,
				Angle = 55,
				Shadows = false,
				Color = Color3.fromRGB(255, 240, 215),
			},
		},
	},
}

VOEPlugins.Plugins.PuddleLights = {
	Name = "PuddleLights",
	Category = "Lighting",
	Description = "Door-mounted puddle lights that illuminate the ground when doors are opened",
	Features = {
		"Automatic activation when doors open",
		"Warm white illumination",
		"Ground lighting for entry/exit",
		"Configurable brightness and range",
	},
	Keybinds = {
		"Automatic - activates when doors are opened",
	},
	Tags = {
		"VOE_Light_Puddle - Puddle light parts",
	},
	Config = {
		Enabled = true,
		Lights = {
			Puddle = {
				Brightness = 1.4,
				Range = 18,
				Angle = 95,
				Shadows = false,
				Color = Color3.fromRGB(255, 245, 230),
			},
		},
	},
}

VOEPlugins.Plugins.Reflectors = {
	Name = "Reflectors",
	Category = "Lighting",
	Description = "Passive reflector system for safety and compliance",
	Features = {
		"Low beam reflectors (yellowish-white)",
		"High beam reflectors (white)",
		"Brake reflectors (red)",
		"Reverse reflectors (white)",
		"Turn signal reflectors (amber)",
		"Configurable colors for each type",
	},
	Keybinds = {
		"Passive - no keybinds required",
	},
	Tags = {
		"VOE_Reflector_Low - Low beam reflectors",
		"VOE_Reflector_High - High beam reflectors",
		"VOE_Reflector_Brake - Brake reflectors",
		"VOE_Reflector_Reverse - Reverse reflectors",
		"VOE_Reflector_SignalLeft - Left signal reflectors",
		"VOE_Reflector_SignalRight - Right signal reflectors",
	},
	Config = {
		Enabled = true,
		Reflectors = {
			Low = {Color = Color3.fromRGB(255, 255, 200)},
			High = {Color = Color3.fromRGB(255, 255, 255)},
			Brake = {Color = Color3.fromRGB(255, 60, 60)},
			Reverse = {Color = Color3.fromRGB(255, 255, 255)},
			SignalLeft = {Color = Color3.fromRGB(255, 170, 0)},
			SignalRight = {Color = Color3.fromRGB(255, 170, 0)},
		},
	},
}

-- ============================================================================
-- BODY PLUGINS
-- ============================================================================

VOEPlugins.Plugins.Doors = {
	Name = "Doors",
	Category = "Body",
	Description = "Comprehensive door system with opening, closing, and seat entry/exit management",
	Features = {
		"Individual door control (driver, passenger, rear doors)",
		"Automatic seat entry/exit authorization",
		"Driver role assignment for default door",
		"Configurable entry distance limits",
		"Exit direction control per door role",
		"Toggle debounce to prevent rapid repeat toggles",
		"Seat-to-door mapping system",
	},
	Keybinds = {
		"Configurable - typically bound to door controls per seat",
	},
	Tags = {
		"VOE_Door_Driver - Driver door",
		"VOE_Door_FRPass - Front passenger door",
		"VOE_Door_RLPass - Rear left passenger door",
		"VOE_Door_RRPass - Rear right passenger door",
	},
	Config = {
		Enabled = true,
		ToggleDebounce = 0.2,
		SeatScopedActionsBySeatName = {
			DriveSeat = {},
			FRPassSeat = {},
			RLPassSeat = {},
			RRPassSeat = {},
		},
	},
}

VOEPlugins.Plugins.Windows = {
	Name = "Windows",
	Category = "Body",
		Description = "Power window system with individual and group control",
	Features = {
		"Individual window control (FL, FR, RL, RR)",
		"Rear window control (left and right)",
		"All windows toggle",
		"Seat-scoped permissions",
		"Power requirement check",
		"Configurable per-window seat mapping",
	},
	Keybinds = {
		"Configurable - typically bound to window controls per seat",
	},
	Tags = {
		"VOE_Window_FL - Front left window",
		"VOE_Window_FR - Front right window",
		"VOE_Window_RL - Rear left window",
		"VOE_Window_RR - Rear right window",
		"VOE_Window_RearLeft - Rear left window (alternative)",
		"VOE_Window_RearRight - Rear right window (alternative)",
	},
	Config = {
		Enabled = true,
		PowerActions = {
			ToggleWindowFL = true,
			ToggleWindowFR = true,
			ToggleWindowRL = true,
			ToggleWindowRR = true,
			ToggleRearWindowLeft = true,
			ToggleRearWindowRight = true,
			ToggleWindowsAll = true,
		},
		SeatScopedActionsBySeatName = {
			DriveSeat = {
				ToggleWindowFL = true,
				ToggleWindowsAll = true,
			},
			FRPassSeat = {
				ToggleWindowFR = true,
			},
			RLPassSeat = {
				ToggleWindowRL = true,
			},
			RRPassSeat = {
				ToggleWindowRR = true,
			},
		},
	},
}

VOEPlugins.Plugins.Hood = {
	Name = "Hood",
	Category = "Body",
	Description = "Hood opening system with servo-controlled hinge mechanism",
	Features = {
		"Toggle hood open/close",
		"Configurable open angle (default 55 degrees)",
		"Adjustable servo speed and torque",
		"Sound effects on state change",
		"Smooth servo-controlled movement",
	},
	Keybinds = {
		"Configurable - typically bound to hood control",
	},
	Tags = {
		"VOE_Hood - Hood hinge attachment",
	},
	Config = {
		Enabled = true,
		OpenAngle = 55,
		OpenSpeed = 3.0,
		OpenTorque = 20000,
		ClientAudio = {
			{
				Type = "TransitionFalse",
				State = "Hood",
				Sound = "HoodClose",
			},
		},
	},
}

VOEPlugins.Plugins.Trunk = {
	Name = "Trunk",
	Category = "Body",
	Description = "Trunk opening system with servo-controlled hinge mechanism",
	Features = {
		"Toggle trunk open/close",
		"Configurable open angle (default -60 degrees)",
		"Adjustable servo speed and torque",
		"Sound effects support",
		"Smooth servo-controlled movement",
	},
	Keybinds = {
		"G - Toggle trunk",
	},
	Tags = {
		"VOE_Trunk - Trunk hinge attachment",
	},
	Config = {
		Enabled = true,
		OpenAngle = -60,
		OpenSpeed = 3.0,
		OpenTorque = 20000,
		Keybinds = {
			ToggleTrunk = Enum.KeyCode.G,
		},
	},
}

VOEPlugins.Plugins.Sunroof = {
	Name = "Sunroof",
	Category = "Body",
	Description = "Sunroof opening system with servo-controlled hinge mechanism",
	Features = {
		"Toggle sunroof open/close",
		"Configurable open angle (default -35 degrees)",
		"Adjustable servo speed and torque",
		"Smooth servo-controlled movement",
	},
	Keybinds = {
		"M - Toggle sunroof",
	},
	Tags = {
		"VOE_Sunroof - Sunroof hinge attachment",
	},
	Config = {
		Enabled = true,
		OpenAngle = -35,
		OpenSpeed = 2.8,
		OpenTorque = 15000,
		Keybinds = {
			ToggleSunroof = Enum.KeyCode.M,
		},
	},
}

VOEPlugins.Plugins.Spoiler = {
	Name = "Spoiler",
	Category = "Body",
	Description = "Active spoiler system with deployment control",
	Features = {
		"Toggle spoiler deploy/retract",
		"Configurable deployment angle (default 35 degrees)",
		"Adjustable servo speed and torque",
		"Active aerodynamic control",
		"Smooth servo-controlled movement",
	},
	Keybinds = {
		"B - Toggle spoiler",
	},
	Tags = {
		"VOE_Spoiler - Spoiler hinge attachment",
	},
	Config = {
		Enabled = true,
		OpenAngle = 35,
		OpenSpeed = 2.5,
		OpenTorque = 18000,
		Keybinds = {
			ToggleSpoiler = Enum.KeyCode.B,
		},
	},
}

VOEPlugins.Plugins.TonneauCover = {
	Name = "TonneauCover",
	Category = "Body",
	Description = "Tonneau cover system for truck beds with opening/closing functionality",
	Features = {
		"Toggle tonneau cover open/close",
		"Configurable open angle",
		"Adjustable servo speed and torque",
		"Smooth servo-controlled movement",
	},
	Keybinds = {
		"Configurable - typically bound to tonneau cover control",
	},
	Tags = {
		"VOE_TonneauCover - Tonneau cover hinge attachment",
	},
	Config = {
		Enabled = true,
		OpenAngle = -60,
		OpenSpeed = 3.0,
		OpenTorque = 20000,
	},
}

VOEPlugins.Plugins.Popups = {
	Name = "Popups",
	Category = "Body",
	Description = "Popup headlight system with retractable headlight assemblies",
	Features = {
		"Left and right popup headlight control",
		"Configurable open angles (45/-45 degrees)",
		"Adjustable servo speed and torque",
		"Optional auto-on with headlights",
		"Smooth servo-controlled movement",
	},
	Keybinds = {
		"Configurable - typically bound to popup controls",
	},
	Tags = {
		"VOE_PopupLeft - Left popup hinge attachment",
		"VOE_PopupRight - Right popup hinge attachment",
	},
	Config = {
		Enabled = true,
		AutoOnHeadlights = false,
		Openables = {
			PopupLeft = {
				OpenAngle = 45,
				OpenSpeed = 3.0,
				OpenTorque = 20000,
			},
			PopupRight = {
				OpenAngle = -45,
				OpenSpeed = 3.0,
				OpenTorque = 20000,
			},
		},
	},
}

VOEPlugins.Plugins.RunningBoards = {
	Name = "RunningBoards",
	Category = "Body",
	Description = "Fixed running boards for vehicle entry/exit assistance",
	Features = {
		"Left and right running boards",
		"Fixed position (non-deploying)",
		"Configurable deployment distance and angle",
		"Smooth tween animation",
	},
	Keybinds = {
		"Passive - no keybinds required",
	},
	Tags = {
		"VOE_RunningBoardLeft - Left running board",
		"VOE_RunningBoardRight - Right running board",
	},
	Config = {
		Enabled = true,
		Left_DeployDistance = -1.25,
		Left_DeployAngle = 0,
		Left_DeployAxis = "Y",
		Left_TweenTime = 0.22,
		Right_DeployDistance = -1.25,
		Right_DeployAngle = 0,
		Right_DeployAxis = "Y",
		Right_TweenTime = 0.22,
	},
}

VOEPlugins.Plugins.PowerSteps = {
	Name = "PowerSteps",
	Category = "Body",
	Description = "Power-deployable running boards that extend when doors are opened",
	Features = {
		"Left and right power steps",
		"Automatic deployment when doors open",
		"Configurable deployment distance and angle",
		"Smooth tween animation",
		"Retracts when doors close",
	},
	Keybinds = {
		"Automatic - activates when doors are opened",
	},
	Tags = {
		"VOE_PowerStepLeft - Left power step",
		"VOE_PowerStepRight - Right power step",
	},
	Config = {
		Enabled = true,
		Left_DeployDistance = -1.5,
		Left_DeployAngle = 0,
		Left_DeployAxis = "Y",
		Left_TweenTime = 0.22,
		Right_DeployDistance = -1.5,
		Right_DeployAngle = 0,
		Right_DeployAxis = "Y",
		Right_TweenTime = 0.22,
	},
}

-- ============================================================================
-- SYSTEMS PLUGINS
-- ============================================================================

VOEPlugins.Plugins.Engine = {
	Name = "Engine",
	Category = "Systems",
	Description = "Engine simulation system with RPM, temperature, and wear tracking",
	Features = {
		"Engine RPM simulation (idle to max)",
		"Engine temperature simulation with warmup/cooldown",
		"Engine wear tracking (0-100 scale)",
		"Configurable idle and max RPM",
		"Temperature monitoring and warnings",
		"Shared state for other systems to read",
	},
	Keybinds = {
		"Automatic - runs continuously when vehicle is active",
	},
	Tags = {
		"VOE_Engine - Engine parts",
	},
	Config = {
		Enabled = true,
		EngineState = {
			IdleRPM = 800,
			MaxRPM = 7000,
			SpeedToRPMReferenceMph = 140,
		},
		EngineTemp = {
			Enabled = true,
			Ambient = 80,
			Normal = 195,
			Max = 260,
			WarmupRate = 22,
			CooldownRate = 14,
		},
	},
}

VOEPlugins.Plugins.Ignition = {
	Name = "Ignition",
	Category = "Systems",
	Description = "Vehicle ignition system for starting and stopping the engine",
	Features = {
		"Engine start/stop control",
		"Ignition state management",
		"Integration with other vehicle systems",
	},
	Keybinds = {
		"Configurable - typically bound to ignition controls",
	},
	Tags = {
		"VOE_Ignition - Ignition components",
	},
	Config = {
		Enabled = true,
	},
}

VOEPlugins.Plugins.Fuel = {
	Name = "Fuel",
	Category = "Systems",
	Description = "Fuel system with tank capacity, consumption, and refueling mechanics",
	Features = {
		"Configurable tank capacity (default 18 gallons)",
		"Starting fuel level configuration",
		"Incremental refueling (1 gallon per use)",
		"Gas door requirement check",
		"Fuel cap requirement check",
		"Refuel while engine running option",
		"Fuel consumption tracking",
	},
	Keybinds = {
		"Configurable - typically bound to fuel pump interaction",
	},
	Tags = {
		"VOE_Fuel - Fuel system components",
		"VOE_GasDoor - Gas door",
		"VOE_FuelCap - Fuel cap",
	},
	Config = {
		Enabled = true,
		MaxGallons = 18,
		StartingGallons = nil,
		RefuelGallonsPerUse = 1.0,
		RequireGasDoorOpen = true,
		RequireFuelCapRemoved = true,
		AllowRefuelWhileEngineOn = false,
	},
}

VOEPlugins.Plugins.Seatbelt = {
	Name = "Seatbelt",
	Category = "Systems",
	Description = "Seatbelt system with per-seat toggle functionality",
	Features = {
		"Individual seatbelt control per seat",
		"Driver and front passenger seat support",
		"Seat-scoped permissions",
		"Seatbelt state tracking",
	},
	Keybinds = {
		"U - Toggle seatbelt",
	},
	Tags = {
		"VOE_Seatbelt - Seatbelt components",
	},
	Config = {
		Enabled = true,
		Seats = {
			DriverSeatName = "DriveSeat",
			FrontPassengerSeatName = "FRPassSeat",
		},
		Actions = {
			ToggleSeatbelt = "ToggleSeatbelt",
		},
		SeatScopedActionsBySeatName = {
			DriveSeat = {
				ToggleSeatbelt = true,
			},
			FRPassSeat = {
				ToggleSeatbelt = true,
			},
		},
		Keybinds = {
			ToggleSeatbelt = Enum.KeyCode.U,
		},
	},
}

VOEPlugins.Plugins.Wipers = {
	Name = "Wipers",
	Category = "Systems",
	Description = "Windshield wiper system with front, rear, and headlight wiper support",
	Features = {
		"Front windshield wipers",
		"Rear window wiper",
		"Headlight wipers",
		"Rain-sensing automatic mode",
		"Power requirement check",
		"Configurable wiper speeds",
	},
	Keybinds = {
		"Configurable - typically bound to wiper controls",
	},
	Tags = {
		"VOE_WiperFront - Front wiper components",
		"VOE_WiperRear - Rear wiper components",
		"VOE_WiperHeadlight - Headlight wiper components",
	},
	Config = {
		Enabled = true,
		PowerActions = {
			ToggleWipers = true,
			ToggleRearWiper = true,
			ToggleHeadlightWipers = true,
		},
		RainSensing = {
			Enabled = false,
			StateName = nil,
			Attribute = nil,
		},
	},
}

VOEPlugins.Plugins.Extras = {
	Name = "Extras",
	Category = "Systems",
	Description = "Generic hinge system for custom vehicle features and accessories",
	Features = {
		"Support for up to 12 custom hinges (A-L)",
		"Configurable attachment names",
		"Custom keybinds per hinge",
		"Flexible for various vehicle accessories",
		"Example: custom storage compartments, toolboxes, etc.",
	},
	Keybinds = {
		"Configurable - set per hinge in configuration",
	},
	Tags = {
		"VOE_HingeA through VOE_HingeL - Custom hinge attachments",
	},
	Config = {
		Enabled = true,
		Hinges = {
			-- A = { attachment = "HingeA_Attachment", key = "Z" },
			-- Add more hinges as needed
		},
	},
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

function VOEPlugins.GetPlugin(pluginName)
	return VOEPlugins.Plugins[pluginName]
end

function VOEPlugins.GetPluginsByCategory(categoryName)
	local plugins = {}
	for _, pluginName in ipairs(VOEPlugins.Categories[categoryName] or {}) do
		table.insert(plugins, VOEPlugins.Plugins[pluginName])
	end
	return plugins
end

function VOEPlugins.GetAllPlugins()
	local allPlugins = {}
	for name, plugin in pairs(VOEPlugins.Plugins) do
		table.insert(allPlugins, plugin)
	end
	return allPlugins
end

function VOEPlugins.GetPluginCount()
	local count = 0
	for _ in pairs(VOEPlugins.Plugins) do
		count = count + 1
	end
	return count
end

function VOEPlugins.GetCategories()
	local categories = {}
	for name, _ in pairs(VOEPlugins.Categories) do
		table.insert(categories, name)
	end
	return categories
end

return VOEPlugins