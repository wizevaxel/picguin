--!strict
--!native
--!optimize 2

local LOOKUP = buffer.create(0x1000)

for index = 0, 0xFF do
	local crc = index
	for _ = 1, 8 do
		crc = crc % 2 == 1 and bit32.bxor(crc // 2, 0xEDB88320) or crc // 2
	end

	buffer.writeu32(LOOKUP, index * 4, crc)
end

for index = 0, 0xFF do
	local crc = buffer.readu32(LOOKUP, index * 4)
	for cursor = 1, 3 do
		crc = bit32.bxor(crc // 0x100, buffer.readu32(LOOKUP, (crc % 0x100) * 4))
		buffer.writeu32(LOOKUP, cursor * 0x400 + index * 4, crc)
	end
end

return function(source: buffer, read_offset: number, read_length: number): number
	local read_end = read_offset + read_length

	local crc = 0xFFFFFFFF
	local offset = read_offset

	while offset + 4 <= read_end do
		crc = bit32.bxor(
			buffer.readu32(LOOKUP, 0xC00 + bit32.bxor((crc % 0x100), buffer.readu8(source, offset)) * 4),
			buffer.readu32(LOOKUP, 0x800 + bit32.bxor((crc // 0x100) % 0x100, buffer.readu8(source, offset + 1)) * 4),
			buffer.readu32(LOOKUP, 0x400 + bit32.bxor((crc // 0x10000) % 0x100, buffer.readu8(source, offset + 2)) * 4),
			buffer.readu32(LOOKUP, bit32.bxor((crc // 0x1000000), buffer.readu8(source, offset + 3)) * 4)
		)

		offset += 4
	end

	while offset < read_end do
		local index = bit32.bxor(crc % 0x100, buffer.readu8(source, offset))
		crc = bit32.bxor(buffer.readu32(LOOKUP, index * 4), crc // 0x100)
		offset += 1
	end

	return bit32.bxor(crc, 0xFFFFFFFF)
end
