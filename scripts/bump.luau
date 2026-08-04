local PACKAGES_DIR = "packages"

local function bump_file(path: string, version: string)
	local write = zune.fs.readFile(path):gsub('version%s*=%s*"[^"]+"', `version = "{version}"`, 1)
	zune.fs.writeFile(path, write)
end

local function bump()
	local codec = assert(zune.process.args[2], "no codec provided")
	local version = assert(zune.process.args[3], "no version provided")

	local package_dir = `{PACKAGES_DIR}/{codec}`
	assert(zune.fs.stat(package_dir).kind ~= "none", "codec not found in packages")

	local config_path = `{package_dir}/pesde.toml`
	assert(zune.fs.stat(config_path).kind ~= "none", "codec package has no pesde.toml")
	bump_file(config_path, version)

	local source_path = `{package_dir}/src/init.luau`
	assert(zune.fs.stat(source_path).kind ~= "none", "codec package has no src/init.luau")
	bump_file(source_path, version)
end

bump()
