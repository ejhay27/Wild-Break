--!strict
--[[
	InventoryService.luau
	Every inventory mutation runs here, on the server, against the player's
	profile. Clients request; the server verifies ownership, capacity and
	validity, then pushes the authoritative result.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)
local Logger = require(Shared.Utilities.Logger)
local Inventory = require(Shared.Inventory.InventoryModel)
local Items = require(Shared.Config.ItemConfig)
local Weapons = require(Shared.Config.WeaponConfig)
local Attachments = require(Shared.Config.AttachmentConfig)
local Crafting = require(Shared.Config.CraftingConfig)
local Limits = require(Shared.Constants.Limits)

local InventoryService = {
	Name = "InventoryService",
}

local containers: { [Player]: { bag: any, stash: any } } = {}
local services: any = nil

local function containersFor(player: Player)
	local existing = containers[player]
	if existing then
		return existing
	end
	local profile = services.PlayerService.Profile(player)
	if not profile then
		return nil
	end
	local pair = {
		bag = Inventory.FromStorage(profile.inventory, profile.inventoryCapacity),
		stash = Inventory.FromStorage(profile.stash, profile.stashCapacity),
	}
	containers[player] = pair
	return pair
end

local function persist(player: Player)
	local profile = services.PlayerService.Profile(player)
	local pair = containers[player]
	if not profile or not pair then
		return
	end
	profile.inventory = Inventory.ToStorage(pair.bag)
	profile.stash = Inventory.ToStorage(pair.stash)
	services.DataService.MarkDirty(player)
end

local function push(player: Player)
	local pair = containers[player]
	if not pair then
		return
	end
	services.NetworkService.Fire(player, Remotes.InventoryUpdated.name, {
		inventory = Inventory.ToList(pair.bag),
		capacity = pair.bag.capacity,
		stash = Inventory.ToList(pair.stash),
		stashCapacity = pair.stash.capacity,
	})
end

function InventoryService.Init(svc: any)
	services = svc
end

function InventoryService.Start(svc: any)
	services = svc
	local Network = services.NetworkService

	Network.On(Remotes.RequestEquip.name, function(player, args)
		return InventoryService.Equip(player, args[1], args[2])
	end)
	Network.On(Remotes.RequestUseConsumable.name, function(player, args)
		return InventoryService.UseConsumable(player, args[1])
	end)
	Network.On(Remotes.RequestDropItem.name, function(player, args)
		return InventoryService.Drop(player, args[1], args[2])
	end)
	Network.On(Remotes.RequestCraft.name, function(player, args)
		return InventoryService.Craft(player, args[1], args[2])
	end)
	Network.On(Remotes.RequestRecipes.name, function(player)
		local profile = services.PlayerService.Profile(player)
		if not profile then
			return {}
		end
		local out = {}
		for _, recipe in Crafting:List() do
			if not recipe.requiresBlueprint or profile.recipes[recipe.requiresBlueprint] then
				table.insert(out, recipe.id)
			end
		end
		return out
	end)
	Network.On(Remotes.RequestAttach.name, function(player, args)
		return InventoryService.Attach(player, args[1], args[2])
	end)
	Network.On(Remotes.RequestDetach.name, function(player, args)
		return InventoryService.Detach(player, args[1], args[2])
	end)
	Network.On(Remotes.RequestEvolveWeapon.name, function(player, args)
		return InventoryService.EvolveWeapon(player, args[1])
	end)
end

function InventoryService.OnProfileLoaded(player: Player)
	containersFor(player)
	push(player)
end

function InventoryService.OnPlayerRemoving(player: Player)
	persist(player)
	containers[player] = nil
end

function InventoryService.Container(player: Player): any
	local pair = containersFor(player)
	return pair and pair.bag or nil
end

-- ---------------------------------------------------------------------------
-- Core operations
-- ---------------------------------------------------------------------------

function InventoryService.AddItem(player: Player, itemId: string, quantity: number): number
	local pair = containersFor(player)
	if not pair then
		return 0
	end
	if not Items:Has(itemId) and not Weapons:Has(itemId) then
		Logger.Warn("InventoryService", string.format("refused to add unknown item %s", tostring(itemId)))
		return 0
	end
	local result = Inventory.Add(pair.bag, itemId, quantity)
	if result.added > 0 then
		persist(player)
		push(player)
	end
	if result.leftover > 0 then
		services.NetworkService.Fire(player, Remotes.Notification.name, {
			kind = "Warning",
			title = "Inventory full",
			body = string.format("%d x %s did not fit.", result.leftover, tostring(itemId)),
		})
	end
	return result.added
end

function InventoryService.RemoveItem(player: Player, itemId: string, quantity: number): number
	local pair = containersFor(player)
	if not pair then
		return 0
	end
	local removed = Inventory.Remove(pair.bag, itemId, quantity)
	if removed > 0 then
		persist(player)
		push(player)
	end
	return removed
end

function InventoryService.CountItem(player: Player, itemId: string): number
	local pair = containersFor(player)
	if not pair then
		return 0
	end
	return Inventory.QuantityOf(pair.bag, itemId)
end

-- Grants a weapon instance (used by crafting, rewards and admin grants).
function InventoryService.GrantWeapon(player: Player, weaponId: string): boolean
	local profile = services.PlayerService.Profile(player)
	if not profile or not Weapons:Has(weaponId) then
		return false
	end
	if not profile.weapons[weaponId] then
		profile.weapons[weaponId] = { id = weaponId, stars = 0, level = 1, attachments = {}, core = nil }
		services.DataService.MarkDirty(player)
		services.CombatService.BuildLoadout(player)
		services.NetworkService.Fire(player, Remotes.WeaponInstanceUpdated.name, { weaponId = weaponId, granted = true })
	end
	return true
end

function InventoryService.Equip(player: Player, slot: string, itemId: string?): boolean
	local profile = services.PlayerService.Profile(player)
	if not profile then
		return false
	end
	if itemId == nil then
		profile.equipped[slot] = nil
		services.DataService.MarkDirty(player)
		push(player)
		return true
	end
	if slot == "primary" or slot == "secondary" then
		if not profile.weapons[itemId] then
			return false
		end
		if Weapons:Get(itemId).kind == "Melee" then
			return false
		end
	elseif slot == "melee" then
		if not profile.weapons[itemId] or Weapons:Get(itemId).kind ~= "Melee" then
			return false
		end
	elseif slot == "companion" then
		if not profile.companions[itemId] then
			return false
		end
	else
		return false
	end
	profile.equipped[slot] = itemId
	services.DataService.MarkDirty(player)
	push(player)
	return true
end

function InventoryService.UseConsumable(player: Player, uid: string): boolean
	local pair = containersFor(player)
	local state = services.PlayerService.Get(player)
	if not pair or not state then
		return false
	end
	local stack = Inventory.GetByUid(pair.bag, uid)
	if not stack then
		return false
	end
	local item = Items:Get(stack.id)
	if not item or item.itemType ~= "Consumable" then
		return false
	end

	-- Consumable effects are data driven: heal, stamina, status cure or buff.
	local effects = item.effects or {}
	if effects.heal then
		services.PlayerService.Heal(player, effects.heal)
	end
	if effects.stamina then
		state.stamina = math.min(state.maxStamina, state.stamina + effects.stamina)
	end
	if effects.cures then
		local StatusEffects = require(Shared.Combat.StatusEffects)
		for _, effectId in effects.cures do
			StatusEffects.Remove(state.statusEffects, effectId)
		end
	end
	if effects.buff then
		local StatusEffects = require(Shared.Combat.StatusEffects)
		StatusEffects.Apply(state.statusEffects, effects.buff, os.clock(), { duration = effects.duration })
	end

	Inventory.RemoveAt(pair.bag, Inventory.GetByUid(pair.bag, uid) and pair.bag.byUid[uid] or "", 1)
	persist(player)
	push(player)
	return true
end

function InventoryService.Drop(player: Player, uid: string, quantity: number?): boolean
	local pair = containersFor(player)
	if not pair then
		return false
	end
	local slot = pair.bag.byUid[uid]
	if not slot then
		return false
	end
	local stack = pair.bag.slots[slot]
	if not stack then
		return false
	end
	local removed = Inventory.RemoveAt(pair.bag, slot, quantity or stack.quantity)
	if removed > 0 then
		-- Dropped items become a world pickup handled by the world service.
		if services.WorldService then
			services.WorldService.SpawnPickup(player, stack.id, removed)
		end
		persist(player)
		push(player)
	end
	return removed > 0
end

-- ---------------------------------------------------------------------------
-- Crafting
-- ---------------------------------------------------------------------------

function InventoryService.CanCraft(player: Player, recipeId: string): (boolean, string?)
	local pair = containersFor(player)
	local profile = services.PlayerService.Profile(player)
	if not pair or not profile then
		return false, "Not ready."
	end
	local recipe = Crafting:Get(recipeId)
	if not recipe then
		return false, "Unknown recipe."
	end
	if recipe.requiresBlueprint and not profile.recipes[recipe.requiresBlueprint] then
		return false, "Blueprint required."
	end
	if recipe.requiredLevel and profile.level < recipe.requiredLevel then
		return false, "Level too low."
	end
	for materialId, required in recipe.materials do
		if Inventory.QuantityOf(pair.bag, materialId) < required then
			return false, string.format("Missing %s.", tostring(materialId))
		end
	end
	return true, nil
end

function InventoryService.Craft(player: Player, recipeId: string, quantity: number?): boolean
	local canCraft, reason = InventoryService.CanCraft(player, recipeId)
	if not canCraft then
		services.NetworkService.Fire(player, Remotes.CraftingResult.name, { recipeId = recipeId, success = false, reason = reason })
		return false
	end
	local pair = containersFor(player) :: any
	local recipe = Crafting:Get(recipeId)
	local count = math.max(1, math.min(10, math.floor(quantity or 1)))

	for materialId, required in recipe.materials do
		Inventory.Remove(pair.bag, materialId, required * count)
	end

	for outputId, amount in recipe.output do
		if Weapons:Has(outputId) then
			for _ = 1, amount * count do
				InventoryService.GrantWeapon(player, outputId)
			end
		else
			Inventory.Add(pair.bag, outputId, amount * count)
		end
	end

	persist(player)
	push(player)
	services.NetworkService.Fire(player, Remotes.CraftingResult.name, { recipeId = recipeId, success = true, quantity = count })
	return true
end

-- ---------------------------------------------------------------------------
-- Attachments and evolution
-- ---------------------------------------------------------------------------

function InventoryService.Attach(player: Player, weaponId: string, attachmentId: string): boolean
	local profile = services.PlayerService.Profile(player)
	local pair = containersFor(player)
	if not profile or not pair then
		return false
	end
	local weapon = profile.weapons[weaponId]
	local attachment = Attachments:Get(attachmentId)
	if not weapon or not attachment then
		return false
	end
	local weaponDef = Weapons:Get(weaponId)
	if not Attachments.IsCompatible(attachmentId, weaponId, weaponDef and weaponDef.class or "") then
		services.NetworkService.Fire(player, Remotes.WeaponInstanceUpdated.name, { weaponId = weaponId, success = false, reason = "Incompatible" })
		return false
	end
	if Inventory.QuantityOf(pair.bag, attachmentId) < 1 then
		services.NetworkService.Fire(player, Remotes.WeaponInstanceUpdated.name, { weaponId = weaponId, success = false, reason = "Missing" })
		return false
	end
	local slots = Weapons.CompatibleAttachments(weaponId)
	if slots and #slots > 0 then
		local used = 0
		for _ in weapon.attachments do
			used += 1
		end
		if used >= #slots then
			services.NetworkService.Fire(player, Remotes.WeaponInstanceUpdated.name, { weaponId = weaponId, success = false, reason = "NoSlot" })
			return false
		end
	end
	Inventory.Remove(pair.bag, attachmentId, 1)
	weapon.attachments[attachment.slot] = attachmentId
	services.DataService.MarkDirty(player)
	services.CombatService.BuildLoadout(player)
	persist(player)
	push(player)
	services.NetworkService.Fire(player, Remotes.WeaponInstanceUpdated.name, { weaponId = weaponId, success = true, attachments = weapon.attachments })
	return true
end

function InventoryService.Detach(player: Player, weaponId: string, slot: string): boolean
	local profile = services.PlayerService.Profile(player)
	local pair = containersFor(player)
	if not profile or not pair then
		return false
	end
	local weapon = profile.weapons[weaponId]
	if not weapon or not weapon.attachments[slot] then
		return false
	end
	local attachmentId = weapon.attachments[slot]
	weapon.attachments[slot] = nil
	Inventory.Add(pair.bag, attachmentId, 1)
	services.DataService.MarkDirty(player)
	services.CombatService.BuildLoadout(player)
	persist(player)
	push(player)
	services.NetworkService.Fire(player, Remotes.WeaponInstanceUpdated.name, { weaponId = weaponId, success = true, attachments = weapon.attachments })
	return true
end

-- Star evolution consumes World Tree Sap and the matching upgrade item.
function InventoryService.EvolveWeapon(player: Player, weaponId: string): boolean
	local profile = services.PlayerService.Profile(player)
	local pair = containersFor(player)
	if not profile or not pair then
		return false
	end
	local weapon = profile.weapons[weaponId]
	if not weapon then
		return false
	end
	local def = Weapons:Get(weaponId)
	if not def then
		return false
	end
	local maxStars = require(Shared.Config.RarityConfig).MaxStars(def.rarity)
	if weapon.stars >= maxStars then
		services.NetworkService.Fire(player, Remotes.WeaponInstanceUpdated.name, { weaponId = weaponId, success = false, reason = "MaxStars" })
		return false
	end
	local upgradeItem = weapon.stars + 1 >= 6 and "upgrade_star_mythical" or "upgrade_star_legendary"
	local cost = weapon.stars + 1
	if Inventory.QuantityOf(pair.bag, upgradeItem) < 1 or Inventory.QuantityOf(pair.bag, "world_tree_sap") < cost then
		services.NetworkService.Fire(player, Remotes.WeaponInstanceUpdated.name, { weaponId = weaponId, success = false, reason = "Materials" })
		return false
	end
	Inventory.Remove(pair.bag, upgradeItem, 1)
	Inventory.Remove(pair.bag, "world_tree_sap", cost)
	weapon.stars += 1
	services.DataService.MarkDirty(player)
	services.CombatService.BuildLoadout(player)
	persist(player)
	push(player)
	services.NetworkService.Fire(player, Remotes.WeaponInstanceUpdated.name, { weaponId = weaponId, success = true, stars = weapon.stars })
	return true
end

return InventoryService
