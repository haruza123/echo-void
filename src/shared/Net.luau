-- Akses RemoteEvent. Remote dibuat sebagai instance asli di ReplicatedStorage.Remotes
-- (lihat default.project.json); Net.ensure() di server membuat yang hilang sebagai jaring pengaman.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

Net.Names = {
	"RequestManualPing", -- client -> server, tanpa argumen
	"RequestMoveMode", -- client -> server, "Walk" | "Run" | "Crouch"
	"RequestThrow", -- client -> server, arah lempar (Vector3)
	"RequestDrop", -- client -> server, tanpa argumen
	"EchoSoundEvent", -- server -> client, SoundEvent
	"DevRegenerateMap", -- client -> server, DEV (hanya diproses di Studio)
}

function Net.ensure()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in Net.Names do
		if not folder:FindFirstChild(name) then
			warn(`[Net] Remote {name} tidak ada, dibuat otomatis`)
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

function Net.get(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	return folder:WaitForChild(name) :: RemoteEvent
end

return Net
