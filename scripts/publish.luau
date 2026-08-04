local PACKAGES_DIR = "packages"

local function is_released(release_tag: string): boolean
	return zune.process.run("gh", {"release", "view", release_tag}).ok
end

local function publish()
	local codec = assert(zune.process.args[2], "no codec provided")

	local package_dir = `{PACKAGES_DIR}/{codec}`
	assert(zune.fs.stat(package_dir).kind ~= "none", "codec not found in packages")

	local config_path = `{package_dir}/pesde.toml`
	assert(zune.fs.stat(config_path).kind ~= "none", "codec package has no pesde.toml")
	local config_source = zune.fs.readFile(config_path)
	local config = zune.serde.toml.decode(config_source)

	local release_tag = `{codec}@v{config.version}`
	assert(not is_released(release_tag), `release '{release_tag}' already exists`)

	local github_env = zune.process.env.GITHUB_ENV
	if github_env then
		local env = zune.fs.stat(github_env).kind ~= "none" and zune.fs.readFile(github_env) or ""
		zune.fs.writeFile(github_env, env .. `RELEASE_TAG={release_tag}\n`)
	end

	local ok, err = pcall(function()
		for _, target in {"roblox", "lune", "luau"} do
			print(`publishing target: {target}`)

			local active_config = table.clone(config)
			active_config.target = config.target and table.clone(config.target) or {}
			active_config.target.environment = target
			if target ~= "roblox" then
				active_config.scripts = nil
				active_config.dev_dependencies = nil
				active_config.target.build_files = nil
			end

			zune.fs.writeFile(config_path, zune.serde.toml.encode(active_config))

			local result = zune.process.run("pesde", {"publish", "-y"}, {cwd = package_dir})
			assert(result.ok, result.stderr)
		end
	end :: any)

	zune.fs.writeFile(config_path, config_source)

	assert(ok, err)
	print("successfully published targets")
end

publish()
