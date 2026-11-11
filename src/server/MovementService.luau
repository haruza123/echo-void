-- MovementService: mode gerak (Walk/Run/Crouch) dikelola server.
-- Client hanya meminta mode; server yang mengatur WalkSpeed. Jenis langkah tetap
-- diklasifikasi dari kecepatan yang terukur (FootstepService), jadi klaim "crouch" palsu tidak membantu.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local RateLimiter = require(script.Parent.RateLimiter)

local MovementService = {}

local VALID = { Walk = true, Run = true, Crouch = true }
local SPEED = {
	Walk = Config.Movement.WalkSpeed,
	Run = Config.Movement.RunSpeed,
	Crouch = Config.Movement.CrouchSpeed,
}

function MovementService.getMode(player: Player): string
	local mode = player:GetAttribute("MoveMode")
	if type(mode) == "string" and VALID[mode] then
		return mode
	end
	return "Walk"
end

local function apply(player: Player, mode: string)
	player:SetAttribute("MoveMode", mode)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = SPEED[mode]
	end
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	-- Nama/HP di atas kepala bisa terlihat menembus dinding; matikan.
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	apply(player, "Walk")
end

function MovementService.init()
	local limiter = RateLimiter.new(Config.Network.RemoteBurst, Config.Network.RemoteRefillPerSecond)
	Net.get("RequestMoveMode").OnServerEvent:Connect(function(player, mode)
		if not limiter:allow(player) then
			return
		end
		if type(mode) ~= "string" or not VALID[mode] then
			return
		end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end
		apply(player, mode)
	end)

	local function onPlayer(player: Player)
		player:SetAttribute("MoveMode", "Walk")
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return MovementService
