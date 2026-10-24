--!strict
--[[
	Runtime spec: the shared gameplay logic that the server services are built
	on - player profiles, inventories, the damage pipeline, status effects and
	resource node lifecycles.
]]

local Test = require("../harness/Harness")

local Enums = require("@shared/Constants/Enums")
local Limits = require("@shared/Constants/Limits")
local Profile = require("@shared/PlayerData/Profile")
local Inventory = require("@shared/Inventory/InventoryModel")
local Damage = require("@shared/Combat/DamagePipeline")
local Status = require("@shared/Combat/StatusEffects")
local ResourceState = require("@shared/Resources/ResourceState")
local Items = require("@shared/Config/ItemConfig")
local Ores = require("@shared/Config/OreConfig")

local systems: { { name: string, validate: () -> { string } } } = {
	{ name = "Profile", validate = function() return Profile.ValidateAll() end },
	{ name = "Inventory", validate = function() return Inventory.ValidateAll() end },
	{ name = "Damage", validate = function() return Damage.ValidateAll() end },
	{ name = "StatusEffects", validate = function() return Status.ValidateAll() end },
	{ name = "ResourceState", validate = function() return ResourceState.ValidateAll() end },
}

Test.describe("Shared runtime", function()
	for _, system in systems do
		Test.it(system.name .. " validates", function()
			Test.empty(system.validate(), system.name .. " ValidateAll")
		end)
	end
end)

Test.describe("Player profile", function()
	Test.it("a default profile is valid and empty", function()
		local data = Profile.Default(1, 0)
		Test.eq(data.level, 1, "starting level")
		Test.eq(data.sap, 0, "starting sap")
		Test.eq(data.userId, 1, "user id")
		Test.truthy(Profile.IsLoadoutValid(data), "default loadout invalid")
	end)

	Test.it("a hostile save cannot grant anything", function()
		local data = Profile.Sanitise({
			level = 999999,
			sap = -100,
			experience = {},
			inventory = { ["1"] = { id = "fake_item", quantity = -5 } },
			weapons = { ["fake_gun"] = { stars = 50 } },
			equipped = { primary = "fake_gun" },
		}, 99, 0)
		Test.eq(data.level, Limits.Progression.MaxPlayerLevel, "level clamp")
		Test.eq(data.sap, 0, "negative currency")
		Test.eq(data.experience, 0, "invalid experience")
		Test.eq(data.weapons["fake_gun"], nil, "unknown weapon")
		Test.eq(data.equipped.primary, nil, "unowned weapon equipped")
		Test.truthy(Profile.IsLoadoutValid(data), "sanitised loadout invalid")
	end)

	Test.it("migration stamps the current version", function()
		local data = Profile.Sanitise({ level = 3 }, 5, 0)
		Test.eq(data.version, Profile.Version, "version")
		Test.eq(data.level, 3, "level carried over")
	end)
end)

Test.describe("Inventory", function()
	Test.it("stacking, capacity and removal behave", function()
		Inventory.ResetUidCounter(0)
		local bag = Inventory.New(3)
		local limit = Inventory.StackLimit("stone_rubble")
		local result = Inventory.Add(bag, "stone_rubble", 20)
		Test.eq(result.leftover, 0, "stackable item should fit")
		Test.eq(Inventory.Count(bag), 1, "one slot used")
		Test.eq(Inventory.QuantityOf(bag, "stone_rubble"), 20, "quantity")
		Test.eq(Inventory.FreeSlots(bag), 2, "free slots")
		local tooMuch = Inventory.Add(bag, "stone_rubble", limit * 10)
		Test.gte(tooMuch.leftover, 1, "capacity must be respected")
		Test.eq(Inventory.QuantityOf(bag, "stone_rubble"), limit * 3, "filled every slot to the stack limit")
		Test.eq(Inventory.Remove(bag, "stone_rubble", 700), 700, "removal")
		Test.eq(Inventory.Fits(bag, "stone_rubble", 5), 5, "fits")
	end)

	Test.it("unknown items are rejected", function()
		local bag = Inventory.New(4)
		local result = Inventory.Add(bag, "definitely_not_an_item", 5)
		Test.eq(result.added, 0, "unknown item added")
		Test.eq(Inventory.Count(bag), 0, "bag should be empty")
	end)
end)

Test.describe("Damage pipeline", function()
	Test.it("basic hits, resistance and falloff", function()
		local plain = Damage.Resolve({ damage = 200 }, {}, {})
		Test.near(plain.damage, 200, 0.001, "plain hit")
		local resist = Damage.Resolve(
			{ damage = 200, damageType = Enums.DamageType.Fire },
			{ resistances = { [Enums.DamageType.Fire] = 0.25 } },
			{}
		)
		Test.near(resist.damage, 50, 0.001, "resisted hit")
		local weakPoint = Damage.Resolve({ damage = 200, weakPointMultiplier = 2 }, { weakPointMultiplier = 1 }, { isWeakPoint = true })
		Test.near(weakPoint.damage, 400, 0.001, "weak point hit")
		Test.truthy(weakPoint.isWeakPoint, "weak point flag")
	end)

	Test.it("invulnerability is absolute", function()
		local blocked = Damage.Resolve({ damage = 1000, damageType = Enums.DamageType.True }, { invulnerable = true }, {})
		Test.eq(blocked.damage, 0, "true damage bypassed invulnerability")
		local phase = Damage.ResolveAgainstBoss({ damage = 500 }, {}, { incomingDamageMultiplier = 1, defenseState = Enums.DefenseState.Invulnerable }, {})
		Test.eq(phase.damage, 0, "invulnerable boss phase took damage")
	end)

	Test.it("shields absorb before health", function()
		local hit = Damage.Resolve({ damage = 300 }, { shield = 120 }, {})
		Test.near(hit.shieldAbsorbed, 120, 0.001, "shield absorption")
		Test.near(hit.healthDamage, 180, 0.001, "health damage")
	end)

	Test.it("criticals need a random source and never apply to damage over time", function()
		local alwaysCrit = { Next = function()
			return 0
		end }
		local crit = Damage.Resolve({ damage = 100, critChance = 1, critMultiplier = 2 }, {}, {}, { Next = function()
			return 0
		end })
		Test.truthy(crit.isCrit, "critical did not fire")
		Test.near(crit.damage, 200, 0.001, "critical damage")
		local dot = Damage.Resolve(
			{ damage = 100, critChance = 1, critMultiplier = 2 },
			{},
			{ hitKind = Enums.HitKind.DamageOverTime },
			{ Next = function()
				return 0
			end }
		)
		Test.falsy(dot.isCrit, "damage over time should not crit")
		_ = alwaysCrit
	end)
end)

Test.describe("Status effects", function()
	Test.it("stacking rules are respected", function()
		local state = Status.New()
		Status.Apply(state, Enums.StatusEffect.Burn, 0)
		Status.Apply(state, Enums.StatusEffect.Burn, 0.5)
		Test.eq(Status.StacksOf(state, Enums.StatusEffect.Burn), 1, "refresh effect stacked")
		local corroded = Status.New()
		Status.Apply(corroded, Enums.StatusEffect.Corrosion, 0)
		Status.Apply(corroded, Enums.StatusEffect.Corrosion, 0)
		Test.eq(Status.StacksOf(corroded, Enums.StatusEffect.Corrosion), 2, "stacking effect did not stack")
	end)

	Test.it("effects expire and tick damage on their own cadence", function()
		local state = Status.New()
		Status.Apply(state, Enums.StatusEffect.Burn, 0)
		local early = Status.Tick(state, 0.4)
		Test.eq(#early.damage, 0, "ticked too early")
		local ticked = Status.Tick(state, 0.6)
		Test.eq(#ticked.damage, 1, "no damage tick")
		Test.gte(ticked.damage[1].amount, 1, "tick damage too small")
		local expired = Status.Tick(state, 1000)
		Test.eq(#expired.expired, 1, "effect did not expire")
		Test.falsy(Status.Has(state, Enums.StatusEffect.Burn), "effect still present after expiry")
	end)
end)

Test.describe("Resource nodes", function()
	Test.it("ordinary nodes respawn in exactly three minutes", function()
		local node = ResourceState.New("tree_softwood", "inst_1")
		local now = 500
		ResourceState.Deplete(node, now, function()
			return 0.5
		end, 0)
		Test.eq(ResourceState.RemainingSeconds(node, now), 180, "ordinary respawn time")
		Test.falsy(ResourceState.IsAvailable(node, now + 179), "available early")
		Test.truthy(ResourceState.IsAvailable(node, now + 180), "not available on time")
		local respawned = ResourceState.Update({ node }, now + 180)
		Test.eq(#respawned, 1, "respawn not reported")
		Test.eq(node.state, Enums.ResourceState.Available, "state after respawn")
	end)

	Test.it("a depleted node cannot be harvested twice", function()
		local node = ResourceState.New("ore_common", "inst_2")
		ResourceState.Deplete(node, 0, function()
			return 0.5
		end, 0)
		local again = ResourceState.TryHarvest(node, 10, 10, 1, function()
			return 0.5
		end, 0)
		Test.eq(again, nil, "double harvest allowed")
	end)

	Test.it("yields are always positive integer amounts of known items", function()
		for _ = 1, 25 do
			local node = ResourceState.New("ore_common", "inst_3")
			local outcome = ResourceState.TryHarvest(node, 0, 100, 1, function()
				return 0.5
			end, 0)
			Test.truthy(outcome, "harvest failed")
			if outcome then
				local any = false
				for itemId, quantity in outcome.yields do
					any = true
					Test.truthy(Items:Has(itemId) or Ores:Has(itemId), "unknown yield " .. tostring(itemId))
					Test.gte(quantity, 1, "non-positive yield")
					Test.eq(quantity, math.floor(quantity), "fractional yield")
				end
				Test.truthy(any, "no yields")
			end
		end
	end)
end)

Test.Finish()

return true
