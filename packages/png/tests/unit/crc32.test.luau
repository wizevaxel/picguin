local testing = zune.testing

local crc32 = require("../../src/crc32")

testing.describe("crc32", function()
	testing.test("matches standard checksum", function()
		testing.expect(crc32(buffer.fromstring("123456789"), 0, 9)).toBe(0xCBF43926)
	end)
end)
