-- PingService: sonar manual (Q). Client hanya meminta; server cek cooldown, status hidup,
-- dan memakai posisi karakter versi SERVER (posisi dari client tidak dipercaya / tidak dikirim).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local EchoSoundService = require(script.Parent.EchoSoundService)
local RateLimiter = require(script.Parent.RateLimiter)

local PingService = {}

local lastPing: { [Player]: number } = {}

function PingService.init()
	local cooldown = Config.Sources.ManualPing.Cooldown
	local limiter = RateLimiter.new(Config.Network.RemoteBurst, Config.Network.RemoteRefillPerSecond)

	Net.get("RequestManualPing").OnServerEvent:Connect(function(player, ...)
		if select("#", ...) > 0 then
			return -- remote ini tidak menerima argumen; payload apa pun = request palsu
		end
		if not limiter:allow(player) then
			return
		end
		local now = Workspace:GetServerTimeNow()
		local last = lastPing[player]
		if last and now - last < cooldown - Config.Network.PingLatencyTolerance then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not (humanoid and root) or humanoid.Health <= 0 then
			return
		end
		lastPing[player] = now
		-- Atribut tereplikasi ke client: dipakai HUD untuk cooldown yang otoritatif.
		player:SetAttribute("PingReadyAt", now + cooldown)
		EchoSoundService.emit("ManualPing", root.Position, { actor = player })
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastPing[player] = nil
	end)
end

return PingService
