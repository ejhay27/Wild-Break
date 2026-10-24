--!strict
--[[
	Symbol audit.
	tools/run_tests.py statically collects every Enums.X.Y and Limits.X.Y
	reference in src/ and tests/ into tests/_symbols.luau. This spec proves
	each one actually resolves, which catches silently-nil constants that a
	compile-only check can never see.
]]

local Test = require("../harness/Harness")
local Enums = require("@shared/Constants/Enums")
local Limits = require("@shared/Constants/Limits")

local audit = require("../_symbols")

Test.describe("Constants", function()
	Test.it("every referenced Enums member exists", function()
		local missing = {}
		for tableName, keys in audit.enums do
			local container = (Enums :: any)[tableName]
			if container == nil then
				table.insert(missing, string.format("Enums.%s is nil (used for %s)", tableName, table.concat(keys, ", ")))
				continue
			end
			for _, key in keys do
				if container[key] == nil then
					table.insert(missing, string.format("Enums.%s.%s is nil", tableName, key))
				end
			end
		end
		Test.empty(missing, "missing enum members")
	end)

	Test.it("every referenced Limits member exists", function()
		local missing = {}
		for tableName, keys in audit.limits do
			local container = (Limits :: any)[tableName]
			if container == nil then
				table.insert(missing, string.format("Limits.%s is nil (used for %s)", tableName, table.concat(keys, ", ")))
				continue
			end
			for _, key in keys do
				if container[key] == nil then
					table.insert(missing, string.format("Limits.%s.%s is nil", tableName, key))
				end
			end
		end
		Test.empty(missing, "missing limit members")
	end)

	Test.it("the audit actually collected symbols", function()
		local count = 0
		for _ in audit.enums do
			count += 1
		end
		Test.gte(count, 10, "enum tables audited")
	end)
end)

Test.Finish()

return true
