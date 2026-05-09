--!strict
--!native
--!optimize 2

local types = require("./types")

export type DecompressErrorCode =
	| "unsupported"
	| "invalid_header"
export type DecompressError = types.Error<DecompressErrorCode>

local function repetition(t: {number}): {number}
	local out: {number} = {}

	for i = 1, #t, 2 do
		local value = t[i]
		for _ = 1, t[i + 1] do
			table.insert(out, value)
		end
	end

	return out
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

local BYTESWAP = table.create(0xFF, 0)
for byte = 0, 0xFF do
	local swap = 0
	local bit = byte

	for _ = 1, 8 do
		swap = (swap * 2) + (bit % 2)
		bit //= 2
	end

	BYTESWAP[byte] = swap
end

local function huffman_tree(lengths: {number}): ({number}, number)
	local max_bits = 0
	for _, length in lengths do
		if length > max_bits then max_bits = length end
	end

	local count = table.create(max_bits, 0)
	for _, length in lengths do
		if length > 0 then count[length] += 1 end
	end

	local size = 2 ^ max_bits
	local tree = table.create(size, 0)

	local next_code = table.create(max_bits, 0)
	local code = 0
	for bits = 2, max_bits do
		code = (code + count[bits - 1]) * 2
		next_code[bits] = code
	end

	for symbol, length in lengths do
		if length > 0 then
			code = next_code[length]
			next_code[length] += 1

			local swap = if length <= 8
				then bit32.rshift(BYTESWAP[code], 8 - length)
				else bit32.rshift(BYTESWAP[code // 0x100], 16 - length) + bit32.lshift(BYTESWAP[code % 0x100], length - 8)

			local entry = (symbol - 1) * 0x10 + length
			local step = 2 ^ length

			local index = swap
			while index < size do
				tree[index] = entry
				index += step
			end
		end
	end

	return tree, max_bits
end

local FIXED_LIT_TREE, FIXED_LIT_BITS = huffman_tree(repetition {8, 144, 9, 112, 7, 24, 8, 8})
local FIXED_DIST_TREE, FIXED_DIST_BITS = huffman_tree(repetition {5, 32})

local function inflate_blocks(source: buffer, out_size: number): buffer
	local offset = 16

	local function read_tree(tree: {number}, bits: number): number
		local path = buffer.readbits(source, offset, bits)
		local entry = tree[path] or 0
		local length = entry % 0x10
		offset += length
		return (entry - length) / 0x10
	end

	local function decode_trees(): ({number}, number, {number}, number)
		local hread = buffer.readbits(source, offset, 14)
		offset += 14
		local hlit = (hread % 0x20) + 257
		local hdist = bit32.extract(hread, 5, 5) + 1
		local hclen = (hread // 0x400) + 4

		local code_lengths = table.create(19, 0)
		for i = 1, hclen do
			code_lengths[LEN_ORDER[i] + 1] = buffer.readbits(source, offset, 3)
			offset += 3
		end

		local length_tree, length_bits = huffman_tree(code_lengths)

		local code_count = hlit + hdist
		local symbol_lengths = table.create(code_count, 0)

		local i = 1
		while i <= code_count do
			local repeats = 1
			local value = 0

			local symbol = read_tree(length_tree, length_bits)
			if symbol <= 15 then
				value = symbol
			elseif symbol == 16 then
				repeats = buffer.readbits(source, offset, 2) + 3
				offset += 2
				value = symbol_lengths[i - 1]
			elseif symbol == 17 then
				repeats = buffer.readbits(source, offset, 3) + 3
				offset += 3
			elseif symbol == 18 then
				repeats = buffer.readbits(source, offset, 7) + 11
				offset += 7
			end

			for _ = 1, repeats do
				symbol_lengths[i] = value
				i += 1
			end
		end

		local lit_tree, lit_bits = huffman_tree(table.move(symbol_lengths, 1, hlit, 1, table.create(hlit, 0)))
		local dist_tree, dist_bits = huffman_tree(table.move(symbol_lengths, hlit + 1, code_count, 1, table.create(hdist, 0)))
		return lit_tree, lit_bits, dist_tree, dist_bits
	end

	local out = buffer.create(out_size)
	local cursor = 0

	local function inflate_compressed(lit_tree: {number}, lit_bits: number, dist_tree: {number}, dist_bits: number): ()
		while true do
			local symbol = read_tree(lit_tree, lit_bits)
			if symbol == 256 then
				break
			elseif symbol < 256 then
				buffer.writeu8(out, cursor, symbol)
				cursor += 1
			else
				local len_index = symbol - 256
				local len_extra = LEN_EXTRA[len_index]
				local len = LEN_BASE[len_index] + buffer.readbits(source, offset, len_extra)
				offset += len_extra

				local dist_index = read_tree(dist_tree, dist_bits) + 1
				local dist_extra = DIST_EXTRA[dist_index]
				local dist = DIST_BASE[dist_index] + buffer.readbits(source, offset, dist_extra)
				offset += dist_extra

				if len > dist then
					while len > 0 do
						local size = math.min(dist, len)
						buffer.copy(out, cursor, out, cursor - dist, size)
						cursor += size
						len -= size
					end
				else
					buffer.copy(out, cursor, out, cursor - dist, len)
					cursor += len
				end
			end
		end
	end

	while true do
		local bread = buffer.readbits(source, offset, 3)
		offset += 3

		local bfinal = bread % 2
		local btype = bread // 2

		if btype == 0 then
			local byte_offset = (offset + 7) // 8
			local len = buffer.readu16(source, byte_offset)
			buffer.copy(out, cursor, source, byte_offset + 4, len)
			cursor += len
			offset = (byte_offset + 4 + len) * 8
		elseif btype == 1 then
			inflate_compressed(FIXED_LIT_TREE, FIXED_LIT_BITS, FIXED_DIST_TREE, FIXED_DIST_BITS)
		elseif btype == 2 then
			inflate_compressed(decode_trees())
		end

		if bfinal == 1 then break end
	end

	return out
end

local function decompress(source: buffer, out_size: number): (buffer?, DecompressError)
	local cmf = buffer.readu8(source, 0)

	local cm = cmf % 0x10
	if cm ~= 8 then
		return nil, decompress_error("unsupported", `unsupported zlib compression method: {cm}`)
	end

	local ci = bit32.extract(cmf, 4, 4)
	local window_size = 2 ^ (ci + 8)
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

	return inflate_blocks(source, out_size), nil :: any
end

local function compress()
	-- not implemented
end

return table.freeze {
	decompress = decompress,
	compress = compress,
}
