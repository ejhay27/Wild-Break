--!strict
--[[
	HazardConfig.luau
	Environmental hazards and protective mitigation.

	WILDBREAK uses tactical survival, not hardcore punishment: hazards are
	readable, avoidable and mitigable with equipment, routes and consumables.
	Food and water provide useful buffs; players are never forced to eat and
	drink constantly just to stay alive during ordinary exploration.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)
local Registry = require(script.Parent.Registry)

export type HazardDef = {
	id: string,
	displayName: string,
	kind: string,
	regions: { string },
	damagePerSecond: number,
	tickSeconds: number,
	statusEffect: string?,
	protectionItems: { string },
	consumableMitigation: { [string]: number },
	warningText: string,
	visualWarning: string,
	audioWarning: string?,
	description: string,
}

local entries: { [string]: HazardDef } = {
	["Heat"] = {
		id = "Heat",
		displayName = "Extreme Heat",
		kind = Enums.HazardType.Heat,
		regions = { Enums.RegionId.Cinderfall },
		damagePerSecond = Limits.Hazard.HeatDamagePerSecond,
		tickSeconds = Limits.Hazard.TickSeconds,
		statusEffect = Enums.StatusEffect.Heatstroke,
		protectionItems = { "eq_heat_vest", "con_heat_salve" },
		consumableMitigation = { con_heat_salve = 0.6, con_water = 0.2 },
		warningText = "Extreme heat. Equip a Thermal Vest or apply Heat Salve.",
		visualWarning = "heat_shimmer",
		audioWarning = "hazard_heat_warning",
		description = "Environmental heat in Cinderfall. Mitigated by thermal equipment and salves.",
	},
	["Cold"] = {
		id = "Cold",
		displayName = "Extreme Cold",
		kind = Enums.HazardType.Cold,
		regions = { Enums.RegionId.Frostveil },
		damagePerSecond = Limits.Hazard.ColdDamagePerSecond,
		tickSeconds = Limits.Hazard.TickSeconds,
		statusEffect = Enums.StatusEffect.Frostbite,
		protectionItems = { "eq_cold_cloak", "con_cold_salve" },
		consumableMitigation = { con_cold_salve = 0.6, con_ration = 0.15 },
		warningText = "Extreme cold. Equip a Frost Cloak or apply Cold Salve.",
		visualWarning = "frost_edges",
		audioWarning = "hazard_cold_warning",
		description = "Environmental cold in Frostveil. Mitigated by cold equipment and salves.",
	},
	["Contamination"] = {
		id = "Contamination",
		displayName = "Contamination",
		kind = Enums.HazardType.Contamination,
		regions = { Enums.RegionId.UmbraExpanse },
		damagePerSecond = Limits.Hazard.ContaminationDamagePerSecond,
		tickSeconds = Limits.Hazard.TickSeconds,
		statusEffect = Enums.StatusEffect.Contamination,
		protectionItems = { "eq_hazard_suit", "con_antidote" },
		consumableMitigation = { con_antidote = 0.7 },
		warningText = "Contaminated zone. Equip a Hazard Suit or use an Antidote.",
		visualWarning = "contamination_haze",
		audioWarning = "hazard_contamination_warning",
		description = "Contaminated areas inside Umbra Expanse.",
	},
	["VoidAnomaly"] = {
		id = "VoidAnomaly",
		displayName = "Void Anomaly",
		kind = Enums.HazardType.VoidAnomaly,
		regions = { Enums.RegionId.NullHorizon },
		damagePerSecond = Limits.Hazard.VoidAnomalyDamagePerSecond,
		tickSeconds = Limits.Hazard.TickSeconds,
		statusEffect = Enums.StatusEffect.VoidInstability,
		protectionItems = { "eq_void_anchor" },
		consumableMitigation = {},
		warningText = "Unstable space. Equip a Void Anchor before entering rift fields.",
		visualWarning = "void_distortion",
		audioWarning = "hazard_void_warning",
		description = "Reality anomalies that damage and destabilise unprotected hunters.",
	},
	["UnderwaterPressure"] = {
		id = "UnderwaterPressure",
		displayName = "Underwater Pressure",
		kind = Enums.HazardType.UnderwaterPressure,
		regions = { Enums.RegionId.PelagicFrontier },
		damagePerSecond = 0,
		tickSeconds = Limits.Hazard.TickSeconds,
		protectionItems = { "eq_dive_gear", "con_oxygen_canister" },
		consumableMitigation = { con_oxygen_canister = 1.0 },
		warningText = "Oxygen is draining. Surface or use an Oxygen Canister.",
		visualWarning = "oxygen_warning",
		audioWarning = "hazard_oxygen_warning",
		description = "Oxygen drain while diving. Extended by dive gear and canisters.",
	},
	["Volcanic"] = {
		id = "Volcanic",
		displayName = "Volcanic Activity",
		kind = Enums.HazardType.Volcanic,
		regions = { Enums.RegionId.Cinderfall },
		damagePerSecond = 18,
		tickSeconds = Limits.Hazard.TickSeconds,
		statusEffect = Enums.StatusEffect.Burn,
		protectionItems = { "eq_heat_vest" },
		consumableMitigation = { con_heat_salve = 0.3 },
		warningText = "Lava ahead. Watch for eruption telegraphs.",
		visualWarning = "lava_glow",
		audioWarning = "hazard_volcanic_warning",
		description = "Lava channels, fountains and eruption zones.",
	},
	["Storm"] = {
		id = "Storm",
		displayName = "Storm",
		kind = Enums.HazardType.Storm,
		regions = { Enums.RegionId.Frostveil, Enums.RegionId.PelagicFrontier },
		damagePerSecond = 2,
		tickSeconds = Limits.Hazard.TickSeconds,
		statusEffect = Enums.StatusEffect.Chill,
		protectionItems = { "eq_cold_cloak" },
		consumableMitigation = { con_cold_salve = 0.4 },
		warningText = "Storm conditions reduce visibility.",
		visualWarning = "storm_overlay",
		audioWarning = "hazard_storm_warning",
		description = "Blizzards and sea storms that reduce visibility and chill hunters.",
	},
	["Fall"] = {
		id = "Fall",
		displayName = "Fall Damage",
		kind = Enums.HazardType.Fall,
		regions = Enums.RegionOrder,
		damagePerSecond = 0,
		tickSeconds = 0,
		protectionItems = {},
		consumableMitigation = {},
		warningText = "",
		visualWarning = "fall_warning",
		audioWarning = "hazard_fall_warning",
		description = "Fall damage is applied by the server from validated velocity, never from a client report. Deployment landings have a short grace window.",
	},
}

local Hazard = Registry.new("Hazard", entries, { "id", "displayName", "kind" })

function Hazard.ByRegion(regionId: string): { HazardDef }
	return Hazard:Filter(function(def)
		return table.find(def.regions, regionId) ~= nil
	end)
end

-- Returns a 0..1 mitigation factor from equipped items and active buffs.
function Hazard.Mitigation(hazardId: string, equippedItemIds: { string }, activeBuffs: { [string]: number }?): number
	local def = Hazard:Get(hazardId)
	if not def then
		return 0
	end
	local mitigation = 0
	for _, itemId in equippedItemIds do
		if table.find(def.protectionItems, itemId) then
			mitigation += 0.5
		end
	end
	if activeBuffs then
		for itemId, value in def.consumableMitigation do
			if activeBuffs[itemId] then
				mitigation += value
			end
		end
	end
	return math.clamp(mitigation, 0, Limits.Hazard.ProtectionMitigationMax)
end

function Hazard.DamagePerSecond(hazardId: string, mitigation: number?): number
	local def = Hazard:Get(hazardId)
	if not def then
		return 0
	end
	return def.damagePerSecond * (1 - math.clamp(mitigation or 0, 0, Limits.Hazard.ProtectionMitigationMax))
end

function Hazard.ValidateAll(): { string }
	local problems = Registry.Validate(Hazard)
	for _, def in Hazard:List() do
		if not Enums.HazardType[def.kind] then
			table.insert(problems, string.format("[Hazard] %s has unknown kind %q", def.id, tostring(def.kind)))
		end
	end
	return problems
end

Hazard.Registry = Hazard
return Hazard
