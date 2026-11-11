-- WorldDarkness: membuat dunia "tanpa penglihatan normal" TANPA mematikan collision.
--
-- Strategi: geometri map tetap OPAQUE (Transparency 0, CanCollide tidak diubah) tapi dicat hitam
-- dan semua cahaya dimatikan. Hasilnya:
--   * tidak ada yang terlihat (hitam di atas hitam),
--   * collision & raycast tetap normal,
--   * dinding tetap menulis depth buffer, jadi garis echo / highlight pemain di BALIK dinding
--     tertutup secara visual (tidak bocor menembus dinding seperti kalau Transparency = 1).
-- Di mode Edit Studio map tetap berwarna abu-abu supaya mudah di-desain.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local WorldDarkness = {}

local BLACK = Config.World.DarkColor
-- Warna asli hanya disimpan untuk dev view di Studio; di game live tidak pernah dikirim ke client.
local KEEP_ORIGINAL = Config.Debug.DevView and RunService:IsStudio()

local function darkenPart(inst: Instance)
	if inst:IsA("BasePart") then
		if KEEP_ORIGINAL and inst:GetAttribute("DevColor") == nil then
			inst:SetAttribute("DevColor", inst.Color)
			inst:SetAttribute("DevMaterial", inst.Material.Name)
		end
		inst.Color = BLACK
		inst.Material = Enum.Material.SmoothPlastic
		inst.Reflectance = 0
		inst.CastShadow = false
		if inst:IsA("MeshPart") then
			inst.TextureID = ""
		end
	elseif inst:IsA("Decal") or inst:IsA("Texture") then
		inst.Transparency = 1
	elseif inst:IsA("SurfaceGui") or inst:IsA("BillboardGui") then
		inst.Enabled = false
	elseif inst:IsA("Light") or inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") then
		inst.Enabled = false
	end
end

local function darkenFolder(folder: Instance)
	for _, d in folder:GetDescendants() do
		darkenPart(d)
	end
	folder.DescendantAdded:Connect(darkenPart)
end

local function setupLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 0
	Lighting.Ambient = BLACK
	Lighting.OutdoorAmbient = BLACK
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	Lighting.ExposureCompensation = 0
	Lighting.GlobalShadows = true
	Lighting.FogColor = BLACK
	for _, child in Lighting:GetChildren() do
		-- Efek yang bisa mencerahkan layar atau menampilkan langit dimatikan.
		if child:IsA("Sky") or child:IsA("Atmosphere") or child:IsA("Clouds") then
			child:Destroy()
		elseif child:IsA("PostEffect") then
			child.Enabled = false
		end
	end
	local sky = Instance.new("Sky")
	sky.Name = "VoidSky"
	sky.CelestialBodiesShown = false
	sky.StarCount = 0
	sky.Parent = Lighting
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "VoidAtmosphere"
	atmosphere.Density = 0.6
	atmosphere.Offset = 1
	atmosphere.Color = BLACK
	atmosphere.Decay = BLACK
	atmosphere.Glare = 0
	atmosphere.Haze = 0
	atmosphere.Parent = Lighting
end

function WorldDarkness.apply()
	setupLighting()
	for _, name in Config.World.MapFolders do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			darkenFolder(folder)
		end
	end
	Workspace.ChildAdded:Connect(function(child)
		if table.find(Config.World.MapFolders, child.Name) then
			darkenFolder(child)
		end
	end)
	-- Part lepas di root Workspace (mis. Baseplate bawaan) juga digelapkan.
	for _, child in Workspace:GetChildren() do
		if child:IsA("BasePart") and child ~= Workspace.Terrain then
			darkenPart(child)
		end
	end
end

return WorldDarkness
