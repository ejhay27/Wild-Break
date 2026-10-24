--!strict
--[[
	Enums.luau
	Stable gameplay enumerations for WILDBREAK.

	These are plain tables (not Roblox `Enum` items) so that:
	  * they can be used by pure-logic modules and by the offline test harness,
	  * they remain stable across sessions and can be persisted safely,
	  * every gameplay branch reads from one place instead of magic strings.
]]

local Enums = {}

-- ---------------------------------------------------------------------------
-- Classification
-- ---------------------------------------------------------------------------

Enums.Rank = {
	C = "C",
	B = "B",
	A = "A",
	S = "S",
	SS = "SS",
	X = "X",
}
Enums.RankOrder = { "C", "B", "A", "S", "SS", "X" }
Enums.TierOrder = { 1, 2, 3, 4, 5 }
Enums.MinTier = 1
Enums.MaxTier = 5

function Enums.IsValidRank(rank: any): boolean
	for _, value in Enums.RankOrder do
		if value == rank then
			return true
		end
	end
	return false
end

function Enums.IsValidTier(tier: any): boolean
	return type(tier) == "number" and tier >= Enums.MinTier and tier <= Enums.MaxTier and tier % 1 == 0
end

function Enums.RankIndex(rank: string): number
	for index, value in Enums.RankOrder do
		if value == rank then
			return index
		end
	end
	return 0
end

-- ---------------------------------------------------------------------------
-- Rarity
-- ---------------------------------------------------------------------------

Enums.Rarity = {
	Common = "Common",
	Rare = "Rare",
	Epic = "Epic",
	Legendary = "Legendary",
	Mythical = "Mythical",
	Prismatic = "Prismatic",
	Unknown = "Unknown",
}
Enums.RarityOrder = {
	"Common",
	"Rare",
	"Epic",
	"Legendary",
	"Mythical",
	"Prismatic",
	"Unknown",
}

function Enums.IsValidRarity(rarity: any): boolean
	for _, value in Enums.RarityOrder do
		if value == rarity then
			return true
		end
	end
	return false
end

function Enums.RarityIndex(rarity: string): number
	for index, value in Enums.RarityOrder do
		if value == rarity then
			return index
		end
	end
	return 0
end

-- ---------------------------------------------------------------------------
-- Elements / regions
-- ---------------------------------------------------------------------------

Enums.Element = {
	Forest = "Forest",
	Fire = "Fire",
	Ice = "Ice",
	Dark = "Dark",
	Light = "Light",
	Water = "Water",
	Void = "Void",
}

Enums.RegionId = {
	VerdantReach = "VerdantReach",
	Cinderfall = "Cinderfall",
	Frostveil = "Frostveil",
	UmbraExpanse = "UmbraExpanse",
	SolaraBasin = "SolaraBasin",
	PelagicFrontier = "PelagicFrontier",
	NullHorizon = "NullHorizon",
}

Enums.RegionOrder = {
	"VerdantReach",
	"Cinderfall",
	"Frostveil",
	"UmbraExpanse",
	"SolaraBasin",
	"PelagicFrontier",
	"NullHorizon",
}

-- ---------------------------------------------------------------------------
-- Combat
-- ---------------------------------------------------------------------------

Enums.WeaponClass = {
	AssaultRifle = "AssaultRifle",
	SubmachineGun = "SubmachineGun",
	Shotgun = "Shotgun",
	SniperRifle = "SniperRifle",
	DMR = "DMR",
	LMG = "LMG",
	Pistol = "Pistol",
	Special = "Special",
}

Enums.WeaponKind = {
	Firearm = "Firearm",
	Melee = "Melee",
}

Enums.FireMode = {
	Auto = "Auto",
	Burst = "Burst",
	Semi = "Semi",
	Bolt = "Bolt",
	Charge = "Charge",
	Beam = "Beam",
}

Enums.ProjectileKind = {
	Hitscan = "Hitscan",
	Projectile = "Projectile",
	Beam = "Beam",
	HitscanChain = "HitscanChain",
}

Enums.DamageType = {
	Physical = "Physical",
	Energy = "Energy",
	Fire = "Fire",
	Ice = "Ice",
	Dark = "Dark",
	Light = "Light",
	Water = "Water",
	Void = "Void",
	Sonic = "Sonic",
	Bio = "Bio",
	Explosive = "Explosive",
	True = "True",
}

Enums.HitKind = {
	Direct = "Direct",
	WeakPoint = "WeakPoint",
	Area = "Area",
	DamageOverTime = "DamageOverTime",
	Environmental = "Environmental",
	Ultimate = "Ultimate",
}

Enums.DefenseState = {
	Normal = "Normal",
	Armored = "Armored",
	Shielded = "Shielded",
	Invulnerable = "Invulnerable",
	Vulnerable = "Vulnerable",
	Cocooned = "Cocooned",
	Phased = "Phased",
}

Enums.StatusEffect = {
	Burn = "Burn",
	Chill = "Chill",
	Shock = "Shock",
	Corrosion = "Corrosion",
	Marked = "Marked",
	Slowed = "Slowed",
	Rooted = "Rooted",
	Stunned = "Stunned",
	Staggered = "Staggered",
	Weakened = "Weakened",
	Shielded = "Shielded",
	Regeneration = "Regeneration",
	Hastened = "Hastened",
	VoidInstability = "VoidInstability",
	Heatstroke = "Heatstroke",
	Frostbite = "Frostbite",
	Contamination = "Contamination",
	Irradiated = "Irradiated",
	Drenched = "Drenched",
}

Enums.CombatState = {
	Idle = "Idle",
	Firing = "Firing",
	Reloading = "Reloading",
	Switching = "Switching",
	MeleeAttack = "MeleeAttack",
	Ability = "Ability",
	Ultimate = "Ultimate",
	Gadget = "Gadget",
	Stunned = "Stunned",
	Staggered = "Staggered",
	Dodging = "Dodging",
	Sliding = "Sliding",
	Gliding = "Gliding",
	Swimming = "Swimming",
	Dead = "Dead",
	Interacting = "Interacting",
	Menu = "Menu",
}

-- ---------------------------------------------------------------------------
-- Abilities / gadgets / ultimates
-- ---------------------------------------------------------------------------

Enums.AbilitySlotCount = 4
Enums.AbilitySlot = { Slot1 = 1, Slot2 = 2, Slot3 = 3, Slot4 = 4 }

Enums.AbilityTargetKind = {
	Self = "Self",
	Point = "Point",
	Target = "Target",
	Aura = "Aura",
	Projectile = "Projectile",
}

Enums.GadgetKind = {
	Deployable = "Deployable",
	Throwable = "Throwable",
	Consumable = "Consumable",
	Traversal = "Traversal",
}

Enums.UltimateChargeSource = {
	DamageDealt = "DamageDealt",
	WeakPointHit = "WeakPointHit",
	Kill = "Kill",
	ObjectiveParticipation = "ObjectiveParticipation",
	DamageTaken = "DamageTaken",
	Assist = "Assist",
	TimeInCombat = "TimeInCombat",
}

Enums.UltimateState = {
	Charging = "Charging",
	Ready = "Ready",
	Active = "Active",
	Cooldown = "Cooldown",
	Locked = "Locked",
}

-- ---------------------------------------------------------------------------
-- Beasts / bosses
-- ---------------------------------------------------------------------------

Enums.BeastArchetype = {
	Stalker = "Stalker",
	Brute = "Brute",
	Spitter = "Spitter",
	Apex = "Apex",
	Flyer = "Flyer",
	Aquatic = "Aquatic",
	Burrower = "Burrower",
	PackHunter = "PackHunter",
	Corrupted = "Corrupted",
	Elite = "Elite",
	Machine = "Machine",
}

Enums.BehaviourState = {
	Idle = "Idle",
	Patrol = "Patrol",
	Investigate = "Investigate",
	Chase = "Chase",
	Attack = "Attack",
	Flee = "Flee",
	Stagger = "Stagger",
	Dead = "Dead",
	Dormant = "Dormant",
}

Enums.BossKind = {
	WorldBoss = "WorldBoss",
	DungeonBoss = "DungeonBoss",
	WorldDungeonBoss = "WorldDungeonBoss",
}

Enums.BossState = {
	Dormant = "Dormant",
	Spawning = "Spawning",
	Intro = "Intro",
	Active = "Active",
	PhaseTransition = "PhaseTransition",
	Vulnerable = "Vulnerable",
	Cocoon = "Cocoon",
	Transforming = "Transforming",
	FinalDetonation = "FinalDetonation",
	Defeated = "Defeated",
	Cleanup = "Cleanup",
	Respawning = "Respawning",
}

Enums.EncounterResult = {
	Defeat = "Defeat",
	Victory = "Victory",
	Expired = "Expired",
	Aborted = "Aborted",
}

-- ---------------------------------------------------------------------------
-- Items / inventory
-- ---------------------------------------------------------------------------

Enums.ItemType = {
	Weapon = "Weapon",
	MeleeWeapon = "MeleeWeapon",
	Attachment = "Attachment",
	Gadget = "Gadget",
	Consumable = "Consumable",
	Material = "Material",
	BossMaterial = "BossMaterial",
	Ore = "Ore",
	BeastCore = "BeastCore",
	Sap = "Sap",
	CompanionEgg = "CompanionEgg",
	ResearchItem = "ResearchItem",
	Blueprint = "Blueprint",
	QuestItem = "QuestItem",
	Cosmetic = "Cosmetic",
	Module = "Module",
	Food = "Food",
	Water = "Water",
	Equipment = "Equipment",
	Boat = "Boat",
}

Enums.AttachmentSlot = {
	Optic = "Optic",
	Muzzle = "Muzzle",
	Barrel = "Barrel",
	Grip = "Grip",
	Magazine = "Magazine",
	Stock = "Stock",
	Ammo = "Ammo",
	Module = "Module",
}

Enums.AttachmentSlotOrder = {
	"Optic",
	"Muzzle",
	"Barrel",
	"Grip",
	"Magazine",
	"Stock",
	"Ammo",
	"Module",
}

Enums.CoreCategory = {
	Wild = "Wild",
	Resonance = "Resonance",
	Apex = "Apex",
	Anomaly = "Anomaly",
}

-- ---------------------------------------------------------------------------
-- Resources
-- ---------------------------------------------------------------------------

Enums.ResourceKind = {
	Timber = "Timber",
	Stone = "Stone",
	Ore = "Ore",
	Plant = "Plant",
	Fiber = "Fiber",
	Mushroom = "Mushroom",
	Animal = "Animal",
	Crystal = "Crystal",
	RegionalMineral = "RegionalMineral",
	Aquatic = "Aquatic",
	ResearchSample = "ResearchSample",
	Cache = "Cache",
	BeastMaterial = "BeastMaterial",
	BossMaterial = "BossMaterial",
	Energy = "Energy",
	Sap = "Sap",
}

Enums.ResourceState = {
	Available = "Available",
	BeingHarvested = "BeingHarvested",
	Depleted = "Depleted",
}

Enums.ToolRequirement = {
	None = "None",
	Axe = "Axe",
	Pickaxe = "Pickaxe",
	Harvester = "Harvester",
	Extractor = "Extractor",
	DivingGear = "DivingGear",
	Scanner = "Scanner",
	Any = "Any",
}

-- ---------------------------------------------------------------------------
-- Survival
-- ---------------------------------------------------------------------------

Enums.HazardType = {
	Heat = "Heat",
	Cold = "Cold",
	Contamination = "Contamination",
	Storm = "Storm",
	Terrain = "Terrain",
	UnderwaterPressure = "UnderwaterPressure",
	VoidAnomaly = "VoidAnomaly",
	Volcanic = "Volcanic",
	Fall = "Fall",
	Drowning = "Drowning",
}

Enums.SurvivalStat = {
	Health = "Health",
	Stamina = "Stamina",
	Hunger = "Hunger",
	Thirst = "Thirst",
	Oxygen = "Oxygen",
	Temperature = "Temperature",
	Shield = "Shield",
}

-- ---------------------------------------------------------------------------
-- Companions
-- ---------------------------------------------------------------------------

Enums.CompanionRole = {
	Combat = "Combat",
	Exploration = "Exploration",
	Support = "Support",
}

Enums.CompanionState = {
	Egg = "Egg",
	Hatching = "Hatching",
	Active = "Active",
	Stowed = "Stowed",
	Dismissed = "Dismissed",
}

Enums.CompanionCommand = {
	Follow = "Follow",
	Hold = "Hold",
	Attack = "Attack",
	Defend = "Defend",
	Scout = "Scout",
	Dismiss = "Dismiss",
}

-- ---------------------------------------------------------------------------
-- Multiplayer / clans
-- ---------------------------------------------------------------------------

Enums.SquadState = {
	None = "None",
	Forming = "Forming",
	Deploying = "Deploying",
	InActivity = "InActivity",
}

Enums.ClanRole = {
	Owner = "Owner",
	Officer = "Officer",
	Member = "Member",
	Recruit = "Recruit",
}
Enums.ClanRoleOrder = { "Owner", "Officer", "Member", "Recruit" }
Enums.ClanRoleRank = { Owner = 4, Officer = 3, Member = 2, Recruit = 1 }

Enums.ClanWarMode = {
	OutpostAssault = "OutpostAssault",
	CoreControl = "CoreControl",
	BeastfrontWar = "BeastfrontWar",
}

Enums.ClanWarState = {
	Queueing = "Queueing",
	Starting = "Starting",
	Active = "Active",
	Ending = "Ending",
	Finished = "Finished",
	Aborted = "Aborted",
}

-- ---------------------------------------------------------------------------
-- World events / dungeons
-- ---------------------------------------------------------------------------

Enums.WorldEventState = {
	Inactive = "Inactive",
	Announced = "Announced",
	Active = "Active",
	Completing = "Completing",
	Cooldown = "Cooldown",
}

Enums.DungeonFormat = {
	OpenWorldFacility = "OpenWorldFacility",
	MajorOperation = "MajorOperation",
}

Enums.DungeonState = {
	Idle = "Idle",
	Running = "Running",
	Completed = "Completed",
	Failed = "Failed",
	Resetting = "Resetting",
}

-- ---------------------------------------------------------------------------
-- Platform / settings / admin
-- ---------------------------------------------------------------------------

Enums.InputDevice = {
	PC = "PC",
	Mobile = "Mobile",
	Console = "Console",
}

Enums.GraphicsPreset = {
	Auto = "Auto",
	VeryLow = "VeryLow",
	Low = "Low",
	Medium = "Medium",
	High = "High",
	Ultra = "Ultra",
}
Enums.GraphicsPresetOrder = { "Auto", "VeryLow", "Low", "Medium", "High", "Ultra" }

Enums.AudioCategory = {
	Master = "Master",
	Music = "Music",
	SFX = "SFX",
	Environment = "Environment",
	UI = "UI",
	Dialogue = "Dialogue",
}
Enums.AudioCategoryOrder = { "Master", "Music", "SFX", "Environment", "UI", "Dialogue" }

Enums.AdminLevel = {
	None = 0,
	Tester = 1,
	Owner = 2,
}

Enums.AuditResult = {
	Success = "Success",
	Denied = "Denied",
	Failure = "Failure",
}

Enums.DeploymentMode = {
	QuickDrop = "QuickDrop",
	Tactical = "Tactical",
}

Enums.MovementSkill = {
	Sprint = "Sprint",
	Slide = "Slide",
	Dodge = "Dodge",
	DoubleJump = "DoubleJump",
	Glide = "Glide",
	AerialDash = "AerialDash",
	Grapple = "Grapple",
	GrappleLaunch = "GrappleLaunch",
	PhaseBlink = "PhaseBlink",
}

Enums.DeployPhase = {
	Idle = "Idle",
	Launching = "Launching",
	Gliding = "Gliding",
	Landing = "Landing",
	Complete = "Complete",
}

return Enums
