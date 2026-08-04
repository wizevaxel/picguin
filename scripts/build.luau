local PACKAGES_DIR = "packages"
local RELEASES_DIR = "release"

local function release()
	local codec = assert(zune.process.args[2], "no codec provided")

	local package_dir = `{PACKAGES_DIR}/{codec}`
	assert(zune.fs.stat(package_dir).kind ~= "none", "codec not found in packages")

    zune.fs.makeDir(RELEASES_DIR, true)

	local project_path = `{package_dir}/.project.json`
	zune.fs.writeFile(project_path, zune.serde.json.encode({
		name = codec,
		tree = {
			["$path"] = "src"
		}
	}))

	local result = zune.process.run("rojo", {"build", "-o", `{RELEASES_DIR}/{codec}.rbxm`, project_path})
	zune.fs.deleteFile(project_path)
	assert(result.ok, result.stderr)
end

release()
