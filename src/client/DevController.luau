-- DevController: alat bantu DEV, tombol V ganti mode tampilan:
--   OFF        -> gameplay normal (gelap)
--   WIREFRAME  -> semua wireframe tampil terus (tanpa oklusi/fade), untuk cek layout & EdgeBuilder
--   LIT        -> dunia diterangi dengan warna asli (hanya di client ini), untuk cek geometri
-- Hanya aktif kalau Config.Debug.DevView = true DAN berjalan di Roblox Studio.
-- Tidak mengubah server: hanya visual lokal; sound event, oklusi echo, dan collision tetap sama.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DevController = {}

local MODES = { "OFF", "WIREFRAME", "LIT" }
local modeIndex = 1
local renderer
local label: TextLabel

local savedLighting: { [string]: any }? = nil
local savedAtmosphereDensity: number? = nil
local litParts: { [BasePart]: boolean } = {}

local LIT_LIGHTING = {
	ClockTime = 14,
	Brightness = 2,
	Ambient = Color3.fromRGB(110, 110, 115),
	OutdoorAmbient = Color3.fromRGB(128, 128, 128),
	EnvironmentDiffuseScale = 1,
	EnvironmentSpecularScale = 1,
}

local function forEachMapPart(fn: (BasePart) -> ())
	for _, name in Config.World.MapFolders do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			for _, d in folder:GetDescendants() do
				if d:IsA("BasePart") then
					fn(d)
				end
			end
		end
	end
end

local function setLit(on: boolean)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if on then
		savedLighting = {}
		for prop, value in LIT_LIGHTING do
			(savedLighting :: any)[prop] = (Lighting :: any)[prop];
			(Lighting :: any)[prop] = value
		end
		if atmosphere then
			savedAtmosphereDensity = atmosphere.Density
			atmosphere.Density = 0
		end
		forEachMapPart(function(part)
			local color = part:GetAttribute("DevColor")
			local material = part:GetAttribute("DevMaterial")
			if typeof(color) == "Color3" then
				part.Color = color
				local ok, mat = pcall(function()
					return (Enum.Material :: any)[material]
				end)
				if ok and mat then
					part.Material = mat
				end
				litParts[part] = true
			end
		end)
	else
		if savedLighting then
			for prop, value in savedLighting do
				(Lighting :: any)[prop] = value
			end
			savedLighting = nil
		end
		if atmosphere and savedAtmosphereDensity then
			atmosphere.Density = savedAtmosphereDensity
		end
		savedAtmosphereDensity = nil
		for part in litParts do
			if part.Parent then
				part.Color = Config.World.DarkColor
				part.Material = Enum.Material.SmoothPlastic
			end
		end
		table.clear(litParts)
	end
end

-- Plafon disembunyikan lokal di mode dev supaya layout bisa dilihat dari atas (freecam Shift+P).
local function setCeilingsHidden(hidden: boolean)
	forEachMapPart(function(part)
		if part.Name == "Ceiling" then
			part.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end)
end

local function apply()
	local mode = MODES[modeIndex]
	renderer.setShowAll(mode == "WIREFRAME")
	setLit(mode == "LIT")
	setCeilingsHidden(mode ~= "OFF")
	label.Visible = mode ~= "OFF"
	label.Text = `DEV VIEW: {mode}   [V] next   [N] new map`
end

local function buildLabel()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DevViewHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 16)
	label.Size = UDim2.fromOffset(360, 28)
	label.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
	label.BackgroundTransparency = 0.25
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Visible = false
	label.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function appendHelp()
	local hud = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("GameHUD", 10)
	local text = hud and hud:FindFirstChild("HelpPanel") and hud.HelpPanel:FindFirstChild("Text")
	if text and text:IsA("TextLabel") then
		text.Text ..= "\nV  dev view   N  new map (Studio only)"
		hud.HelpPanel.Size += UDim2.fromOffset(0, 18)
	end
end

function DevController.init(echoRenderer)
	if not (Config.Debug.DevView and RunService:IsStudio()) then
		return
	end
	renderer = echoRenderer
	buildLabel()
	task.spawn(appendHelp)
	local regenRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DevRegenerateMap", 5)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Config.Debug.DevViewKey then
			modeIndex = modeIndex % #MODES + 1
			apply()
		elseif input.KeyCode == Config.Debug.DevRegenerateKey and regenRemote then
			regenRemote:FireServer()
		end
	end)
	-- Peta baru = part lama hilang & part baru muncul; terapkan ulang mode LIT/WIREFRAME.
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "RuntimeMap" and MODES[modeIndex] ~= "OFF" then
			task.wait(0.5)
			local keep = modeIndex
			modeIndex = 1
			apply()
			modeIndex = keep
			apply()
		end
	end)
	print("[ECHO//VOID] dev view aktif (Studio): tekan V")
end

return DevController
