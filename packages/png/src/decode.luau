--!strict
--!native
--!optimize 2

local core = require("../roblox_packages/core")
local types = require("./types")
local crc32 = require("./crc32")

export type DecodeErrorCode =
	| core.ErrorCode
	| "invalid_signature"
	| "invalid_crc"
	| "invalid_length"
	| "invalid_header"
	| "unknown_chunk"
export type DecodeError = core.Error<DecodeErrorCode>

export type ReadErrorCode =
	| core.ErrorCode
export type ReadError = core.Error<ReadErrorCode>

export type DecodeOptions = {
	crc: ("all" | "critical" | "none")?,
	use: {types.AncillaryChunk}?,
}

export type Decoded = core.Decoded<ReadErrorCode, {
	alpha: boolean,

	headers: {
		color_space: types.ColorSpace,
		bit_depth: number,
		channels: number,
		interlacing: boolean,
	},
	_ranges: {source: buffer} & {[types.Chunk]: SourceRanges},
}>

type DecodeContext = {
	source: buffer,
	length: number,

	crc: ("all" | "critical" | "none"),
	use: {[types.Chunk]: true},

	decoded: Decoded,
}

type SourceRanges = {number}

local function map<T>(array: {T}): {[T]: true}
	local result: {[T]: true} = {}
	for _, value in array do
		result[value] = true
	end

	return result
end

local function decode_error(code: DecodeErrorCode, message: string): DecodeError
	return {code = code, message = message}
end

local SIGNATURE = "\x89PNG\x0D\x0A\x1A\x0A"

local CRITICAL_CHUNK_MAP = map {
	"IHDR", "IDAT", "PLTE", "IEND",
} :: {[types.CriticalChunk]: true} & {[types.AncillaryChunk]: nil}

local COLOR_TYPE_MAP: {[number]: {color_space: types.ColorSpace, bit_depths: {[number]: true}}} = {
	[0] = {color_space = "grayscale", bit_depths = map {1, 2, 4, 8, 16}},
	[2] = {color_space = "truecolor", bit_depths = map {8, 16}},
	[3] = {color_space = "indexed", bit_depths =  map {1, 2, 4, 8}},
	[4] = {color_space = "grayscale", bit_depths = map {8, 16}},
	[6] = {color_space = "truecolor", bit_depths = map {8, 16}},
}

local CHUNK_PARSER_MAP: {[types.Chunk]: (DecodeContext, SourceRanges) -> DecodeError?} = {
	["IHDR"] = function(context, chunk_ranges)
		local chunk_offset = chunk_ranges[1]
		local chunk_length = chunk_ranges[2]
		if chunk_length ~= 13 then
			return decode_error("invalid_length", `invalid IHDR chunk length: expected 13 bytes, got {chunk_length}`)
		end

		local source = context.source

		local width = bit32.byteswap(buffer.readu32(source, chunk_offset))
		local height = bit32.byteswap(buffer.readu32(source, chunk_offset + 4))
		if width == 0 or height == 0 then
			return decode_error("invalid_header", `invalid image dimensions: {width}x{height}`)
		end

		local bit_depth = buffer.readu8(source, chunk_offset + 8)
		local color_type = buffer.readu8(source, chunk_offset + 9)
		local color_info = COLOR_TYPE_MAP[color_type]
		if not color_info then
			return decode_error("invalid_header", `invalid color type: {color_type}`)
		elseif not color_info.bit_depths[bit_depth] then
			return decode_error("invalid_header", `invalid bit depth: {bit_depth}`)
		end

		local compression = buffer.readu8(source, chunk_offset + 10)
		if compression > 0 then
			return decode_error("unsupported", `unsupported compression method: {compression}`)
		end

		local filtering = buffer.readu8(source, chunk_offset + 11)
		if filtering > 0 then
			return decode_error("unsupported", `unsupported filter method: {filtering}`)
		end

		local interlacing = buffer.readu8(source, chunk_offset + 12)
		if interlacing > 1 then
			return decode_error("invalid_header", `invalid interlacing specifier: {interlacing}`)
		end

		local alpha = color_type > 3
		local color_space = color_info.color_space

		local decoded = context.decoded
		decoded.width = width
		decoded.height = height
		decoded.alpha = alpha

		decoded.headers.color_space = color_space
		decoded.headers.bit_depth = bit_depth
		decoded.headers.channels = 1 + (color_space == "truecolor" and 2 or 0) + (alpha and 1 or 0)
		decoded.headers.interlacing = interlacing == 1

		return nil
	end,
	["PLTE"] = function(context, chunk_ranges)
		local chunk_length = chunk_ranges[2]
		if chunk_length == 0 or chunk_length > 768 or chunk_length % 3 ~= 0 then
			return decode_error("invalid_length", `invalid PLTE chunk length: expected 3-768 bytes in multiples of 3, got {chunk_length}`)
		end

		return nil
	end,
}

local function parse_png(context: DecodeContext): DecodeError?
	local source = context.source
	local length = context.length
	if length < 8 then
		return decode_error("unexpected_eof", "EOF while reading signature")
	end

	local signature = buffer.readstring(source, 0, 8)
	if signature ~= SIGNATURE then
		return decode_error("invalid_signature", "invalid PNG signature")
	end

	local offset = 8

	local crc_mode = context.crc
	local use = context.use
	local ranges = context.decoded._ranges

	while true do
		if offset + 8 > length then
			return decode_error("unexpected_eof", "EOF without IEND chunk")
		end

		local chunk_length = bit32.byteswap(buffer.readu32(source, offset))
		local chunk_type = buffer.readstring(source, offset + 4, 4) :: types.Chunk
		offset += 8

		if offset + chunk_length + 4 > length then
			return decode_error("unexpected_eof", `EOF while reading {chunk_type} chunk`)
		end

		local critical = bit32.band(string.byte(chunk_type), 0x20) == 0
		if critical and not CRITICAL_CHUNK_MAP[chunk_type] then
			return decode_error("unknown_chunk", `unknown critical chunk type: {chunk_type}`)
		end

		if crc_mode == "all" or (critical and crc_mode == "critical") then
			local crc = bit32.byteswap(buffer.readu32(source, offset + chunk_length))
			if crc ~= crc32(source, offset - 4, chunk_length + 4) then
				return decode_error("invalid_crc", `invalid checksum in {chunk_type} chunk`)
			end
		end

		if critical or use[chunk_type] then
			local chunk_ranges = ranges[chunk_type]
			if not chunk_ranges then
				chunk_ranges = {}
				ranges[chunk_type] = chunk_ranges
			end

			table.insert(chunk_ranges, offset)
			table.insert(chunk_ranges, chunk_length)
		end

		offset += chunk_length + 4

		if chunk_type == "IEND" then break end
	end

	for chunk_type, chunk_ranges in ranges do
		local parser = CHUNK_PARSER_MAP[chunk_type]
		if parser then
			local err = parser(context, chunk_ranges)
			if err then return err end
		end
	end

	return nil
end

return function(source: core.DecodeSource, options: DecodeOptions?): (Decoded?, DecodeError)
	source = core.convert_source(source)
	options = options or {} :: DecodeOptions

	local context: DecodeContext = {
		source = source,
		length = buffer.len(source),

		crc = options.crc or "all" :: "all",
		use = map((options.use or {}) :: {types.Chunk}),

		decoded = {
			codec = "png",

			headers = {},
			_ranges = {source = source},
		} :: Decoded,
	}

	local err = parse_png(context)
	if err then return nil, err end

	return context.decoded, nil :: any
end
