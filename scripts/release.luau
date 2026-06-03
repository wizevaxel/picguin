local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local PACKAGES_DIR = "packages"
local RELEASES_DIR = "release"

local function build_release(codec: string, package_dir: string)
	if not fs.isDir(RELEASES_DIR) then
		fs.writeDir(RELEASES_DIR)
	end

	local project_path = `{package_dir}/.project.json`
	fs.writeFile(project_path, serde.encode("json", {
		name = codec,
		tree = {
			["$path"] = "src"
		}
	}))

	local result = process.exec("rojo", {"build", "-o", `{RELEASES_DIR}/{codec}.rbxm`, project_path})
	fs.removeFile(project_path)
	assert(result.ok, result.stderr)
end

local function publish_targets(codec: string, package_dir: string)
	local config_path = `{package_dir}/pesde.toml`
	assert(fs.isFile(config_path), "codec package has no pesde.toml")
	local config_source = fs.readFile(config_path)

	local config = serde.decode("toml", config_source)
	local release_tag = `{codec}@v{config.version}`

	local result = process.exec("gh", {"release", "view", release_tag})
	assert(not result.ok, `release '{release_tag}' already exists`)

	local function publish(target: string)
		print(`publishing target: {target}`)

		local result = process.exec("pesde", {"publish", "-y"}, {cwd = package_dir})
		assert(result.ok, result.stderr)
	end

	local ok, err = pcall(function()
		publish("roblox")

		local github_env = process.env.GITHUB_ENV
		if github_env then
			local env = fs.isFile(github_env) and fs.readFile(github_env) or ""
			fs.writeFile(github_env, env .. `RELEASE_TAG={release_tag}\n`)
		end

		config.scripts = nil
		config.dev_dependencies = nil
		config.target.build_files = nil

		for _, target in {"lune", "luau"} do
			config.target.environment = target
			fs.writeFile(config_path, serde.encode("toml", config))
			publish(target)
		end
	end)

	fs.writeFile(config_path, config_source)
	if not ok then
		error(err)
	end
end

local function release()
	local codec = assert(process.args[1], "no codec provided")

	local package_dir = `{PACKAGES_DIR}/{codec}`
	assert(fs.isDir(package_dir), "codec not found in packages")

	build_release(codec, package_dir)
	publish_targets(codec, package_dir)
end

release()
