--!strict
--[[
	Signal.luau
	Minimal synchronous signal implementation. Used by pure-logic modules and
	by the offline test harness so gameplay code never depends on an engine
	specific event object.
]]

local Signal = {}
Signal.__index = Signal

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
	_signal: any,
	_index: number,
	_callback: (...any) -> (),
}

export type Signal = typeof(setmetatable({} :: {
	_connections: { Connection },
	_firing: boolean,
	_head: number,
}, Signal))

function Signal.new(): Signal
	return setmetatable({
		_connections = {},
		_firing = false,
		_head = 1,
	}, Signal)
end

function Signal.Connect(self: Signal, callback: (...any) -> ()): Connection
	assert(type(callback) == "function", "Signal.Connect expects a function")
	local index = self._head
	self._head += 1
	local connection
	connection = {
		Connected = true,
		_signal = self,
		_index = index,
		_callback = callback,
		Disconnect = function(this: Connection)
			if not this.Connected then
				return
			end
			this.Connected = false
			local signal = this._signal :: Signal
			signal._connections[this._index] = nil
		end,
	} :: Connection
	self._connections[index] = connection
	return connection
end

function Signal.Once(self: Signal, callback: (...any) -> ()): Connection
	local connection
	connection = self:Connect(function(...)
		if connection then
			connection:Disconnect()
		end
		callback(...)
	end)
	return connection
end

function Signal.Fire(self: Signal, ...: any)
	if self._firing then
		-- Re-entrant fire: defer to avoid corrupting iteration.
		task.spawn(function(...)
			self._firing = true
			for _, connection in pairs(table.clone(self._connections)) do
				if connection.Connected then
					local ok, err = pcall(connection._callback, ...)
					if not ok then
						warn(string.format("[Signal] listener error: %s", tostring(err)))
					end
				end
			end
			self._firing = false
		end, ...)
		return
	end
	self._firing = true
	for _, connection in pairs(table.clone(self._connections)) do
		if connection.Connected then
			local ok, err = pcall(connection._callback, ...)
			if not ok then
				warn(string.format("[Signal] listener error: %s", tostring(err)))
			end
		end
	end
	self._firing = false
end

function Signal.Wait(self: Signal): ...any
	local thread = coroutine.running()
	local connection
	connection = self:Connect(function(...)
		if connection then
			connection:Disconnect()
		end
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal.Destroy(self: Signal)
	for _, connection in pairs(self._connections) do
		connection.Connected = false
	end
	table.clear(self._connections)
end

Signal.DisconnectAll = Signal.Destroy

return Signal
