--!strict
--[[
	WeaponConfig.luau
	The public weapon registry: forty firearms, ten melee weapons and the
	signature Ultimate for every firearm.

	This module merges the pure data modules (WeaponData / MeleeData /
	WeaponUltimates) and adds the derived-stat maths that the server applies.
	The server is the only authority for these numbers: the client receives
	resolved stats for presentation but never decides damage.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)
local Registry = require(script.Parent.Registry)
local Rarity = require(script.Parent.RarityConfig)
local AttachmentConfig = require(script.Parent.AttachmentConfig)
local FirearmData = require(script.Parent.WeaponData)
local MeleeData = require(script.Parent.MeleeData)
local Ultimates = require(script.Parent.WeaponUltimates)

local entries: { [string]: any } = {}
for id, def in FirearmData do
	entries[id] = def
end
for id, def in MeleeData do
	entries[id] = def
end

local Weapon = Registry.new("Weapon", entries, { "id", "displayName", "rarity" })

export type ResolvedStats = {
	damage: number,
	rpm: number,
	magazine: number,
	reloadTime: number,
	range: number,
	spread: number,
	adsSpread: number,
	recoilVertical: number,
	recoilHorizontal: number,
	adsTime: number,
	mobility: number,
	weakPointMultiplier: number,
	headMultiplier: number,
	multiplier: number,
}

-- Stat fields attachments are allowed to modify.
local MODIFIABLE_STATS = {
	"damage", "rpm", "magazine", "reloadTime", "range", "spread", "adsSpread",
	"recoilVertical", "recoilHorizontal", "adsTime", "switchTime", "mobility",
	"weakPointMultiplier", "headMultiplier",
}

function Weapon.IsFirearm(id: string): boolean
	local def = Weapon:Get(id)
	return def ~= nil and def.kind == Enums.WeaponKind.Firearm
end

function Weapon.IsMelee(id: string): boolean
	local def = Weapon:Get(id)
	return def ~= nil and def.kind == Enums.WeaponKind.Melee
end

function Weapon.Firearms(): { any }
	return Weapon:Filter(function(def)
		return def.kind == Enums.WeaponKind.Firearm
	end)
end

function Weapon.Melee(): { any }
	return Weapon:Filter(function(def)
		return def.kind == Enums.WeaponKind.Melee
	end)
end

function Weapon.ByClass(className: string): { any }
	return Weapon:Filter(function(def)
		return def.class == className
	end)
end

function Weapon.UltimateId(weaponId: string): string?
	local def = Weapon:Get(weaponId)
	if not def or def.kind ~= Enums.WeaponKind.Firearm then
		return nil
	end
	return def.ultimateId
end

function Weapon.Ultimate(weaponId: string): any?
	local ultimateId = Weapon.UltimateId(weaponId)
	if not ultimateId then
		return nil
	end
	return Ultimates[ultimateId]
end

function Weapon.UltimateById(ultimateId: string): any?
	return Ultimates[ultimateId]
end

function Weapon.AllUltimates(): { [string]: any }
	return Ultimates
end

-- Resolved stats for a concrete weapon instance.
-- `attachments` maps slot -> attachmentId, `modules` maps slot -> moduleId.
function Weapon.ComputeStats(
	weaponId: string,
	rarity: string?,
	stars: number?,
	attachments: { [string]: string }?,
	level: number?
): ResolvedStats
	local def = Weapon:GetOrError(weaponId)
	local rarityId = rarity or def.rarity
	local starCount = stars or 0
	local rarityMultiplier = Rarity.StatMultiplier(rarityId, starCount)
	local levelBonus = 1 + ((level or 1) - 1) * 0.012

	local stats: { [string]: number } = {
		damage = def.damage or def.baseDamage or 0,
		rpm = def.rpm or (600 / ((def.combo and def.combo[1].windup + def.combo[1].window) or 0.5)),
		magazine = def.magazine or 0,
		reloadTime = def.reloadTime or 0,
		range = def.range or def.reach or 0,
		spread = def.spread or 0,
		adsSpread = def.adsSpread or 0,
		recoilVertical = def.recoilVertical or 0,
		recoilHorizontal = def.recoilHorizontal or 0,
		adsTime = def.adsTime or 0,
		mobility = def.mobility or 1,
		weakPointMultiplier = def.weakPointMultiplier or 1,
		headMultiplier = def.headMultiplier or def.weakPointMultiplier or 1,
	}

	-- Rarity/stars scale throughput and damage but never mobility or handling,
	-- so a Prismatic weapon still has the same feel and trade-offs.
	stats.damage *= rarityMultiplier * levelBonus

	if attachments then
		for slot, attachmentId in attachments do
			local attachment = AttachmentConfig:Get(attachmentId)
			if attachment then
				for statName in MODIFIABLE_STATS do
					local additive = attachment.add and attachment.add[statName] or 0
					local multiplicative = attachment.mult and attachment.mult[statName] or 1
					stats[statName] = (stats[statName] + additive) * multiplicative
				end
			end
		end
	end

	-- Hard sanity clamps so no combination can produce negative or absurd values.
	stats.damage = math.max(1, stats.damage)
	stats.rpm = math.clamp(stats.rpm, 20, 1500)
	stats.magazine = math.max(1, math.floor(stats.magazine))
	stats.reloadTime = math.max(Limits.Combat.ReloadMinSeconds, stats.reloadTime)
	stats.range = math.clamp(stats.range, 5, 1200)
	stats.spread = math.max(0, stats.spread)
	stats.adsSpread = math.max(0, stats.adsSpread)
	stats.mobility = math.clamp(stats.mobility, 0.5, 1.4)
	stats.weakPointMultiplier = math.clamp(stats.weakPointMultiplier, 1, 4)
	stats.headMultiplier = math.clamp(stats.headMultiplier, 1, 4.5)
	stats.multiplier = rarityMultiplier

	return stats :: ResolvedStats
end

-- How much ammo a weapon holds in total (magazine + reserve).
function Weapon.TotalAmmo(weaponId: string): number
	local def = Weapon:Get(weaponId)
	if not def or def.kind ~= Enums.WeaponKind.Firearm then
		return 0
	end
	return def.magazine + def.reserve
end

function Weapon.CompatibleAttachments(weaponId: string): { any }
	local def = Weapon:Get(weaponId)
	if not def then
		return {}
	end
	return AttachmentConfig.CompatibleWith(weaponId, def.attachmentSlots or {}, def.class)
end

function Weapon.CoreCompatibility(weaponId: string): { string }
	local def = Weapon:Get(weaponId)
	if not def then
		return {}
	end
	return def.coreCompatibility or {}
end

function Weapon.AcceptsCore(weaponId: string, coreCategory: string): boolean
	for _, category in Weapon.CoreCompatibility(weaponId) do
		if category == coreCategory then
			return true
		end
	end
	return false
end

function Weapon.ValidateAll(): { string }
	local problems = Registry.Validate(Weapon)

	local firearms = Weapon.Firearms()
	if #firearms ~= 40 then
		table.insert(problems, string.format("[Weapon] expected 40 firearms, found %d", #firearms))
	end
	local melee = Weapon.Melee()
	if #melee ~= 10 then
		table.insert(problems, string.format("[Weapon] expected 10 melee weapons, found %d", #melee))
	end

	-- Every firearm needs a unique, defined Ultimate.
	local seenUltimates: { [string]: string } = {}
	local ultimateCount = 0
	for _, def in firearms do
		if not def.ultimateId then
			table.insert(problems, string.format("[Weapon] %s has no ultimateId", def.id))
			continue
		end
		local ultimate = Ultimates[def.ultimateId]
		if not ultimate then
			table.insert(problems, string.format("[Weapon] %s references missing ultimate %s", def.id, def.ultimateId))
			continue
		end
		if ultimate.weaponId ~= def.id then
			table.insert(problems, string.format("[Weapon] %s ultimate %s points at weapon %s", def.id, def.ultimateId, ultimate.weaponId))
		end
		if seenUltimates[def.ultimateId] then
			table.insert(problems, string.format("[Weapon] ultimate %s is reused by %s and %s", def.ultimateId, seenUltimates[def.ultimateId], def.id))
		end
		seenUltimates[def.ultimateId] = def.id
		ultimateCount += 1
	end
	if ultimateCount ~= 40 then
		table.insert(problems, string.format("[Weapon] expected 40 ultimates, found %d", ultimateCount))
	end

	-- Distinct weapon identities: no two firearms may share an identical stat signature.
	local signatures: { [string]: string } = {}
	for _, def in firearms do
		local signature = string.format(
			"%d|%d|%s|%d|%d|%d|%d|%.2f|%.2f|%.2f|%.2f|%.2f|%s",
			def.damage, def.rpm, def.fireMode, def.magazine, def.reserve, def.range, def.spread,
			def.recoilVertical, def.recoilHorizontal, def.adsTime, def.mobility, def.weakPointMultiplier, def.damageType
		)
		if signatures[signature] then
			table.insert(problems, string.format("[Weapon] %s has the same stat signature as %s", def.id, signatures[signature]))
		end
		signatures[signature] = def.id
	end

	for _, def in melee do
		if not def.combo or #def.combo < 2 then
			table.insert(problems, string.format("[Weapon] melee %s needs at least two combo steps", def.id))
		end
		if not def.identity or def.identity == "" then
			table.insert(problems, string.format("[Weapon] melee %s has no declared combat identity", def.id))
		end
	end

	return problems
end

Weapon.Registry = Weapon
return Weapon
