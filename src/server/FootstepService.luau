-- FootstepService: langkah kaki dihitung SERVER dari posisi karakter yang tereplikasi.
-- Client tidak mengirim langkah sama sekali => tidak bisa memalsukan atau menyembunyikan suara langkah.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local EchoSoundService = require(script.Parent.EchoSoundService)
local MovementService = require(script.Parent.MovementService)

local FootstepService = {}

type State = { lastPos: Vector3?, dist: number }
local states: { [Player]: State } = {}

local M = Config.Movement

local function surfaceFor(part: BasePart, material: Enum.Material): string
	local attr = part:GetAttribute("SurfaceProfile")
	if type(attr) == "string" and Config.Surfaces[attr] then
		return attr
	end
	return Config.MaterialToSurface[material] or "Concrete"
end

local function classify(player: Player, speed: number): (string, number)
	if speed > M.WalkSpeed * M.RunThreshold then
		return "RunStep", M.StrideRun
	end
	if MovementService.getMode(player) == "Crouch" and speed <= M.CrouchSpeed * M.CrouchTolerance then
		return "CrouchStep", M.StrideCrouch
	end
	return "WalkStep", M.StrideWalk
end

local function step(player: Player, character: Model, root: BasePart, humanoid: Humanoid, kind: string)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local depth = humanoid.HipHeight + root.Size.Y / 2 + 2
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -depth, 0), params)
	local pos: Vector3
	local surface = "Concrete"
	if hit then
		pos = hit.Position + Vector3.new(0, 0.5, 0)
		surface = surfaceFor(hit.Instance :: BasePart, hit.Material)
	else
		pos = root.Position - Vector3.new(0, depth - 2.5, 0)
	end
	local def = Config.Sources[kind]
	local mul = Config.Surfaces[surface] or Config.Surfaces.Concrete
	EchoSoundService.emit(kind, pos, {
		actor = player,
		radius = def.RevealRadius * mul.RadiusMul,
		strength = def.Strength * mul.StrengthMul,
		material = surface,
	})
end

local function update()
	for _, player in Players:GetPlayers() do
		local state = states[player]
		if not state then
			state = { lastPos = nil, dist = 0 }
			states[player] = state
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (character and root and humanoid) or humanoid.Health <= 0 then
			state.lastPos = nil
			state.dist = 0
			continue
		end
		local pos = root.Position
		local last = state.lastPos
		state.lastPos = pos
		if not last or humanoid.FloorMaterial == Enum.Material.Air then
			continue
		end
		local delta = Vector3.new(pos.X - last.X, 0, pos.Z - last.Z).Magnitude
		if delta > M.TeleportReset then
			state.dist = 0
			continue
		end
		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		if speed < M.MinStepSpeed then
			continue
		end
		state.dist += delta
		local kind, stride = classify(player, speed)
		if state.dist >= stride then
			state.dist = 0
			step(player, character :: Model, root :: BasePart, humanoid :: Humanoid, kind)
		end
	end
end

function FootstepService.init()
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	RunService.Heartbeat:Connect(update)
end

return FootstepService
