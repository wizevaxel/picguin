local process = zune.process
local fs = zune.fs

local PACKAGES_DIR = "packages"
local TESTS_DIR = "tests"

local function test_package(package_dir: string)
	local test_file = `{package_dir}/{TESTS_DIR}/test.luau`
	if fs.stat(test_file).kind ~= "file" then return end

	print(`\n== {package_dir} ==`)

	local _ = require(`../{fs.path.dirname(test_file)}/{fs.path.stem(test_file)}`) :: any
end

local function tests()
	local codec = process.args[2]

	if codec and #codec > 0 then
		local package_dir = `{PACKAGES_DIR}/{codec}`
		assert(fs.stat(package_dir).kind ~= "none", "codec not found in packages")
		test_package(package_dir)
	else
		for _, entry in fs.entries(PACKAGES_DIR) do
			if entry.kind ~= "directory" then continue end
			local package_dir = fs.path.join(PACKAGES_DIR, entry.name)
			test_package(package_dir)
		end
	end
end

tests()
