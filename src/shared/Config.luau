-- ECHO//VOID - Konfigurasi bersama (server + client).
-- SEMUA angka di sini PROVISIONAL (lihat PRD 5.2). Ubah di sini, jangan hardcode di sistem lain.
local Config = {}

Config.Version = "0.2.0-p2"

-- Nama tag CollectionService yang dipakai di map.
Config.Tags = {
	Geometry = "EchoGeometry", -- part yang punya wireframe + (default) menghalangi gelombang
	Throwable = "EchoThrowable", -- item yang bisa diambil/dilempar (batu tes)
	Door = "EchoDoor", -- panel pintu geser
	Emitter = "EchoEmitter", -- sumber suara lingkungan (mesin)
}

-- Kategori visual. Ketebalan garis sengaja berbeda per kategori supaya
-- informasi tidak hanya bergantung pada warna (aksesibilitas, PRD 5.3).
Config.Categories = {
	Structure = { Color = Color3.fromRGB(70, 225, 255), Thickness = 2 }, -- cyan
	Interactive = { Color = Color3.fromRGB(255, 255, 255), Thickness = 3.5 }, -- putih
	Valuable = { Color = Color3.fromRGB(255, 184, 64), Thickness = 3 }, -- amber
	Threat = { Color = Color3.fromRGB(255, 60, 60), Thickness = 4.5 }, -- merah
	Player = { Color = Color3.fromRGB(90, 255, 140), Thickness = 3 }, -- hijau (pemain lain)
	Exit = { Color = Color3.fromRGB(190, 120, 255), Thickness = 4 }, -- ungu (zona ekstraksi)
}

-- Generator peta prosedural (PRD 6). Semua angka provisional.
Config.MapGen = {
	Enabled = true, -- false = pakai arena tes lama (Workspace.Arena)
	Seed = 0, -- 0 = acak tiap server; isi angka untuk mereproduksi peta tertentu
	ContentVersion = "industrial-1", -- naikkan kalau template berubah (seed lama jadi tidak setara)
	Origin = Vector3.new(0, 0, 0),
	CellSize = 32, -- satu sel grid (stud)
	RoomHeight = 14,
	WallThickness = 1,
	DoorWidth = 6,
	DoorHeight = 9,
	RoomCountMin = 8,
	RoomCountMax = 12,
	LoopChance = 0.6, -- peluang dua socket yang berhadapan disambung jadi loop
	MaxLoops = 3, -- maks loop per peta
	LoopMaxLength = 3, -- panjang maks koridor loop (sel)
	LoopRoomBudget = 2, -- slot ruangan yang disisakan untuk koridor loop
	DoorChance = 0.35, -- peluang sambungan diberi pintu geser
	MaxAttempts = 12, -- percobaan seed turunan sebelum fallback
	FallbackSeed = 1, -- seed peta cadangan yang dijamin valid oleh tes GeneratorSeeds
	Required = { -- tag ruangan wajib per peta (array supaya urutan deterministik)
		{ tag = "Machine", count = 1 },
		{ tag = "Loot", count = 1 },
		{ tag = "Danger", count = 1 },
	},
	ExitMinCells = 2, -- ruang cukup untuk 4 pemain + barang bawaan
	PathAgent = { AgentRadius = 2, AgentHeight = 5, AgentCanJump = false },
}

-- Sumber suara. RevealRadius = radius visual (stud), Strength = kekuatan untuk AI (nanti),
-- Duration = lama fase terang (detik), Speed = kecepatan gelombang (stud/detik),
-- Brightness = transparansi awal garis (0 = paling terang).
-- Radius visual dan kekuatan AI SENGAJA terpisah (PRD 5.2).
Config.Sources = {
	CrouchStep = { RevealRadius = 4, Duration = 0.8, Strength = 3, Speed = 40, Brightness = 0.35 },
	WalkStep = { RevealRadius = 10, Duration = 1.4, Strength = 12, Speed = 45, Brightness = 0.2 },
	RunStep = { RevealRadius = 15, Duration = 1.1, Strength = 32, Speed = 55, Brightness = 0.15 },
	ManualPing = { RevealRadius = 38, Duration = 2.7, Strength = 65, Speed = 40, Brightness = 0, Cooldown = 3 },
	ItemImpact = {
		RevealRadiusMin = 12,
		RevealRadiusMax = 25,
		Duration = 1.5,
		StrengthMin = 20,
		StrengthMax = 55,
		Speed = 50,
		Brightness = 0.05,
	},
	Machine = { RevealRadius = 30, Duration = 2.0, Strength = 60, Speed = 30, Brightness = 0.1 },
	DoorMove = { RevealRadius = 9, Duration = 1.2, Strength = 18, Speed = 40, Brightness = 0.1 },
}

-- Batas override atribut untuk emitter lingkungan (PRD: 20-50 stud, 1-3 s, 40-90).
Config.EmitterLimits = {
	RadiusMin = 20,
	RadiusMax = 50,
	DurationMin = 1,
	DurationMax = 3,
	StrengthMin = 40,
	StrengthMax = 90,
	IntervalMin = 2,
}

-- Profil permukaan langkah kaki. Pengali diterapkan ke radius & kekuatan langkah.
Config.Surfaces = {
	Concrete = { RadiusMul = 1.0, StrengthMul = 1.0 },
	Metal = { RadiusMul = 1.25, StrengthMul = 1.4 },
	Water = { RadiusMul = 1.1, StrengthMul = 1.25 },
}
-- Material Roblox -> profil (kalau part tidak punya atribut SurfaceProfile).
Config.MaterialToSurface = {
	[Enum.Material.Metal] = "Metal",
	[Enum.Material.DiamondPlate] = "Metal",
	[Enum.Material.CorrodedMetal] = "Metal",
	[Enum.Material.Foil] = "Metal",
	[Enum.Material.Water] = "Water",
}

Config.Movement = {
	CrouchSpeed = 6,
	WalkSpeed = 12,
	RunSpeed = 20,
	-- Langkah dihitung dari jarak tempuh (bukan timer) supaya tidak tergantung FPS.
	StrideCrouch = 2.4,
	StrideWalk = 3.4,
	StrideRun = 4.6,
	MinStepSpeed = 1.5, -- di bawah ini dianggap diam
	RunThreshold = 1.15, -- speed > WalkSpeed * ini => langkah lari
	CrouchTolerance = 1.3, -- crouch hanya diakui kalau speed <= CrouchSpeed * ini
	TeleportReset = 12, -- lompatan posisi > ini per frame dianggap teleport (tidak dihitung)
	CrouchCameraOffset = Vector3.new(0, -1.6, 0),
}

Config.Items = {
	PickupRange = 8,
	ThrowSpeed = 55,
	ThrowUpBoost = 6,
	DropSpeed = 4,
	ImpactMinSpeed = 6,
	ImpactMaxSpeed = 45,
	ImpactDebounce = 0.3,
	ArmDelay = 0.08, -- detik setelah lempar sebelum benturan dihitung
	KillY = -60, -- batu jatuh di bawah ini dikembalikan ke posisi awal
}

Config.Doors = {
	TweenTime = 0.7,
	PromptDistance = 8,
}

Config.Network = {
	RelevancyMargin = 40, -- event dikirim ke pemain dalam RevealRadius + ini
	RemoteBurst = 8, -- token bucket per pemain per remote
	RemoteRefillPerSecond = 6,
	PingLatencyTolerance = 0.1, -- detik toleransi cooldown karena latensi
}

Config.Render = {
	SegmentLength = 3, -- rusuk panjang dipecah jadi segmen <= ini (supaya gelombang terlihat merambat)
	EdgeInflate = 0.15, -- garis digeser sedikit keluar dari permukaan (0.06 masih putus-putus di kejauhan)
	GridCell = 16, -- ukuran sel spatial hash
	FadeExponent = 1.6, -- kurva fade fase terang (1 = linear)
	AfterglowSeconds = 5, -- sisa jejak redup setelah fase terang ("echo memudar perlahan")
	AfterglowTransparency = 0.82,
	OcclusionTolerance = 0.75, -- hit raycast sejauh ini dari target masih dianggap terlihat
	OriginMarkerRadius = 0.3,
	OriginMarkerLifetime = 0.8,
	DevShowAllTransparency = 0.45, -- dev view: transparansi wireframe penuh
	Quality = "Auto", -- "Auto" | "PC" | "Mobile"
	Presets = {
		PC = { MaxActiveSegments = 3500, RaycastsPerFrame = 450, MaxWaves = 24, ThicknessScale = 1, Prewarm = 400 },
		Mobile = { MaxActiveSegments = 1400, RaycastsPerFrame = 160, MaxWaves = 12, ThicknessScale = 1.3, Prewarm = 150 },
	},
}

Config.Players = {
	VisibleRange = 70, -- pemain lain terlihat (highlight hijau) dalam jarak ini, tetap terhalang dinding
	FillTransparency = 0.78,
	OutlineTransparency = 0.05,
}

-- Folder map yang digelapkan saat runtime.
Config.World = {
	MapFolders = { "Arena", "RuntimeMap" },
	DarkColor = Color3.new(0, 0, 0),
}

-- ID audio. Kosongkan ("") untuk mematikan suara tertentu.
-- Sumber: suara bawaan Roblox (rbxasset://) dan library resmi Pro Sound Effects di Creator Store
-- (dilisensikan Roblox untuk kreator). Semua sudah dicek bisa dimuat (ContentProvider) 2026-11-11.
-- PLACEHOLDER: ganti dengan audio final saat sound pass (PRD P5).
Config.Audio = {
	Footstep = {
		Concrete = "rbxasset://sounds/action_jump_land.mp3",
		Metal = "rbxassetid://9116711303", -- Metal Impacts Hard Clanking Hits 12 (SFX)
		Water = "rbxassetid://9120582975", -- Water Slosh Short Shake Movement 4 (SFX)
	},
	FootstepVolume = 0.35,
	OwnFootstepVolumeMul = 0.6,
	ManualPing = "rbxassetid://9117327720", -- Piano Trails Slowed String Impacts (SFX), sci-fi stinger
	PingVolume = 0.5,
	ItemImpact = "rbxassetid://9118634469", -- Rock Impacts Throwing Stones (SFX)
	ImpactVolume = 0.8,
	Machine = "rbxassetid://9125782644", -- Pot Clank Hit Metal (SFX)
	MachineVolume = 0.5,
	MachineHum = "rbxassetid://9125674129", -- Metallic Glow Constant Deep Bassy Hum (SFX), loop
	MachineHumVolume = 0.25,
	DoorMove = "rbxassetid://9116570547", -- Metal Desk Drawer, heavy sliding (SFX)
	DoorVolume = 0.6,
}

Config.Debug = {
	LogEvents = false, -- print setiap sound event di server
	-- Dev view (tombol V): wireframe penuh / dunia terang. HANYA aktif di Roblox Studio
	-- (RunService:IsStudio()), jadi tidak bisa dipakai di game live walau lupa dimatikan.
	-- Set false sebelum rilis supaya warna asli map juga tidak ikut dikirim ke client.
	DevView = true,
	DevViewKey = Enum.KeyCode.V,
	DevRegenerateKey = Enum.KeyCode.N, -- dev: peta baru dengan seed acak (hanya diproses server di Studio)
}

return Config
