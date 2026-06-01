local process = require("@lune/process")
local fs = require("@lune/fs")

local PACKAGES_DIR = "packages"

local function bump()
	local codec = assert(process.args[1], "no codec provided")
	local version = assert(process.args[2], "no version provided")

	local package_dir = `{PACKAGES_DIR}/{codec}`
	assert(fs.isDir(package_dir), "codec not found in packages")

	local source_path = `{package_dir}/src/init.luau`
	assert(fs.isFile(source_path), "codec package has no src/init.luau")
	local source = fs.readFile(source_path)

	fs.writeFile(source_path, source:gsub('version%s*=%s*"[^"]+"', `version = "{version}"`, 1))

	local config_path = `{package_dir}/pesde.toml`
	assert(fs.isFile(config_path), "codec package has no pesde.toml")
	local config = fs.readFile(config_path)

	fs.writeFile(config_path, config:gsub('version%s*=%s*"[^"]+"', `version = "{version}"`, 1))
end

bump()
