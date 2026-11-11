-- Entry point server ECHO//VOID (P0+P1). Hanya merangkai sistem; logika ada di modul.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

Net.ensure()
StarterPlayer.CameraMode = Enum.CameraMode.LockFirstPerson

local Systems = script.Parent
local order = {
	"MapService", -- pertama: peta harus ada sebelum sistem lain memindai tag
	"WorldDarkness",
	"EchoSoundService",
	"MovementService",
	"PingService",
	"FootstepService",
	"ThrowableService",
	"DoorService",
	"MachineService",
}

for _, name in order do
	local ok, err = pcall(function()
		local mod = require(Systems:WaitForChild(name))
		if mod.apply then
			mod.apply()
		else
			mod.init()
		end
	end)
	if not ok then
		warn(`[ECHO//VOID] Gagal start {name}: {err}`)
	end
end

print(`[ECHO//VOID] server siap, versi {Config.Version}`)
