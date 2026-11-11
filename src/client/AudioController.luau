-- AudioController: memutar suara 3D untuk tiap sound event (kosmetik, milik client).
-- ID audio diatur di Config.Audio; ID kosong = suara itu dilewati.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local A = Config.Audio
local localPlayer = Players.LocalPlayer

local AudioController = {}
local rng = Random.new()

local function soundFor(ev): (string, number)
	local t = ev.sourceType
	if t == "WalkStep" or t == "RunStep" or t == "CrouchStep" then
		local id = A.Footstep[ev.materialProfile] or A.Footstep.Concrete
		local vol = A.FootstepVolume * math.clamp(ev.soundStrength / 20, 0.25, 1.6)
		if ev.actorId == localPlayer.UserId then
			vol *= A.OwnFootstepVolumeMul
		end
		return id, vol
	elseif t == "ManualPing" then
		return A.ManualPing, A.PingVolume
	elseif t == "ItemImpact" then
		return A.ItemImpact, A.ImpactVolume * math.clamp(ev.soundStrength / 55, 0.4, 1)
	elseif t == "Machine" then
		return A.Machine, A.MachineVolume
	elseif t == "DoorMove" then
		return A.DoorMove, A.DoorVolume
	end
	return "", 0
end

function AudioController.onEvent(ev)
	local id, volume = soundFor(ev)
	if id == "" or volume <= 0 then
		return
	end
	local att = Instance.new("Attachment")
	att.WorldPosition = ev.worldPosition
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = rng:NextNumber(0.92, 1.08)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 4
	sound.RollOffMaxDistance = math.max(40, ev.revealRadius * 4)
	sound.Parent = att
	att.Parent = Workspace.Terrain
	sound:Play()
	Debris:AddItem(att, 6)
end

function AudioController.init() end

return AudioController
