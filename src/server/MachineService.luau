-- MachineService: sumber suara lingkungan terjadwal (bertag EchoEmitter).
-- Atribut opsional: RevealRadius, Strength, Duration, IntervalMin, IntervalMax (dibatasi Config.EmitterLimits).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local EchoSoundService = require(script.Parent.EchoSoundService)

local MachineService = {}

local L = Config.EmitterLimits
local running: { [BasePart]: boolean } = {}

local function num(part: BasePart, name: string, default: number, lo: number, hi: number): number
	local v = part:GetAttribute(name)
	if type(v) ~= "number" then
		v = default
	end
	return math.clamp(v, lo, hi)
end

local function startEmitter(part: Instance)
	if not part:IsA("BasePart") or running[part] then
		return
	end
	running[part] = true
	local def = Config.Sources.Machine

	if Config.Audio.MachineHum ~= "" and not part:FindFirstChild("Hum") then
		local hum = Instance.new("Sound")
		hum.Name = "Hum"
		hum.SoundId = Config.Audio.MachineHum
		hum.Looped = true
		hum.Volume = Config.Audio.MachineHumVolume
		hum.RollOffMaxDistance = 80
		hum.Parent = part
		hum:Play()
	end

	task.spawn(function()
		local rng = Random.new()
		task.wait(rng:NextNumber(0.5, 2))
		-- Berhenti kalau mesin dikeluarkan dari Workspace (mis. dipindah ke ServerStorage).
		while part:IsDescendantOf(Workspace) do
			EchoSoundService.emit("Machine", part.Position, {
				radius = num(part, "RevealRadius", def.RevealRadius, L.RadiusMin, L.RadiusMax),
				strength = num(part, "Strength", def.Strength, L.StrengthMin, L.StrengthMax),
				duration = num(part, "Duration", def.Duration, L.DurationMin, L.DurationMax),
				material = "Metal",
			})
			local lo = num(part, "IntervalMin", 5, L.IntervalMin, 120)
			local hi = num(part, "IntervalMax", 8, lo, 120)
			task.wait(rng:NextNumber(lo, hi))
		end
		running[part] = nil
	end)
end

function MachineService.init()
	for _, part in CollectionService:GetTagged(Config.Tags.Emitter) do
		startEmitter(part)
	end
	CollectionService:GetInstanceAddedSignal(Config.Tags.Emitter):Connect(startEmitter)
end

return MachineService
