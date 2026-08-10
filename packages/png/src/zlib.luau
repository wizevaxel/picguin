--!strict
--!native
--!optimize 2

local types = require("./types")

export type DecompressErrorCode =
	| "unsupported"
	| "unexpected_eof"
	| "invalid_length"
	| "invalid_header"
	| "invalid_block"
export type DecompressError = types.Error<DecompressErrorCode>

local function ok(): {code: "ok", message: ""}
	return {code = "ok", message = ""}
end

local function decompress_error(code: DecompressErrorCode, message: string): DecompressError
	return {code = code, message = message}
end

local LEN_BASE = {
	3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
	35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258
}
local LEN_EXTRA = {
	0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0
}
local DIST_BASE = {
	1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
	257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577
}
local DIST_EXTRA = {
	0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
	7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13
}
local LEN_ORDER = {
	16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
}

local BITSWAP = buffer.create(0x100)
for index = 0, 0xFF do
	local value = index
	value = bit32.band(value, 0xAA) // 0b00010 + bit32.band(value, 0x55) * 0b00010
	value = bit32.band(value, 0xCC) // 0b00100 + bit32.band(value, 0x33) * 0b00100
	value = bit32.band(value, 0xF0) // 0b10000 + bit32.band(value, 0x0F) * 0b10000
	buffer.writeu8(BITSWAP, index, value)
end

local function unroll(runs: {number}): {number}
	local out: {number} = {}

	for index = 1, #runs, 2 do
		local value = runs[index]
		for _ = 1, runs[index + 1] do
			table.insert(out, value)
		end
	end

	return out
end

local function huffman_tree(lengths: {number}): (buffer, number)
	local max_bits = 0
	for _, length in lengths do
		if length > max_bits then max_bits = length end
	end

	local count = table.create(max_bits, 0)
	count[0] = 0
	for _, length in lengths do
		if length > 0 then count[length] += 1 end
	end

	local next_code = table.create(max_bits, 0)
	local code = 0

	for bits = 1, max_bits do
		code = (code + count[bits - 1]) * 2
		next_code[bits] = code
	end

	local size = bit32.lshift(1, max_bits) * 2
	local tree = buffer.create(size)

	for symbol, length in lengths do
		if length > 0 then
			code = next_code[length]
			next_code[length] += 1

			local entry = (symbol - 1) * 0x10 + length
			local step = bit32.lshift(1, length) * 2

			local index = bit32.rshift(buffer.readu8(BITSWAP, code % 0x100) * 0x100 + buffer.readu8(BITSWAP, code // 0x100), 16 - length) * 2
			while index < size do
				buffer.writeu16(tree, index, entry)
				index += step
			end
		end
	end

	return tree, max_bits
end

local FIXED_LIT_TREE, FIXED_LIT_BITS = huffman_tree(unroll({8, 144, 9, 112, 7, 24, 8, 8}))
local FIXED_DIST_TREE, FIXED_DIST_BITS = huffman_tree(unroll({5, 32}))

local function inflate_blocks(source: buffer, out_length: number): (buffer?, DecompressError)
	local out = buffer.create(out_length)
	local cursor = 0

	local offset = 2
	local stream = 0
	local stream_bits = 0

	while true do
		if stream_bits < 3 then
			stream += bit32.lshift(buffer.readu16(source, offset), stream_bits)
			offset += 2
			stream_bits += 16
		end

		local bread = stream % 8
		stream //= 8
		stream_bits -= 3

		local bfinal = bread % 2
		local btype = bread // 2

		if btype == 0 then
			local byte_offset = offset - (stream_bits // 8)
			local len = buffer.readu16(source, byte_offset)
			buffer.copy(out, cursor, source, byte_offset + 4, len)
			cursor += len
			offset = byte_offset + 4 + len
			stream = 0
			stream_bits = 0
		elseif btype < 3 then
			local lit_tree = FIXED_LIT_TREE
			local lit_bits = FIXED_LIT_BITS
			local dist_tree = FIXED_DIST_TREE
			local dist_bits = FIXED_DIST_BITS

			if btype == 2 then
				if stream_bits < 14 then
					stream += bit32.lshift(buffer.readu16(source, offset), stream_bits)
					offset += 2
					stream_bits += 16
				end

				local hread = stream % 16384
				stream //= 16384
				stream_bits -= 14

				local hlit = (hread % 0x20) + 257
				local hdist = bit32.extract(hread, 5, 5) + 1
				local hclen = (hread // 0x400) + 4

				local code_lengths = table.create(19, 0)
				for index = 1, hclen do
					if stream_bits < 3 then
						stream += bit32.lshift(buffer.readu16(source, offset), stream_bits)
						offset += 2
						stream_bits += 16
					end

					code_lengths[LEN_ORDER[index] + 1] = stream % 8
					stream //= 8
					stream_bits -= 3
				end

				local length_tree, length_bits = huffman_tree(code_lengths)

				local code_count = hlit + hdist
				local symbol_lengths = table.create(code_count, 0)

				local index = 1
				while index <= code_count do
					local repeats = 1
					local value = 0

					if stream_bits < length_bits then
						stream += bit32.lshift(buffer.readu16(source, offset), stream_bits)
						offset += 2
						stream_bits += 16
					end

					local path = bit32.extract(stream, 0, length_bits)
					local entry = buffer.readu16(length_tree, path * 2)
					local length = entry % 0x10
					stream = bit32.rshift(stream, length)
					stream_bits -= length

					local symbol = (entry - length) // 0x10
					if symbol <= 15 then
						value = symbol
					elseif symbol <= 16 then
						if stream_bits < 2 then
							stream += bit32.lshift(buffer.readu16(source, offset), stream_bits)
							offset += 2
							stream_bits += 16
						end

						repeats = stream % 4 + 3
						stream //= 4
						stream_bits -= 2
						value = symbol_lengths[index - 1]
					elseif symbol == 17 then
						if stream_bits < 3 then
							stream += bit32.lshift(buffer.readu16(source, offset), stream_bits)
							offset += 2
							stream_bits += 16
						end

						repeats = stream % 8 + 3
						stream //= 8
						stream_bits -= 3
					elseif symbol == 18 then
						if stream_bits < 7 then
							stream += bit32.lshift(buffer.readu16(source, offset), stream_bits)
							offset += 2
							stream_bits += 16
						end

						repeats = stream % 128 + 11
						stream //= 128
						stream_bits -= 7
					end

					for _ = 1, repeats do
						symbol_lengths[index] = value
						index += 1
					end
				end

				lit_tree, lit_bits = huffman_tree(table.move(symbol_lengths, 1, hlit, 1, table.create(hlit, 0)))
				dist_tree, dist_bits = huffman_tree(table.move(symbol_lengths, hlit + 1, code_count, 1, table.create(hdist, 0)))
			end

			while true do
				if stream_bits < lit_bits then
					stream += bit32.lshift(buffer.readu16(source, offset), stream_bits)
					offset += 2
					stream_bits += 16
				end

				local path = bit32.extract(stream, 0, lit_bits)
				local entry = buffer.readu16(lit_tree, path * 2)
				local length = entry % 0x10

				if length == 0 then
					return nil, decompress_error("invalid_block", "invalid huffman code")
				end

				stream = bit32.rshift(stream, length)
				stream_bits -= length

				local symbol = (entry - length) // 0x10
				if symbol < 256 then
					buffer.writeu8(out, cursor, symbol)
					cursor += 1
				elseif symbol > 256 then
					local len_index = symbol - 256
					local len_extra = LEN_EXTRA[len_index]

					if stream_bits < len_extra then
						stream += bit32.lshift(buffer.readu16(source, offset), stream_bits)
						offset += 2
						stream_bits += 16
					end

					local len = LEN_BASE[len_index]
					if len_extra > 0 then
						len += bit32.extract(stream, 0, len_extra)
						stream = bit32.rshift(stream, len_extra)
						stream_bits -= len_extra
					end

					if stream_bits < dist_bits then
						stream += bit32.lshift(buffer.readu16(source, offset), stream_bits)
						offset += 2
						stream_bits += 16
					end

					path = bit32.extract(stream, 0, dist_bits)
					entry = buffer.readu16(dist_tree, path * 2)
					length = entry % 0x10
					stream = bit32.rshift(stream, length)
					stream_bits -= length

					local dist_index = (entry - length) // 0x10 + 1
					local dist_extra = DIST_EXTRA[dist_index]

					if stream_bits < dist_extra then
						stream += bit32.lshift(buffer.readu16(source, offset), stream_bits)
						offset += 2
						stream_bits += 16
					end

					local dist = DIST_BASE[dist_index]
					if dist_extra > 0 then
						dist += bit32.extract(stream, 0, dist_extra)
						stream = bit32.rshift(stream, dist_extra)
						stream_bits -= dist_extra
					end

					if dist == 1 then
						buffer.fill(out, cursor, buffer.readu8(out, cursor - 1), len)
						cursor += len
					elseif len > dist then
						local position = cursor - dist

						while len > 0 do
							local size = math.min(dist, len)
							buffer.copy(out, cursor, out, position, size)
							cursor += size
							len -= size
							dist += size
						end
					else
						buffer.copy(out, cursor, out, cursor - dist, len)
						cursor += len
					end
				else
					break
				end
			end
		else
			return nil, decompress_error("invalid_block", "block type 3 is unsupported")
		end

		if bfinal == 1 then break end
	end

	return out, ok()
end

local function decompress(source: buffer, out_length: number): (buffer?, DecompressError)
	local length = buffer.len(source)

	if length < 8 then
		return nil, decompress_error("unexpected_eof", "EOF while reading zlib header")
	elseif length % 2 ~= 0 then
		return nil, decompress_error("invalid_length", "(unreachable) zlib data must be 2-padded to prevent bit stream errors")
	end

	local cmf = buffer.readu8(source, 0)

	local cm = cmf % 0x10
	if cm ~= 8 then
		return nil, decompress_error("unsupported", `unsupported zlib compression method: {cm}`)
	end

	local ci = bit32.extract(cmf, 4, 4)
	local window_size = bit32.lshift(1, ci + 8)
	if ci > 7 then
		return nil, decompress_error("invalid_header", `invalid zlib window size: expected <32KiB, got {window_size // 1024}KiB`)
	end

	local flg = buffer.readu8(source, 1)
	if (cmf * 0x100 + flg) % 0x1F ~= 0 then
		return nil, decompress_error("invalid_header", "invalid zlib header checksum")
	end

	if bit32.extract(flg, 5, 1) == 1 then
		return nil, decompress_error("invalid_header", "zlib preset dictionary is not allowed")
	end

	return inflate_blocks(source, out_length)
end

local function compress()
	-- not implemented
end

return table.freeze {
	decompress = decompress,
	compress = compress,
}
