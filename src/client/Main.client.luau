-- Entry point client ECHO//VOID (P0+P1).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Schema = require(Shared:WaitForChild("SoundEventSchema"))
local Net = require(Shared:WaitForChild("Net"))

local folder = script.Parent
local EchoRenderer = require(folder:WaitForChild("EchoRenderer"))
local AudioController = require(folder:WaitForChild("AudioController"))
local UIController = require(folder:WaitForChild("UIController"))
local InputController = require(folder:WaitForChild("InputController"))
local TeammateHighlighter = require(folder:WaitForChild("TeammateHighlighter"))
local DevController = require(folder:WaitForChild("DevController"))

EchoRenderer.init()
AudioController.init()
TeammateHighlighter.init()
InputController.init(UIController)
DevController.init(EchoRenderer) -- hanya aktif di Studio + Config.Debug.DevView

Net.get("EchoSoundEvent").OnClientEvent:Connect(function(ev)
	if not Schema.isValid(ev) then
		warn("[ECHO//VOID] sound event tidak valid diabaikan")
		return
	end
	EchoRenderer.onEvent(ev)
	AudioController.onEvent(ev)
end)

-- UI terakhir karena menunggu GameHUD ter-clone ke PlayerGui.
task.spawn(UIController.init, EchoRenderer)

print(`[ECHO//VOID] client siap, versi {Config.Version}`)
