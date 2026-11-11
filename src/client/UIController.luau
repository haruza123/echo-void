-- UIController: mengisi HUD yang sudah di-author di StarterGui.GameHUD (lihat tools/BuildPlace.luau).
-- Teks in-game berbahasa Inggris; Roblox Automatic Translation bisa menerjemahkannya.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local localPlayer = Players.LocalPlayer
local UIController = {}

local hud: ScreenGui
local renderer
local flashUntil = 0

local READY_COLOR = Config.Categories.Structure.Color
local WAIT_COLOR = Color3.fromRGB(120, 140, 150)
local DENY_COLOR = Color3.fromRGB(255, 90, 90)

function UIController.flashCooldown()
	flashUntil = os.clock() + 0.35
end

local function setMode()
	local mode = localPlayer:GetAttribute("MoveMode")
	hud.ModeLabel.Text = string.upper(if type(mode) == "string" then mode else "Walk")
end

local function setHeld()
	local item = localPlayer:GetAttribute("HeldItem")
	if type(item) == "string" then
		hud.HeldLabel.Text = `HOLDING: {string.upper(item)}   [F] THROW   [G] DROP`
		hud.HeldLabel.Visible = true
	else
		hud.HeldLabel.Visible = false
	end
end

function UIController.init(echoRenderer)
	renderer = echoRenderer
	hud = localPlayer:WaitForChild("PlayerGui"):WaitForChild("GameHUD") :: ScreenGui
	local sonar = hud:WaitForChild("SonarPanel")
	local sonarLabel = sonar:WaitForChild("Label") :: TextLabel
	local fill = sonar:WaitForChild("Bar"):WaitForChild("Fill") :: Frame
	local help = hud:WaitForChild("HelpPanel") :: GuiObject
	local debugPanel = hud:WaitForChild("DebugPanel") :: GuiObject
	local debugText = debugPanel:WaitForChild("Text") :: TextLabel
	hud:WaitForChild("ModeLabel")
	hud:WaitForChild("HeldLabel")

	localPlayer:GetAttributeChangedSignal("MoveMode"):Connect(setMode)
	localPlayer:GetAttributeChangedSignal("HeldItem"):Connect(setHeld)
	setMode()
	setHeld()

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.H then
			help.Visible = not help.Visible
		elseif input.KeyCode == Enum.KeyCode.F3 then
			debugPanel.Visible = not debugPanel.Visible
		end
	end)

	local cooldown = Config.Sources.ManualPing.Cooldown
	local frames, fpsT, fps = 0, os.clock(), 0
	RunService.RenderStepped:Connect(function()
		local readyAt = localPlayer:GetAttribute("PingReadyAt")
		local remaining = if type(readyAt) == "number" then readyAt - Workspace:GetServerTimeNow() else 0
		if remaining > 0 then
			fill.Size = UDim2.fromScale(1 - remaining / cooldown, 1)
			fill.BackgroundColor3 = WAIT_COLOR
			sonarLabel.Text = string.format("SONAR  %.1fs", remaining)
		else
			fill.Size = UDim2.fromScale(1, 1)
			fill.BackgroundColor3 = READY_COLOR
			sonarLabel.Text = "SONAR READY  [Q]"
		end
		sonarLabel.TextColor3 = if os.clock() < flashUntil then DENY_COLOR else Color3.new(1, 1, 1)

		frames += 1
		local now = os.clock()
		if now - fpsT >= 0.5 then
			fps = frames / (now - fpsT)
			frames, fpsT = 0, now
			if debugPanel.Visible and renderer then
				local s = renderer.getStats()
				local map = Workspace:FindFirstChild("RuntimeMap")
				local mapLine = if map
					then string.format("\nmap seed %s | rooms %s | loops %s", tostring(map:GetAttribute("UsedSeed")), tostring(map:GetAttribute("Rooms")), tostring(map:GetAttribute("Loops")))
					else "\nmap: test arena"
				debugText.Text = string.format(
					"FPS %d | quality %s\nsegments %d | lit %d | pool %d\nwaves %d | raycasts/frame %d\nlast event %s" .. mapLine,
					fps,
					s.quality,
					s.segmentsTotal,
					s.active,
					s.pool,
					s.waves,
					s.raycastsLastFrame or 0,
					s.lastEvent
				)
			end
		end
	end)
end

return UIController
