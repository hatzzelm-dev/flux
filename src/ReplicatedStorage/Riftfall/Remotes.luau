--!nolint
local RunService = game:GetService("RunService")

local Remotes = {}

Remotes.Names = {
	"RequestRoll",
	"SetAutoRoll",
	"RequestUpgrade",
	"RequestProduct",
	"RequestState",
	"Tutorial",
	"State",
	"Collection",
	"Event",
}

local function folder()
	local parent = script.Parent
	local existing = parent:FindFirstChild("Remotes")
	if existing then
		return existing
	end
	if RunService:IsServer() then
		local created = Instance.new("Folder")
		created.Name = "Remotes"
		created.Parent = parent
		return created
	end
	return parent:WaitForChild("Remotes", 30)
end

--- Server: create every RemoteEvent and return the folder.
function Remotes.server()
	local parent = folder()
	if not parent then
		error("Riftfall: unable to create remote folder")
	end
	for _, name in ipairs(Remotes.Names) do
		if not parent:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = parent
		end
	end
	return parent
end

--- Client: yield until every RemoteEvent exists, then return a name map.
function Remotes.client()
	local parent = folder()
	if not parent then
		error("Riftfall: remotes never replicated")
	end
	local map = {}
	for _, name in ipairs(Remotes.Names) do
		local remote = parent:WaitForChild(name, 30)
		if not remote then
			error("Riftfall: missing remote " .. name)
		end
		map[name] = remote
	end
	return map
end

return Remotes
