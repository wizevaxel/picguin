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
	| "invalid_chunk"
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
		color_type: types.ColorType,
		bit_depth: number,
		channels: number,
		interlacing: boolean,
	}
}>

type DecodeContext = {
	source: buffer,
	length: number,
	offset: number,

	use: {[types.Chunk]: true},
	options: DecodeOptions,
	decoded: Decoded,
}

local function map<T>(array: {T}): {[T]: true}
	local result: {[T]: true} = {}
	for _, value in array do
		result[value] = true
	end

	return result
end

local CRITICAL_CHUNK_MAP = map {
	"IHDR", "IDAT", "PLTE", "IEND",
} :: {[types.CriticalChunk]: true} & {[types.AncillaryChunk]: nil}
local ANCILLARY_CHUNK_MAP = map {
	"tRNS", "gAMA", "cHRM", "sRGB",
	"iCCP", "pHYs", "bKGD", "tEXt",
	"iTXt", "zTXt", "tIME", "eXIf",
} :: {[types.AncillaryChunk]: true} & {[types.CriticalChunk]: nil}

local BIT_DEPTH_MAP = {
	[0] = map {1, 2, 4, 8, 16},
	[2] = map {8, 16},
	[3] = map {1, 2, 4, 8},
	[4] = map {8, 16},
	[6] = map {8, 16},
}

local function decode_error(code: DecodeErrorCode, message: string): DecodeError
	return {
		code = code,
		message = message,
	}
end

local parse_chunk: {[types.Chunk]: (DecodeContext, chunk_length: number) -> DecodeError?} = {
	["IHDR"] = function(context, chunk_length)
		if chunk_length ~= 13 then
			return decode_error("invalid_length", `invalid IHDR chunk length: expected 13 bytes, got {chunk_length}`)
		end

		local source = context.source
		local offset = context.offset

		local width = bit32.byteswap(buffer.readu32(source, offset))
		local height = bit32.byteswap(buffer.readu32(source, offset + 4))
		if width == 0 or height == 0 then
			return decode_error("invalid_header", `invalid image dimensions: {width}x{height}`)
		end

		local bit_depth = buffer.readu8(source, offset + 8)
		local color_space = buffer.readu8(source, offset + 9)
		if not BIT_DEPTH_MAP[color_space] then
			return decode_error("invalid_header", `invalid color space: {color_space}`)
		elseif not BIT_DEPTH_MAP[color_space][bit_depth] then
			return decode_error("invalid_header", `invalid bit depth: {bit_depth}`)
		end

		local compression = buffer.readu8(source, offset + 10)
		if compression > 0 then
			return decode_error("unsupported", `unsupported compression method: {compression}`)
		end

		local filtering = buffer.readu8(source, offset + 11)
		if filtering > 0 then
			return decode_error("unsupported", `unsupported filter method: {filtering}`)
		end

		local interlacing = buffer.readu8(source, offset + 12)
		if interlacing < 0 or interlacing > 1 then
			return decode_error("invalid_header", `invalid interlacing specifier: {interlacing}`)
		end

		local has_alpha = color_space > 3

		local color_type: types.ColorType =
			(color_space % 4 == 0 and "grayscale")
			or (color_space == 3 and "indexed")
			or "truecolor"

		local channels = 1
			+ (color_type == "truecolor" and 2 or 0)
			+ (has_alpha and 1 or 0)

		local decoded = context.decoded
		decoded.width = width
		decoded.height = height
		decoded.alpha = has_alpha

		decoded.headers.color_type = color_type
		decoded.headers.bit_depth = bit_depth
		decoded.headers.channels = channels
		decoded.headers.interlacing = interlacing == 1

		context.offset += 13

		return nil
	end
}

local function parse_headers(context: DecodeContext): DecodeError?
	local source = context.source
	local length = context.length
	local offset = context.offset

	if offset + 8 > length then
		return decode_error("unexpected_eof", "EOF while reading signature")
	end

	local signature = buffer.readstring(source, offset, 8)
	if signature ~= "\137PNG\r\n\26\n" then
		return decode_error("invalid_signature", "invalid PNG signature")
	end

	offset += 8

	local options = context.options
	local use = context.use
	local crc_check = options.crc

	while true do
		if offset + 8 > length then
			return decode_error("unexpected_eof", "EOF without IEND chunk")
		end

		local chunk_length = bit32.byteswap(buffer.readu32(source, offset))
		local chunk_type = buffer.readstring(source, offset + 4, 4) :: types.Chunk
		offset += 8

		if chunk_type == "IEND" then
			break
		else
			if offset + chunk_length + 4 > length then
				return decode_error("unexpected_eof", `EOF while reading {chunk_type} chunk`)
			end
		end

		local critical = CRITICAL_CHUNK_MAP[chunk_type] ~= nil
		if critical or use[chunk_type] then
			context.offset = offset
			parse_chunk[chunk_type](context, chunk_length)

			if crc_check == "all" or (critical and crc_check == "critical") then
				local crc = bit32.byteswap(buffer.readu32(source, offset + chunk_length))
				if crc ~= crc32(source, offset - 4, chunk_length + 4) then
					return decode_error("invalid_crc", `invalid checksum in {chunk_type} chunk`)
				end
			end
		elseif not ANCILLARY_CHUNK_MAP[chunk_type] then
			return decode_error("invalid_chunk", `invalid chunk type: {chunk_type}`)
		end

		offset += chunk_length + 4
	end

	context.offset = offset

	return nil
end

local function parse_png(source: buffer, options: DecodeOptions): (Decoded?, DecodeError)
	local context: DecodeContext = {
		source = source,
		length = buffer.len(source),
		offset = 0,

		use = map((options.use or {}) :: {types.Chunk}),
		options = options,
		decoded = {
			codec = "png",

			headers = {},
		} :: Decoded,
	}

	local err: DecodeError?

	err = parse_headers(context)
	if err then return nil, err end

	return context.decoded, {} :: DecodeError
end

return function(source: core.DecodeSource, options: DecodeOptions): (Decoded?, DecodeError)
	return parse_png(core.convert_source(source), options)
end
