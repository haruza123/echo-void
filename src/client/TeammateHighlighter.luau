-- TeammateHighlighter: pemain lain terlihat sebagai siluet hijau.
-- DepthMode Occluded + dinding opaque hitam => highlight TIDAK terlihat menembus dinding.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local P = Config.Players
local color = Config.Categories.Player.Color
local localPlayer = Players.LocalPlayer

local TeammateHighlighter = {}

local highlights: { [Player]: Highlight } = {}

local function attach(player: Player, character: Model)
	local old = highlights[player]
	if old then
		old:Destroy()
	end
	local h = Instance.new("Highlight")
	h.Name = "EchoTeammate"
	h.Adornee = character
	h.FillColor = color
	h.OutlineColor = color
	h.FillTransparency = P.FillTransparency
	h.OutlineTransparency = P.OutlineTransparency
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Enabled = false
	h.Parent = character
	highlights[player] = h
end

local function track(player: Player)
	if player == localPlayer then
		return
	end
	player.CharacterAdded:Connect(function(c)
		attach(player, c)
	end)
	if player.Character then
		attach(player, player.Character)
	end
end

function TeammateHighlighter.init()
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player)
		local h = highlights[player]
		if h then
			h:Destroy()
		end
		highlights[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		track(player)
	end

	-- Cek jarak 4x per detik (murah); oklusi ditangani depth buffer.
	task.spawn(function()
		while true do
			local myChar = localPlayer.Character
			local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart") :: BasePart?
			for player, h in highlights do
				local c = player.Character
				local root = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
				local hum = c and c:FindFirstChildOfClass("Humanoid")
				h.Enabled = myRoot ~= nil
					and root ~= nil
					and hum ~= nil
					and hum.Health > 0
					and (root.Position - myRoot.Position).Magnitude <= P.VisibleRange
			end
			task.wait(0.25)
		end
	end)
end

return TeammateHighlighter
