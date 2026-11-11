-- BuildPlace: dijalankan SEKALI di mode Edit Studio (command bar / MCP execute_luau).
-- Membuat instance asli yang tersimpan di place: arena tes, HUD, folder Remotes, setting pemain.
-- Aman dijalankan ulang: arena & HUD lama dihapus dulu.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

-- ===== Setting place =====
StarterPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
StarterPlayer.CharacterWalkSpeed = 12
Workspace.StreamingEnabled = false -- P1: seluruh arena di-load; streaming ditangani milestone berikutnya
Lighting.ClockTime = 14 -- terang di mode Edit; server menggelapkan saat runtime

local baseplate = Workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate:Destroy()
end
local oldSpawn = Workspace:FindFirstChild("SpawnLocation")
if oldSpawn then
	oldSpawn:Destroy()
end

-- ===== Remotes =====
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
for _, name in { "RequestManualPing", "RequestMoveMode", "RequestThrow", "RequestDrop", "EchoSoundEvent", "DevRegenerateMap" } do
	if not remotes:FindFirstChild(name) then
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
	end
end

-- ===== Arena =====
local old = Workspace:FindFirstChild("Arena")
if old then
	old:Destroy()
end
local arena = Instance.new("Folder")
arena.Name = "Arena"

local GRAY = Color3.fromRGB(150, 150, 155)
local FLOOR_Y = 0.5 -- permukaan atas lantai
local H = 16 -- tinggi ruangan

local function part(name: string, size: Vector3, pos: Vector3, props: { [string]: any }?, cls: string?)
	local p = Instance.new(cls or "Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(pos)
	p.Anchored = true
	p.Color = GRAY
	p.Material = Enum.Material.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	CollectionService:AddTag(p, "EchoGeometry")
	if props then
		for k, v in props do
			if k == "Attributes" then
				for an, av in v do
					p:SetAttribute(an, av)
				end
			elseif k == "CFrame" then
				p.CFrame = v
			else
				(p :: any)[k] = v
			end
		end
	end
	p.Parent = arena
	return p
end

-- Lantai utama dengan grid 8 stud
part("Floor", Vector3.new(120, 1, 120), Vector3.new(0, 0, 0), {
	Attributes = { EchoGrid = 8, SurfaceProfile = "Concrete" },
})
-- Langit-langit: menghalangi gelombang & langit, tanpa garis
part("Ceiling", Vector3.new(124, 1, 124), Vector3.new(0, FLOOR_Y + H + 0.5, 0), {
	Attributes = { EchoEdges = "none" },
})

-- Dinding luar
local wy = FLOOR_Y + H / 2
part("WallNorth", Vector3.new(124, H, 2), Vector3.new(0, wy, 61))
part("WallSouth", Vector3.new(124, H, 2), Vector3.new(0, wy, -61))
part("WallEast", Vector3.new(2, H, 120), Vector3.new(61, wy, 0))
part("WallWest", Vector3.new(2, H, 120), Vector3.new(-61, wy, 0))

-- Dinding pemisah di z = 0: celah pintu di x = 0 (lebar 6) dan lorong terbuka di x = -40 (lebar 6)
part("DividerWest", Vector3.new(17, H, 2), Vector3.new(-51.5, wy, 0)) -- x -60..-43
part("DividerMid", Vector3.new(34, H, 2), Vector3.new(-20, wy, 0)) -- x -37..-3
part("DividerEast", Vector3.new(57, H, 2), Vector3.new(31.5, wy, 0)) -- x 3..60
part("DoorLintel", Vector3.new(6, H - 10, 2), Vector3.new(0, FLOOR_Y + 10 + (H - 10) / 2, 0))
part("ArchLintel", Vector3.new(6, H - 10, 2), Vector3.new(-40, FLOOR_Y + 10 + (H - 10) / 2, 0))

-- Pintu geser (interaktif, putih). Terbuka = geser ke +X masuk ke dalam dinding.
local door = part("DoorPanel", Vector3.new(6, 10, 0.8), Vector3.new(0, FLOOR_Y + 5, 0), {
	Material = Enum.Material.Metal,
	Attributes = { EchoCategory = "Interactive", EchoDynamic = true, SurfaceProfile = "Metal", OpenOffset = Vector3.new(6.2, 0, 0) },
})
CollectionService:AddTag(door, "EchoDoor")
local doorPrompt = Instance.new("ProximityPrompt")
doorPrompt.ActionText = "Open"
doorPrompt.ObjectText = "Door"
doorPrompt.Parent = door

-- ===== Ruang A (selatan, spawn) =====
local spawn = Instance.new("SpawnLocation")
spawn.Name = "SpawnLocation"
spawn.Size = Vector3.new(6, 1, 6)
spawn.CFrame = CFrame.new(0, FLOOR_Y + 0.05, -48)
spawn.Anchored = true
spawn.CanCollide = false
spawn.Transparency = 1
spawn.Duration = 0
spawn.Neutral = true
spawn.Parent = arena

part("CrateA1", Vector3.new(6, 6, 6), Vector3.new(15, FLOOR_Y + 3, -22))
part("CrateA2", Vector3.new(4, 8, 4), Vector3.new(-14, FLOOR_Y + 4, -18))
part("StoneTable", Vector3.new(6, 3, 3), Vector3.new(6, FLOOR_Y + 1.5, -40))
-- Plat logam (langkah lebih keras)
part("MetalPlate", Vector3.new(24, 0.2, 24), Vector3.new(-30, FLOOR_Y + 0.1, -32), {
	Material = Enum.Material.DiamondPlate,
	Attributes = { EchoGrid = 4, SurfaceProfile = "Metal" },
})
-- Genangan air (tidak padat, tapi terkena raycast langkah)
part("Puddle", Vector3.new(16, 0.2, 14), Vector3.new(30, FLOOR_Y + 0.1, -36), {
	CanCollide = false,
	Material = Enum.Material.Glass,
	Color = Color3.fromRGB(80, 120, 160),
	Attributes = { EchoEdges = "top", EchoOccludes = false, SurfaceProfile = "Water" },
})
-- Lorong timur: dinding di x = 45 dari z = -52 sampai -12, menguji oklusi lintas dinding
part("CorridorWall", Vector3.new(2, H, 40), Vector3.new(45, wy, -32))

-- Batu yang bisa dilempar (interaktif, putih)
for i, x in { 4, 6, 8 } do
	local stone = part(`Stone{i}`, Vector3.new(1.2, 1.2, 1.2), Vector3.new(x, FLOOR_Y + 3.6, -40), {
		Anchored = false,
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Slate,
		Attributes = {
			EchoCategory = "Interactive",
			EchoDynamic = true,
			EchoOccludes = false,
			DisplayName = "Stone",
			ItemWeight = 1,
		},
	})
	CollectionService:AddTag(stone, "EchoThrowable")
	local p = Instance.new("ProximityPrompt")
	p.ActionText = "Pick up"
	p.ObjectText = "Stone"
	p.MaxActivationDistance = 8
	p.Parent = stone
end

-- ===== Ruang B (utara) =====
for _, pos in { Vector3.new(-20, 0, 20), Vector3.new(20, 0, 20), Vector3.new(-20, 0, 40), Vector3.new(20, 0, 40) } do
	part("Pillar", Vector3.new(4, H, 4), Vector3.new(pos.X, wy, pos.Z))
end
part("LowCover", Vector3.new(15, 3, 1.5), Vector3.new(-37, FLOOR_Y + 1.5, 30))
part("CrateB1", Vector3.new(5, 5, 5), Vector3.new(-45, FLOOR_Y + 2.5, 48))
part("CrateB2", Vector3.new(5, 5, 5), Vector3.new(-39.5, FLOOR_Y + 2.5, 48))
part("CrateB3", Vector3.new(5, 5, 5), Vector3.new(-42, FLOOR_Y + 7.5, 48))
-- Platform + ramp (WedgePart: sisi tinggi di +Z)
part("Platform", Vector3.new(14, 4, 14), Vector3.new(38, FLOOR_Y + 2, 45))
part("Ramp", Vector3.new(6, 4, 10), Vector3.new(38, FLOOR_Y + 2, 33), nil, "WedgePart")

-- Mesin: sumber suara lingkungan terjadwal
local machine = part("Generator", Vector3.new(8, 6, 6), Vector3.new(0, FLOOR_Y + 3, 47), {
	Material = Enum.Material.Metal,
	Attributes = { RevealRadius = 30, Strength = 60, Duration = 2, IntervalMin = 5, IntervalMax = 8 },
})
CollectionService:AddTag(machine, "EchoEmitter")

arena.Parent = Workspace

-- ===== HUD =====
local oldHud = StarterGui:FindFirstChild("GameHUD")
if oldHud then
	oldHud:Destroy()
end
local hud = Instance.new("ScreenGui")
hud.Name = "GameHUD"
hud.ResetOnSpawn = false
hud.IgnoreGuiInset = true
hud.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local FONT = Enum.Font.GothamMedium
local function label(name: string, parent: Instance, text: string, size: UDim2, pos: UDim2, anchor: Vector2)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = FONT
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextSize = 16
	l.Size = size
	l.Position = pos
	l.AnchorPoint = anchor
	l.Parent = parent
	return l
end

-- Crosshair: titik + cincin tipis
local cross = Instance.new("Frame")
cross.Name = "Crosshair"
cross.AnchorPoint = Vector2.new(0.5, 0.5)
cross.Position = UDim2.fromScale(0.5, 0.5)
cross.Size = UDim2.fromOffset(18, 18)
cross.BackgroundTransparency = 1
cross.Parent = hud
local ring = Instance.new("UIStroke")
ring.Color = Color3.new(1, 1, 1)
ring.Transparency = 0.55
ring.Thickness = 1.5
ring.Parent = cross
Instance.new("UICorner", cross).CornerRadius = UDim.new(1, 0)
local dot = Instance.new("Frame")
dot.Name = "Dot"
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.fromScale(0.5, 0.5)
dot.Size = UDim2.fromOffset(4, 4)
dot.BackgroundColor3 = Color3.new(1, 1, 1)
dot.BorderSizePixel = 0
dot.Parent = cross
Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

-- Panel sonar (bawah tengah)
local sonar = Instance.new("Frame")
sonar.Name = "SonarPanel"
sonar.AnchorPoint = Vector2.new(0.5, 1)
sonar.Position = UDim2.new(0.5, 0, 1, -28)
sonar.Size = UDim2.fromOffset(260, 40)
sonar.BackgroundTransparency = 1
sonar.Parent = hud
label("Label", sonar, "SONAR READY  [Q]", UDim2.new(1, 0, 0, 20), UDim2.fromScale(0.5, 0), Vector2.new(0.5, 0))
local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.fromScale(0.5, 1)
bar.Size = UDim2.new(1, 0, 0, 6)
bar.BackgroundColor3 = Color3.fromRGB(30, 40, 45)
bar.BorderSizePixel = 0
bar.Parent = sonar
local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(1, 1)
fill.BackgroundColor3 = Color3.fromRGB(70, 225, 255)
fill.BorderSizePixel = 0
fill.Parent = bar

local mode = label("ModeLabel", hud, "WALK", UDim2.fromOffset(200, 22), UDim2.new(0, 24, 1, -30), Vector2.new(0, 1))
mode.TextXAlignment = Enum.TextXAlignment.Left
local held = label("HeldLabel", hud, "", UDim2.fromOffset(420, 22), UDim2.new(1, -24, 1, -30), Vector2.new(1, 1))
held.TextXAlignment = Enum.TextXAlignment.Right
held.Visible = false

-- Panel bantuan (H)
local help = Instance.new("Frame")
help.Name = "HelpPanel"
help.Position = UDim2.fromOffset(24, 24)
help.Size = UDim2.fromOffset(330, 230)
help.BackgroundColor3 = Color3.new(0, 0, 0)
help.BackgroundTransparency = 0.35
help.BorderSizePixel = 0
help.Parent = hud
local helpText = label(
	"Text",
	help,
	table.concat({
		"ECHO//VOID  -  sound is sight",
		"",
		"WASD  move      SHIFT  run (loud)",
		"C / CTRL  crouch (quiet)",
		"Q  sonar ping (3 s cooldown)",
		"E  interact      F  throw      G  drop",
		"H  toggle help   F3  debug",
		"",
		"--- cyan thin: structure",
		"=== white thick: interactive",
		"green glow: other players",
	}, "\n"),
	UDim2.new(1, -24, 1, -20),
	UDim2.fromOffset(12, 10),
	Vector2.zero
)
helpText.TextXAlignment = Enum.TextXAlignment.Left
helpText.TextYAlignment = Enum.TextYAlignment.Top
helpText.TextSize = 15

-- Panel debug (F3)
local dbg = Instance.new("Frame")
dbg.Name = "DebugPanel"
dbg.AnchorPoint = Vector2.new(1, 0)
dbg.Position = UDim2.new(1, -24, 0, 24)
dbg.Size = UDim2.fromOffset(300, 90)
dbg.BackgroundColor3 = Color3.new(0, 0, 0)
dbg.BackgroundTransparency = 0.35
dbg.BorderSizePixel = 0
dbg.Visible = false
dbg.Parent = hud
local dbgText = label("Text", dbg, "", UDim2.new(1, -16, 1, -12), UDim2.fromOffset(8, 6), Vector2.zero)
dbgText.TextXAlignment = Enum.TextXAlignment.Left
dbgText.TextYAlignment = Enum.TextYAlignment.Top
dbgText.TextSize = 14
dbgText.Font = Enum.Font.Code

hud.Parent = StarterGui

return "BuildPlace OK"
