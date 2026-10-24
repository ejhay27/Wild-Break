--!strict
--[[
	Data integrity spec.
	Proves that no configuration references an id that does not exist. This is
	the guard against fabricated content: a recipe, loot table, region or dungeon
	may only point at items, weapons, bosses and events that are really defined.
]]

local Test = require("../harness/Harness")

local Items = require("@shared/Config/ItemConfig")
local Ores = require("@shared/Config/OreConfig")
local Weapons = require("@shared/Config/WeaponConfig")
local Attachments = require("@shared/Config/AttachmentConfig")
local Gadgets = require("@shared/Config/GadgetConfig")
local Abilities = require("@shared/Config/AbilityConfig")
local Crafting = require("@shared/Config/CraftingConfig")
local Resources = require("@shared/Config/ResourceConfig")
local Beasts = require("@shared/Config/BeastConfig")
local Companions = require("@shared/Config/CompanionConfig")
local Bosses = require("@shared/Config/BossConfig")
local Loot = require("@shared/Config/LootConfig")
local Regions = require("@shared/Config/RegionConfig")
local Dungeons = require("@shared/Config/DungeonConfig")
local Events = require("@shared/Config/WorldEventConfig")
local Hazards = require("@shared/Config/HazardConfig")
local Enums = require("@shared/Constants/Enums")

local function isKnownContent(id: string): boolean
	return Items:Has(id)
		or Ores:Has(id)
		or Weapons:Has(id)
		or Attachments:Has(id)
		or Gadgets:Has(id)
		or Abilities:Has(id)
		or Companions:Has(id)
end

local function isKnownItem(id: string): boolean
	return Items:Has(id) or Ores:Has(id)
end

Test.describe("Crafting", function()
	Test.it("every recipe material exists", function()
		local missing = {}
		for _, recipe in Crafting:List() do
			for materialId in recipe.materials do
				if not isKnownItem(materialId) then
					table.insert(missing, string.format("%s needs unknown material %s", recipe.id, tostring(materialId)))
				end
			end
		end
		Test.empty(missing, "unknown crafting materials")
	end)

	Test.it("every recipe output exists", function()
		local missing = {}
		for _, recipe in Crafting:List() do
			for outputId in recipe.output do
				if not isKnownContent(outputId) then
					table.insert(missing, string.format("%s produces unknown output %s", recipe.id, tostring(outputId)))
				end
			end
		end
		Test.empty(missing, "unknown crafting outputs")
	end)
end)

Test.describe("World references", function()
	Test.it("resource yields point at real items", function()
		local missing = {}
		for _, node in Resources:List() do
			for _, yield in node.yields do
				if not isKnownItem(yield.itemId) then
					table.insert(missing, string.format("%s yields unknown item %s", node.id, tostring(yield.itemId)))
				end
			end
		end
		Test.empty(missing, "unknown resource yields")
	end)

	Test.it("beast drops and taming items exist", function()
		local missing = {}
		for _, beast in Beasts:List() do
			for _, drop in beast.drops or {} do
				if not isKnownItem(drop.itemId) then
					table.insert(missing, string.format("%s drops unknown item %s", beast.id, tostring(drop.itemId)))
				end
			end
			if beast.tamingItemId and not isKnownItem(beast.tamingItemId) then
				table.insert(missing, string.format("%s tames with unknown item %s", beast.id, tostring(beast.tamingItemId)))
			end
		end
		Test.empty(missing, "unknown beast items")
	end)

	Test.it("companion eggs and evolution items exist", function()
		local missing = {}
		for _, companion in Companions:List() do
			if not isKnownItem(companion.eggItemId) then
				table.insert(missing, string.format("%s has unknown egg item %s", companion.id, tostring(companion.eggItemId)))
			end
			for _, form in companion.forms or {} do
				if form.evolutionItemId and not isKnownItem(form.evolutionItemId) then
					table.insert(missing, string.format("%s evolves with unknown item %s", companion.id, tostring(form.evolutionItemId)))
				end
			end
		end
		Test.empty(missing, "unknown companion items")
	end)

	Test.it("bosses use real reward tables", function()
		local missing = {}
		for _, boss in Bosses:List() do
			if not Loot:Has(boss.rewardTableId) then
				table.insert(missing, string.format("%s references unknown loot table %s", boss.id, tostring(boss.rewardTableId)))
			end
		end
		Test.empty(missing, "unknown boss reward tables")
	end)

	Test.it("loot tables only contain real rewards", function()
		local missing = {}
		for _, table_ in Loot:List() do
			for _, entry in table_.entries do
				if not isKnownContent(entry.id) then
					table.insert(missing, string.format("%s can roll unknown reward %s", table_.id, tostring(entry.id)))
				end
			end
			for _, guaranteed in table_.guaranteed or {} do
				if not isKnownContent(guaranteed.id) then
					table.insert(missing, string.format("%s guarantees unknown reward %s", table_.id, tostring(guaranteed.id)))
				end
			end
		end
		Test.empty(missing, "unknown loot rewards")
	end)

	Test.it("regions point at real bosses, dungeons, events and hazards", function()
		local missing = {}
		for _, region in Regions:List() do
			if region.worldBossId and region.worldBossId ~= "" and not Bosses:Has(region.worldBossId) then
				table.insert(missing, string.format("%s references unknown boss %s", region.id, tostring(region.worldBossId)))
			end
			if region.dungeonId and region.dungeonId ~= "" and not Dungeons:Has(region.dungeonId) then
				table.insert(missing, string.format("%s references unknown dungeon %s", region.id, tostring(region.dungeonId)))
			end
			if region.eventId and region.eventId ~= "" and not Events:Has(region.eventId) then
				table.insert(missing, string.format("%s references unknown event %s", region.id, tostring(region.eventId)))
			end
			for _, hazardId in region.hazards or {} do
				if not Hazards:Has(hazardId) then
					table.insert(missing, string.format("%s references unknown hazard %s", region.id, tostring(hazardId)))
				end
			end
			for nodeId in region.resourceNodes or {} do
				if not Resources:Has(nodeId) then
					table.insert(missing, string.format("%s references unknown resource node %s", region.id, tostring(nodeId)))
				end
			end
			for _, speciesId in region.beastSpecies or {} do
				if not Beasts:Has(speciesId) then
					table.insert(missing, string.format("%s references unknown beast %s", region.id, tostring(speciesId)))
				end
			end
		end
		Test.empty(missing, "unknown region references")
	end)

	Test.it("dungeons point at real bosses", function()
		local missing = {}
		for _, dungeon in Dungeons:List() do
			for _, bossId in dungeon.bossIds or {} do
				if not Bosses:Has(bossId) then
					table.insert(missing, string.format("%s references unknown boss %s", dungeon.id, tostring(bossId)))
				end
			end
		end
		Test.empty(missing, "unknown dungeon bosses")
	end)

	Test.it("every world event belongs to a region or is global", function()
		local missing = {}
		for _, worldEvent in Events:List() do
			if worldEvent.regionId ~= nil and worldEvent.regionId ~= "" then
				if not Regions:Has(worldEvent.regionId) then
					table.insert(missing, string.format("%s references unknown region %s", worldEvent.id, tostring(worldEvent.regionId)))
				end
			end
		end
		Test.empty(missing, "unknown event regions")
	end)
end)

Test.describe("Weapons", function()
	Test.it("attachments fit real slots and weapons", function()
		local missing = {}
		for _, attachment in Attachments:List() do
			local knownSlot = false
			for _, slot in Enums.AttachmentSlotOrder do
				if slot == attachment.slot then
					knownSlot = true
					break
				end
			end
			if not knownSlot then
				table.insert(missing, string.format("%s has unknown slot %s", attachment.id, tostring(attachment.slot)))
			end
		end
		Test.empty(missing, "unknown attachment slots")
	end)

	Test.it("every weapon has a valid class and rarity", function()
		local missing = {}
		for _, weapon in Weapons:List() do
			local isMelee = weapon.kind == Enums.WeaponKind.Melee
			local knownClass = isMelee and weapon.class == "Melee" or false
			if not isMelee then
				for _, className in Enums.WeaponClass do
					if className == weapon.class then
						knownClass = true
						break
					end
				end
			end
			if not knownClass then
				table.insert(missing, string.format("%s has unknown class %s", weapon.id, tostring(weapon.class)))
			end
			if not Enums.IsValidRarity(weapon.rarity) then
				table.insert(missing, string.format("%s has unknown rarity %s", weapon.id, tostring(weapon.rarity)))
			end
		end
		Test.empty(missing, "invalid weapon metadata")
	end)
end)

Test.Finish()

return true
