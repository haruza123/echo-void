-- MapService: membuat peta prosedural saat server start (PRD 6.1 langkah 7-8).
--   * seed -> MapLayout (retry + fallback) -> MapBuilder -> Workspace.RuntimeMap
--   * validasi jalur fisik Spawn -> Exit pakai PathfindingService; gagal -> seed turunan
--   * seed, versi konten, dan hasil validasi dicatat di Output + atribut RuntimeMap
--   * dev (Studio saja): remote DevRegenerateMap membuat peta baru dengan seed acak
-- Arena tes lama dipindah ke ServerStorage selama generator aktif.
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local MapGen = script.Parent:WaitForChild("MapGen")
local MapLayout = require(MapGen.MapLayout)
local MapBuilder = require(MapGen.MapBuilder)

local MapService = {}

local current: Folder? = nil

local function randomSeed(): number
	return Random.new():NextInteger(1, 2147483646)
end

local function pathCheck(fromPos: Vector3, toPos: Vector3): (boolean, string)
	local path = PathfindingService:CreatePath(Config.MapGen.PathAgent)
	local ok, err = pcall(function()
		path:ComputeAsync(fromPos, toPos)
	end)
	if not ok then
		return false, tostring(err)
	end
	return path.Status == Enum.PathStatus.Success, path.Status.Name
end

function MapService.generate(seed: number)
	local cfg = Config.MapGen
	local trySeed = seed
	for buildAttempt = 1, 3 do
		local t0 = os.clock()
		local layout = MapLayout.generate(trySeed, cfg)
		local folder, info = MapBuilder.build(layout, cfg)
		folder:SetAttribute("Seed", layout.seed)
		folder:SetAttribute("UsedSeed", layout.usedSeed)
		folder:SetAttribute("Attempt", layout.attempt)
		folder:SetAttribute("Fallback", layout.fallback)
		folder:SetAttribute("Rooms", #layout.rooms)
		folder:SetAttribute("Loops", layout.loops)
		folder:SetAttribute("ContentVersion", cfg.ContentVersion)

		if current then
			current:Destroy()
		end
		folder.Parent = Workspace
		current = folder
		task.wait() -- beri satu frame supaya geometri baru masuk ke dunia fisika

		local ok, status = false, "tanpa spawn/exit"
		if info.spawnPos and info.exitPos then
			ok, status = pathCheck(info.spawnPos + Vector3.new(0, 3, 0), info.exitPos + Vector3.new(0, 3, 0))
		end
		folder:SetAttribute("PathCheck", status)

		for _, f in layout.failures do
			warn(`[MapGen] seed gagal -> {f}`)
		end
		print(string.format(
			"[MapGen] seed=%d used=%d attempt=%d fallback=%s rooms=%d loops=%d doors=%d path=%s versi=%s (%.0f ms)",
			layout.seed,
			layout.usedSeed,
			layout.attempt,
			tostring(layout.fallback),
			#layout.rooms,
			layout.loops,
			#folder.Doors:GetChildren(),
			status,
			cfg.ContentVersion,
			(os.clock() - t0) * 1000
		))
		if ok then
			return folder
		end
		warn(`[MapGen] jalur Spawn->Exit gagal ({status}), coba seed turunan`)
		trySeed = (trySeed * 31 + buildAttempt * 104729) % 2147483647
	end
	warn("[MapGen] cek jalur gagal 3x; peta terakhir tetap dipakai, periksa seed di atas")
	return current
end

local function respawnAll()
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			player:LoadCharacter()
		end)
	end
end

function MapService.init()
	local cfg = Config.MapGen
	if not cfg.Enabled then
		return
	end
	Players.CharacterAutoLoads = false -- jangan spawn sebelum peta siap
	local arena = Workspace:FindFirstChild("Arena")
	if arena then
		arena.Parent = ServerStorage
	end

	MapService.generate(if cfg.Seed ~= 0 then cfg.Seed else randomSeed())

	Players.CharacterAutoLoads = true
	respawnAll()

	if Config.Debug.DevView and RunService:IsStudio() then
		local busy = false
		Net.get("DevRegenerateMap").OnServerEvent:Connect(function()
			if busy then
				return
			end
			busy = true
			MapService.generate(randomSeed())
			respawnAll()
			busy = false
		end)
	end
end

return MapService
