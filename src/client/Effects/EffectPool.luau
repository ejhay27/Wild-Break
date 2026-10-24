--!strict
--[[
	EffectPool.luau
	Pooled visual effects for hits, explosions and boss telegraphs.

	Effects are procedural primitives (parts, beams, particles) rather than
	imported assets, so combat reads correctly before any art exists. Every
	effect is recycled through a pool and returned by a hard lifetime so a
	long fight cannot leak instances.
]]

local Debris = game:GetService("Debris")

local EffectPool = {}

local pools: { [string]: { Instance } } = {}
local MAX_POOLED = 24

local function acquire(kind: string, create: () -> Instance): Instance
	local pool = pools[kind]
	if not pool then
		pool = {}
		pools[kind] = pool
	end
	local instance = table.remove(pool)
	if not instance then
		instance = create()
	end
	instance.Parent = workspace
	return instance
end

local function release(kind: string, instance: Instance)
	local pool = pools[kind] or {}
	if #pool >= MAX_POOLED then
		instance:Destroy()
		return
	end
	instance.Parent = nil
	table.insert(pool, instance)
end

-- A short-lived sphere used for impacts and explosion read-outs.
function EffectPool.Burst(position: Vector3, radius: number, color: Color3?)
	local part = acquire("Burst", function()
		local sphere = Instance.new("Part")
		sphere.Shape = Enum.PartType.Ball
		sphere.Anchored = true
		sphere.CanCollide = false
		sphere.Material = Enum.Material.Neon
		sphere.Transparency = 0.5
		return sphere
	end) :: Part

	part.Size = Vector3.new(1, 1, 1)
	part.Position = position
	part.Color = color or Color3.fromRGB(255, 190, 90)

	local lifetime = 0.35
	Debris:AddItem(part, lifetime + 0.1)
	task.delay(lifetime, function()
		if part.Parent then
			release("Burst", part)
		end
	end)

	-- Scale up and fade out.
	local steps = 8
	for step = 1, steps do
		task.wait(lifetime / steps)
		if not part.Parent then
			return
		end
		local t = step / steps
		part.Size = Vector3.new(radius, radius, radius) * (0.4 + t * 0.6)
		part.Transparency = 0.5 + t * 0.5
	end
end

-- A vertical beam used to telegraph boss attacks and zone hazards.
function EffectPool.Telegraph(position: Vector3, radius: number, duration: number, color: Color3?)
	local beam = acquire("Telegraph", function()
		local cylinder = Instance.new("Part")
		cylinder.Shape = Enum.PartType.Cylinder
		cylinder.Anchored = true
		cylinder.CanCollide = false
		cylinder.Material = Enum.Material.Neon
		cylinder.Transparency = 0.7
		return cylinder
	end) :: Part

	beam.Size = Vector3.new(0.2, 40, 0.2)
	beam.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	beam.Color = color or Color3.fromRGB(255, 80, 80)

	-- Grow the radius to the real hit radius so the telegraph is honest.
	local steps = 10
	for step = 1, steps do
		task.wait(duration / steps)
		if not beam.Parent then
			return
		end
		local t = step / steps
		local diameter = radius * 2 * t
		beam.Size = Vector3.new(diameter, 40, diameter)
	end

	Debris:AddItem(beam, 0.1)
	task.delay(0.15, function()
		if beam.Parent then
			release("Telegraph", beam)
		end
	end)
end

function EffectPool.ActiveCount(): number
	local count = 0
	for _, pool in pools do
		count += #pool
	end
	return count
end

return EffectPool
