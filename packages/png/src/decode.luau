--!strict
--!native
--!optimize 2

local core = require("../roblox_packages/core")
local types = require("./types")

return function(source: core.DecodeSource): types.Decoded
	source = core.convert_source(source)

	return {} :: types.Decoded
end
