local testing = zune.testing

testing.describe("png", function()
	require("./conformance/pngsuite.test")
	require("./unit/crc32.test")
end)

return nil
