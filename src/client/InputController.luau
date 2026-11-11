-- InputController: Q sonar, Shift lari, C/Ctrl jongkok, F lempar, G jatuhkan.
-- ContextActionService otomatis membuat tombol sentuh untuk mobile.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local localPlayer = Players.LocalPlayer
local InputController = {}

local running = false
local crouching = false
local sentMode = "Walk"
local ui -- UIController (opsional, untuk feedback cooldown)

local pingRemote = Net.get("RequestManualPing")
local modeRemote = Net.get("RequestMoveMode")
local throwRemote = Net.get("RequestThrow")
local dropRemote = Net.get("RequestDrop")

local function desiredMode(): string
	if running then
		return "Run"
	elseif crouching then
		return "Crouch"
	end
	return "Walk"
end

local function syncMode()
	local mode = desiredMode()
	if mode ~= sentMode then
		sentMode = mode
		modeRemote:FireServer(mode)
	end
end

local function applyCameraOffset()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local target = if localPlayer:GetAttribute("MoveMode") == "Crouch"
		then Config.Movement.CrouchCameraOffset
		else Vector3.zero
	TweenService:Create(humanoid, TweenInfo.new(0.2), { CameraOffset = target }):Play()
end

local function onPing(_, state)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local readyAt = localPlayer:GetAttribute("PingReadyAt")
	if type(readyAt) == "number" and Workspace:GetServerTimeNow() < readyAt then
		if ui then
			ui.flashCooldown()
		end
		return Enum.ContextActionResult.Sink
	end
	pingRemote:FireServer()
	return Enum.ContextActionResult.Sink
end

local function onRun(_, state)
	if state == Enum.UserInputState.Begin then
		running = true
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		running = false
	else
		return Enum.ContextActionResult.Pass
	end
	syncMode()
	return Enum.ContextActionResult.Pass
end

local function onCrouch(_, state)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	crouching = not crouching
	syncMode()
	return Enum.ContextActionResult.Sink
end

local function onThrow(_, state)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if localPlayer:GetAttribute("HeldItem") == nil then
		return Enum.ContextActionResult.Pass
	end
	throwRemote:FireServer(Workspace.CurrentCamera.CFrame.LookVector)
	return Enum.ContextActionResult.Sink
end

local function onDrop(_, state)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if localPlayer:GetAttribute("HeldItem") == nil then
		return Enum.ContextActionResult.Pass
	end
	dropRemote:FireServer()
	return Enum.ContextActionResult.Sink
end

function InputController.init(uiController)
	ui = uiController
	ContextActionService:BindAction("EchoPing", onPing, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("EchoPing", "PING")
	ContextActionService:BindAction("EchoRun", onRun, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("EchoRun", "RUN")
	ContextActionService:BindAction("EchoCrouch", onCrouch, true, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle("EchoCrouch", "CROUCH")
	ContextActionService:BindAction("EchoThrow", onThrow, true, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("EchoThrow", "THROW")
	ContextActionService:BindAction("EchoDrop", onDrop, false, Enum.KeyCode.G, Enum.KeyCode.ButtonY)

	localPlayer:GetAttributeChangedSignal("MoveMode"):Connect(applyCameraOffset)
	localPlayer.CharacterAdded:Connect(function()
		-- Server reset ke Walk saat respawn; samakan state lokal.
		running = false
		crouching = false
		sentMode = "Walk"
	end)
end

return InputController
