--!strict
--!native
--!optimize 2

local LOOKUP = table.create(256, 0)

for i = 0, 255 do
	local crc = i
	for _ = 1, 8 do
		if crc % 2 == 1 then
			crc = bit32.bxor(crc // 2, 0xEDB88320)
		else
			crc //= 2
		end
	end

	LOOKUP[i + 1] = crc
end

return function(source: buffer, offset: number, length: number): number
	local crc = 0xFFFFFFFF
	for i = offset, offset + length - 1 do
		crc = bit32.bxor(LOOKUP[bit32.bxor(crc % 256, buffer.readu8(source, i)) + 1], crc // 256)
	end

	return bit32.bxor(crc, 0xFFFFFFFF)
end
