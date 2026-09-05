local testing = zune.testing
local crypto = zune.crypto
local serde = zune.serde
local fs = zune.fs

local png = require("../../src")

local PNGSUITE_DIR = "fixtures/png/tests/pngsuite"
local HASHES: {[string]: {string}} = serde.json.decode(fs.readFile(`{PNGSUITE_DIR}/hashes.json`, false))

local function get_input(name: string): buffer
	return fs.readFile(`{PNGSUITE_DIR}/{name}.png`, true)
end

testing.describe("pngsuite", function()
	testing.describe("rejects invalid inputs", function()
		local expected: {[string]: png.DecodeErrorCode} = {
			["xdtn0g01"] = "missing_chunk",
			["xhdn0g08"] = "invalid_crc",
			["xcsn0g01"] = "invalid_crc",
			["xc1n0g08"] = "invalid_header",
			["xc9n2c08"] = "invalid_header",
			["xd0n2c08"] = "invalid_header",
			["xd9n2c08"] = "invalid_header",
			["basi0g01"] = "unsupported",
		}
		for name, expected_code in expected do
			testing.test(name, function()
				local parsed, err = png.decode(get_input(name))
				testing.expect(parsed).toBeNil()
				testing.expect(err.code).toBe(expected_code)
			end)
		end
	end)

	testing.describe("decodes valid inputs", function()
		for name, frames in HASHES do
			testing.test(name, function()
				local parsed, err_parsed = png.decode(get_input(name))
				testing.expect(err_parsed.code).toBe("ok")
				testing.expect(parsed).toBeDefined()
				if not parsed then return end

				for index, expected_hash in frames do
					local cel, err_cel = parsed.cel(index - 1, "rgba8")
					testing.expect(err_cel.code).toBe("ok")
					testing.expect(cel).toBeDefined()
					if not cel then return end

					local hash = crypto.createHash("sha256")
					hash:update(cel.bitmap)
					testing.expect(hash:digest("hex")).toBe(expected_hash)
				end
			end)
		end
	end)
end)

return nil
