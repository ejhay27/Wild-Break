--!strict
--[[
	InventoryController.luau
	Inventory intents and the client's cached view of the result.

	Nothing is added or removed locally: every mutation is a request, and the
	inventory is replaced wholesale by the server's response.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)

local InventoryController = { Name = "InventoryController" }

local controllers: any = nil
local inventory: any? = nil
local recipes: any? = nil
local listeners: { (any) -> () } = {}

function InventoryController.Init(svc: any)
	controllers = svc
end

function InventoryController.OnChanged(listener: (any) -> ())
	table.insert(listeners, listener)
end

function InventoryController.Get()
	return inventory
end

function InventoryController.Count(itemId: string): number
	if not inventory or not inventory.items then
		return 0
	end
	local total = 0
	for _, entry in inventory.items do
		if entry.id == itemId then
			total += entry.quantity or 0
		end
	end
	return total
end

function InventoryController.Equip(slot: string, instanceId: string)
	controllers.NetworkController.Fire(Remotes.RequestEquip.name, { slot = slot, instanceId = instanceId })
end

function InventoryController.Use(itemId: string)
	controllers.NetworkController.Fire(Remotes.RequestUseConsumable.name, { itemId = itemId })
end

function InventoryController.Drop(itemId: string, quantity: number)
	controllers.NetworkController.Fire(Remotes.RequestDropItem.name, { itemId = itemId, quantity = quantity })
end

function InventoryController.Craft(recipeId: string)
	controllers.NetworkController.Fire(Remotes.RequestCraft.name, { recipeId = recipeId })
end

function InventoryController.RequestRecipes()
	recipes = controllers.NetworkController.Invoke(Remotes.RequestRecipes.name, {}, 5) or recipes
	return recipes
end

function InventoryController.Start()
	local Network = controllers.NetworkController
	Network.On(Remotes.InventoryUpdated.name, function(payload: any)
		inventory = payload
		for _, listener in listeners do
			pcall(listener, payload)
		end
	end)
	Network.On(Remotes.CraftingResult.name, function(payload: any)
		if type(payload) == "table" and not payload.success then
			controllers.NotificationController.Notify("Crafting failed", tostring(payload.reason))
		end
	end)
	controllers.InputController.Bind("Inventory", function(down: boolean)
		if down then
			controllers.HudController.ToggleScreen("Inventory")
		end
	end)
end

return InventoryController
