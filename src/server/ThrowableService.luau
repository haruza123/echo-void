-- ThrowableService: ambil (ProximityPrompt), lempar (F), jatuhkan (G) batu tes.
-- Benturan dideteksi server pada batu milik server (network owner = server), lalu jadi sound event.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Schema = require(Shared.SoundEventSchema)
local EchoSoundService = require(script.Parent.EchoSoundService)
local RateLimiter = require(script.Parent.RateLimiter)

local ThrowableService = {}

local I = Config.Items
local held: { [Player]: BasePart } = {}
local holder: { [BasePart]: Player } = {}
local thrower: { [BasePart]: Player } = {}
local armedAt: { [BasePart]: number } = {}
local lastImpact: { [BasePart]: number } = {}
local lastVel: { [BasePart]: Vector3 } = {}
local homeCFrame: { [BasePart]: CFrame } = {}

local function displayName(stone: BasePart): string
	local n = stone:GetAttribute("DisplayName")
	return if type(n) == "string" then n else stone.Name
end

local function rootOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?, character:FindFirstChildOfClass("Humanoid")
end

local function promptOf(stone: BasePart): ProximityPrompt?
	return stone:FindFirstChildOfClass("ProximityPrompt")
end

local function surfaceOf(part: BasePart): string
	local attr = part:GetAttribute("SurfaceProfile")
	if type(attr) == "string" then
		return attr
	end
	return Config.MaterialToSurface[part.Material] or "Concrete"
end

local function isCharacterPart(part: BasePart): boolean
	local model = part:FindFirstAncestorOfClass("Model")
	return model ~= nil and Players:GetPlayerFromCharacter(model) ~= nil
end

local function detach(player: Player, stone: BasePart)
	held[player] = nil
	holder[stone] = nil
	local weld = stone:FindFirstChild("HoldWeld")
	if weld then
		weld:Destroy()
	end
	stone.CanCollide = true
	stone.Massless = false
	player:SetAttribute("HeldItem", nil)
	local prompt = promptOf(stone)
	if prompt then
		prompt.Enabled = true
	end
end

-- Lepas batu dari tangan ke dunia dengan kecepatan tertentu.
local function release(player: Player, stone: BasePart, origin: Vector3, velocity: Vector3)
	detach(player, stone)
	stone.CFrame = CFrame.new(origin)
	stone.Anchored = false
	stone:SetNetworkOwner(nil) -- server memegang fisika => benturan tidak bisa dipalsukan client
	stone.AssemblyLinearVelocity = velocity
	thrower[stone] = player
	armedAt[stone] = os.clock() + I.ArmDelay
end

local function pickup(player: Player, stone: BasePart)
	local root, humanoid = rootOf(player)
	if not (root and humanoid) or humanoid.Health <= 0 then
		return
	end
	if held[player] or holder[stone] then
		return
	end
	if (root.Position - stone.Position).Magnitude > I.PickupRange + 2 then
		return
	end
	held[player] = stone
	holder[stone] = player
	local prompt = promptOf(stone)
	if prompt then
		prompt.Enabled = false
	end
	stone.Anchored = false
	stone.CanCollide = false
	stone.Massless = true
	stone.AssemblyLinearVelocity = Vector3.zero
	stone.CFrame = root.CFrame * CFrame.new(1.1, -0.6, -1.4)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "HoldWeld"
	weld.Part0 = root
	weld.Part1 = stone
	weld.Parent = stone
	player:SetAttribute("HeldItem", displayName(stone))
end

-- Titik keluar lemparan: depan kepala, tapi jangan menembus dinding.
local function launchPoint(character: Model, from: Vector3, dir: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = Workspace:Raycast(from, dir * 2.2, params)
	if hit then
		return hit.Position - dir * 0.7
	end
	return from + dir * 2
end

local function onImpact(stone: BasePart, hit: BasePart)
	if holder[stone] or isCharacterPart(hit) or hit:IsDescendantOf(stone) then
		return
	end
	local now = os.clock()
	if now < (armedAt[stone] or 0) then
		return
	end
	if now - (lastImpact[stone] or 0) < I.ImpactDebounce then
		return
	end
	local v = lastVel[stone] or stone.AssemblyLinearVelocity
	local speed = v.Magnitude
	if speed < I.ImpactMinSpeed then
		return
	end
	lastImpact[stone] = now
	local def = Config.Sources.ItemImpact
	local weight = stone:GetAttribute("ItemWeight")
	weight = if type(weight) == "number" then math.clamp(weight, 0.2, 3) else 1
	local alpha = math.clamp((speed - I.ImpactMinSpeed) / (I.ImpactMaxSpeed - I.ImpactMinSpeed), 0, 1)
	alpha = math.clamp(alpha * (0.6 + 0.4 * weight), 0, 1)
	EchoSoundService.emit("ItemImpact", stone.Position, {
		actor = thrower[stone],
		radius = def.RevealRadiusMin + (def.RevealRadiusMax - def.RevealRadiusMin) * alpha,
		strength = def.StrengthMin + (def.StrengthMax - def.StrengthMin) * alpha,
		material = surfaceOf(hit),
	})
end

local function setupStone(stone: Instance)
	-- Hanya batu di Workspace (batu arena lama di ServerStorage diabaikan).
	if not stone:IsA("BasePart") or homeCFrame[stone] or not stone:IsDescendantOf(Workspace) then
		return
	end
	homeCFrame[stone] = stone.CFrame
	stone:SetAttribute("EchoDynamic", true)
	local prompt = promptOf(stone)
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = stone
	end
	prompt.ActionText = "Pick up"
	prompt.ObjectText = displayName(stone)
	prompt.MaxActivationDistance = I.PickupRange
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Triggered:Connect(function(player)
		pickup(player, stone)
	end)
	stone.Touched:Connect(function(hit)
		onImpact(stone, hit)
	end)
	if not stone.Anchored then
		stone:SetNetworkOwner(nil)
	end
end

function ThrowableService.init()
	for _, stone in CollectionService:GetTagged(Config.Tags.Throwable) do
		setupStone(stone)
	end
	CollectionService:GetInstanceAddedSignal(Config.Tags.Throwable):Connect(setupStone)

	local throwLimiter = RateLimiter.new(4, 3)
	Net.get("RequestThrow").OnServerEvent:Connect(function(player, dir)
		if not throwLimiter:allow(player) then
			return
		end
		local stone = held[player]
		if not stone or not Schema.isFiniteVector(dir) then
			return
		end
		local mag = dir.Magnitude
		if mag < 0.5 or mag > 1.5 then
			return
		end
		dir = dir.Unit
		local root, humanoid = rootOf(player)
		if not (root and humanoid) or humanoid.Health <= 0 then
			return
		end
		-- Arah harus kira-kira ke depan karakter (first-person: karakter ikut menghadap kamera).
		if dir:Dot(root.CFrame.LookVector) < -0.2 then
			return
		end
		local character = player.Character :: Model
		local head = character:FindFirstChild("Head") :: BasePart?
		local from = if head then head.Position else root.Position + Vector3.new(0, 1.5, 0)
		release(player, stone, launchPoint(character, from, dir), dir * I.ThrowSpeed + Vector3.new(0, I.ThrowUpBoost, 0))
	end)

	local dropLimiter = RateLimiter.new(4, 3)
	Net.get("RequestDrop").OnServerEvent:Connect(function(player, ...)
		if select("#", ...) > 0 or not dropLimiter:allow(player) then
			return
		end
		local stone = held[player]
		local root = rootOf(player)
		if not stone or not root then
			return
		end
		local character = player.Character :: Model
		local look = root.CFrame.LookVector
		release(player, stone, launchPoint(character, root.Position, look), look * I.DropSpeed)
	end)

	local function dropOnLoss(player: Player)
		local stone = held[player]
		if stone then
			local pos = stone.Position
			release(player, stone, pos, Vector3.zero)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		dropOnLoss(player)
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterRemoving:Connect(function()
			dropOnLoss(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterRemoving:Connect(function()
			dropOnLoss(player)
		end)
	end

	-- Simpan kecepatan frame sebelumnya (Touched datang setelah tumbukan mengubah kecepatan)
	-- dan kembalikan batu yang jatuh keluar map.
	RunService.Heartbeat:Connect(function()
		for stone, home in homeCFrame do
			if not stone.Parent then
				homeCFrame[stone] = nil
				continue
			end
			if holder[stone] then
				continue
			end
			lastVel[stone] = stone.AssemblyLinearVelocity
			if stone.Position.Y < I.KillY then
				stone.AssemblyLinearVelocity = Vector3.zero
				stone.CFrame = home
			end
		end
	end)
end

return ThrowableService
