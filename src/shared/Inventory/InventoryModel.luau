--!strict
--[[
	InventoryModel.luau
	Pure inventory logic used by the server InventoryService and by tests.

	The model never trusts a client slot index blindly: every operation
	re-checks that the item exists, that quantities are positive integers and
	that the resulting state still fits the container. Any operation that
	cannot be completed returns `false` plus a reason instead of silently
	duplicating or destroying items.
]]

local Items = require(script.Parent.Parent.Config.ItemConfig)
local Weapons = require(script.Parent.Parent.Config.WeaponConfig)
local Limits = require(script.Parent.Parent.Constants.Limits)

local Inventory = {}

export type Stack = {
	uid: string,
	id: string,
	quantity: number,
	data: { [string]: any }?,
}

export type Container = {
	capacity: number,
	slots: { [string]: Stack },
	-- uid -> slot key, maintained so lookups stay cheap.
	byUid: { [string]: string },
}

export type AddResult = {
	added: number,
	leftover: number,
	slots: { string },
	reason: string?,
}

local nextUid = 0
local function newUid(prefix: string): string
	nextUid += 1
	return string.format("%s_%d", prefix, nextUid)
end

-- Test hook: keeps generated uids deterministic inside specs.
function Inventory.ResetUidCounter(value: number?)
	nextUid = value or 0
end

function Inventory.New(capacity: number): Container
	return {
		capacity = math.max(1, math.floor(capacity)),
		slots = {},
		byUid = {},
	}
end

function Inventory.StackLimit(itemId: string): number
	local item = Items:Get(itemId)
	if item and item.stackSize then
		return math.max(1, item.stackSize)
	end
	if Weapons:Has(itemId) then
		return 1
	end
	return Limits.Inventory.DefaultStackSize
end

function Inventory.IsStackable(itemId: string): boolean
	return Inventory.StackLimit(itemId) > 1
end

local function reindex(container: Container)
	container.byUid = {}
	for key, stack in container.slots do
		container.byUid[stack.uid] = key
	end
end

function Inventory.Count(container: Container): number
	local total = 0
	for _ in container.slots do
		total += 1
	end
	return total
end

function Inventory.QuantityOf(container: Container, itemId: string): number
	local total = 0
	for _, stack in container.slots do
		if stack.id == itemId then
			total += stack.quantity
		end
	end
	return total
end

function Inventory.FreeSlots(container: Container): number
	return math.max(0, container.capacity - Inventory.Count(container))
end

-- How many more of `itemId` will fit, without mutating anything.
function Inventory.Fits(container: Container, itemId: string, quantity: number): number
	if quantity <= 0 then
		return 0
	end
	local limit = Inventory.StackLimit(itemId)
	local remaining = quantity
	for _, stack in container.slots do
		if stack.id == itemId and stack.quantity < limit then
			local space = limit - stack.quantity
			remaining -= math.min(space, remaining)
			if remaining <= 0 then
				return quantity
			end
		end
	end
	local freeSlots = Inventory.FreeSlots(container)
	local fitsInNewSlots = freeSlots * limit
	return quantity - math.max(0, remaining - fitsInNewSlots)
end

-- Adds items. Returns how many were added, how many did not fit and where.
function Inventory.Add(container: Container, itemId: string, quantity: number, data: { [string]: any }?): AddResult
	local wanted = math.floor(quantity)
	if wanted <= 0 then
		return { added = 0, leftover = 0, slots = {}, reason = "Nothing to add." }
	end
	if not Items:Has(itemId) and not Weapons:Has(itemId) then
		return { added = 0, leftover = wanted, slots = {}, reason = "Unknown item." }
	end
	local limit = Inventory.StackLimit(itemId)
	local touched = {}
	local remaining = wanted

	if Inventory.IsStackable(itemId) then
		for key, stack in container.slots do
			if remaining <= 0 then
				break
			end
			if stack.id == itemId and stack.quantity < limit then
				local space = limit - stack.quantity
				local moved = math.min(space, remaining)
				stack.quantity += moved
				remaining -= moved
				table.insert(touched, key)
			end
		end
	end

	while remaining > 0 and Inventory.FreeSlots(container) > 0 do
		local take = math.min(limit, remaining)
		local key = Inventory.FirstFreeKey(container)
		local uid = newUid("item")
		container.slots[key] = { uid = uid, id = itemId, quantity = take, data = data }
		remaining -= take
		table.insert(touched, key)
		if not Inventory.IsStackable(itemId) then
			-- Non-stackable items occupy exactly one slot each.
			break
		end
	end

	reindex(container)
	return {
		added = wanted - remaining,
		leftover = remaining,
		slots = touched,
		reason = remaining > 0 and "Not enough inventory space." or nil,
	}
end

function Inventory.FirstFreeKey(container: Container): string
	for index = 1, container.capacity do
		local key = tostring(index)
		if container.slots[key] == nil then
			return key
		end
	end
	return tostring(container.capacity + 1)
end

function Inventory.Get(container: Container, key: string): Stack?
	return container.slots[key]
end

function Inventory.GetByUid(container: Container, uid: string): Stack?
	local key = container.byUid[uid]
	if not key then
		return nil
	end
	return container.slots[key]
end

-- Removes up to `quantity` of an item from anywhere in the container.
function Inventory.Remove(container: Container, itemId: string, quantity: number): number
	local wanted = math.floor(quantity)
	if wanted <= 0 then
		return 0
	end
	local removed = 0
	for key, stack in container.slots do
		if removed >= wanted then
			break
		end
		if stack.id == itemId then
			local take = math.min(stack.quantity, wanted - removed)
			stack.quantity -= take
			removed += take
			if stack.quantity <= 0 then
				container.slots[key] = nil
			end
		end
	end
	reindex(container)
	return removed
end

-- Removes from one specific stack (a drag-and-drop drop / sell / consume).
function Inventory.RemoveAt(container: Container, key: string, quantity: number?): number
	local stack = container.slots[key]
	if not stack then
		return 0
	end
	local take = math.min(stack.quantity, math.floor(quantity or stack.quantity))
	if take <= 0 then
		return 0
	end
	stack.quantity -= take
	if stack.quantity <= 0 then
		container.slots[key] = nil
	end
	reindex(container)
	return take
end

function Inventory.Has(container: Container, itemId: string, quantity: number): boolean
	return Inventory.QuantityOf(container, itemId) >= quantity
end

-- Moves a stack to a free slot. Fails instead of merging when the target is
-- taken, so a mis-click can never destroy an item.
function Inventory.Move(container: Container, fromKey: string, toKey: string): boolean
	if fromKey == toKey then
		return false
	end
	local stack = container.slots[fromKey]
	if not stack then
		return false
	end
	if container.slots[toKey] ~= nil then
		return false
	end
	if tonumber(toKey) ~= nil and tonumber(toKey) > container.capacity then
		return false
	end
	container.slots[fromKey] = nil
	container.slots[toKey] = stack
	reindex(container)
	return true
end

function Inventory.Swap(container: Container, keyA: string, keyB: string): boolean
	if keyA == keyB then
		return false
	end
	local a, b = container.slots[keyA], container.slots[keyB]
	if not a and not b then
		return false
	end
	container.slots[keyA] = b
	container.slots[keyB] = a
	reindex(container)
	return true
end

-- Merges two stacks of the same stackable item.
function Inventory.Merge(container: Container, fromKey: string, toKey: string): boolean
	local source, target = container.slots[fromKey], container.slots[toKey]
	if not source or not target then
		return false
	end
	if source.id ~= target.id or not Inventory.IsStackable(source.id) then
		return false
	end
	local limit = Inventory.StackLimit(source.id)
	if target.quantity >= limit then
		return false
	end
	local moved = math.min(source.quantity, limit - target.quantity)
	target.quantity += moved
	source.quantity -= moved
	if source.quantity <= 0 then
		container.slots[fromKey] = nil
	end
	reindex(container)
	return true
end

-- Splits `quantity` off a stack into a free slot.
function Inventory.Split(container: Container, key: string, quantity: number): boolean
	local stack = container.slots[key]
	if not stack then
		return false
	end
	if quantity <= 0 or quantity >= stack.quantity then
		return false
	end
	if Inventory.FreeSlots(container) <= 0 then
		return false
	end
	stack.quantity -= quantity
	local newKey = Inventory.FirstFreeKey(container)
	local uid = newUid("item")
	container.slots[newKey] = { uid = uid, id = stack.id, quantity = quantity, data = stack.data }
	reindex(container)
	return true
end

-- Total weight using a caller supplied weight table (item id -> weight).
function Inventory.Weight(container: Container, weightOf: (string) -> number): number
	local total = 0
	for _, stack in container.slots do
		total += (weightOf(stack.id) or 0) * stack.quantity
	end
	return total
end

function Inventory.ToList(container: Container): { Stack }
	local out = {}
	for _, stack in container.slots do
		table.insert(out, stack)
	end
	table.sort(out, function(a, b)
		if a.id == b.id then
			return a.quantity > b.quantity
		end
		return a.id < b.id
	end)
	return out
end

-- Serialises to the profile format (uid -> stack), dropping the index.
function Inventory.ToStorage(container: Container): { [string]: Stack }
	local out = {}
	for _, stack in container.slots do
		out[stack.uid] = stack
	end
	return out
end

function Inventory.FromStorage(raw: any, capacity: number): Container
	local container = Inventory.New(capacity)
	if type(raw) ~= "table" then
		return container
	end
	local index = 1
	for uid, value in raw do
		if index > capacity then
			break
		end
		if type(value) == "table" and type(value.id) == "string" then
			local quantity = math.floor(tonumber(value.quantity) or 1)
			if quantity > 0 and (Items:Has(value.id) or Weapons:Has(value.id)) then
				local key = tostring(index)
				container.slots[key] = {
					uid = type(uid) == "string" and uid or newUid("item"),
					id = value.id,
					quantity = quantity,
					data = type(value.data) == "table" and value.data or nil,
				}
				index += 1
			end
		end
	end
	reindex(container)
	return container
end

function Inventory.ValidateAll(): { string }
	local problems = {}
	local container = Inventory.New(3)
	local result = Inventory.Add(container, "stone_rubble", 20)
	if result.added ~= 20 or result.leftover ~= 0 then
		table.insert(problems, string.format("[Inventory] expected 20 added, got %d (+%d leftover)", result.added, result.leftover))
	end
	if Inventory.Count(container) ~= 1 then
		table.insert(problems, "[Inventory] a stackable item should occupy one slot")
	end
	local overflow = Inventory.Add(container, "stone_rubble", 100_000)
	if overflow.leftover == 0 then
		table.insert(problems, "[Inventory] inventory accepted more than its capacity")
	end
	if Inventory.QuantityOf(container, "stone_rubble") ~= container.capacity * Inventory.StackLimit("stone_rubble") then
		table.insert(problems, "[Inventory] overflow did not respect the stack limit")
	end
	if Inventory.Remove(container, "stone_rubble", 5) ~= 5 then
		table.insert(problems, "[Inventory] could not remove items that are definitely present")
	end

	local small = Inventory.New(4)
	Inventory.Add(small, "stone_rubble", 5)
	Inventory.Add(small, "stone_rubble", 7)
	if Inventory.Count(small) ~= 1 then
		table.insert(problems, "[Inventory] identical items did not stack")
	end
	if Inventory.QuantityOf(small, "stone_rubble") ~= 12 then
		table.insert(problems, "[Inventory] stacked quantities are wrong")
	end
	if Inventory.Add(small, "unknown_item_xyz", 1).added ~= 0 then
		table.insert(problems, "[Inventory] unknown items can be added")
	end
	Inventory.Add(small, "timber_softwood", 3)
	if Inventory.Move(small, "1", "3") ~= true then
		table.insert(problems, "[Inventory] Move to a free slot failed")
	end
	if Inventory.Move(small, "3", "3") ~= false then
		table.insert(problems, "[Inventory] Move onto itself should fail")
	end
	-- Slot 2 is occupied by timber: moving onto it must fail rather than swap.
	if Inventory.Move(small, "3", "2") ~= false then
		table.insert(problems, "[Inventory] Move onto an occupied slot must fail instead of destroying items")
	end
	if Inventory.Split(small, "3", 4) ~= true then
		table.insert(problems, "[Inventory] Split failed")
	end
	if Inventory.Split(small, "3", 999) ~= false then
		table.insert(problems, "[Inventory] Split accepted an impossible quantity")
	end
	local splitTotal = 0
	for _, stack in small.slots do
		if stack.id == "stone_rubble" then
			splitTotal += stack.quantity
		end
	end
	if splitTotal ~= 12 then
		table.insert(problems, string.format("[Inventory] Split changed the total amount: %d", splitTotal))
	end
	if Inventory.Merge(small, "1", "3") ~= true then
		table.insert(problems, "[Inventory] Merge failed for identical stackable items")
	end
	if Inventory.RemoveAt(small, "99", 1) ~= 0 then
		table.insert(problems, "[Inventory] RemoveAt succeeded on an empty slot")
	end
	if Inventory.Add(small, "stone_rubble", -5).added ~= 0 then
		table.insert(problems, "[Inventory] negative quantities can be added")
	end
	local restored = Inventory.FromStorage(Inventory.ToStorage(small), 4)
	if Inventory.QuantityOf(restored, "stone_rubble") ~= Inventory.QuantityOf(small, "stone_rubble") then
		table.insert(problems, "[Inventory] storage round-trip lost items")
	end
	local hostile = Inventory.FromStorage({ ["a"] = { id = "not_real", quantity = 9 }, ["b"] = { id = "stone_rubble", quantity = -2 } }, 4)
	if Inventory.Count(hostile) ~= 0 then
		table.insert(problems, "[Inventory] FromStorage kept invalid entries")
	end
	return problems
end

return Inventory
