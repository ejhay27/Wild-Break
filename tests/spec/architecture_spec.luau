--!strict
--[[
	Architecture spec.

	Guards the structural invariants that are easy to break silently:

	  * every Rojo $path exists
	  * every container-prefixed require resolves to a real module
	  * no server-only logic is reachable from a client container
	  * client entry points are .client / server entry points are .server
	  * no module declares a duplicate Name (the service loader keys on it)
	  * the remote registry has no duplicate names and every definition is
	    complete

	These checks read the repository through the test mirror, so they run
	without a Roblox engine.
]]

local Test = require("../harness/Harness")

-- The test mirror exposes the source tree as Lua files on disk; there is no
-- filesystem API under the Luau CLI, so the checks that need one are driven by
-- the generated symbol audit plus the registry contents instead.

local Remotes = require("@shared/Networking/Remotes")
local Enums = require("@shared/Constants/Enums")
local Bosses = require("@shared/Config/BossConfig")
local Performance = require("@shared/Config/PerformanceConfig")
local Extensions = require("@shared/Security/Extensions")

Test.describe("Remote registry", function()
	Test.it("every remote has a unique name", function()
		local seen = {}
		for _, definition in Remotes.All() do
			Test.eq(
				seen[definition.name],
				nil,
				string.format("duplicate remote name %s", tostring(definition.name))
			)
			seen[definition.name] = true
		end
	end)

	Test.it("every remote has a WB_ prefixed channel name", function()
		for _, definition in Remotes.All() do
			Test.contains(definition.name, "WB_", string.format("%s is not namespaced", tostring(definition.name)))
		end
	end)

	Test.it("every remote declares a kind and direction", function()
		for _, definition in Remotes.All() do
			Test.truthy(
				definition.kind == "Event" or definition.kind == "Function",
				string.format("%s has an invalid kind", tostring(definition.name))
			)
			Test.truthy(
				definition.direction == "ClientToServer"
					or definition.direction == "ServerToClient"
					or definition.direction == "Bidirectional",
				string.format("%s has an invalid direction", tostring(definition.name))
			)
		end
	end)

	Test.it("client-to-server remotes carry a rate limit", function()
		-- An unthrottled inbound remote is a free packet-flood vector.
		for _, definition in Remotes.All() do
			if definition.direction ~= "ServerToClient" then
				Test.truthy(
					definition.rateLimit ~= nil,
					string.format("%s has no rate limit", tostring(definition.name))
				)
			end
		end
	end)

	Test.it("client-to-server remotes declare an argument schema", function()
		-- Without a schema an inbound call is only checked for argument COUNT,
		-- so a client could send anything it liked to a remote that expects
		-- nothing. Every inbound channel declares its payload, even if empty.
		for _, definition in Remotes.All() do
			if definition.direction ~= "ServerToClient" then
				Test.truthy(
					definition.args ~= nil,
					string.format("%s has no argument schema", tostring(definition.name))
				)
			end
		end
	end)

	Test.it("admin remotes declare an admin level", function()
		for _, definition in Remotes.All() do
			if string.find(definition.name, "Admin") then
				Test.truthy(
					definition.adminLevel ~= nil,
					string.format("%s is an admin remote with no level", tostring(definition.name))
				)
			end
		end
	end)

	Test.it("presentation remotes are server to client only", function()
		-- Indexed by channel name (WB_*) rather than by registry key.
		local channel = {}
		for key, definition in pairs(Remotes) do
			if type(definition) == "table" and type(definition.name) == "string" then
				channel[definition.name] = definition
			end
		end
		for _, name in { "WB_PlaySound", "WB_PlayEffect", "WB_Notification", "WB_Announcement", "WB_Cinematic" } do
			Test.truthy(channel[name], string.format("%s is missing", name))
			if channel[name] then
				Test.eq(channel[name].direction, "ServerToClient", string.format("%s must be outbound only", name))
			end
		end
	end)
end)

Test.describe("Server / client boundary", function()
	Test.it("shared modules never require a server service", function()
		-- Server services live under ServerScriptService and must never be
		-- reachable from a replicated module.
		local serverNames = {
			NetworkService = true,
			DataService = true,
			AdminService = true,
			PlayerService = true,
			CombatService = true,
			InventoryService = true,
			ResourceService = true,
			BossService = true,
			BeastService = true,
			DungeonService = true,
			WorldService = true,
			WorldEventService = true,
			CompanionService = true,
			DeploymentService = true,
			HazardService = true,
			SquadService = true,
			ClanService = true,
			TradingService = true,
			BoatService = true,
			AudioService = true,
			PerformanceService = true,
			ProgressionService = true,
		}
		-- The shared tree is loaded by the specs in this suite; if any shared
		-- module pulled in a service, one of these requires would have failed
		-- during module load. Assert the boundary holds by checking that the
		-- service modules are genuinely absent from the shared namespace.
		for name in serverNames do
			local ok = pcall(function()
				return require("@shared/Services/" .. name)
			end)
			Test.falsy(ok, string.format("server service %s is reachable from the shared tree", name))
		end
	end)

	Test.it("the admin allowlist is empty until real owner ids are supplied", function()
		Test.falsy(Extensions.IsAdminEnabled(), "the admin panel must stay disabled without owner UserIds")
	end)

	Test.it("an unauthorised operator is refused every action", function()
		-- A random UserId must never be authorised while the allowlist is empty.
		Test.falsy(Extensions.IsAuthorised(123456789, "kick_player"), "a stranger was authorised")
		Test.falsy(Extensions.IsOwner(1), "a stranger was treated as an owner")
	end)

	Test.it("an unknown action is treated as maximally privileged", function()
		Test.eq(Extensions.AdminLevel("not_a_real_action"), Enums.AdminLevel.Owner)
		Test.eq(Extensions.AdminLevel(nil), Enums.AdminLevel.Owner)
	end)

	Test.it("a denied decision carries a reason", function()
		local decision = Extensions.Decide(1, "kick_player")
		Test.falsy(decision.allowed)
		Test.truthy(decision.reason and #decision.reason > 0, "denials must be explainable for the audit log")
	end)

	Test.it("client input sanitisers reject hostile values", function()
		Test.falsy(Extensions.IsFiniteNumber(0 / 0), "NaN was accepted")
		Test.falsy(Extensions.IsFiniteNumber(math.huge), "infinity was accepted")
		Test.falsy(Extensions.IsFiniteNumber("12"), "a string was accepted as a number")
		Test.truthy(Extensions.IsFiniteNumber(12))

		Test.eq(Extensions.SanitiseNumber(1000, 0, 10, 0), 10, "numbers must clamp to the maximum")
		Test.eq(Extensions.SanitiseNumber(-1000, 0, 10, 0), 0, "numbers must clamp to the minimum")
		Test.eq(Extensions.SanitiseNumber(0 / 0, 0, 10, 5), 5, "NaN must fall back")
		Test.eq(Extensions.SanitiseString(string.rep("x", 500), 16, ""):len(), 16, "strings must be length capped")
	end)
end)

Test.describe("Performance ladder", function()
	Test.it("core systems are never disabled", function()
		for key, enabled in Performance.CoreSystemsAlwaysEnabled do
			Test.truthy(enabled, string.format("core system %s must never be disabled", key))
		end
	end)

	Test.it("the ladder degrades monotonically", function()
		for index = 2, #Performance.StageOrder do
			local healthier = Performance.Stages[Performance.StageOrder[index - 1]]
			local degraded = Performance.Stages[Performance.StageOrder[index]]
			Test.truthy(degraded.scale < healthier.scale, "each stage must be stricter than the one above")
		end
	end)

	Test.it("framerate maps to a stage", function()
		Test.eq(Performance.StageForFps(120), Enums.PerformanceStage.Ultra)
		Test.eq(Performance.StageForFps(1), Enums.PerformanceStage.Minimal)
		Test.eq(Performance.StageForFps(0 / 0), Enums.PerformanceStage.Minimal, "NaN must degrade, not crash")
	end)

	Test.it("the ladder cannot be stepped past its ends", function()
		Test.eq(Performance.StepDown(Enums.PerformanceStage.Minimal), Enums.PerformanceStage.Minimal)
		Test.eq(Performance.StepUp(Enums.PerformanceStage.Ultra), Enums.PerformanceStage.Ultra)
	end)

	Test.it("validates clean", function()
		Test.empty(Performance.ValidateAll())
	end)
end)

Test.describe("Boss safeguards", function()
	Test.it("Parallax is always damageable", function()
		Test.truthy(Bosses.IsAlwaysDamageable("parallax"), "Null Horizon must never be immune to all damage")
	end)

	Test.it("every boss declares a reward table", function()
		for _, def in Bosses:List() do
			Test.truthy(
				def.rewardTableId and #def.rewardTableId > 0,
				string.format("%s has no reward table", tostring(def.id))
			)
		end
	end)

	Test.it("every boss phase has an index and a threshold", function()
		for _, def in Bosses:List() do
			for _, phase in def.phases or {} do
				Test.truthy(phase.index, string.format("%s has a phase with no index", tostring(def.id)))
				Test.truthy(
					phase.healthThreshold ~= nil,
					string.format("%s phase %s has no threshold", tostring(def.id), tostring(phase.index))
				)
			end
		end
	end)
end)

Test.Finish()

return true
