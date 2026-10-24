--!strict
--[[
	Pool.luau
	Generic object pool. Effects, projectiles, damage numbers and audio
	emitters are pooled so long fights never leak thousands of instances.
]]

local Pool = {}
Pool.__index = Pool

export type Pool<T> = typeof(setmetatable({} :: {
	_create: () -> T,
	_reset: ((T) -> ())?,
	_dispose: ((T) -> ())?,
	_free: { T },
	_inUse: { [T]: boolean },
	_created: number,
	_maxSize: number,
}, Pool))

function Pool.new<T>(create: () -> T, reset: ((T) -> ())?, maxSize: number?, dispose: ((T) -> ())?): Pool<T>
	return setmetatable({
		_create = create,
		_reset = reset,
		_dispose = dispose,
		_free = {},
		_inUse = {},
		_created = 0,
		_maxSize = maxSize or 256,
	}, Pool)
end

function Pool.Acquire<T>(self: Pool<T>): T
	local object = table.remove(self._free)
	if not object then
		object = self._create()
		self._created += 1
	end
	if self._reset then
		self._reset(object)
	end
	self._inUse[object] = true
	return object
end

function Pool.Release<T>(self: Pool<T>, object: T)
	if not self._inUse[object] then
		return
	end
	self._inUse[object] = nil
	if #self._free < self._maxSize then
		table.insert(self._free, object)
	elseif self._dispose then
		self._dispose(object)
	end
end

function Pool.ReleaseAll<T>(self: Pool<T>)
	for object in self._inUse do
		self:Release(object)
	end
end

function Pool.Stats<T>(self: Pool<T>): { free: number, inUse: number, created: number }
	local inUse = 0
	for _ in self._inUse do
		inUse += 1
	end
	return { free = #self._free, inUse = inUse, created = self._created }
end

return Pool
