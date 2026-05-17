--!strict
--!native
--!optimize 2

local types = require("./types")
local crc32 = require("./crc32")
local zlib = require("./zlib")

export type DecodeErrorCode =
	| "unsupported"
	| "overflow"
	| "unexpected_eof"
	| "invalid_signature"
	| "invalid_crc"
	| "invalid_length"
	| "invalid_header"
	| "unknown_chunk"
	| "missing_chunk"
export type DecodeError = types.Error<DecodeErrorCode>

export type ReadErrorCode =
	| zlib.DecompressErrorCode
	| "invalid_filter"
export type ReadError = types.Error<ReadErrorCode>

export type ColorTarget =
	| "rgba8"
	| "rgba16"

export type Parsed = {
	width: number,
	height: number,
	frames: number,
	alpha: boolean,

	headers: {
		interlacing: boolean,
		channels: number,
		bit_depth: number,
		color_space: types.ColorSpace,
	},
	palette: {number}?,

	read: (frame: number?, target: ColorTarget?) -> (Cel?, ReadError),
}

export type Cel = {
	bitmap: buffer,
	region: BitmapRegion,
	duration: number,
}

export type BitmapRegion = {
	size: vector,
	position: vector,
}

export type DecodeOptions = {
	crc: ("all" | "critical" | "none")?,
}

type DecodeContext = {
	source: buffer,
	length: number,

	crc: ("all" | "critical" | "none"),

	ranges: {[types.Chunk]: SourceSpans},
	parsed: Parsed,
}

type SourceSpans = {number}

local function map<T>(t: {T}): {[T]: true}
	local out: {[T]: true} = {}
	for _, value in t do
		out[value] = true
	end

	return out
end

local function decode_error(code: DecodeErrorCode, message: string): DecodeError
	return {code = code, message = message}
end

local function read_error(code: ReadErrorCode, message: string): ReadError
	return {code = code, message = message}
end

local MAX_BUFFER_SIZE = 2 ^ 30

local SIGNATURE = "\x89PNG\x0D\x0A\x1A\x0A"

local CRITICAL_CHUNK_MAP = map {
	"IHDR", "IDAT", "PLTE", "IEND",
} :: {[types.CriticalChunk]: true} & {[types.AncillaryChunk]: nil}

local COLOR_TYPE_MAP: {[number]: {color_space: types.ColorSpace, channels: number, bit_depths: {[number]: true}}} = {
	[0] = {color_space = "grayscale", channels = 1, bit_depths = map {1, 2, 4, 8, 16}},
	[2] = {color_space = "truecolor", channels = 3, bit_depths = map {8, 16}},
	[3] = {color_space = "indexed", channels = 1, bit_depths =  map {1, 2, 4, 8}},
	[4] = {color_space = "grayscale", channels = 2, bit_depths = map {8, 16}},
	[6] = {color_space = "truecolor", channels = 4, bit_depths = map {8, 16}},
}

local CHUNK_PARSER: {[types.Chunk]: (DecodeContext, SourceSpans) -> DecodeError?} = {
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
		elseif interlacing == 1 then
			return decode_error("unsupported", "interlacing is not supported")
		end

		local alpha = color_type > 3
		local color_space = color_info.color_space
		local channels = color_info.channels

		local parsed = context.parsed
		parsed.width = width
		parsed.height = height
		parsed.frames = 0
		parsed.alpha = alpha

		local headers = parsed.headers
		headers.interlacing = interlacing == 1
		headers.color_space = color_space
		headers.bit_depth = bit_depth
		headers.channels = channels

		return nil
	end,
	["PLTE"] = function(context, chunk_ranges)
		local chunk_offset = chunk_ranges[1]
		local chunk_length = chunk_ranges[2]
		if chunk_length == 0 or chunk_length > 768 or chunk_length % 3 ~= 0 then
			return decode_error("invalid_length", `invalid PLTE chunk length: expected 3-768 bytes in multiples of 3, got {chunk_length}`)
		end

		local source = context.source

		local palette = table.create(chunk_length // 3, 0xFF000000)
		context.parsed.palette = palette

		for index = 0, chunk_length // 3 - 1 do
			local offset = chunk_offset + index * 3
			palette[index + 1] += buffer.readu16(source, offset) + buffer.readu8(source, offset + 2) * 0x10000
		end

		return nil
	end,
	["tRNS"] = function(context, chunk_ranges)
		local chunk_offset = chunk_ranges[1]
		local chunk_length = chunk_ranges[2]

		local source = context.source
		local parsed = context.parsed

		if parsed.headers.color_space == "indexed" then
			local palette = parsed.palette
			if not palette then return nil end

			local count = math.min(chunk_length, #palette)
			local offset = chunk_offset - 1
			for index = 1, count do
				palette[index] = palette[index] % 0x1000000 + buffer.readu8(source, offset + index) * 0x1000000
			end
		end

		return nil
	end,
	["IEND"] = function(context, chunk_ranges)
		if not context.ranges["IDAT"] then
			return decode_error("missing_chunk", "missing IDAT chunk")
		end

		if context.parsed.headers.color_space == "indexed" and not context.ranges["PLTE"] then
			return decode_error("missing_chunk", "missing PLTE chunk with indexed color type")
		end

		return nil
	end,
}

local CONVERT_COLOR: {[types.ColorSpace]: (DecodeContext, buffer) -> buffer} = {
	["truecolor"] = function(context, data)
		local length = buffer.len(data)
		local parsed = context.parsed
		local headers = parsed.headers

		local channels = headers.channels
		local bit_depth = headers.bit_depth

		local transparency: number?
		if context.ranges["tRNS"] then
			local source = context.source
			local offset = context.ranges["tRNS"][1]

			if bit_depth == 16 then
				transparency = bit32.byteswap(buffer.readu16(source, offset) * 0x10000)
					+ bit32.byteswap(buffer.readu16(source, offset + 2))
					+ bit32.byteswap(buffer.readu16(source, offset + 4)) * 0x10000
			else
				transparency = buffer.readu8(source, offset)
					+ buffer.readu8(source, offset + 2) * 0x100
					+ buffer.readu8(source, offset + 4) * 0x10000
			end
		end

		local out = buffer.create(parsed.width * parsed.height * (bit_depth == 16 and 2 or 1) * 4)

		if bit_depth == 16 then
			if channels == 4 then
				buffer.copy(out, 0, data, 0, length)
			else
				local cursor = 0
				for offset = 0, length - 1, 6 do
					local value = bit32.byteswap(buffer.readu16(data, offset) * 0x10000)
						+ bit32.byteswap(buffer.readu16(data, offset + 2))
						+ bit32.byteswap(buffer.readu16(data, offset + 4)) * 0x10000
					buffer.writeu32(out, cursor, value % 0x100000000)
					buffer.writeu32(out, cursor + 4, value // 0x100000000 + (value == transparency and 0 or 0xFFFF0000))
					cursor += 8
				end
			end
		else
			if channels == 4 then
				buffer.copy(out, 0, data, 0, length)
			else
				local cursor = 0
				for offset = 0, length - 1, 3 do
					local value = buffer.readu16(data, offset) + buffer.readu8(data, offset + 2) * 0x10000
					buffer.writeu32(out, cursor, value + (value == transparency and 0 or 0xFF000000))
					cursor += 4
				end
			end
		end

		return out
	end,
	["grayscale"] = function(context, data)
		local length = buffer.len(data)
		local parsed = context.parsed
		local headers = parsed.headers

		local channels = headers.channels
		local bit_depth = headers.bit_depth

		local transparency = -1
		if context.ranges["tRNS"] then
			local source = context.source
			local offset = context.ranges["tRNS"][1]

			if bit_depth == 8 then
				transparency = buffer.readu8(source, offset)
			elseif bit_depth == 16 then
				transparency = bit32.byteswap(buffer.readu16(source, offset) * 0x10000)
			end
		end

		local out = buffer.create(parsed.width * parsed.height * (bit_depth == 16 and 2 or 1) * 4)

		if bit_depth == 16 then
			if channels == 2 then
				local cursor = 0
				for offset = 0, length - 1, 4 do
					local value = bit32.byteswap(buffer.readu16(data, offset) * 0x10000)
					buffer.writeu32(out, cursor, value + value * 0x10000)
					buffer.writeu32(out, cursor + 4, value + bit32.byteswap(buffer.readu16(data, offset + 2)))
					cursor += 4
				end
			else
				local cursor = 0
				for offset = 0, length - 1, 2 do
					local value = bit32.byteswap(buffer.readu16(data, offset) * 0x10000)
					buffer.writeu32(out, cursor, value + value * 0x10000)
					buffer.writeu32(out, cursor + 4, value + (value == transparency and 0 or 0xFFFF0000))
					cursor += 4
				end
			end
		elseif bit_depth == 8 then
			if channels == 2 then
				local cursor = 0
				for offset = 0, length - 1, 2 do
					local value = buffer.readu8(data, offset)
					buffer.writeu32(out, cursor, value + value * 0x100 + value * 0x10000 + buffer.readu8(data, offset + 1) * 0x1000000)
					cursor += 4
				end
			else
				local cursor = 0
				for offset = 0, length - 1, 1 do
					local value = buffer.readu8(data, offset)
					buffer.writeu32(out, cursor, value + value * 0x100 + value * 0x10000 + (value == transparency and 0 or 0xFF000000))
					cursor += 4
				end
			end
		else
			local scale = 255 // (2 ^ bit_depth - 1)
			local field = 8 - bit_depth
			local cursor = 0
			for offset = 0, length - 1, 1 do
				local byte = buffer.readu8(data, offset)
				for shift = field, 0, -bit_depth do
					local value = bit32.extract(byte, shift, bit_depth) * scale
					buffer.writeu32(out, cursor, value + value * 0x100 + value * 0x10000 + (value == transparency and 0 or 0xFF000000))
					cursor += 4
				end
			end
		end

		return out
	end,
	["indexed"] = function(context, data)
		local length = buffer.len(data)
		local parsed = context.parsed
		local headers = parsed.headers

		local palette = assert(parsed.palette)
		local bit_depth = headers.bit_depth

		local out = buffer.create(parsed.width * parsed.height * 4)

		if bit_depth == 8 then
			local cursor = 0
			for offset = 0, length - 1, 1 do
				buffer.writeu32(out, cursor, palette[buffer.readu8(data, offset) + 1])
				cursor += 4
			end
		else
			local field = 8 - bit_depth
			local cursor = 0
			for offset = 0, length - 1, 1 do
				local byte = buffer.readu8(data, offset)
				for shift = field, 0, -bit_depth do
					buffer.writeu32(out, cursor, palette[bit32.extract(byte, shift, bit_depth) + 1])
					cursor += 4
				end
			end
		end

		return out
	end,
}

local CONVERT_TARGET: {[ColorTarget]: (DecodeContext, buffer) -> buffer} = {
	["rgba8"] = function(context, data)
		local parsed = context.parsed
		if parsed.headers.bit_depth < 16 then return data end

		local out = buffer.create(parsed.width * parsed.height * 4)

		local cursor = 0
		for offset = 0, buffer.len(data) - 1, 8 do
			local r = buffer.readu16(data, offset) // 0x101
			local g = buffer.readu16(data, offset + 2) // 0x101
			local b = buffer.readu16(data, offset + 4) // 0x101
			local a = buffer.readu16(data, offset + 6) // 0x101
			buffer.writeu32(out, cursor, r + g * 0x100 + b * 0x10000 + a * 0x1000000)
			cursor += 4
		end

		return out
	end,
	["rgba16"] = function(context, data)
		local parsed = context.parsed
		if parsed.headers.bit_depth == 16 then return data end

		local out = buffer.create(parsed.width * parsed.height * 2 * 4)

		local cursor = 0
		for offset = 0, buffer.len(data) - 1, 4 do
			local r = buffer.readu8(data, offset) * 0x101
			local g = buffer.readu8(data, offset + 1) * 0x101
			local b = buffer.readu8(data, offset + 2) * 0x101
			local a = buffer.readu8(data, offset + 3) * 0x101
			buffer.writeu32(out, cursor, r + g * 0x10000)
			buffer.writeu32(out, cursor + 4, b + a * 0x10000)
			cursor += 8
		end

		return out
	end,
}

local function unfilter(parsed: Parsed, data: buffer): (buffer?, ReadError)
	local headers = parsed.headers

	local bpp = (headers.bit_depth * headers.channels + 7) // 8
	local row_width = (parsed.width * headers.bit_depth * headers.channels + 7) // 8

	local out = buffer.create(parsed.height * row_width)

	local offset = 0
	local cursor = 0

	for y = 1, parsed.height do
		local filter = buffer.readu8(data, offset)
		offset += 1

		if filter == 0 or (filter == 2 and y == 1) then
			buffer.copy(out, cursor, data, offset, row_width)
			offset += row_width
			cursor += row_width
		elseif filter == 1 then
			for x = 1, row_width do
				local a = x > bpp and buffer.readu8(out, cursor - bpp) or 0
				local value = buffer.readu8(data, offset) + a
				buffer.writeu8(out, cursor, value % 0x100)
				offset += 1
				cursor += 1
			end
		elseif filter == 2 then
			for _ = 1, row_width do
				local b = buffer.readu8(out, cursor - row_width)
				local value = buffer.readu8(data, offset) + b
				buffer.writeu8(out, cursor, value % 0x100)
				offset += 1
				cursor += 1
			end
		elseif filter == 3 then
			for x = 1, row_width do
				local a = x > bpp and buffer.readu8(out, cursor - bpp) or 0
				local b = y > 1 and buffer.readu8(out, cursor - row_width) or 0
				local value = buffer.readu8(data, offset) + (a + b) // 2
				buffer.writeu8(out, cursor, value % 0x100)
				offset += 1
				cursor += 1
			end
		elseif filter == 4 then
			for x = 1, row_width do
				local a = x > bpp and buffer.readu8(out, cursor - bpp) or 0
				local b = y > 1 and buffer.readu8(out, cursor - row_width) or 0
				local c = (y > 1 and x > bpp) and buffer.readu8(out, cursor - row_width - bpp) or 0
				local p = a + b - c
				local pa = math.abs(p - a)
				local pb = math.abs(p - b)
				local pc = math.abs(p - c)
				local paeth = (pa <= pb and pa <= pc and a) or (pb <= pc and b) or c
				local value = buffer.readu8(data, offset) + paeth
				buffer.writeu8(out, cursor, value % 0x100)
				offset += 1
				cursor += 1
			end
		else
			return nil, read_error("invalid_filter", `invalid row filter: {filter}`)
		end
	end

	return out, {code = "ok", message = ""}
end

local function concatenate_ranges(source: buffer, ranges: SourceSpans): buffer
	local out_size = 0
	for size = 2, #ranges, 2 do
		out_size += ranges[size]
	end

	local out = buffer.create(out_size)
	local cursor = 0
	for index = 1, #ranges, 2 do
		local size = ranges[index + 1]
		buffer.copy(out, cursor, source, ranges[index], size)
		cursor += size
	end

	return out
end

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

	local parsed = context.parsed
	local crc_mode = context.crc

	local order: {types.Chunk} = {}
	local ranges = context.ranges

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

		local chunk_ranges = ranges[chunk_type]
		if not chunk_ranges then
			chunk_ranges = {}
			ranges[chunk_type] = chunk_ranges
		end

		table.insert(chunk_ranges, offset)
		table.insert(chunk_ranges, chunk_length)
		table.insert(order, chunk_type)

		offset += chunk_length + 4

		if chunk_type == "IEND" then break end
	end

	for _, chunk_type in order do
		local parser = CHUNK_PARSER[chunk_type]
		if parser then
			local err = parser(context, ranges[chunk_type])
			if err then return err end
		end
	end

	local out_size = parsed.height * ((parsed.width * parsed.headers.channels * parsed.headers.bit_depth + 7) // 8 + 1)
	if out_size > MAX_BUFFER_SIZE then
		return decode_error("overflow", "predetermined decompressed image data size exceeds buffer limits")
	end

	parsed.read = function(frame: number?, target: ColorTarget?): (Cel?, ReadError)
		frame = frame and frame // 1 or 0
		target = target or "rgba8" :: ColorTarget

		local decompressed, err0 = zlib.decompress(concatenate_ranges(source, ranges["IDAT"]), out_size)
		if not decompressed then return nil, err0 :: ReadError end
		local unfiltered, err1 = unfilter(parsed, decompressed)
		if not unfiltered then return nil, err1 :: ReadError end

		local converted = CONVERT_COLOR[parsed.headers.color_space](context, unfiltered)
		local bitmap = CONVERT_TARGET[target](context, converted)

		return {
			bitmap = bitmap,
			region = {
				size = vector.create(parsed.width, parsed.height),
				position = vector.zero
			},
			duration = 0,
		}, {code = "ok", message = ""}
	end

	return nil
end

return function(source: buffer | string, options: DecodeOptions?): (Parsed?, DecodeError)
	source = type(source) == "buffer" and source or buffer.fromstring(source)
	options = options or {} :: DecodeOptions

	local context: DecodeContext = {
		source = source,
		length = buffer.len(source),

		crc = options.crc or "all" :: "all",

		ranges = {},
		parsed = {
			headers = {},
		} :: Parsed,
	}

	local err = parse_png(context)
	if err then return nil, err end

	return context.parsed, {code = "ok", message = ""}
end
