-- EchoSoundService: SATU-SATUNYA jalur untuk membuat sound event resmi.
-- Client tidak pernah bisa membuat event langsung; mereka hanya "meminta" (ping, lempar),
-- lalu sistem server memvalidasi dan memanggil emit().
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Schema = require(Shared.SoundEventSchema)
local Net = require(Shared.Net)

local EchoSoundService = {}

local emittedEvent = Instance.new("BindableEvent")
-- Untuk MonsterService di milestone berikutnya: konsumsi event tanpa bergantung pada rendering.
EchoSoundService.Emitted = emittedEvent.Event

local nextId = 0
local remote: RemoteEvent

export type EmitOptions = {
	actor: Player?,
	radius: number?,
	strength: number?,
	duration: number?,
	material: string?,
}

function EchoSoundService.init()
	remote = Net.get("EchoSoundEvent")
end

local function characterRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function EchoSoundService.emit(sourceType: string, position: Vector3, opts: EmitOptions?): Schema.SoundEvent?
	local def = Config.Sources[sourceType]
	if not def then
		warn(`[EchoSound] sourceType tidak dikenal: {sourceType}`)
		return nil
	end
	if not Schema.isFiniteVector(position) then
		warn(`[EchoSound] posisi tidak valid untuk {sourceType}`)
		return nil
	end
	local o: EmitOptions = opts or {}
	nextId += 1

	local ev: Schema.SoundEvent = {
		eventId = nextId,
		sourceType = sourceType,
		worldPosition = position,
		startedAtServer = Workspace:GetServerTimeNow(),
		revealRadius = o.radius or def.RevealRadius,
		soundStrength = o.strength or def.Strength,
		propagationSpeed = def.Speed,
		duration = o.duration or def.Duration,
		materialProfile = o.material or "None",
		brightness = def.Brightness,
		actorId = if o.actor then o.actor.UserId else nil,
	}

	-- Relevansi: kirim hanya ke pemain yang mungkin bisa melihat sebagian gelombang.
	local range = ev.revealRadius + Config.Network.RelevancyMargin
	local sent = 0
	for _, player in Players:GetPlayers() do
		local root = characterRoot(player)
		if player == o.actor or (root and (root.Position - position).Magnitude <= range) then
			remote:FireClient(player, ev)
			sent += 1
		end
	end

	if Config.Debug.LogEvents then
		print(
			`[EchoSound] #{ev.eventId} {sourceType} r={string.format("%.1f", ev.revealRadius)} `
				.. `str={string.format("%.0f", ev.soundStrength)} mat={ev.materialProfile} -> {sent} client`
		)
	end

	emittedEvent:Fire(ev)
	return ev
end

return EchoSoundService
