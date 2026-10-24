--!strict
--[[
	Configuration registry spec.
	Runs every ValidateAll() in src/shared/Config and asserts the core content
	counts the design calls for (40 firearms, 10 melee, 12 abilities, 12 gadgets,
	7 world bosses, 7 dungeon bosses, 7 regions, 8 dungeons, ordinary resources
	respawning in exactly 3 minutes).
]]

local Test = require("../harness/Harness")

local Enums = require("@shared/Constants/Enums")
local Limits = require("@shared/Constants/Limits")
local Rarity = require("@shared/Config/RarityConfig")
local Ores = require("@shared/Config/OreConfig")
local Weapons = require("@shared/Config/WeaponConfig")
local Attachments = require("@shared/Config/AttachmentConfig")
local Abilities = require("@shared/Config/AbilityConfig")
local Gadgets = require("@shared/Config/GadgetConfig")
local Items = require("@shared/Config/ItemConfig")
local Resources = require("@shared/Config/ResourceConfig")
local Crafting = require("@shared/Config/CraftingConfig")
local Bosses = require("@shared/Config/BossConfig")
local Loot = require("@shared/Config/LootConfig")
local Beasts = require("@shared/Config/BeastConfig")
local Regions = require("@shared/Config/RegionConfig")
local Dungeons = require("@shared/Config/DungeonConfig")
local Companions = require("@shared/Config/CompanionConfig")
local Events = require("@shared/Config/WorldEventConfig")
local Hazards = require("@shared/Config/HazardConfig")
local Audio = require("@shared/Config/AudioConfig")
local Progression = require("@shared/Config/ProgressionConfig")
local Movement = require("@shared/Config/MovementConfig")
local Graphics = require("@shared/Config/GraphicsConfig")
local Settings = require("@shared/Config/SettingsConfig")
local Deployment = require("@shared/Config/DeploymentConfig")
local Clan = require("@shared/Config/ClanConfig")
local Trading = require("@shared/Config/TradingConfig")
local Boat = require("@shared/Config/BoatConfig")
local Admin = require("@shared/Config/AdminConfig")

Test.describe("ValidateAll", function()
	local registries: { { name: string, validate: () -> { string }, count: () -> number } } = {
		{ name = "Rarity", validate = function() return Rarity.ValidateAll() end, count = function() return Rarity:Count() end },
		{ name = "Ore", validate = function() return Ores.ValidateAll() end, count = function() return Ores:Count() end },
		{ name = "Weapon", validate = function() return Weapons.ValidateAll() end, count = function() return Weapons:Count() end },
		{ name = "Attachment", validate = function() return Attachments.ValidateAll() end, count = function() return Attachments:Count() end },
		{ name = "Ability", validate = function() return Abilities.ValidateAll() end, count = function() return Abilities:Count() end },
		{ name = "Gadget", validate = function() return Gadgets.ValidateAll() end, count = function() return Gadgets:Count() end },
		{ name = "Item", validate = function() return Items.ValidateAll() end, count = function() return Items:Count() end },
		{ name = "Resource", validate = function() return Resources.ValidateAll() end, count = function() return Resources:Count() end },
		{ name = "Crafting", validate = function() return Crafting.ValidateAll() end, count = function() return Crafting:Count() end },
		{ name = "Boss", validate = function() return Bosses.ValidateAll() end, count = function() return Bosses:Count() end },
		{ name = "Loot", validate = function() return Loot.ValidateAll() end, count = function() return Loot:Count() end },
		{ name = "Beast", validate = function() return Beasts.ValidateAll() end, count = function() return Beasts:Count() end },
		{ name = "Region", validate = function() return Regions.ValidateAll() end, count = function() return Regions:Count() end },
		{ name = "Dungeon", validate = function() return Dungeons.ValidateAll() end, count = function() return Dungeons:Count() end },
		{ name = "Companion", validate = function() return Companions.ValidateAll() end, count = function() return Companions:Count() end },
		{ name = "WorldEvent", validate = function() return Events.ValidateAll() end, count = function() return Events:Count() end },
		{ name = "Hazard", validate = function() return Hazards.ValidateAll() end, count = function() return Hazards:Count() end },
	}
	for _, entry in registries do
		Test.it(entry.name .. " registry validates", function()
			Test.gte(entry.count(), 1, entry.name .. " is empty")
			Test.empty(entry.validate(), entry.name .. " ValidateAll")
		end)
	end
end)

Test.describe("Loadout content", function()
	Test.it("40 firearms", function()
		Test.eq(#Weapons.Firearms(), 40, "firearm count")
	end)
	Test.it("10 melee weapons", function()
		Test.eq(#Weapons.Melee(), 10, "melee count")
	end)
	Test.it("every firearm has a unique ultimate", function()
		local seen = {}
		for _, weapon in Weapons.Firearms() do
			local ultimate = Weapons.Ultimate(weapon.id)
			Test.truthy(ultimate, weapon.id .. " has no ultimate")
			Test.falsy(seen[ultimate :: any ~= nil and (ultimate :: any).id or ""], "duplicate ultimate id")
			if ultimate then
				seen[ultimate.id] = true
				Test.eq(ultimate.weaponId, weapon.id, "ultimate/weapon mismatch")
			end
		end
		Test.eq(next(seen) ~= nil, true, "no ultimates registered")
	end)
	Test.it("12 abilities and 12 gadgets", function()
		Test.eq(#Abilities:List(), 12, "ability count")
		Test.eq(#Gadgets:List(), 12, "gadget count")
	end)
	Test.it("ability tiers never change rank classification", function()
		for _, ability in Abilities:List() do
			Test.eq(ability.rank, Abilities:Get(ability.id).rank, "rank mutated by tier data")
			Test.eq(#ability.tiers, 5, ability.id .. " tier count")
		end
	end)
	Test.it("rarity multipliers increase with stars", function()
		local previous = 0
		for _, rarity in ipairs(Enums.RarityOrder) do
			if rarity == Enums.Rarity.Unknown then
				-- Unknown weapons intentionally ignore the star curve.
				continue
			end
			local value = Rarity.StatMultiplier(rarity, 0)
			Test.gte(value, previous, "rarity multiplier ordering")
			previous = value
		end
	end)
end)

Test.describe("World content", function()
	Test.it("7 world bosses and 7 dungeon bosses", function()
		Test.eq(#Bosses.WorldBosses(), 7, "world boss count")
		Test.eq(#Bosses.DungeonBosses(), 7, "dungeon boss count")
	end)
	Test.it("every region has a world boss", function()
		for _, regionId in ipairs(Enums.RegionOrder) do
			local worldBoss = Bosses.WorldBossForRegion(regionId)
			Test.truthy(worldBoss, "no world boss for " .. tostring(regionId))
		end
	end)
	Test.it("7 regions plus the Haven Overlook hub", function()
		Test.eq(#Regions.Wilderness(), 7, "region count")
		Test.truthy(Regions:Get(Regions.HubId), "hub missing")
		Test.truthy(Regions.IsHub(Regions.HubId), "hub not flagged")
	end)
	Test.it("8 dungeons including ROOTFALL", function()
		Test.eq(#Dungeons:List(), 8, "dungeon count")
		Test.truthy(Dungeons:Get("dungeon_rootfall"), "ROOTFALL missing")
		Test.eq(#Dungeons:Get("dungeon_rootfall").stages, 5, "ROOTFALL stage count")
	end)
	Test.it("taming is disabled inside dungeons", function()
		for _, dungeon in Dungeons:List() do
			Test.falsy(dungeon.allowsTaming, dungeon.id .. " allows taming")
			Test.falsy(Dungeons.AllowsTaming(dungeon.id), dungeon.id .. " AllowsTaming() true")
			Test.eq(dungeon.maxActiveCompanions, Limits.Companion.MaxActiveDungeon, dungeon.id .. " companion cap")
		end
	end)
	Test.it("ordinary resources respawn in exactly 180 seconds", function()
		for _, node in Resources:List() do
			if node.respawnClass == "Ordinary" then
				Test.eq(node.respawnSeconds, 180, node.id .. " ordinary respawn")
				Test.eq(node.respawnSeconds, Limits.Resource.OrdinaryRespawnSeconds, node.id .. " drifted from Limits")
			end
		end
	end)
end)

Test.describe("Boss safety invariants", function()
	Test.it("Parallax is always damageable", function()
		local parallax = Bosses:Get("parallax")
		Test.truthy(parallax, "parallax missing")
		Test.truthy(Bosses.IsAlwaysDamageable("parallax"), "parallax not always damageable")
		for index, phase in parallax.phases do
			Test.neq(
				phase.defenseState,
				Enums.DefenseState.Invulnerable,
				"parallax phase " .. index .. " is invulnerable"
			)
			local mult = Bosses.DamageMultiplier("parallax", index, "Physical", false)
			Test.gte(mult, 0.01, "parallax phase " .. index .. " takes no damage")
		end
	end)
	Test.it("Light Samurai has 4 stages and ends in a detonation", function()
		local boss = Bosses:Get("light_samurai")
		Test.eq(#boss.phases, 4, "stage count")
		Test.eq(boss.phases[4].defenseState, Enums.DefenseState.Invulnerable, "final stage not invulnerable")
		Test.truthy(boss.special and boss.special.survivorsAutoDefeatBoss, "missing survivorsAutoDefeatBoss")
	end)
	Test.it("Pyraxis cocoon shield is 5x baseline", function()
		local boss = Bosses:Get("pyraxis")
		Test.truthy(boss, "pyraxis missing")
		Test.truthy(boss.special, "pyraxis has no special block")
		Test.eq(boss.special.type, "PyraxisCocoon", "pyraxis special type")
		Test.near(
			boss.special.cocoonShieldCapacity,
			boss.special.baselineShieldCapacity * boss.special.cocoonShieldMultiplier,
			0.001,
			"cocoon shield capacity"
		)
		Test.near(boss.special.cocoonShieldMultiplier, 5, 0.001, "cocoon shield multiplier")
		Test.gte(Bosses.ShieldCapacity("pyraxis", 2), 1, "cocoon phase has no shield capacity")
	end)
end)

Test.describe("System configuration", function()
	local systems: { { name: string, validate: () -> { string } } } = {
		{ name = "Progression", validate = function() return Progression.ValidateAll() end },
		{ name = "Movement", validate = function() return Movement.ValidateAll() end },
		{ name = "Graphics", validate = function() return Graphics.ValidateAll() end },
		{ name = "Settings", validate = function() return Settings.ValidateAll() end },
		{ name = "Deployment", validate = function() return Deployment.ValidateAll() end },
		{ name = "Clan", validate = function() return Clan.ValidateAll() end },
		{ name = "Trading", validate = function() return Trading.ValidateAll() end },
		{ name = "Boat", validate = function() return Boat.ValidateAll() end },
		{ name = "Admin", validate = function() return Admin.ValidateAll() end },
	}
	for _, system in systems do
		Test.it(system.name .. " configuration validates", function()
			Test.empty(system.validate(), system.name .. " ValidateAll")
		end)
	end

	Test.it("the experience curve is monotonic and reachable", function()
		local previous = 0
		for level = 1, Limits.Progression.MaxPlayerLevel do
			local needed = Progression.ExperienceForLevel(level)
			Test.gte(needed, previous, "experience curve")
			previous = needed
		end
		local check = Progression.LevelFromExperience(Progression.CumulativeExperience(60))
		Test.eq(check.level, 60, "cumulative experience resolves to the right level")
	end)

	Test.it("movement is server validated and the glide cannot cancel death", function()
		Test.truthy(Movement.Get("glide"), "the Quick Drop glide is missing")
		Test.eq(Movement.Glide.endsOnGroundContact, true, "the glide must end on ground contact")
		Test.eq(Movement.FallDamageFor(10000, 100, false) <= 100, true, "fall damage must be clamped")
		Test.falsy(Movement.IsPlausibleMove(100000, 1), "impossible movement was accepted")
		Test.truthy(Movement.IsPlausibleMove(20, 1), "normal movement was rejected")
	end)

	Test.it("every region has landing zones and respawn returns to the hub", function()
		for _, regionId in ipairs(Enums.RegionOrder) do
			Test.gte(#Deployment.ZonesForRegion(regionId), 1, "no landing zone for " .. tostring(regionId))
		end
		Test.eq(Deployment.Respawn.returnToHub, true, "respawn must return to the hub")
		Test.eq(Deployment.Respawn.hubId, Regions.HubId, "respawn hub mismatch")
	end)

	Test.it("graphics presets cover Auto through Ultra", function()
		for _, preset in ipairs(Enums.GraphicsPresetOrder) do
			Test.truthy(Graphics.Get(preset), "missing preset " .. preset)
		end
		Test.eq(Graphics.AutoStep("Medium", 20), "Low", "auto did not drop quality")
		Test.eq(Graphics.AutoStep("Medium", 120), "High", "auto did not raise quality")
	end)

	Test.it("the admin panel stays disabled until owner ids are supplied", function()
		Test.eq(#Admin.OwnerUserIds, 0, "owner ids were invented")
		Test.eq(Admin.PanelEnabled, false, "the panel must stay disabled without owner ids")
		Test.falsy(Admin.Can(12345, "ban_player"), "an arbitrary user id had authority")
		Test.falsy(Admin.Can(1, "view_status"), "an arbitrary user id had authority")
		Test.truthy(Admin.Audit.appendOnly, "the audit log must be append-only")
	end)
end)

Test.describe("Audio manifest", function()
	Test.it("every sound key is declared and placeholder-tracked", function()
		Test.gte(Audio.Count(), 100, "audio map too small")
		Test.eq(#Audio.MissingAssets(), Audio.Count(), "some sounds claim assets that were never imported")
	end)
	Test.it("boss signature attacks are mapped", function()
		for _, boss in Bosses:List() do
			Test.truthy(Audio.Has(boss.audio.intro), boss.id .. " intro unmapped")
			Test.truthy(Audio.Has(boss.audio.phase), boss.id .. " phase unmapped")
			Test.truthy(Audio.Has(boss.audio.death), boss.id .. " death unmapped")
		end
	end)
end)

Test.Finish()

return true
