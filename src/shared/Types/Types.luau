--!strict
--[[
	Types.luau
	Shared structural types used by both the client and the server.

	These are Luau type declarations only; they cost nothing at runtime and
	are consumed by the static checker (see tools/typecheck.py) and by
	Roblox Studio's Luau language server.
]]

export type Rank = "C" | "B" | "A" | "S" | "SS" | "X"
export type Tier = number
export type Rarity =
	"Common"
	| "Rare"
	| "Epic"
	| "Legendary"
	| "Mythical"
	| "Prismatic"
	| "Unknown"
export type Element = "Forest" | "Fire" | "Ice" | "Dark" | "Light" | "Water" | "Void"
export type RegionId =
	"VerdantReach"
	| "Cinderfall"
	| "Frostveil"
	| "UmbraExpanse"
	| "SolaraBasin"
	| "PelagicFrontier"
	| "NullHorizon"
export type DamageType =
	"Physical"
	| "Energy"
	| "Fire"
	| "Ice"
	| "Dark"
	| "Light"
	| "Water"
	| "Void"
	| "Sonic"
	| "Bio"
	| "Explosive"
	| "True"
export type HitKind =
	"Direct" | "WeakPoint" | "Area" | "DamageOverTime" | "Environmental" | "Ultimate"
export type DefenseState =
	"Normal"
	| "Armored"
	| "Shielded"
	| "Invulnerable"
	| "Vulnerable"
	| "Cocooned"
	| "Phased"
export type ItemType =
	"Weapon"
	| "MeleeWeapon"
	| "Attachment"
	| "Gadget"
	| "Consumable"
	| "Material"
	| "Ore"
	| "BeastCore"
	| "Sap"
	| "CompanionEgg"
	| "ResearchItem"
	| "Blueprint"
	| "QuestItem"
	| "Cosmetic"
	| "Module"
	| "Food"
	| "Water"
	| "Equipment"
	| "Boat"

-- A persisted stack of a single item.
export type ItemStack = {
	itemId: string,
	quantity: number,
	-- Per-instance data (weapon instance id, egg genes, core roll ...)
	instanceId: string?,
	data: { [string]: any }?,
}

-- Weapon instance as stored in a player profile.
export type WeaponInstance = {
	instanceId: string,
	weaponId: string,
	rarity: Rarity,
	stars: number,
	level: number,
	experience: number,
	attachments: { [string]: string? },
	modules: { [string]: string? },
	coreId: string?,
	skinId: string?,
	evolvedFrom: string?,
	stats: { [string]: number }?,
}

export type CompanionInstance = {
	instanceId: string,
	speciesId: string,
	level: number,
	experience: number,
	role: "Combat" | "Exploration" | "Support",
	state: "Egg" | "Hatching" | "Active" | "Stowed" | "Dismissed",
	nickname: string?,
	form: string?,
	genes: { [string]: number }?,
	hatchTime: number?,
}

export type Loadout = {
	weaponInstanceIds: { string },
	meleeInstanceId: string?,
	abilityIds: { string },
	gadgetIds: { string },
	consumables: { [string]: number },
	activeCompanionIds: { string },
	movementSkills: { string },
}

export type PlayerProfile = {
	schemaVersion: number,
	userId: number,
	level: number,
	experience: number,
	currency: { [string]: number },
	inventory: { [string]: ItemStack },
	weapons: { [string]: WeaponInstance },
	companions: { [string]: CompanionInstance },
	loadout: Loadout,
	unlocks: {
		weapons: { [string]: boolean },
		abilities: { [string]: { rank: Rank, tier: Tier } },
		gadgets: { [string]: boolean },
		recipes: { [string]: boolean },
		movementSkills: { [string]: boolean },
		regions: { [string]: boolean },
		cosmetics: { [string]: boolean },
	},
	progression: {
		research: { [string]: number },
		missions: { [string]: { state: string, objectives: { [string]: number } } },
		discoveries: { [string]: boolean },
		bossRecords: { [string]: { kills: number, bestTimeSeconds: number?, lastRewardAt: number? } },
		dungeons: { [string]: { completions: number, bestRank: string?, lastCompletedAt: number? } },
	},
	clanId: string?,
	settings: { [string]: any },
	hudLayouts: { [string]: any }?,
	stats: { [string]: number },
	createdAt: number,
	updatedAt: number,
}

-- Damage request flowing through the authoritative pipeline.
export type DamageRequest = {
	sourceUserId: number?,
	sourceKind: "Player" | "Beast" | "Boss" | "Environment" | "Gadget" | "Ability",
	sourceInstanceId: string?,
	weaponId: string?,
	targetKind: "Player" | "Beast" | "Boss" | "Resource" | "Structure",
	targetId: string,
	targetPart: any?,
	amount: number,
	damageType: DamageType,
	hitKind: HitKind,
	hitPosition: Vector3?,
	-- Client provided values are advisory only and are re-validated.
	clientPosition: Vector3?,
	clientDistance: number?,
	timestamp: number?,
	isUltimate: boolean?,
	ignoreArmor: boolean?,
	metadata: { [string]: any }?,
}

export type DamageResult = {
	applied: number,
	absorbed: number,
	killed: boolean,
	blocked: boolean,
	reason: string?,
	defenseState: DefenseState?,
	weakPointHit: boolean,
	shieldBroken: boolean,
	statusEffects: { string }?,
}

export type StatusEffectInstance = {
	id: string,
	kind: string,
	remaining: number,
	duration: number,
	magnitude: number,
	sourceUserId: number?,
	stacks: number,
	tickInterval: number?,
	lastTick: number?,
}

export type RemoteDefinition = {
	name: string,
	kind: "Event" | "Function",
	-- Argument validators applied on the server before any handler runs.
	args: { [string]: any }?,
	rateLimit: number?,
	-- Minimum admin level required, if any.
	adminLevel: number?,
	description: string?,
}

export type RewardGrant = {
	itemId: string?,
	quantity: number?,
	weaponId: string?,
	rarity: Rarity?,
	companionEggSpeciesId: string?,
	currency: string?,
	amount: number?,
	chance: number?,
}

export type RewardTable = {
	id: string,
	grants: { RewardGrant },
	minQuantity: number?,
	maxQuantity: number?,
}

return {}
