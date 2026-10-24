--!strict
--[[
	GadgetConfig.luau
	The twelve tactical gadgets and the loadout rules that contain them.

	Gadgets never deal damage on their own authority: a gadget that damages
	targets asks the server combat system to resolve every hit, respecting
	range, ownership, cooldown and the target's defense state.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)
local Registry = require(script.Parent.Registry)

export type GadgetDef = {
	id: string,
	displayName: string,
	kind: string,
	reusable: boolean,
	cooldown: number,
	maxCharges: number,
	deployRange: number,
	duration: number,
	maxDeployedPerPlayer: number,
	effects: { [string]: any },
	audio: { [string]: string },
	vfx: { [string]: string },
	unlock: { kind: string, value: any },
	description: string,
	performanceCost: number,
}

local function gadget(def: GadgetDef): GadgetDef
	return def
end

local entries: { [string]: GadgetDef } = {
	["scout_drone"] = gadget({
		id = "scout_drone",
		displayName = "Scout Drone",
		kind = Enums.GadgetKind.Deployable,
		reusable = true,
		cooldown = 25,
		maxCharges = 1,
		deployRange = 40,
		duration = 45,
		maxDeployedPerPlayer = 1,
		effects = {
			scansTerrain = true,
			scanRadius = 220,
			revealsBeasts = true,
			revealsResources = true,
			markTargets = false,
		},
		audio = { deploy = "gadget_drone_deploy", active = "gadget_drone_loop", expire = "gadget_drone_expire" },
		vfx = { deploy = "fx_drone_deploy", model = "fx_drone_body" },
		unlock = { kind = "Level", value = 2 },
		description = "Flies a configurable pattern and reveals beasts and resource nodes on the map.",
		performanceCost = 2,
	}),
	["sentry_pod"] = gadget({
		id = "sentry_pod",
		displayName = "Sentry Pod",
		kind = Enums.GadgetKind.Deployable,
		reusable = true,
		cooldown = 45,
		maxCharges = 1,
		deployRange = 30,
		duration = 40,
		maxDeployedPerPlayer = 1,
		effects = {
			autoFire = true,
			damagePerShot = 55,
			fireInterval = 0.55,
			range = 180,
			requiresLineOfSight = true,
			health = 600,
		},
		audio = { deploy = "gadget_sentry_deploy", fire = "gadget_sentry_fire", expire = "gadget_sentry_expire" },
		vfx = { deploy = "fx_sentry_deploy", model = "fx_sentry_body" },
		unlock = { kind = "Level", value = 5 },
		description = "Automated defense pod. Damage is resolved by the server combat pipeline.",
		performanceCost = 3,
	}),
	["medstation"] = gadget({
		id = "medstation",
		displayName = "Medstation",
		kind = Enums.GadgetKind.Deployable,
		reusable = true,
		cooldown = 40,
		maxCharges = 1,
		deployRange = 20,
		duration = 35,
		maxDeployedPerPlayer = 1,
		effects = {
			healsAllies = true,
			healPerSecond = 9,
			radius = 34,
			reviveAssist = true,
		},
		audio = { deploy = "gadget_med_deploy", active = "gadget_med_loop", expire = "gadget_med_expire" },
		vfx = { deploy = "fx_med_deploy", field = "fx_med_field" },
		unlock = { kind = "Level", value = 4 },
		description = "Limited area healing for the squad. Never outpaces incoming boss damage.",
		performanceCost = 1,
	}),
	["decoy_beacon"] = gadget({
		id = "decoy_beacon",
		displayName = "Decoy Beacon",
		kind = Enums.GadgetKind.Deployable,
		reusable = true,
		cooldown = 30,
		maxCharges = 2,
		deployRange = 60,
		duration = 20,
		maxDeployedPerPlayer = 2,
		effects = {
			attractsBeasts = true,
			attractRadius = 160,
			emitsNoise = true,
			health = 250,
		},
		audio = { deploy = "gadget_decoy_deploy", active = "gadget_decoy_loop", expire = "gadget_decoy_expire" },
		vfx = { deploy = "fx_decoy_deploy", model = "fx_decoy_body" },
		unlock = { kind = "Level", value = 3 },
		description = "Draws eligible creatures toward its position so the squad can reposition.",
		performanceCost = 1,
	}),
	["emp_charge"] = gadget({
		id = "emp_charge",
		displayName = "EMP Charge",
		kind = Enums.GadgetKind.Throwable,
		reusable = false,
		cooldown = 0,
		maxCharges = Limits.Gadget.MaxStackPerConsumable,
		deployRange = 50,
		duration = 6,
		maxDeployedPerPlayer = 2,
		effects = {
			disablesMachines = true,
			disablesElectronics = true,
			shieldsDownDuration = 6,
			radius = 26,
			damageToMachines = 320,
			damageType = Enums.DamageType.Energy,
		},
		audio = { deploy = "gadget_emp_throw", impact = "gadget_emp_impact" },
		vfx = { deploy = "fx_emp_throw", impact = "fx_emp_burst" },
		unlock = { kind = "Level", value = 8 },
		description = "Disrupts machines and electronics and drops eligible shields for a short window.",
		performanceCost = 2,
	}),
	["cover_projector"] = gadget({
		id = "cover_projector",
		displayName = "Cover Projector",
		kind = Enums.GadgetKind.Deployable,
		reusable = true,
		cooldown = 35,
		maxCharges = 1,
		deployRange = 25,
		duration = 30,
		maxDeployedPerPlayer = 2,
		effects = {
			createsCover = true,
			coverWidth = 16,
			coverHeight = 10,
			blocksProjectiles = true,
			health = 900,
		},
		audio = { deploy = "gadget_cover_deploy", active = "gadget_cover_loop", expire = "gadget_cover_expire" },
		vfx = { deploy = "fx_cover_deploy", wall = "fx_cover_wall" },
		unlock = { kind = "Level", value = 7 },
		description = "Temporary hard cover. Real collision, real health pool, real cleanup.",
		performanceCost = 2,
	}),
	["motion_sensor"] = gadget({
		id = "motion_sensor",
		displayName = "Motion Sensor",
		kind = Enums.GadgetKind.Deployable,
		reusable = true,
		cooldown = 22,
		maxCharges = 2,
		deployRange = 35,
		duration = 60,
		maxDeployedPerPlayer = 2,
		effects = {
			detectsMovement = true,
			detectRadius = 180,
			pingsOnDetect = true,
			detectsPlayersInClanWar = true,
		},
		audio = { deploy = "gadget_sensor_deploy", ping = "gadget_sensor_ping", expire = "gadget_sensor_expire" },
		vfx = { deploy = "fx_sensor_deploy", ping = "fx_sensor_ping" },
		unlock = { kind = "Level", value = 6 },
		description = "Detects movement inside its area and pings the squad map.",
		performanceCost = 1,
	}),
	["grapple_launcher"] = gadget({
		id = "grapple_launcher",
		displayName = "Grapple Launcher",
		kind = Enums.GadgetKind.Traversal,
		reusable = true,
		cooldown = 9,
		maxCharges = 3,
		deployRange = 120,
		duration = 0,
		maxDeployedPerPlayer = 0,
		effects = {
			pullsPlayer = true,
			maxDistance = 120,
			requiresValidAnchor = true,
			anchorTags = { "GrappleAnchor", "Terrain", "Structure" },
		},
		audio = { deploy = "gadget_grapple_fire", impact = "gadget_grapple_hit" },
		vfx = { deploy = "fx_grapple_fire", rope = "fx_grapple_rope" },
		unlock = { kind = "Level", value = 9 },
		description = "Traversal gadget. It does not replace the dedicated Grapple Launch movement skill.",
		performanceCost = 1,
	}),
	["smoke_capsule"] = gadget({
		id = "smoke_capsule",
		displayName = "Smoke Capsule",
		kind = Enums.GadgetKind.Throwable,
		reusable = false,
		cooldown = 0,
		maxCharges = Limits.Gadget.MaxStackPerConsumable,
		deployRange = 45,
		duration = 14,
		maxDeployedPerPlayer = 2,
		effects = {
			obscuresVision = true,
			radius = 34,
			breaksBeastLineOfSight = true,
			blocksPlayerVisionEqually = true,
		},
		audio = { deploy = "gadget_smoke_throw", active = "gadget_smoke_loop", expire = "gadget_smoke_expire" },
		vfx = { deploy = "fx_smoke_throw", cloud = "fx_smoke_cloud" },
		unlock = { kind = "Level", value = 5 },
		description = "Obscures vision for beasts and players equally. Denser on PC, lighter on mobile.",
		performanceCost = 2,
	}),
	["ammo_cache"] = gadget({
		id = "ammo_cache",
		displayName = "Ammo Cache",
		kind = Enums.GadgetKind.Deployable,
		reusable = true,
		cooldown = 50,
		maxCharges = 1,
		deployRange = 20,
		duration = 45,
		maxDeployedPerPlayer = 1,
		effects = {
			resuppliesAmmo = true,
			radius = 30,
			resupplyPerSecond = 12,
			maxResupplyPerPlayer = 240,
		},
		audio = { deploy = "gadget_ammo_deploy", active = "gadget_ammo_loop", expire = "gadget_ammo_expire" },
		vfx = { deploy = "fx_ammo_deploy", field = "fx_ammo_field" },
		unlock = { kind = "Level", value = 10 },
		description = "Limited resupply for the whole squad, capped per player.",
		performanceCost = 1,
	}),
	["shock_grenade"] = gadget({
		id = "shock_grenade",
		displayName = "Shock Grenade",
		kind = Enums.GadgetKind.Throwable,
		reusable = false,
		cooldown = 0,
		maxCharges = Limits.Gadget.MaxStackPerConsumable,
		deployRange = 55,
		duration = 3,
		maxDeployedPerPlayer = 3,
		effects = {
			damage = 240,
			damageType = Enums.DamageType.Energy,
			radius = 22,
			statusEffect = Enums.StatusEffect.Shock,
			statusDuration = 3,
			interruptPower = 40,
		},
		audio = { deploy = "gadget_shock_throw", impact = "gadget_shock_impact" },
		vfx = { deploy = "fx_shock_throw", impact = "fx_shock_burst" },
		unlock = { kind = "Level", value = 11 },
		description = "Disrupts and interrupts eligible targets inside its radius.",
		performanceCost = 2,
	}),
	["core_extractor"] = gadget({
		id = "core_extractor",
		displayName = "Core Extractor",
		kind = Enums.GadgetKind.Deployable,
		reusable = true,
		cooldown = 60,
		maxCharges = 1,
		deployRange = 25,
		duration = 30,
		maxDeployedPerPlayer = 1,
		effects = {
			improvesHarvest = true,
			radius = 40,
			yieldBonus = 0.35,
			coreChanceBonus = 0.08,
			requiresEligibleNode = true,
		},
		audio = { deploy = "gadget_extractor_deploy", active = "gadget_extractor_loop", expire = "gadget_extractor_expire" },
		vfx = { deploy = "fx_extractor_deploy", field = "fx_extractor_field" },
		unlock = { kind = "Research", value = 4 },
		description = "Improves material and Beast Core yield from eligible nodes when its conditions are met.",
		performanceCost = 1,
	}),
}

local Gadget = Registry.new("Gadget", entries, { "id", "displayName", "kind" })

function Gadget.Reusable(): { GadgetDef }
	return Gadget:Filter(function(def)
		return def.reusable
	end)
end

function Gadget.Consumables(): { GadgetDef }
	return Gadget:Filter(function(def)
		return not def.reusable
	end)
end

function Gadget.IsConsumable(gadgetId: string): boolean
	local def = Gadget:Get(gadgetId)
	return def ~= nil and not def.reusable
end

function Gadget.ValidateAll(): { string }
	local problems = Registry.Validate(Gadget)
	if Gadget:Count() ~= 12 then
		table.insert(problems, string.format("[Gadget] expected 12 gadgets, found %d", Gadget:Count()))
	end
	for _, def in Gadget:List() do
		if not Enums.GadgetKind[def.kind] then
			table.insert(problems, string.format("[Gadget] %s has unknown kind %q", def.id, tostring(def.kind)))
		end
		if def.reusable and def.cooldown < 1 then
			table.insert(problems, string.format("[Gadget] reusable gadget %s has no cooldown", def.id))
		end
		if def.maxCharges > Limits.Gadget.MaxStackPerConsumable and not def.reusable then
			table.insert(problems, string.format("[Gadget] consumable %s exceeds the stack cap", def.id))
		end
	end
	return problems
end

Gadget.Registry = Gadget
return Gadget
