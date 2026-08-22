local process = zune.process
local fs = zune.fs

local PACKAGES_DIR = "packages"
local TESTS_DIR = "tests"

local function gather_tests(dir: string, out: {string}): {string}
	for _, entry in fs.entries(dir) do
		local path = fs.path.join(dir, entry.name)

		if entry.kind == "directory" then
			gather_tests(path, out)
		elseif entry.name:match("%.test%.luau$") then
			table.insert(out, path)
		end
	end

	return out
end

local function run_test(file: string): boolean
	local result = process.run("zune", {"test", file}, {
		stdout = "inherit",
		stderr = "inherit",
	})
	local failed = not result.ok
	return failed
end

local function test_package(package_dir: string): boolean
	local dir = `{package_dir}/{TESTS_DIR}`
	if fs.stat(dir).kind ~= "directory" then
		return false
	end

	local tests = gather_tests(dir, {})

	print(`\n== {package_dir} ==`)

	local failed = false
	for _, file in tests do
		failed = run_test(file) or failed
	end

	return failed
end

local function tests()
	local codec = process.args[2]

	local failed = false

	if codec and #codec > 0 then
		local package_dir = `{PACKAGES_DIR}/{codec}`
		assert(fs.stat(package_dir).kind ~= "none", "codec not found in packages")
		failed = test_package(package_dir)
	else
		for _, entry in fs.entries(PACKAGES_DIR) do
			if entry.kind ~= "directory" then continue end
			local package_dir = fs.path.join(PACKAGES_DIR, entry.name)
			failed = test_package(package_dir) or failed
		end
	end

	if failed then
		process.exit(1)
	end
end

tests()
