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

export type CelErrorCode =
	| zlib.DecompressErrorCode
	| "invalid_filter"
	| "invalid_option"
export type CelError = types.Error<CelErrorCode>

export type DecodeOptions = {
	crc: ("all" | "critical" | "none")?,
}

export type Parsed = {
	width: number,
	height: number,
	frames: number,
	plays: number,
	alpha: boolean,

	headers: {
		interlacing: boolean,
		channels: number,
		bit_depth: number,
		color_space: types.ColorSpace,
	},
	palette: {number}?,

	cel: (frame: number?, target: ColorTarget?) -> (Cel?, CelError),
}

export type Cel = {
	bitmap: buffer,
	region: BitmapRegion,
	duration: number,

	dispose: types.DisposeOperation,
	blend: types.BlendOperation,
}

export type ColorTarget =
	| "rgba8"
	| "rgba16"

export type BitmapRegion = {
	size: vector,
	position: vector,
}

type DecodeContext = {
	source: buffer,
	length: number,

	crc: ("all" | "critical" | "none"),

	frames: {FrameContext},
	frame: FrameContext | false,

	spans: {[types.Chunk]: SourceSpans},
	parsed: Parsed,
}

type FrameContext = {
	width: number,
	height: number,
	x: number,
	y: number,

	dispose: types.DisposeOperation,
	blend: types.BlendOperation,
	duration: number,

	row_size: number,
	out_size: number,
	spans: SourceSpans,
}

type SourceSpans = {number}

local function map<T>(t: {T}): {[T]: true}
	local out: {[T]: true} = {}
	for _, value in t do
		out[value] = true
	end

	return out
end

local function ok(): {code: "ok", message: ""}
	return {code = "ok", message = ""}
end

local function decode_error(code: DecodeErrorCode, message: string): DecodeError
	return {code = code, message = message}
end

local function cel_error(code: CelErrorCode, message: string): CelError
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

local DISPOSE_OP_MAP: {[number]: types.DisposeOperation} = {
	[0] = "none",
	[1] = "background",
	[2] = "previous",
}
local BLEND_OP_MAP: {[number]: types.BlendOperation} = {
	[0] = "source",
	[1] = "over",
}

local CHUNK_PARSER: {[types.Chunk]: (DecodeContext, SourceSpans, number) -> DecodeError?} = {
	["IHDR"] = function(context, chunk_spans, spans_index)
		local chunk_offset = chunk_spans[spans_index]
		local chunk_length = chunk_spans[spans_index + 1]
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

		local alpha = color_type > 3
		local color_space = color_info.color_space
		local channels = color_info.channels

		local row_size = (width * bit_depth * channels + 7) // 8
		local out_size = height * row_size
		if out_size + height > MAX_BUFFER_SIZE then
			return decode_error("overflow", "predetermined decompressed output too large")
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
			return decode_error("unsupported", "interlacing is unsupported")
		end

		local parsed = context.parsed
		parsed.width = width
		parsed.height = height
		parsed.frames = 1
		parsed.alpha = alpha

		local headers = parsed.headers
		headers.interlacing = interlacing == 1
		headers.color_space = color_space
		headers.bit_depth = bit_depth
		headers.channels = channels

		local frame: FrameContext = {
			width = parsed.width,
			height = parsed.height,
			x = 0,
			y = 0,

			dispose = "none",
			blend = "source",
			duration = 0,

			row_size = row_size,
			out_size = out_size,
			spans = {},
		}
		context.frames[0] = frame
		context.frame = frame

		return nil
	end,
	["acTL"] = function(context, chunk_spans, spans_index)
		local chunk_offset = chunk_spans[spans_index]
		local chunk_length = chunk_spans[spans_index + 1]
		if chunk_length ~= 8 then
			return decode_error("invalid_length", `invalid acTL chunk length: expected 8 bytes, got {chunk_length}`)
		end

		context.parsed.frames = bit32.byteswap(buffer.readu32(context.source, chunk_offset))
		context.parsed.plays = bit32.byteswap(buffer.readu32(context.source, chunk_offset + 4))

		return nil
	end,
	["PLTE"] = function(context, chunk_spans, spans_index)
		local chunk_offset = chunk_spans[spans_index]
		local chunk_length = chunk_spans[spans_index + 1]
		if chunk_length < 3 or chunk_length > 768 then
			return decode_error("invalid_length", `invalid PLTE chunk length: expected 3-768 bytes, got {chunk_length}`)
		elseif chunk_length % 3 ~= 0 then
			return decode_error("invalid_length", `invalid PLTE chunk length: expected a multiple of 3, got {chunk_length}`)
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
	["tRNS"] = function(context, chunk_spans, spans_index)
		local chunk_offset = chunk_spans[spans_index]
		local chunk_length = chunk_spans[spans_index + 1]

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
	["fcTL"] = function(context, chunk_spans, spans_index)
		local chunk_offset = chunk_spans[spans_index]
		local chunk_length = chunk_spans[spans_index + 1]
		if chunk_length ~= 26 then
			return decode_error("invalid_length", `invalid fcTL chunk length: expected 26 bytes, got {chunk_length}`)
		end

		local source = context.source
		local headers = context.parsed.headers

		local width = bit32.byteswap(buffer.readu32(source, chunk_offset + 4))
		local height = bit32.byteswap(buffer.readu32(source, chunk_offset + 8))
		if width == 0 or height == 0 then
			return decode_error("invalid_header", `invalid image dimensions: {width}x{height}`)
		end

		local x = bit32.byteswap(buffer.readu32(source, chunk_offset + 12))
		local y = bit32.byteswap(buffer.readu32(source, chunk_offset + 16))

		local dispose_op = buffer.readu8(source, chunk_offset + 24)
		local dispose = DISPOSE_OP_MAP[dispose_op]
		if not dispose then
			return decode_error("invalid_header", `invalid dispose_op: {dispose_op}`)
		end

		local blend_op = buffer.readu8(source, chunk_offset + 25)
		local blend = BLEND_OP_MAP[blend_op]
		if not blend then
			return decode_error("invalid_header", `invalid blend_op: {blend_op}`)
		end

		local delay_num = bit32.byteswap(buffer.readu16(source, chunk_offset + 20) * 0x10000)
		local delay_den = bit32.byteswap(buffer.readu16(source, chunk_offset + 22) * 0x10000)

		local row_size = (width * headers.bit_depth * headers.channels + 7) // 8
		local out_size = height * row_size
		if out_size + height > MAX_BUFFER_SIZE then
			return decode_error("overflow", `frame {#context.frames + 1} predetermined decompressed output too large`)
		end

		local frame: FrameContext = {
			width = width,
			height = height,
			x = x,
			y = y,

			dispose = dispose,
			blend = blend,
			duration = delay_num / (delay_den == 0 and 100 or delay_den),

			row_size = row_size,
			out_size = out_size,
			spans = {},
		}
		table.insert(context.frames, frame)
		context.frame = frame

		return nil
	end,
	["IDAT"] = function(context, chunk_spans, spans_index)
		local chunk_offset = chunk_spans[spans_index]
		local chunk_length = chunk_spans[spans_index + 1]

		local frame = context.frame
		if frame then
			table.insert(frame.spans, chunk_offset)
			table.insert(frame.spans, chunk_length)
		end

		return nil
	end,
	["fdAT"] = function(context, chunk_spans, spans_index)
		local chunk_offset = chunk_spans[spans_index]
		local chunk_length = chunk_spans[spans_index + 1]
		if chunk_length < 4 then
			return decode_error("invalid_length", `invalid fdAT chunk length: expected less than 4 bytes, got {chunk_length}`)
		end

		local frame = context.frame
		if frame then
			table.insert(frame.spans, chunk_offset + 4)
			table.insert(frame.spans, chunk_length - 4)
		end

		return nil
	end,
	["IEND"] = function(context, chunk_spans, spans_index)
		if not context.spans["IDAT"] then
			return decode_error("missing_chunk", "missing IDAT chunk")
		end

		if context.parsed.headers.color_space == "indexed" and not context.spans["PLTE"] then
			return decode_error("missing_chunk", "missing PLTE chunk with indexed color type")
		end

		context.frame = false

		return nil
	end,
}

local CONVERT_COLOR: {[types.ColorSpace]: (DecodeContext, FrameContext, buffer) -> buffer} = {
	["truecolor"] = function(context, frame, data)
		local length = buffer.len(data)
		local parsed = context.parsed
		local headers = parsed.headers

		local channels = headers.channels
		local bit_depth = headers.bit_depth

		local transparency: number?
		if context.spans["tRNS"] then
			local source = context.source
			local offset = context.spans["tRNS"][1]

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

		local out = buffer.create(frame.width * frame.height * (bit_depth == 16 and 2 or 1) * 4)

		if bit_depth == 16 then
			if channels == 4 then
				local cursor = 0
				for offset = 0, length - 1, 4 do
					local value0 = bit32.byteswap(buffer.readu16(data, offset) * 0x10000)
						+ bit32.byteswap(buffer.readu16(data, offset + 2))
					local value1 = bit32.byteswap(buffer.readu16(data, offset + 4))
						+ bit32.byteswap(buffer.readu16(data, offset + 6))
					buffer.writeu32(out, cursor, value0)
					buffer.writeu32(out, cursor + 4, value1 + bit32.byteswap(buffer.readu16(data, offset + 2)))
					cursor += 8
				end
			else
				local cursor = 0
				for offset = 0, length - 1, 6 do
					local value0 = bit32.byteswap(buffer.readu16(data, offset) * 0x10000)
						+ bit32.byteswap(buffer.readu16(data, offset + 2))
					local value1 = bit32.byteswap(buffer.readu16(data, offset + 4))
					buffer.writeu32(out, cursor, value0)
					buffer.writeu32(out, cursor + 4, value1 + (value0 + value1 == transparency and 0 or 0xFFFF0000))
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
	["grayscale"] = function(context, frame, data)
		local length = buffer.len(data)
		local parsed = context.parsed
		local headers = parsed.headers

		local channels = headers.channels
		local bit_depth = headers.bit_depth

		local transparency = -1
		if context.spans["tRNS"] then
			local source = context.source
			local offset = context.spans["tRNS"][1]

			if bit_depth == 8 then
				transparency = buffer.readu8(source, offset)
			elseif bit_depth == 16 then
				transparency = bit32.byteswap(buffer.readu16(source, offset) * 0x10000)
			end
		end

		local out = buffer.create(frame.width * frame.height * (bit_depth == 16 and 2 or 1) * 4)

		if bit_depth == 16 then
			if channels == 2 then
				local cursor = 0
				for offset = 0, length - 1, 4 do
					local value = bit32.byteswap(buffer.readu16(data, offset) * 0x10000)
					buffer.writeu32(out, cursor, value + value * 0x10000)
					buffer.writeu32(out, cursor + 4, value + bit32.byteswap(buffer.readu16(data, offset + 2)))
					cursor += 8
				end
			else
				local cursor = 0
				for offset = 0, length - 1, 2 do
					local value = bit32.byteswap(buffer.readu16(data, offset) * 0x10000)
					buffer.writeu32(out, cursor, value + value * 0x10000)
					buffer.writeu32(out, cursor + 4, value + (value == transparency and 0 or 0xFFFF0000))
					cursor += 8
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
	["indexed"] = function(context, frame, data)
		local length = buffer.len(data)
		local parsed = context.parsed
		local headers = parsed.headers

		local palette = assert(parsed.palette)
		local bit_depth = headers.bit_depth

		local out = buffer.create(frame.width * frame.height * 4)

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

local CONVERT_TARGET: {[ColorTarget]: (DecodeContext, FrameContext, buffer) -> buffer} = {
	["rgba8"] = function(context, frame, data)
		local parsed = context.parsed
		if parsed.headers.bit_depth < 16 then return data end

		local out = buffer.create(frame.width * frame.height * 4)

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
	["rgba16"] = function(context, frame, data)
		local parsed = context.parsed
		if parsed.headers.bit_depth == 16 then return data end

		local out = buffer.create(frame.width * frame.height * 2 * 4)

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

local function unfilter(context: DecodeContext, frame: FrameContext, data: buffer): (buffer?, CelError)
	local parsed = context.parsed
	local headers = parsed.headers

	local row_size = frame.row_size
	local bpp = (headers.bit_depth * headers.channels + 7) // 8

	local out = buffer.create(frame.out_size)

	local offset = 0
	local cursor = 0

	for y = 1, frame.height do
		local filter = buffer.readu8(data, offset)
		offset += 1

		if filter == 0 or (filter == 2 and y == 1) then
			buffer.copy(out, cursor, data, offset, row_size)
			offset += row_size
			cursor += row_size
		elseif filter == 1 then
			for x = 1, row_size do
				local a = x > bpp and buffer.readu8(out, cursor - bpp) or 0
				local value = buffer.readu8(data, offset) + a
				buffer.writeu8(out, cursor, value % 0x100)
				offset += 1
				cursor += 1
			end
		elseif filter == 2 then
			for _ = 1, row_size do
				local b = buffer.readu8(out, cursor - row_size)
				local value = buffer.readu8(data, offset) + b
				buffer.writeu8(out, cursor, value % 0x100)
				offset += 1
				cursor += 1
			end
		elseif filter == 3 then
			for x = 1, row_size do
				local a = x > bpp and buffer.readu8(out, cursor - bpp) or 0
				local b = y > 1 and buffer.readu8(out, cursor - row_size) or 0
				local value = buffer.readu8(data, offset) + (a + b) // 2
				buffer.writeu8(out, cursor, value % 0x100)
				offset += 1
				cursor += 1
			end
		elseif filter == 4 then
			for x = 1, row_size do
				local a = x > bpp and buffer.readu8(out, cursor - bpp) or 0
				local b = y > 1 and buffer.readu8(out, cursor - row_size) or 0
				local c = (y > 1 and x > bpp) and buffer.readu8(out, cursor - row_size - bpp) or 0
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
			return nil, cel_error("invalid_filter", `invalid row filter: {filter}`)
		end
	end

	return out, ok()
end

local function concatenate_spans(source: buffer, spans: SourceSpans): buffer
	local out_size = 0
	for size = 2, #spans, 2 do
		out_size += spans[size]
	end

	local out = buffer.create(out_size)
	local cursor = 0
	for index = 1, #spans, 2 do
		local size = spans[index + 1]
		buffer.copy(out, cursor, source, spans[index], size)
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
	local spans = context.spans

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

		local chunk_spans = spans[chunk_type]
		if not chunk_spans then
			chunk_spans = {}
			spans[chunk_type] = chunk_spans
		end

		local spans_index = #chunk_spans + 1
		table.insert(chunk_spans, offset)
		table.insert(chunk_spans, chunk_length)

		local parser = CHUNK_PARSER[chunk_type]
		if parser then
			local err = parser(context, chunk_spans, spans_index)
			if err then return err end
		end

		offset += chunk_length + 4

		if chunk_type == "IEND" then break end
	end

	parsed.cel = function(frame: number?, target: ColorTarget?): (Cel?, CelError)
		if frame and type(frame) ~= "number" then
			return nil, cel_error("invalid_option", "specified frame must be a number")
		end

		frame = frame and (frame // 1) % parsed.frames + 1 or 0
		target = target or "rgba8" :: ColorTarget

		if not CONVERT_TARGET[target] then
			return nil, cel_error("invalid_option", `invalid color target: {target}`)
		end

		local active = context.frames[frame] or context.frames[0]

		local concatenated = concatenate_spans(source, active.spans)
		local decompressed, err_decompress = zlib.decompress(concatenated, active.out_size + active.height)
		if not decompressed then
			return nil, err_decompress :: CelError
		end

		local unfiltered, err_unfilter = unfilter(context, active, decompressed)
		if not unfiltered then
			return nil, err_unfilter
		end

		local converted = CONVERT_COLOR[parsed.headers.color_space](context, active, unfiltered)
		local bitmap = CONVERT_TARGET[target](context, active, converted)

		return {
			bitmap = bitmap,
			region = {
				size = vector.create(active.width, active.height),
				position = vector.create(active.x, active.y),
			},
			duration = active.duration,

			dispose = active.dispose,
			blend = active.blend,
		}, ok()
	end

	return nil
end

return function(source: buffer, options: DecodeOptions?): (Parsed?, DecodeError)
	options = options or {} :: DecodeOptions

	local context: DecodeContext = {
		source = source,
		length = buffer.len(source),

		crc = options.crc or "all" :: "all",

		frames = {},
		frame = false,

		spans = {},
		parsed = {
			headers = {},
		} :: Parsed,
	}

	local err = parse_png(context)
	if err then return nil, err end

	return context.parsed, ok()
end
