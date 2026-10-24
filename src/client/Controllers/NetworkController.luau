--!strict
--[[
	NetworkController.luau
	The only client module that touches RemoteEvents.

	Every outbound call goes through the declared definitions in
	Shared/Networking/Remotes, so the client can never invent a remote and the
	server can never receive a name it does not know.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Networking.Remotes)
local Logger = require(Shared.Utilities.Logger)

local NetworkController = { Name = "NetworkController" }

local folder: Folder? = nil
local remoteCache: { [string]: RemoteEvent | RemoteFunction } = {}
local listeners: { [string]: { (any) -> () } } = {}

local function container(): Folder?
	if folder and folder.Parent then
		return folder
	end
	folder = ReplicatedStorage:WaitForChild("WB_Remotes", 30) :: Folder?
	return folder
end

local function objectFor(definition: any): RemoteEvent | RemoteFunction?
	local cached = remoteCache[definition.name]
	if cached and cached.Parent then
		return cached
	end
	local parent = container()
	if not parent then
		return nil
	end
	local instance = parent:FindFirstChild(definition.name)
	if not instance then
		return nil
	end
	remoteCache[definition.name] = instance :: any
	return instance :: any
end

function NetworkController.Platform(): string
	if GuiService:IsTenFootInterface() then
		return "Console"
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Mobile"
	end
	return "PC"
end

-- Fire a declared remote. Silently drops the call if the server has not
-- created the remote yet rather than throwing into the client log.
function NetworkController.Fire(remoteName: string, payload: any?): boolean
	local object = objectFor({ name = remoteName })
	if not object then
		Logger.Debug("Network", string.format("remote %s is not available yet", remoteName))
		return false
	end
	if object:IsA("RemoteEvent") then
		object:FireServer(payload or {})
		return true
	end
	-- A RemoteFunction is invoked on a worker thread so a slow server can
	-- never stall the render loop.
	task.spawn(function()
		local ok, err = pcall(function()
			(object :: RemoteFunction):InvokeServer(payload or {})
		end)
		if not ok then
			Logger.Debug("Network", string.format("%s failed: %s", remoteName, tostring(err)))
		end
	end)
	return true
end

-- Invoke a declared RemoteFunction and wait for the result.
function NetworkController.Invoke(remoteName: string, payload: any?, timeout: number?): any?
	local object = objectFor({ name = remoteName })
	if not object or not object:IsA("RemoteFunction") then
		return nil
	end
	local result = nil
	local completed = false
	task.spawn(function()
		local ok, value = pcall(function()
			return (object :: RemoteFunction):InvokeServer(payload or {})
		end)
		if ok then
			result = value
		end
		completed = true
	end)
	local deadline = os.clock() + (timeout or 3)
	while not completed and os.clock() < deadline do
		task.wait()
	end
	return result
end

-- Subscribe to a server -> client event.
function NetworkController.On(remoteName: string, handler: (any) -> ())
	if not listeners[remoteName] then
		listeners[remoteName] = {}
	end
	table.insert(listeners[remoteName], handler)
end

-- Connects every inbound remote once the server has created them.
function NetworkController.Start()
	local parent = container()
	if not parent then
		Logger.Warn("Network", "WB_Remotes did not arrive; inbound events are disconnected")
		return
	end

	for _, definition in Remotes.All() do
		if definition.direction ~= "ClientToServer" then
			local object = objectFor(definition)
			if object and object:IsA("RemoteEvent") then
				(object :: RemoteEvent).OnClientEvent:Connect(function(...)
					local handlers = listeners[definition.name]
					if not handlers then
						return
					end
					local args = { ... }
					for _, handler in handlers do
						local ok, err = pcall(handler, if #args == 1 then args[1] else args)
						if not ok then
							Logger.Warn(
								"Network",
								string.format("handler for %s failed: %s", definition.name, tostring(err))
							)
						end
					end
				end)
			end
		end
	end
end

return NetworkController
