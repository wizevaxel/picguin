--!strict
--!native
--!optimize 2

local core = require("../roblox_packages/core")
local types = require("./types")

export type DecodeOptions = {
	crc: ("all" | "critical" | "none")?,
	use: {types.AncillaryChunk}?,
}

export type Decoded = core.Decoded<{
	headers: {},
}>

type DecodeContext = {
	source: buffer,
	options: DecodeOptions,

	byte: number,

	decoded: Decoded,
}

local function parse_headers(context: DecodeContext): types.DecodeError?
	local source = context.source
	local byte = context.byte

	local signature = buffer.readstring(source, byte, 8)
	if signature ~= "\137PNG\r\n\26\n" then
		return {
			code = "invalid_signature",
			message = "invalid png signature",
		}
	end

	return nil
end

local function parse_png(source: buffer, options: DecodeOptions): (Decoded?, types.DecodeError)
	local context: DecodeContext = {
		source = source,
		options = options,

		byte = 0,

		decoded = {
			codec = "png",

			width = 0,
			height = 0,
			frames = 0,

			headers = {},

			read = function() end,
		} :: Decoded,
	}

	local err: types.DecodeError?

	err = parse_headers(context)
	if err then return nil, err end

	return context.decoded, {} :: types.DecodeError
end

return function(source: core.DecodeSource, options: DecodeOptions): (Decoded?, types.DecodeError)
	return parse_png(core.convert_source(source), options)
end
