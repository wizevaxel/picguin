local process = zune.process
local fs = zune.fs

local REPO_URL = "https://github.com/wizevaxel/picguin-fixtures"
local TARGET_DIR = "fixtures"

local function fixtures()
	if fs.stat(TARGET_DIR).kind == "directory" then
		fs.deleteDir(TARGET_DIR, true)
	end

	process.run("git", {"clone", REPO_URL, TARGET_DIR})
end

fixtures()
