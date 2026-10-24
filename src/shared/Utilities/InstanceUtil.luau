--!strict
--[[
	InstanceUtil.luau
	Safe instance helpers. Every world object created by WILDBREAK goes
	through here so cleanup is centralised and tagged consistently.
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local InstanceUtil = {}

function InstanceUtil.Create<T>(className: string, name: string?, parent: Instance?, properties: { [string]: any }?): T
	local instance = Instance.new(className)
	if name then
		instance.Name = name
	end
	if properties then
		for property, value in properties do
			(instance :: any)[property] = value
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance :: T
end

function InstanceUtil.Tag(instance: Instance, tag: string)
	if not CollectionService:HasTag(instance, tag) then
		CollectionService:AddTag(instance, tag)
	end
end

function InstanceUtil.Untag(instance: Instance, tag: string)
	if CollectionService:HasTag(instance, tag) then
		CollectionService:RemoveTag(instance, tag)
	end
end

-- Schedules cleanup. Falls back to immediate destroy when Debris is absent
-- (for example in the offline test harness).
function InstanceUtil.ScheduleRemoval(instance: Instance, seconds: number?)
	if Debris and Debris.AddItem then
		Debris:AddItem(instance, seconds or 5)
	else
		instance:Destroy()
	end
end

function InstanceUtil.DestroyChildren(parent: Instance, filter: ((Instance) -> boolean)?)
	for _, child in parent:GetChildren() do
		if not filter or filter(child) then
			child:Destroy()
		end
	end
end

function InstanceUtil.FindAncestorOfClass(instance: Instance, className: string): Instance?
	local current: Instance? = instance.Parent
	while current do
		if current:IsA(className) then
			return current
		end
		current = current.Parent
	end
	return nil
end

function InstanceUtil.SetNetworkOwnerSafe(part: BasePart, owner: Player?)
	if not part:IsA("BasePart") then
		return false
	end
	local ok, err = pcall(function()
		part:SetNetworkOwner(owner)
	end)
	if not ok then
		warn(string.format("[InstanceUtil] SetNetworkOwner failed: %s", tostring(err)))
		return false
	end
	return true
end

-- Efficient bulk parent assignment to reduce replication churn.
function InstanceUtil.ReparentAll(children: { Instance }, parent: Instance)
	for _, child in children do
		child.Parent = parent
	end
end

return InstanceUtil
