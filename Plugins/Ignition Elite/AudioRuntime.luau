local RunService = game:GetService("RunService")
local AudioRuntime = {}

local function resolveSoundType(soundName)
	return string.sub(soundName, 1, 3)
end

local function collectSounds(soundDirectory, allowedNames)
	local sounds = {}
	for _, child in ipairs(soundDirectory:GetDescendants()) do
		if child:IsA("Sound") and string.sub(child.Name, -6) ~= "_Local" then
			if allowedNames and not allowedNames[child.Name] then
				continue
			end
			table.insert(sounds, child)
		end
	end
	return sounds
end

function AudioRuntime.start(context)
	local vehicle = context.vehicle
	local values = context.values
	local tune = context.tune or {}

	local body = vehicle:WaitForChild("Body", 10)
	if not body then
		return nil
	end
	local soundDirectory = body:WaitForChild("Sounds", 10)
	if not soundDirectory then
	-- Removed: This file is no longer needed. All audio and sound logic has been removed from the Ignition plugin.
	end
local RunService = game:GetService("RunService")
