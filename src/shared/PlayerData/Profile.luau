--!strict
--[[
	Profile.luau
	The single source of truth for what a player owns and has achieved.

	This module is pure data logic: no Roblox services, no networking. The
	server owns the profile, mutates it through the services, and persists it.
	Every value that arrives from storage or from a client passes through
	`Sanitise` first, so a corrupted save can never crash the game or grant
	anything.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)
local Items = require(script.Parent.Parent.Config.ItemConfig)
local Weapons = require(script.Parent.Parent.Config.WeaponConfig)
local Abilities = require(script.Parent.Parent.Config.AbilityConfig)
local Gadgets = require(script.Parent.Parent.Config.GadgetConfig)

local Profile = {}

Profile.Version = 1

export type ItemStack = {
	uid: string, -- unique per physical stack
	id: string,
	quantity: number,
	-- Instance data (stars, level, attachments, cores) for non-stackable gear.
	data: { [string]: any }?,
}

export type WeaponInstance = {
	id: string,
	stars: number,
	level: number,
	attachments: { [string]: string },
	core: string?,
}

export type CompanionInstance = {
	uid: string,
	speciesId: string,
	name: string,
	level: number,
	bond: number,
	role: string?,
}

export type ProfileData = {
	version: number,
	userId: number,
	createdAt: number,
	updatedAt: number,
	level: number,
	experience: number,
	experienceTotal: number,
	sap: number,
	coin: number,
	inventory: { [string]: ItemStack },
	inventoryCapacity: number,
	stash: { [string]: ItemStack },
	stashCapacity: number,
	weapons: { [string]: WeaponInstance },
	equipped: {
		primary: string?,
		secondary: string?,
		melee: string?,
		gadget: string?,
		ability: string?,
		companion: string?,
	},
	abilities: { [string]: { tier: number, unlocked: boolean } },
	gadgets: { [string]: { unlocked: boolean } },
	companions: { [string]: CompanionInstance },
	activeCompanions: { string },
	recipes: { [string]: boolean },
	discoveries: { [string]: boolean },
	mastery: { [string]: number },
	research: { [string]: number },
	stats: { [string]: number },
	settings: { [string]: any },
	clanId: string?,
	playtimeSeconds: number,
	deaths: number,
	tutorialComplete: boolean,
	-- Incremented every time a sanctioned admin action touches this profile.
	adminRevision: number,
}

local function clampNumber(value: any, minimum: number, maximum: number, fallback: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	return math.clamp(value, minimum, maximum)
end

local function sanitiseStack(raw: any, index: string, allowUnknownItems: boolean): ItemStack?
	if type(raw) ~= "table" then
		return nil
	end
	local id = raw.id
	if type(id) ~= "string" then
		return nil
	end
	if not Items:Has(id) and not (Weapons:Has(id) or allowUnknownItems) then
		return nil
	end
	local quantity = clampNumber(raw.quantity, 1, 1_000_000, 1)
	return {
		uid = type(raw.uid) == "string" and raw.uid or (index .. "_" .. id),
		id = id,
		quantity = math.floor(quantity),
		data = type(raw.data) == "table" and raw.data or nil,
	}
end

local function sanitiseStackMap(raw: any, capacity: number, allowUnknownItems: boolean?): { [string]: ItemStack }
	local out = {}
	if type(raw) ~= "table" then
		return out
	end
	local count = 0
	for index, value in raw do
		if count >= capacity then
			break
		end
		if type(index) ~= "string" then
			continue
		end
		local stack = sanitiseStack(value, index, allowUnknownItems == true)
		if stack then
			out[index] = stack
			count += 1
		end
	end
	return out
end

local function sanitiseWeapons(raw: any): { [string]: WeaponInstance }
	local out = {}
	if type(raw) ~= "table" then
		return out
	end
	for id, value in raw do
		if type(id) ~= "string" or type(value) ~= "table" then
			continue
		end
		if not Weapons:Has(id) then
			continue
		end
		local attachments = {}
		if type(value.attachments) == "table" then
			for slot, attachmentId in value.attachments do
				if type(slot) == "string" and type(attachmentId) == "string" then
					attachments[slot] = attachmentId
				end
			end
		end
		out[id] = {
			id = id,
			stars = math.floor(clampNumber(value.stars, 0, 8, 0)),
			level = math.floor(clampNumber(value.level, 1, 100, 1)),
			attachments = attachments,
			core = type(value.core) == "string" and value.core or nil,
		}
	end
	return out
end

local function sanitiseCompanions(raw: any): { [string]: CompanionInstance }
	local out = {}
	if type(raw) ~= "table" then
		return out
	end
	for uid, value in raw do
		if type(uid) ~= "string" or type(value) ~= "table" then
			continue
		end
		if type(value.speciesId) ~= "string" then
			continue
		end
		out[uid] = {
			uid = uid,
			speciesId = value.speciesId,
			name = type(value.name) == "string" and value.name or "Companion",
			level = math.floor(clampNumber(value.level, 1, Limits.Companion.MaxLevel, 1)),
			bond = clampNumber(value.bond, 0, 100, 0),
			role = type(value.role) == "string" and value.role or nil,
		}
	end
	return out
end

local function sanitiseNumberMap(raw: any, minimum: number, maximum: number): { [string]: number }
	local out = {}
	if type(raw) ~= "table" then
		return out
	end
	for key, value in raw do
		if type(key) == "string" then
			out[key] = clampNumber(value, minimum, maximum, minimum)
		end
	end
	return out
end

local function sanitiseBooleanMap(raw: any): { [string]: boolean }
	local out = {}
	if type(raw) ~= "table" then
		return out
	end
	for key, value in raw do
		if type(key) == "string" and type(value) == "boolean" then
			out[key] = value
		end
	end
	return out
end

function Profile.Default(userId: number, now: number?): ProfileData
	local timestamp = now or 0
	return {
		version = Profile.Version,
		userId = userId,
		createdAt = timestamp,
		updatedAt = timestamp,
		level = 1,
		experience = 0,
		experienceTotal = 0,
		sap = 0,
		coin = 0,
		inventory = {},
		inventoryCapacity = Limits.Inventory.DefaultSlots,
		stash = {},
		stashCapacity = Limits.Inventory.DefaultStashSlots,
		weapons = {},
		equipped = {
			primary = nil,
			secondary = nil,
			melee = nil,
			gadget = nil,
			ability = nil,
			companion = nil,
		},
		abilities = {},
		gadgets = {},
		companions = {},
		activeCompanions = {},
		recipes = {},
		discoveries = {},
		mastery = {},
		research = {},
		stats = {},
		settings = {},
		clanId = nil,
		playtimeSeconds = 0,
		deaths = 0,
		tutorialComplete = false,
		adminRevision = 0,
	}
end

-- Brings any stored table up to the current version.
function Profile.Migrate(raw: { [string]: any }): { [string]: any }
	local version = type(raw.version) == "number" and math.floor(raw.version) or 0
	if version < 1 then
		-- v0 was the pre-release schema: nothing to carry over except the id.
		raw.equipped = raw.equipped or {}
		raw.version = 1
	end
	raw.version = Profile.Version
	return raw
end

-- Produces a trusted profile. Anything unusable is replaced with a default.
function Profile.Sanitise(raw: any, userId: number, now: number?): ProfileData
	local clean = Profile.Default(userId, now)
	if type(raw) ~= "table" then
		return clean
	end
	raw = Profile.Migrate(raw)
	clean.userId = userId
	clean.createdAt = clampNumber(raw.createdAt, 0, 4_102_444_800, clean.createdAt)
	clean.updatedAt = clampNumber(raw.updatedAt, 0, 4_102_444_800, clean.updatedAt)
	clean.level = math.floor(clampNumber(raw.level, 1, Limits.Progression.MaxPlayerLevel, 1))
	clean.experience = clampNumber(raw.experience, 0, 1e12, 0)
	clean.experienceTotal = clampNumber(raw.experienceTotal, 0, 1e15, 0)
	clean.sap = math.floor(clampNumber(raw.sap, 0, 1e9, 0))
	clean.coin = math.floor(clampNumber(raw.coin, 0, 1e9, 0))
	clean.inventoryCapacity = math.floor(clampNumber(raw.inventoryCapacity, 1, Limits.Inventory.MaxSlots, Limits.Inventory.DefaultSlots))
	clean.stashCapacity = math.floor(clampNumber(raw.stashCapacity, 1, Limits.Inventory.MaxSlots, Limits.Inventory.DefaultStashSlots))
	clean.inventory = sanitiseStackMap(raw.inventory, clean.inventoryCapacity, true)
	clean.stash = sanitiseStackMap(raw.stash, clean.stashCapacity, true)
	clean.weapons = sanitiseWeapons(raw.weapons)
	clean.companions = sanitiseCompanions(raw.companions)
	clean.playtimeSeconds = clampNumber(raw.playtimeSeconds, 0, 1e9, 0)
	clean.deaths = math.floor(clampNumber(raw.deaths, 0, 1e9, 0))
	clean.tutorialComplete = raw.tutorialComplete == true
	clean.adminRevision = math.floor(clampNumber(raw.adminRevision, 0, 1e9, 0))
	clean.mastery = sanitiseNumberMap(raw.mastery, 0, 1e12)
	clean.research = sanitiseNumberMap(raw.research, 0, Limits.Progression.MaxResearchRank)
	clean.stats = sanitiseNumberMap(raw.stats, 0, 1e12)
	clean.recipes = sanitiseBooleanMap(raw.recipes)
	clean.discoveries = sanitiseBooleanMap(raw.discoveries)
	clean.settings = type(raw.settings) == "table" and raw.settings or {}
	clean.clanId = type(raw.clanId) == "string" and raw.clanId or nil

	if type(raw.equipped) == "table" then
		for slot in clean.equipped do
			local value = raw.equipped[slot]
			if type(value) == "string" then
				if slot == "primary" or slot == "secondary" or slot == "melee" then
					if clean.weapons[value] ~= nil then
						clean.equipped[slot] = value
					end
				elseif slot == "gadget" and Gadgets:Has(value) then
					clean.equipped[slot] = value
				elseif slot == "ability" and Abilities:Has(value) then
					clean.equipped[slot] = value
				elseif slot == "companion" and clean.companions[value] ~= nil then
					clean.equipped[slot] = value
				end
			end
		end
	end

	if type(raw.abilities) == "table" then
		for abilityId, value in raw.abilities do
			if type(abilityId) == "string" and Abilities:Has(abilityId) and type(value) == "table" then
				clean.abilities[abilityId] = {
					tier = math.floor(clampNumber(value.tier, 1, Limits.Progression.MaxAbilityTier, 1)),
					unlocked = value.unlocked == true,
				}
			end
		end
	end

	if type(raw.gadgets) == "table" then
		for gadgetId, value in raw.gadgets do
			if type(gadgetId) == "string" and Gadgets:Has(gadgetId) and type(value) == "table" then
				clean.gadgets[gadgetId] = { unlocked = value.unlocked == true }
			end
		end
	end

	if type(raw.activeCompanions) == "table" then
		local limit = Limits.Companion.MaxActiveOpenWorld
		for _, uid in raw.activeCompanions do
			if type(uid) == "string" and clean.companions[uid] ~= nil and #clean.activeCompanions < limit then
				table.insert(clean.activeCompanions, uid)
			end
		end
	end

	return clean
end

-- True when the equipped loadout points only at things the player owns.
function Profile.IsLoadoutValid(data: ProfileData): boolean
	local equipped = data.equipped
	if equipped.primary and not data.weapons[equipped.primary] then
		return false
	end
	if equipped.secondary and not data.weapons[equipped.secondary] then
		return false
	end
	if equipped.melee and not data.weapons[equipped.melee] then
		return false
	end
	if equipped.companion and not data.companions[equipped.companion] then
		return false
	end
	return true
end

-- Grants a starting loadout. Used once, on first join.
function Profile.ApplyStarterLoadout(data: ProfileData, starterWeapons: { string }, starterItems: { { id: string, quantity: number } }?)
	for _, weaponId in starterWeapons do
		if Weapons:Has(weaponId) and not data.weapons[weaponId] then
			data.weapons[weaponId] = { id = weaponId, stars = 0, level = 1, attachments = {}, core = nil }
		end
	end
	if starterItems then
		local slot = 1
		for _, entry in starterItems do
			if Items:Has(entry.id) then
				data.inventory[tostring(slot)] = {
					uid = "starter_" .. entry.id,
					id = entry.id,
					quantity = entry.quantity,
					data = nil,
				}
				slot += 1
			end
		end
	end
	if not data.equipped.primary then
		data.equipped.primary = starterWeapons[1]
	end
	if not data.equipped.melee then
		for weaponId in data.weapons do
			if Weapons.IsMelee(weaponId) then
				data.equipped.melee = weaponId
				break
			end
		end
	end
	return data
end

function Profile.ValidateAll(): { string }
	local problems = {}
	local sample = Profile.Default(1, 0)
	if sample.version ~= Profile.Version then
		table.insert(problems, "[Profile] default version mismatch")
	end
	-- A hostile or corrupt save must never produce a usable-looking profile.
	local hostile = Profile.Sanitise({
		level = 1e9,
		sap = -50,
		experience = "lots",
		inventory = { ["a"] = { id = "not_an_item", quantity = -3 } },
		weapons = { ["also_not_a_weapon"] = { stars = 99 } },
		equipped = { primary = "weapon_we_do_not_own" },
		abilities = { ["nope"] = { tier = 99 } },
	}, 42, 0)
	if hostile.level ~= Limits.Progression.MaxPlayerLevel then
		table.insert(problems, "[Profile] level is not clamped")
	end
	if hostile.sap < 0 then
		table.insert(problems, "[Profile] currency can go negative")
	end
	if hostile.experience ~= 0 then
		table.insert(problems, "[Profile] non-numeric experience was accepted")
	end
	if hostile.weapons["also_not_a_weapon"] ~= nil then
		table.insert(problems, "[Profile] unknown weapons are kept")
	end
	if hostile.equipped.primary ~= nil then
		table.insert(problems, "[Profile] a weapon the player does not own can be equipped")
	end
	if hostile.abilities["nope"] ~= nil then
		table.insert(problems, "[Profile] unknown abilities are kept")
	end
	if not Profile.IsLoadoutValid(hostile) then
		table.insert(problems, "[Profile] a sanitised profile should have a valid loadout")
	end
	local migrated = Profile.Sanitise({ level = 5 }, 7, 0)
	if migrated.version ~= Profile.Version then
		table.insert(problems, "[Profile] migration does not stamp the current version")
	end
	return problems
end

return Profile
