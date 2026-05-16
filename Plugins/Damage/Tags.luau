
--[[
	Plugin: Damage
	Purpose: Tag definitions for Damage plugin.
	Last updated: 2026-03-21
]]

local Tags = {}

Tags.Name = "Damage"

Tags.Role = "Damage"

Tags.Action = nil

Tags.Required = {
	-- Universal tag: any part with this tag is tracked by the damage system.
	DamageablePart = "VOE_Damageable",

	-- Zone-specific tags: parts tagged with these are assigned to the matching zone.
	Damage_FrontBumper_Part = "VOE_Damage_FrontBumper",
	Damage_RearBumper_Part = "VOE_Damage_RearBumper",
	Damage_Hood_Part = "VOE_Damage_Hood",
	Damage_Trunk_Part = "VOE_Damage_Trunk",
	Damage_Door_Part = "VOE_Damage_Door",
	Damage_Fender_Part = "VOE_Damage_Fender",
	Damage_QuarterPanel_Part = "VOE_Damage_QuarterPanel",
	Damage_Windshield_Part = "VOE_Damage_Windshield",
	Damage_Headlight_Part = "VOE_Damage_Headlight",
	Damage_Taillight_Part = "VOE_Damage_Taillight",
	Damage_Mirror_Part = "VOE_Damage_Mirror",
	Damage_Grill_Part = "VOE_Damage_Grill",
	Damage_Exhaust_Part = "VOE_Damage_Exhaust",
}

Tags.Optional = {
	-- Attribute on a BasePart: number of HitPoints (overrides zone default).
	HitPointsAttribute = "VOE_HitPoints",

	-- Attribute on a BasePart: maximum HitPoints (read back for persistence).
	MaxHitPointsAttribute = "VOE_MaxHitPoints",

	-- Attribute on a BasePart: current damage percentage (0 = pristine, 1 = destroyed).
	DamagePercentAttribute = "VOE_DamagePercent",

	-- Attribute on a BasePart: which damage zone this part belongs to.
	ZoneAttribute = "VOE_DamageZone",
}

Tags.Instructions = {
	"Tag any BasePart that should take damage with VOE_Damageable. This is the universal tag that makes a part trackable by the damage system.",
	"For zone-specific HitPoints, tag parts with the matching VOE_Damage_<ZoneName> tag (e.g. VOE_Damage_FrontBumper, VOE_Damage_Hood, VOE_Damage_Door). The zone's HitPoints from Config will be used instead of the default.",
	"Optional: set the VOE_HitPoints attribute on a part to override the zone or default HitPoints. This is the preferred way to give a specific part a custom HP value.",
	"Optional: set the VOE_DamageZone attribute on a part to assign it to a zone without using zone tags. The value must match a zone name in Config.DamageZones (e.g. \"FrontBumper\", \"Door\").",
	"If no parts are tagged, the plugin will auto-discover all BaseParts under the vehicle Body folder (controlled by Config.AutoDiscoverParts).",
	"Parts whose HitPoints reach zero will have their welds removed and will detach from the vehicle, tumbling away as debris. Set CanDetach = false in the zone config to prevent specific zones from detaching.",
	"Damage state is persisted via part attributes (VOE_HitPoints, VOE_MaxHitPoints, VOE_DamagePercent, VOE_DamageZone). These attributes are read on startup to restore previous damage.",
	"Use the RepairAll keybind (default F5) to restore all parts to full HP and original appearance.",
}

return Tags