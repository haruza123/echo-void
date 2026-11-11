-- DoorService: panel pintu geser bertag EchoDoor. Pintu tertutup = part solid yang menghalangi
-- raycast oklusi; terbuka = panel bergeser ke samping sehingga gelombang bisa lewat.
-- Atribut panel: OpenOffset (Vector3, ruang lokal; default geser sejauh lebar panel + 0.2 di sumbu X).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local EchoSoundService = require(script.Parent.EchoSoundService)

local DoorService = {}

local setup: { [BasePart]: boolean } = {}

local function setupDoor(panel: Instance)
	if not panel:IsA("BasePart") or setup[panel] then
		return
	end
	setup[panel] = true
	panel.Anchored = true
	panel:SetAttribute("EchoDynamic", true)
	if panel:GetAttribute("EchoCategory") == nil then
		panel:SetAttribute("EchoCategory", "Interactive")
	end

	local closedCF = panel.CFrame
	local offset = panel:GetAttribute("OpenOffset")
	if typeof(offset) ~= "Vector3" then
		offset = Vector3.new(panel.Size.X + 0.2, 0, 0)
	end
	local openCF = closedCF * CFrame.new(offset)

	local prompt = panel:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = panel
	end
	prompt.ObjectText = "Door"
	prompt.MaxActivationDistance = Config.Doors.PromptDistance
	prompt.RequiresLineOfSight = false

	local isOpen = panel:GetAttribute("IsOpen") == true
	local busy = false
	local info = TweenInfo.new(Config.Doors.TweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

	local function refreshPrompt()
		prompt.ActionText = if isOpen then "Close" else "Open"
	end
	panel.CFrame = if isOpen then openCF else closedCF
	refreshPrompt()

	prompt.Triggered:Connect(function(player)
		if busy then
			return
		end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end
		busy = true
		isOpen = not isOpen
		panel:SetAttribute("IsOpen", isOpen)
		refreshPrompt()
		EchoSoundService.emit("DoorMove", closedCF.Position, { actor = player, material = "Metal" })
		local tween = TweenService:Create(panel, info, { CFrame = if isOpen then openCF else closedCF })
		tween:Play()
		tween.Completed:Wait()
		busy = false
	end)
end

function DoorService.init()
	for _, panel in CollectionService:GetTagged(Config.Tags.Door) do
		setupDoor(panel)
	end
	CollectionService:GetInstanceAddedSignal(Config.Tags.Door):Connect(setupDoor)
end

return DoorService
