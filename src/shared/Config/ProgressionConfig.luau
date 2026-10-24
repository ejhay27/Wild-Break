--!strict
--[[
	ProgressionConfig.luau
	Levels, experience, mastery tracks and research ranks.

	Design rules:
	  - Experience is never gated behind a single activity: combat, gathering,
	    crafting, exploration, events, dungeons and clan wars all contribute.
	  - Levels unlock systems; they do not replace skill. A level 120 player
	    still has to hit weak points, manage stamina and read telegraphs.
]]

local Registry = require(script.Parent.Registry)
local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)

local Progression = {}

export type LevelRewardDef = {
	level: number,
	kind: string, -- Unlock | Currency | Cosmetic | Capacity | Title
	id: string,
	displayName: string,
	quantity: number?,
	description: string,
}

export type MasteryTrackDef = {
	id: string,
	displayName: string,
	kind: string, -- Weapon | Region | Gathering | Crafting
	targetId: string?,
	maxRank: number,
	experiencePerAction: number,
	rankRewards: { [number]: string },
	description: string,
}

-- ---------------------------------------------------------------------------
-- Experience curve
-- ---------------------------------------------------------------------------

-- Experience needed to go from `level` to `level + 1`.
function Progression.ExperienceForLevel(level: number): number
	if level < 1 then
		return Limits.Progression.BaseExperienceForLevel
	end
	local clamped = math.clamp(math.floor(level), 1, Limits.Progression.MaxPlayerLevel)
	return math.floor(
		Limits.Progression.BaseExperienceForLevel * math.pow(Limits.Progression.ExperienceGrowth, clamped - 1)
	)
end

-- Cumulative experience required to reach `level`.
function Progression.CumulativeExperience(level: number): number
	local total = 0
	for index = 1, math.clamp(math.floor(level), 1, Limits.Progression.MaxPlayerLevel) - 1 do
		total += Progression.ExperienceForLevel(index)
	end
	return total
end

-- Converts a lifetime experience total into { level, into, needed }.
function Progression.LevelFromExperience(totalExperience: number): { level: number, into: number, needed: number }
	local remaining = math.max(0, math.floor(totalExperience or 0))
	local level = 1
	while level < Limits.Progression.MaxPlayerLevel do
		local needed = Progression.ExperienceForLevel(level)
		if remaining < needed then
			return { level = level, into = remaining, needed = needed }
		end
		remaining -= needed
		level += 1
	end
	return { level = Limits.Progression.MaxPlayerLevel, into = 0, needed = 0 }
end

-- ---------------------------------------------------------------------------
-- Experience sources (all additive, no single mandatory path)
-- ---------------------------------------------------------------------------

Progression.ExperienceSources = {
	{ id = "beast_kill", displayName = "Beast defeated", base = 18, scalesWithLevelGap = true },
	{ id = "elite_kill", displayName = "Elite beast defeated", base = 70, scalesWithLevelGap = true },
	{ id = "apex_kill", displayName = "Apex beast defeated", base = 180, scalesWithLevelGap = true },
	{ id = "world_boss", displayName = "World boss defeated", base = 1400, scalesWithLevelGap = true },
	{ id = "dungeon_boss", displayName = "Dungeon boss defeated", base = 950, scalesWithLevelGap = true },
	{ id = "gather_node", displayName = "Resource gathered", base = 9, scalesWithLevelGap = false },
	{ id = "rare_node", displayName = "Rare resource gathered", base = 34, scalesWithLevelGap = false },
	{ id = "craft", displayName = "Item crafted", base = 22, scalesWithLevelGap = false },
	{ id = "first_craft", displayName = "First time crafting an item", base = 120, scalesWithLevelGap = false },
	{ id = "discovery", displayName = "Landmark discovered", base = 85, scalesWithLevelGap = false },
	{ id = "world_event", displayName = "World event completed", base = 420, scalesWithLevelGap = true },
	{ id = "clan_war", displayName = "Clan War match completed", base = 360, scalesWithLevelGap = true },
	{ id = "tame", displayName = "Beast tamed", base = 60, scalesWithLevelGap = false },
	{ id = "quest", displayName = "Objective completed", base = 55, scalesWithLevelGap = true },
}

local sourceById: { [string]: { id: string, displayName: string, base: number, scalesWithLevelGap: boolean } } = {}
for _, source in Progression.ExperienceSources do
	sourceById[source.id] = source
end

function Progression.ExperienceFor(sourceId: string, contentLevel: number?, playerLevel: number?): number
	local source = sourceById[sourceId]
	if not source then
		return 0
	end
	if not source.scalesWithLevelGap or not contentLevel or not playerLevel then
		return source.base
	end
	local gap = contentLevel - playerLevel
	if gap > 0 then
		-- Beating content above your level is worth more, with a ceiling.
		return math.floor(source.base * (1 + math.min(gap, 20) * 0.06))
	elseif gap < 0 then
		-- Farming trivial content still gives something, just much less.
		return math.max(1, math.floor(source.base * math.max(0.1, 1 + gap * 0.05)))
	end
	return source.base
end

-- ---------------------------------------------------------------------------
-- Level rewards
-- ---------------------------------------------------------------------------

local function reward(level: number, kind: string, id: string, displayName: string, description: string, quantity: number?): LevelRewardDef
	return {
		level = level,
		kind = kind,
		id = id,
		displayName = displayName,
		quantity = quantity,
		description = description,
	}
end

Progression.LevelRewards = {
	reward(2, "Unlock", "unlock_crafting", "Workbench crafting", "Allows crafting at the Workbench.", nil),
	reward(3, "Unlock", "unlock_gadget_slot", "Gadget slot", "Equip a tactical gadget.", nil),
	reward(5, "Unlock", "unlock_dungeon_queue", "Dungeon access", "Queue for regional dungeons.", nil),
	reward(7, "Capacity", "capacity_inventory", "Inventory +10", "Ten extra inventory slots.", 10),
	reward(8, "Unlock", "unlock_attachments", "Attachment slots", "Install weapon attachments.", nil),
	reward(10, "Unlock", "unlock_companion", "Companion slot", "Tame and deploy a companion.", nil),
	reward(12, "Currency", "currency_sap", "World Tree Sap", "A small sap reward.", 3),
	reward(15, "Unlock", "unlock_boatyard", "Boatyard", "Craft small boats.", nil),
	reward(18, "Capacity", "capacity_inventory", "Inventory +10", "Ten extra inventory slots.", 10),
	reward(20, "Unlock", "unlock_ability_ultimate", "Ability tier 3", "Upgrade abilities to tier 3.", nil),
	reward(25, "Unlock", "unlock_operation", "Major Operations", "Queue for the ROOTFALL operation.", nil),
	reward(30, "Title", "title_expeditionary", "Expeditionary", "Title: Expeditionary.", nil),
	reward(35, "Capacity", "capacity_stash", "Stash +20", "Twenty extra stash slots.", 20),
	reward(40, "Unlock", "unlock_module_slot", "Module slot", "Install an extra weapon module.", nil),
	reward(50, "Currency", "currency_sap", "World Tree Sap", "A sap reward.", 8),
	reward(60, "Title", "title_breaker", "Breaker", "Title: Breaker.", nil),
	reward(75, "Capacity", "capacity_inventory", "Inventory +10", "Ten extra inventory slots.", 10),
	reward(90, "Title", "title_wildborne", "Wildborne", "Title: Wildborne.", nil),
	reward(100, "Cosmetic", "cosmetic_centurion", "Centurion Mark", "Cosmetic mark for level 100.", nil),
	reward(120, "Cosmetic", "cosmetic_wildbreak", "WILDBREAK Crest", "Cosmetic crest for level 120.", nil),
}

function Progression.RewardsForLevel(level: number): { LevelRewardDef }
	local out = {}
	for _, entry in Progression.LevelRewards do
		if entry.level == level then
			table.insert(out, entry)
		end
	end
	return out
end

function Progression.RewardsUpTo(level: number): { LevelRewardDef }
	local out = {}
	for _, entry in Progression.LevelRewards do
		if entry.level <= level then
			table.insert(out, entry)
		end
	end
	table.sort(out, function(a, b)
		return a.level < b.level
	end)
	return out
end

-- ---------------------------------------------------------------------------
-- Mastery tracks
-- ---------------------------------------------------------------------------

local function track(
	id: string,
	displayName: string,
	kind: string,
	targetId: string?,
	maxRank: number,
	experiencePerAction: number,
	description: string
): MasteryTrackDef
	return {
		id = id,
		displayName = displayName,
		kind = kind,
		targetId = targetId,
		maxRank = maxRank,
		experiencePerAction = experiencePerAction,
		rankRewards = {},
		description = description,
	}
end

local masteryEntries: { [string]: MasteryTrackDef } = {}
local function add(def: MasteryTrackDef)
	def.rankRewards[1] = "Handling +2%"
	def.rankRewards[math.ceil(def.maxRank / 2)] = "Signature perk"
	def.rankRewards[def.maxRank] = "Mastery title"
	masteryEntries[def.id] = def
	return def
end

add(track("mastery_assault_rifle", "Assault Rifle Mastery", "Weapon", "AssaultRifle", 20, 4, "Rewards sustained-fire discipline."))
add(track("mastery_smg", "SMG Mastery", "Weapon", "SMG", 20, 4, "Rewards close-quarters pressure."))
add(track("mastery_sniper", "Sniper Mastery", "Weapon", "Sniper", 20, 5, "Rewards patience and positioning."))
add(track("mastery_shotgun", "Shotgun Mastery", "Weapon", "Shotgun", 20, 4, "Rewards aggressive spacing."))
add(track("mastery_lmg", "LMG Mastery", "Weapon", "LMG", 20, 4, "Rewards area denial."))
add(track("mastery_pistol", "Pistol Mastery", "Weapon", "Pistol", 20, 3, "Rewards sidearm reliability."))
add(track("mastery_bow", "Bow Mastery", "Weapon", "Bow", 20, 5, "Rewards precision and stealth."))
add(track("mastery_launcher", "Launcher Mastery", "Weapon", "Launcher", 20, 6, "Rewards target prioritisation."))
add(track("mastery_melee", "Blade Mastery", "Weapon", "Blade", 20, 4, "Rewards parries and combo finishers."))
add(track("mastery_gathering", "Gathering", "Gathering", nil, 25, 3, "Faster harvests and better yields."))
add(track("mastery_crafting", "Crafting", "Crafting", nil, 25, 3, "Cheaper recipes and better results."))
for _, regionId in ipairs(Enums.RegionOrder) do
	add(track("reputation_" .. string.lower(tostring(regionId)), tostring(regionId) .. " Reputation", "Region", regionId, 15, 2, "Regional reputation unlocks local stock."))
end

local MasteryRegistry = Registry.new("Mastery", masteryEntries, { "id", "displayName", "kind" })

function Progression.Mastery(id: string): MasteryTrackDef?
	return MasteryRegistry:Get(id)
end

function Progression.MasteryTracks(): { MasteryTrackDef }
	return MasteryRegistry:List()
end

function Progression.MasteryExperienceForRank(trackId: string, rank: number): number
	local def = MasteryRegistry:Get(trackId)
	if not def then
		return 0
	end
	local clamped = math.clamp(math.floor(rank), 1, def.maxRank)
	return math.floor(100 * math.pow(1.18, clamped - 1))
end

function Progression.MasteryRankFromExperience(trackId: string, experience: number): number
	local def = MasteryRegistry:Get(trackId)
	if not def then
		return 1
	end
	local remaining = math.max(0, math.floor(experience or 0))
	local rank = 1
	while rank < def.maxRank do
		local needed = Progression.MasteryExperienceForRank(trackId, rank)
		if remaining < needed then
			return rank
		end
		remaining -= needed
		rank += 1
	end
	return def.maxRank
end

-- ---------------------------------------------------------------------------
-- Validation
-- ---------------------------------------------------------------------------

function Progression.ValidateAll(): { string }
	local problems = Registry.Validate(MasteryRegistry)
	if Limits.Progression.MaxPlayerLevel < 2 then
		table.insert(problems, "[Progression] MaxPlayerLevel must be at least 2")
	end
	local previous = 0
	for level = 1, Limits.Progression.MaxPlayerLevel do
		local needed = Progression.ExperienceForLevel(level)
		if needed <= 0 then
			table.insert(problems, string.format("[Progression] level %d needs a positive experience requirement", level))
		end
		if needed < previous then
			table.insert(problems, string.format("[Progression] experience curve decreases at level %d", level))
		end
		previous = needed
	end
	local seenSources = {}
	for _, source in Progression.ExperienceSources do
		if seenSources[source.id] then
			table.insert(problems, string.format("[Progression] duplicate experience source %s", source.id))
		end
		seenSources[source.id] = true
		if source.base <= 0 then
			table.insert(problems, string.format("[Progression] experience source %s has a non-positive value", source.id))
		end
	end
	for level = 1, Limits.Progression.MaxPlayerLevel do
		local check = Progression.LevelFromExperience(Progression.CumulativeExperience(level))
		if check.level ~= level then
			table.insert(problems, string.format("[Progression] cumulative experience for level %d resolves to %d", level, check.level))
		end
	end
	for _, entry in Progression.LevelRewards do
		if entry.level < 1 or entry.level > Limits.Progression.MaxPlayerLevel then
			table.insert(problems, string.format("[Progression] reward %s is outside the level range", entry.id))
		end
	end
	return problems
end

Progression.Registry = MasteryRegistry
return Progression
