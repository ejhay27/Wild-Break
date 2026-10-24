--!strict
--[[
	AttachmentConfig.luau
	Gunsmith data: conventional attachments, experimental modules and Beast
	Core modules.

	Every attachment has a real trade-off. Compatibility is explicit: an
	attachment declares the weapon classes (and optionally the exact weapon
	ids) it fits, and the server re-checks compatibility on every install
	request regardless of what the client UI allowed.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Registry = require(script.Parent.Registry)

export type AttachmentDef = {
	id: string,
	displayName: string,
	slot: string,
	kind: string, -- Conventional | Module | Core
	rarity: string,
	-- Additive and multiplicative stat deltas.
	add: { [string]: number }?,
	mult: { [string]: number }?,
	compatibleClasses: { string }?,
	compatibleWeapons: { string }?,
	incompatibleWeapons: { string }?,
	coreCategory: string?,
	materials: { [string]: number }?,
	unlockLevel: number,
	tradeoff: string,
	description: string,
}

local function att(def: AttachmentDef): AttachmentDef
	def.add = def.add or {}
	def.mult = def.mult or {}
	return def
end

local ALL_CLASSES = {
	Enums.WeaponClass.AssaultRifle,
	Enums.WeaponClass.SubmachineGun,
	Enums.WeaponClass.Shotgun,
	Enums.WeaponClass.SniperRifle,
	Enums.WeaponClass.DMR,
	Enums.WeaponClass.LMG,
	Enums.WeaponClass.Pistol,
	Enums.WeaponClass.Special,
}

local entries: { [string]: AttachmentDef } = {
	-- -------------------------------------------------------------------------
	-- OPTICS
	-- -------------------------------------------------------------------------
	["optic_reflex"] = att({
		id = "optic_reflex",
		displayName = "Reflex Sight",
		slot = "Optic",
		kind = "Conventional",
		rarity = Enums.Rarity.Common,
		add = { adsSpread = -0.15, adsTime = 0.02 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 1,
		tradeoff = "Slightly slower aim-down-sights.",
		description = "Clean 1x sight. Tightens hip-to-ADS spread.",
	}),
	["optic_scout"] = att({
		id = "optic_scout",
		displayName = "Scout Scope 4x",
		slot = "Optic",
		kind = "Conventional",
		rarity = Enums.Rarity.Rare,
		add = { adsSpread = -0.45, range = 60, adsTime = 0.14 },
		compatibleClasses = { Enums.WeaponClass.AssaultRifle, Enums.WeaponClass.DMR, Enums.WeaponClass.SniperRifle, Enums.WeaponClass.LMG },
		unlockLevel = 5,
		tradeoff = "Noticeably slower aim-down-sights and reduced peripheral vision.",
		description = "Variable 4x optic for long-range work.",
	}),
	["optic_thermal"] = att({
		id = "optic_thermal",
		displayName = "Thermal Overlay",
		slot = "Optic",
		kind = "Conventional",
		rarity = Enums.Rarity.Epic,
		add = { adsSpread = -0.3, adsTime = 0.08 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 14,
		tradeoff = "Adds a visible glow that reveals the wielder's position at night.",
		description = "Highlights beast weak points through foliage at the cost of stealth.",
	}),
	["optic_ghostmark"] = att({
		id = "optic_ghostmark",
		displayName = "Ghostmark Lens",
		slot = "Optic",
		kind = "Conventional",
		rarity = Enums.Rarity.Legendary,
		add = { adsSpread = -0.25, weakPointMultiplier = 0.15 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 26,
		tradeoff = "Increases recoil while aiming.",
		description = "Marks weak points briefly when you aim at them.",
	}),

	-- -------------------------------------------------------------------------
	-- MUZZLES
	-- -------------------------------------------------------------------------
	["muzzle_brake"] = att({
		id = "muzzle_brake",
		displayName = "Recoil Brake",
		slot = "Muzzle",
		kind = "Conventional",
		rarity = Enums.Rarity.Common,
		mult = { recoilVertical = 0.75, recoilHorizontal = 0.82 },
		add = { spread = 0.2 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 2,
		tradeoff = "Slightly wider spread.",
		description = "Tames vertical climb for sustained fire.",
	}),
	["muzzle_suppressor"] = att({
		id = "muzzle_suppressor",
		displayName = "Field Suppressor",
		slot = "Muzzle",
		kind = "Conventional",
		rarity = Enums.Rarity.Rare,
		add = { damage = -2, range = -30 },
		mult = { recoilVertical = 0.9 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 6,
		tradeoff = "Reduced damage and effective range.",
		description = "Beasts lose track of suppressed hunters far more quickly.",
	}),
	["muzzle_compensator"] = att({
		id = "muzzle_compensator",
		displayName = "Beast Compensator",
		slot = "Muzzle",
		kind = "Conventional",
		rarity = Enums.Rarity.Epic,
		mult = { recoilHorizontal = 0.6 },
		add = { reloadTime = 0.15, mobility = -0.02 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 15,
		tradeoff = "Heavier, slower reloads and reduced mobility.",
		description = "Stabilises horizontal drift on automatic weapons.",
	}),

	-- -------------------------------------------------------------------------
	-- BARRELS
	-- -------------------------------------------------------------------------
	["barrel_long"] = att({
		id = "barrel_long",
		displayName = "Extended Barrel",
		slot = "Barrel",
		kind = "Conventional",
		rarity = Enums.Rarity.Common,
		add = { range = 70, damage = 2 },
		mult = { mobility = 0.94, adsTime = 1.1 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 3,
		tradeoff = "Reduced mobility and slower handling.",
		description = "More range and punch, less nimbleness.",
	}),
	["barrel_short"] = att({
		id = "barrel_short",
		displayName = "Cut-Down Barrel",
		slot = "Barrel",
		kind = "Conventional",
		rarity = Enums.Rarity.Rare,
		add = { range = -60, spread = 0.6 },
		mult = { mobility = 1.08, adsTime = 0.85 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 8,
		tradeoff = "Much shorter effective range and worse spread.",
		description = "Close-quarters handling package.",
	}),
	["barrel_cryo"] = att({
		id = "barrel_cryo",
		displayName = "Cryo Sleeve",
		slot = "Barrel",
		kind = "Conventional",
		rarity = Enums.Rarity.Epic,
		add = { damage = 3, reloadTime = 0.25 },
		mult = { mobility = 0.96 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 18,
		tradeoff = "Heavier and slower to reload.",
		description = "Adds chill to every shot; sustained fire no longer overheats as fast.",
	}),

	-- -------------------------------------------------------------------------
	-- GRIPS
	-- -------------------------------------------------------------------------
	["grip_vertical"] = att({
		id = "grip_vertical",
		displayName = "Vertical Grip",
		slot = "Grip",
		kind = "Conventional",
		rarity = Enums.Rarity.Common,
		mult = { recoilVertical = 0.85 },
		add = { adsTime = 0.03 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 2,
		tradeoff = "Slightly slower aim-down-sights.",
		description = "Straightforward recoil control.",
	}),
	["grip_sprint"] = att({
		id = "grip_sprint",
		displayName = "Sprint Grip",
		slot = "Grip",
		kind = "Conventional",
		rarity = Enums.Rarity.Rare,
		mult = { adsTime = 0.8, switchTime = 0.85 },
		add = { spread = 0.25 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 9,
		tradeoff = "Worse sustained spread.",
		description = "Faster raising and swapping for aggressive play.",
	}),
	["grip_beast"] = att({
		id = "grip_beast",
		displayName = "Beastbone Grip",
		slot = "Grip",
		kind = "Conventional",
		rarity = Enums.Rarity.Legendary,
		add = { weakPointMultiplier = 0.12 },
		mult = { recoilVertical = 1.08 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 24,
		tradeoff = "Increases recoil.",
		description = "Carved from apex bone. Rewards weak-point precision.",
	}),

	-- -------------------------------------------------------------------------
	-- MAGAZINES
	-- -------------------------------------------------------------------------
	["mag_extended"] = att({
		id = "mag_extended",
		displayName = "Extended Magazine",
		slot = "Magazine",
		kind = "Conventional",
		rarity = Enums.Rarity.Common,
		mult = { magazine = 1.4 },
		add = { reloadTime = 0.45 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 4,
		tradeoff = "Longer reload time.",
		description = "More rounds per magazine, slower reloads.",
	}),
	["mag_quick"] = att({
		id = "mag_quick",
		displayName = "Quick Magazine",
		slot = "Magazine",
		kind = "Conventional",
		rarity = Enums.Rarity.Rare,
		mult = { reloadTime = 0.72 },
		add = { magazine = -2 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 10,
		tradeoff = "Smaller magazine.",
		description = "Fast reloads for hunters who reposition constantly.",
	}),
	["mag_drum"] = att({
		id = "mag_drum",
		displayName = "Drum Magazine",
		slot = "Magazine",
		kind = "Conventional",
		rarity = Enums.Rarity.Epic,
		mult = { magazine = 1.9, reloadTime = 1.5 },
		add = { mobility = -0.05 },
		compatibleClasses = { Enums.WeaponClass.AssaultRifle, Enums.WeaponClass.SubmachineGun, Enums.WeaponClass.LMG },
		unlockLevel = 20,
		tradeoff = "Very long reloads and reduced mobility.",
		description = "Huge capacity for sustained fights.",
	}),

	-- -------------------------------------------------------------------------
	-- STOCKS
	-- -------------------------------------------------------------------------
	["stock_tactical"] = att({
		id = "stock_tactical",
		displayName = "Tactical Stock",
		slot = "Stock",
		kind = "Conventional",
		rarity = Enums.Rarity.Common,
		mult = { recoilHorizontal = 0.8, adsTime = 0.92 },
		add = { mobility = -0.02 },
		compatibleClasses = { Enums.WeaponClass.AssaultRifle, Enums.WeaponClass.DMR, Enums.WeaponClass.LMG, Enums.WeaponClass.SniperRifle },
		unlockLevel = 5,
		tradeoff = "Slightly reduced mobility.",
		description = "Stable firing platform.",
	}),
	["stock_skeleton"] = att({
		id = "stock_skeleton",
		displayName = "Skeleton Stock",
		slot = "Stock",
		kind = "Conventional",
		rarity = Enums.Rarity.Rare,
		mult = { mobility = 1.06, switchTime = 0.9 },
		add = { recoilVertical = 0.18 },
		compatibleClasses = { Enums.WeaponClass.AssaultRifle, Enums.WeaponClass.DMR, Enums.WeaponClass.LMG, Enums.WeaponClass.SniperRifle },
		unlockLevel = 12,
		tradeoff = "More recoil.",
		description = "Lightweight frame for mobile hunters.",
	}),

	-- -------------------------------------------------------------------------
	-- AMMUNITION
	-- -------------------------------------------------------------------------
	["ammo_ap"] = att({
		id = "ammo_ap",
		displayName = "Armour-Piercing Rounds",
		slot = "Ammo",
		kind = "Conventional",
		rarity = Enums.Rarity.Rare,
		add = { damage = 3 },
		mult = { magazine = 0.9 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 11,
		tradeoff = "Smaller magazine and weaker against unarmoured targets.",
		description = "Strong versus armour and shields, softer against exposed flesh.",
	}),
	["ammo_hollow"] = att({
		id = "ammo_hollow",
		displayName = "Hollow-Point Rounds",
		slot = "Ammo",
		kind = "Conventional",
		rarity = Enums.Rarity.Rare,
		add = { damage = 4, range = -40 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 11,
		tradeoff = "Shorter effective range and weak against armour.",
		description = "Devastating on unarmoured beasts at close range.",
	}),
	["ammo_incendiary"] = att({
		id = "ammo_incendiary",
		displayName = "Incendiary Rounds",
		slot = "Ammo",
		kind = "Conventional",
		rarity = Enums.Rarity.Epic,
		add = { damage = 2, reloadTime = 0.2 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 19,
		tradeoff = "Slower reloads.",
		description = "Applies Burn on hit.",
	}),
	["ammo_cryo"] = att({
		id = "ammo_cryo",
		displayName = "Cryo Rounds",
		slot = "Ammo",
		kind = "Conventional",
		rarity = Enums.Rarity.Epic,
		add = { damage = 2, reloadTime = 0.2 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 19,
		tradeoff = "Slower reloads.",
		description = "Applies Chill on hit.",
	}),

	-- -------------------------------------------------------------------------
	-- EXPERIMENTAL MODULES
	-- -------------------------------------------------------------------------
	["mod_overcharger"] = att({
		id = "mod_overcharger",
		displayName = "Overcharger Module",
		slot = "Module",
		kind = "Module",
		rarity = Enums.Rarity.Epic,
		add = { damage = 6, recoilVertical = 0.3 },
		mult = { magazine = 0.9 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 22,
		tradeoff = "More recoil, smaller magazine.",
		description = "Pushes every round harder at the cost of control.",
	}),
	["mod_stabiliser"] = att({
		id = "mod_stabiliser",
		displayName = "Gyro Stabiliser",
		slot = "Module",
		kind = "Module",
		rarity = Enums.Rarity.Epic,
		mult = { recoilVertical = 0.65, recoilHorizontal = 0.7, adsTime = 1.1 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 22,
		tradeoff = "Slower aim-down-sights.",
		description = "Active gyros hold the weapon steady while moving.",
	}),
	["mod_echo_rounds"] = att({
		id = "mod_echo_rounds",
		displayName = "Echo Round Module",
		slot = "Module",
		kind = "Module",
		rarity = Enums.Rarity.Legendary,
		add = { weakPointMultiplier = 0.2 },
		mult = { rpm = 0.92 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 32,
		tradeoff = "Lower rate of fire.",
		description = "Weak-point hits echo for a fraction of the damage.",
	}),
	["mod_phase_barrel"] = att({
		id = "mod_phase_barrel",
		displayName = "Phase Barrel",
		slot = "Module",
		kind = "Module",
		rarity = Enums.Rarity.Mythical,
		add = { damage = 8, spread = -0.4 },
		mult = { mobility = 0.95 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 38,
		tradeoff = "Reduced mobility; requires an Anomaly Core to install.",
		description = "Rounds partially phase through cover and armour.",
	}),

	-- -------------------------------------------------------------------------
	-- BEAST CORE MODULES
	-- -------------------------------------------------------------------------
	["core_wild"] = att({
		id = "core_wild",
		displayName = "Wild Core",
		slot = "Module",
		kind = "Core",
		rarity = Enums.Rarity.Rare,
		coreCategory = "Wild",
		add = { damage = 3, magazine = 2 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 8,
		tradeoff = "None. The baseline core.",
		description = "General crafting and research core. Small, reliable improvement.",
	}),
	["core_resonance"] = att({
		id = "core_resonance",
		displayName = "Resonance Core",
		slot = "Module",
		kind = "Core",
		rarity = Enums.Rarity.Epic,
		coreCategory = "Resonance",
		mult = { recoilVertical = 0.85 },
		add = { damage = 4 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 16,
		tradeoff = "Resonance hum increases beast detection radius slightly.",
		description = "Energy and disruption upgrades harvested from elites.",
	}),
	["core_apex"] = att({
		id = "core_apex",
		displayName = "Apex Core",
		slot = "Module",
		kind = "Core",
		rarity = Enums.Rarity.Legendary,
		coreCategory = "Apex",
		add = { damage = 9, weakPointMultiplier = 0.1 },
		mult = { reloadTime = 1.1 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 28,
		tradeoff = "Slower reloads.",
		description = "Elite and boss upgrades. Significant raw power.",
	}),
	["core_anomaly"] = att({
		id = "core_anomaly",
		displayName = "Anomaly Core",
		slot = "Module",
		kind = "Core",
		rarity = Enums.Rarity.Mythical,
		coreCategory = "Anomaly",
		add = { damage = 12, weakPointMultiplier = 0.15 },
		mult = { magazine = 0.85, mobility = 0.96 },
		compatibleClasses = ALL_CLASSES,
		unlockLevel = 40,
		tradeoff = "Reduced magazine, mobility and stability.",
		description = "Rare evolution core. Unlocks anomalous weapon behaviour.",
	}),
}

local Attachment = Registry.new("Attachment", entries, { "id", "displayName", "slot" })

function Attachment.BySlot(slot: string): { AttachmentDef }
	return Attachment:Filter(function(def)
		return def.slot == slot
	end)
end

function Attachment.IsCompatible(attachmentId: string, weaponId: string, weaponClass: string): boolean
	local def = Attachment:Get(attachmentId)
	if not def then
		return false
	end
	if def.incompatibleWeapons and table.find(def.incompatibleWeapons, weaponId) then
		return false
	end
	if def.compatibleWeapons and #def.compatibleWeapons > 0 then
		return table.find(def.compatibleWeapons, weaponId) ~= nil
	end
	if def.compatibleClasses then
		return table.find(def.compatibleClasses, weaponClass) ~= nil
	end
	return true
end

-- Lists attachments that fit a specific weapon (slot + class aware).
-- `weaponClass` is supplied by the caller so this module never has to require
-- WeaponConfig (which would create a circular dependency).
function Attachment.CompatibleWith(weaponId: string, slots: { string }, weaponClass: string?): { AttachmentDef }
	local result = {}
	for _, def in Attachment:List() do
		if table.find(slots, def.slot) and (not weaponClass or Attachment.IsCompatible(def.id, weaponId, weaponClass)) then
			table.insert(result, def)
		end
	end
	return result
end

function Attachment.IsCore(attachmentId: string): boolean
	local def = Attachment:Get(attachmentId)
	return def ~= nil and def.kind == "Core"
end

function Attachment.ValidateAll(): { string }
	local problems = Registry.Validate(Attachment)
	for _, def in Attachment:List() do
		if not table.find(Enums.AttachmentSlotOrder, def.slot) then
			table.insert(problems, string.format("[Attachment] %s uses unknown slot %q", def.id, tostring(def.slot)))
		end
		if def.kind == "Core" and not def.coreCategory then
			table.insert(problems, string.format("[Attachment] core %s has no coreCategory", def.id))
		end
		if def.kind == "Core" and def.coreCategory and not Enums.CoreCategory[def.coreCategory] then
			table.insert(problems, string.format("[Attachment] core %s has invalid category %s", def.id, tostring(def.coreCategory)))
		end
		if not def.tradeoff or def.tradeoff == "" then
			table.insert(problems, string.format("[Attachment] %s has no documented trade-off", def.id))
		end
	end
	return problems
end

Attachment.Registry = Attachment
return Attachment
