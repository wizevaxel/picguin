--!strict
--!native
--!optimize 2

local core = require("../roblox_packages/core")
local types = require("./types")

return function(source: core.DecodeSource): types.Decoder
	source = core.convert_source(source)

	return {} :: types.Decoder
end
