--!strict
--[[
	BoatConfig.luau
	Small boats for crossing water and reaching the Pelagic Frontier rigs.

	Boats are player-owned vehicles with limited durability. They are not
	required for progression: every island and rig can also be reached by
	glide, swimming or a squad deployment.
]]

local Registry = require(script.Parent.Registry)
local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)

local Boat = {}

export type BoatPartDef = {
	id: string,
	displayName: string,
	slot: string, -- Hull | Deck | Engine | Mast | Utility
	tier: number,
	maxSpeedBonus: number,
	accelerationBonus: number,
	turnBonus: number,
	durabilityBonus: number,
	storageBonus: number,
	-- Some parts make the boat louder, which attracts aquatic beasts.
	noise: number,
	craftCost: { [string]: number },
	description: string,
}

local function part(
	id: string,
	displayName: string,
	slot: string,
	tier: number,
	speed: number,
	accel: number,
	turn: number,
	durability: number,
	storage: number,
	noise: number,
	description: string
): BoatPartDef
	return {
		id = id,
		displayName = displayName,
		slot = slot,
		tier = tier,
		maxSpeedBonus = speed,
		accelerationBonus = accel,
		turnBonus = turn,
		durabilityBonus = durability,
		storageBonus = storage,
		noise = noise,
		craftCost = { ["timber_softwood"] = 4 * tier, ["stone_rubble"] = 2 * tier },
		description = description,
	}
end

local entries: { [string]: BoatPartDef } = {
	["hull_rawhide"] = part("hull_rawhide", "Rawhide Hull", "Hull", 1, 0, 0, 0, 80, 2, 0.2, "Basic lashed-timber hull."),
	["hull_plated"] = part("hull_plated", "Plated Hull", "Hull", 2, 0, 0, -0.05, 220, 4, 0.3, "Ore-plated hull for rougher water."),
	["hull_abyssal"] = part("hull_abyssal", "Abyssal Hull", "Hull", 3, 4, 2, -0.08, 420, 6, 0.45, "Deep-water hull that resists leviathan strikes."),
	["deck_open"] = part("deck_open", "Open Deck", "Deck", 1, 0, 0, 0.05, 20, 6, 0.1, "Nothing but planks and rope."),
	["deck_covered"] = part("deck_covered", "Covered Deck", "Deck", 2, 0, 0, 0, 90, 14, 0.15, "Weather cover for long crossings."),
	["deck_armoured"] = part("deck_armoured", "Armoured Deck", "Deck", 3, -2, 0, -0.05, 260, 10, 0.35, "Slow but survives boarding."),
	["engine_sail"] = part("engine_sail", "Sail Rig", "Engine", 1, 26, 8, 0.2, 0, 0, 0.05, "Quiet and free, but depends on the wind."),
	["engine_outboard"] = part("engine_outboard", "Outboard Engine", "Engine", 2, 48, 18, 0.1, 0, 0, 0.7, "Fast, loud and hungry for fuel."),
	["engine_waterjet"] = part("engine_waterjet", "Waterjet Drive", "Engine", 3, 68, 26, 0.25, 0, 0, 0.5, "Agile enough to dodge a breaching leviathan."),
	["mast_none"] = part("mast_none", "No Mast", "Mast", 1, 0, 0, 0, 0, 0, 0, "Nothing mounted."),
	["mast_signal"] = part("mast_signal", "Signal Mast", "Mast", 2, 0, 0, 0, 10, 0, 0.1, "Marks the boat for squad members."),
	["mast_harpoon"] = part("mast_harpoon", "Harpoon Mast", "Mast", 3, 0, 0, 0, 30, 0, 0.4, "Harpoons large fish and small aquatic beasts."),
	["utility_net"] = part("utility_net", "Salvage Net", "Utility", 1, -2, 0, 0, 0, 8, 0.1, "Collects floating salvage automatically."),
	["utility_sonar"] = part("utility_sonar", "Sonar Array", "Utility", 2, 0, 0, 0, 0, 2, 0.2, "Reveals submerged resources nearby."),
	["utility_ballast"] = part("utility_ballast", "Ballast Tanks", "Utility", 3, -6, -4, -0.1, 180, 0, 0.15, "Keeps the boat stable in a storm."),
}

local Registry_ = Registry.new("BoatPart", entries, { "id", "displayName", "slot" })

Boat.Slots = { "Hull", "Deck", "Engine", "Mast", "Utility" }

function Boat.Get(id: string): BoatPartDef?
	return Registry_:Get(id)
end

function Boat.List(): { BoatPartDef }
	return Registry_:List()
end

function Boat.BySlot(slot: string): { BoatPartDef }
	return Registry_:Filter(function(def)
		return def.slot == slot
	end)
end

-- Computes the effective stats of a boat from its installed parts.
export type BoatStats = {
	maxSpeed: number,
	acceleration: number,
	turnSpeed: number,
	durability: number,
	storage: number,
	noise: number,
}

function Boat.ComputeStats(partIds: { string }): BoatStats
	local stats: BoatStats = {
		maxSpeed = Limits.Boat.MaxSpeedStudsPerSecond,
		acceleration = Limits.Boat.Acceleration,
		turnSpeed = Limits.Boat.TurnSpeed,
		durability = Limits.Boat.Durability,
		storage = 0,
		noise = 0.1,
	}
	for _, partId in partIds do
		local def = Registry_:Get(partId)
		if def then
			stats.maxSpeed += def.maxSpeedBonus
			stats.acceleration += def.accelerationBonus
			stats.turnSpeed += def.turnBonus
			stats.durability += def.durabilityBonus
			stats.storage += def.storageBonus
			stats.noise += def.noise
		end
	end
	stats.maxSpeed = math.clamp(stats.maxSpeed, 10, Limits.Boat.MaxSpeedStudsPerSecond * 1.5)
	stats.acceleration = math.max(4, stats.acceleration)
	stats.turnSpeed = math.clamp(stats.turnSpeed, 0.4, 4)
	stats.durability = math.max(50, stats.durability)
	stats.noise = math.clamp(stats.noise, 0, 1)
	return stats
end

Boat.Rules = {
	maxBoatsPerPlayer = Limits.Boat.MaxBoatsPerPlayer,
	dockRangeStuds = Limits.Boat.DockRangeStuds,
	recoveryAfterSeconds = Limits.Boat.RecoveryAfterSeconds,
	-- Boats are recovered automatically so a player can never lose one forever.
	autoRecoverWhenAbandoned = true,
	-- A destroyed boat loses durability, not the parts.
	destroyedDurabilityLoss = 0.25,
	repairCostPerDurability = 0.02,
}

function Boat.ValidateAll(): { string }
	local problems = Registry.Validate(Registry_)
	for _, slot in Boat.Slots do
		if #Boat.BySlot(slot) == 0 then
			table.insert(problems, string.format("[Boat] no parts are defined for the %s slot", slot))
		end
	end
	local stats = Boat.ComputeStats({ "hull_abyssal", "deck_armoured", "engine_waterjet", "mast_harpoon", "utility_ballast" })
	if stats.maxSpeed <= 0 or stats.durability <= 0 then
		table.insert(problems, "[Boat] a fully equipped boat has invalid stats")
	end
	local bare = Boat.ComputeStats({})
	if bare.maxSpeed <= 0 then
		table.insert(problems, "[Boat] a bare hull must still move")
	end
	for _, def in Boat.List() do
		if def.tier < 1 or def.tier > Enums.MaxTier then
			table.insert(problems, string.format("[Boat] %s has an invalid tier", def.id))
		end
		if def.noise < 0 or def.noise > 1 then
			table.insert(problems, string.format("[Boat] %s has an out-of-range noise value", def.id))
		end
	end
	return problems
end

Boat.Registry = Registry_
return Boat
