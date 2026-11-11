-- EchoRenderer: merender gelombang echo sebagai wireframe secara LOKAL di tiap client.
--
-- Alur:
--   1. Saat start, semua part bertag EchoGeometry diubah jadi segmen (EdgeBuilder) dan dimasukkan
--      ke spatial hash (part statis) atau daftar dinamis (pintu, batu).
--   2. Sound event datang -> kandidat segmen dalam radius dikumpulkan & diurutkan per jarak.
--   3. Tiap frame radius gelombang = (serverNow - startedAtServer) * speed. Segmen yang terlewati
--      dites oklusi (raycast dari sumber suara ke segmen); kalau lolos, segmen menyala.
--   4. Segmen yang menyala memakai LineHandleAdornment dari pool. Echo berulang hanya
--      me-refresh segmen yang sama (tidak membuat garis duplikat).
--   5. Fade: fase terang (Duration event) lalu afterglow redup, lalu adornment kembali ke pool.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local EdgeBuilder = require(Shared:WaitForChild("EdgeBuilder"))

local R = Config.Render
local TAG = Config.Tags.Geometry
local localPlayer = Players.LocalPlayer

local EchoRenderer = {}

-- ===== State =====
local quality
local qualityName = "PC"
local folder: Folder
local pool: { LineHandleAdornment } = {}
local active = {} -- segmen yang sedang punya adornment
local partSegs: { [BasePart]: { any } } = {}
local grid: { [number]: { any } } = {}
local staticKeys: { [string]: boolean } = {}
local dynamicSegs: { [any]: boolean } = {}
local occluderParams = RaycastParams.new()
local occluderDirty = true
local waves = {}
local seen: { [number]: boolean } = {}
local seenCount = 0
local markers: { SphereHandleAdornment } = {}
local liveMarkers = {}
local showAll = false -- dev view: semua wireframe tampil
local pin -- didefinisikan di bagian Reveal (forward declaration)

local stats = {
	segmentsTotal = 0,
	active = 0,
	waves = 0,
	raycasts = 0,
	pool = 0,
	quality = "PC",
	lastEvent = "-",
}

-- ===== Spatial hash =====
local CELL = R.GridCell
local function cellKey(ix: number, iy: number, iz: number): number
	return (ix + 2048) * 16777216 + (iy + 2048) * 4096 + (iz + 2048)
end
local function cellOf(p: Vector3): number
	return cellKey(math.floor(p.X / CELL), math.floor(p.Y / CELL), math.floor(p.Z / CELL))
end

local function roundKey(v: Vector3): string
	return string.format("%.1f,%.1f,%.1f", v.X, v.Y, v.Z)
end

-- ===== Pool adornment =====
local function newAdorn(): LineHandleAdornment
	local a = Instance.new("LineHandleAdornment")
	a.AlwaysOnTop = false
	a.ZIndex = 0
	a.Visible = false
	a.Parent = folder
	return a
end

local function acquire(): LineHandleAdornment
	local a = table.remove(pool)
	return a or newAdorn()
end

local function release(seg)
	local a = seg.adorn
	if not a then
		return
	end
	a.Visible = false
	a.Adornee = nil
	table.insert(pool, a)
	seg.adorn = nil
	local i = seg.activeIndex
	local n = #active
	local last = active[n]
	active[i] = last
	last.activeIndex = i
	active[n] = nil
	seg.activeIndex = nil
end

-- ===== Registrasi geometri =====
local function addPart(part: Instance)
	if not part:IsA("BasePart") or partSegs[part] then
		return
	end
	local segs = EdgeBuilder.build(part, R)
	local kept = {}
	local cf = part.CFrame
	for _, s in segs do
		if s.dynamic then
			dynamicSegs[s] = true
			table.insert(kept, s)
		else
			local wa, wb = cf * s.a, cf * s.b
			local k1, k2 = roundKey(wa), roundKey(wb)
			local key = if k1 < k2 then k1 .. "|" .. k2 else k2 .. "|" .. k1
			if not staticKeys[key] then
				staticKeys[key] = true
				s.key = key
				s.worldMid = cf * s.localMid
				local c = cellOf(s.worldMid)
				s.cell = c
				local bucket = grid[c]
				if not bucket then
					bucket = {}
					grid[c] = bucket
				end
				table.insert(bucket, s)
				table.insert(kept, s)
			end
		end
	end
	partSegs[part] = kept
	stats.segmentsTotal += #kept
	occluderDirty = true
	if showAll then
		for _, s in kept do
			pin(s)
		end
	end
end

local function removePart(part: Instance)
	local segs = partSegs[part :: BasePart]
	if not segs then
		return
	end
	for _, s in segs do
		s.alive = false
		release(s)
		if s.dynamic then
			dynamicSegs[s] = nil
		else
			staticKeys[s.key] = nil
			local bucket = grid[s.cell]
			if bucket then
				local idx = table.find(bucket, s)
				if idx then
					bucket[idx] = bucket[#bucket]
					bucket[#bucket] = nil
				end
			end
		end
	end
	stats.segmentsTotal -= #segs
	partSegs[part :: BasePart] = nil
	occluderDirty = true
end

local function rebuildOccluders()
	local list = {}
	for part in partSegs do
		if part:GetAttribute("EchoOccludes") ~= false then
			table.insert(list, part)
		end
	end
	occluderParams.FilterType = Enum.RaycastFilterType.Include
	occluderParams.FilterDescendantsInstances = list
	occluderDirty = false
end

-- ===== Oklusi =====
local function segWorldMid(s): Vector3
	if s.dynamic then
		return s.part.CFrame * s.localMid
	end
	return s.worldMid
end

local function visibleFrom(origin: Vector3, s): boolean
	local target = segWorldMid(s)
	local dir = target - origin
	local dist = dir.Magnitude
	if dist < 0.6 then
		return true
	end
	stats.raycasts += 1
	local hit = Workspace:Raycast(origin, dir * ((dist - 0.15) / dist), occluderParams)
	if not hit then
		return true
	end
	if hit.Instance == s.part then
		return true
	end
	return hit.Distance >= dist - R.OcclusionTolerance
end

-- ===== Reveal & fade =====
local function attach(s)
	local a = acquire()
	local cat = Config.Categories[s.category] or Config.Categories.Structure
	a.Adornee = s.part
	a.CFrame = s.cf
	a.Length = s.length
	a.Color3 = cat.Color
	a.Thickness = cat.Thickness * quality.ThicknessScale
	a.Visible = true
	s.adorn = a
	table.insert(active, s)
	s.activeIndex = #active
end

-- Dev view: segmen "dipin" tampil terus tanpa fade (hanya dipakai DevController di Studio).
function pin(s)
	if not s.alive then
		return
	end
	if not s.adorn then
		attach(s)
	end
	s.pinned = true
	s.lastT = R.DevShowAllTransparency
	s.adorn.Transparency = R.DevShowAllTransparency
end

local function reveal(s, wave, now: number)
	if not s.alive or s.pinned or not s.part.Parent then
		return
	end
	if s.adorn then
		-- Refresh: hanya kalau echo baru lebih terang dari kondisi sekarang.
		if wave.brightness > (s.lastT or 1) then
			return
		end
	else
		if #active >= quality.MaxActiveSegments then
			local victim = active[1]
			if victim.pinned then
				return
			end
			release(victim)
		end
		attach(s)
	end
	s.t0 = now
	s.dur = wave.duration
	s.startT = wave.brightness
	s.lastT = wave.brightness
	s.adorn.Transparency = wave.brightness
end

local function transparencyAt(s, now: number): number?
	local t = now - s.t0
	if t < s.dur then
		local alpha = (t / s.dur) ^ R.FadeExponent
		return s.startT + (R.AfterglowTransparency - s.startT) * alpha
	end
	local g = (t - s.dur) / R.AfterglowSeconds
	if g >= 1 then
		return nil
	end
	return R.AfterglowTransparency + (1 - R.AfterglowTransparency) * g
end

local function updateFades(now: number)
	for i = #active, 1, -1 do
		local s = active[i]
		if s and not s.pinned then
			local tr = transparencyAt(s, now)
			if not tr then
				release(s)
			elseif math.abs(tr - s.lastT) > 0.01 then
				s.lastT = tr
				s.adorn.Transparency = tr
			end
		end
	end
end

-- ===== Penanda sumber suara =====
local function markerColor(ev): Color3
	local t = ev.sourceType
	if (t == "WalkStep" or t == "RunStep" or t == "CrouchStep") and ev.actorId ~= localPlayer.UserId then
		return Config.Categories.Player.Color
	elseif t == "ItemImpact" or t == "DoorMove" then
		return Config.Categories.Interactive.Color
	end
	return Config.Categories.Structure.Color
end

local function spawnMarker(ev)
	local isOwnStep = ev.actorId == localPlayer.UserId
		and (ev.sourceType == "WalkStep" or ev.sourceType == "RunStep" or ev.sourceType == "CrouchStep")
	if isOwnStep then
		return
	end
	local m = table.remove(markers)
	if not m then
		m = Instance.new("SphereHandleAdornment")
		m.AlwaysOnTop = false
		m.ZIndex = 0
		m.Parent = folder
	end
	m.Adornee = Workspace.Terrain
	m.CFrame = CFrame.new(ev.worldPosition)
	m.Radius = R.OriginMarkerRadius
	m.Color3 = markerColor(ev)
	m.Transparency = 0
	m.Visible = true
	table.insert(liveMarkers, { m = m, t0 = os.clock() })
end

local function updateMarkers(now: number)
	for i = #liveMarkers, 1, -1 do
		local lm = liveMarkers[i]
		local g = (now - lm.t0) / R.OriginMarkerLifetime
		if g >= 1 then
			lm.m.Visible = false
			lm.m.Adornee = nil
			table.insert(markers, lm.m)
			liveMarkers[i] = liveMarkers[#liveMarkers]
			liveMarkers[#liveMarkers] = nil
		else
			lm.m.Transparency = g
		end
	end
end

-- ===== Gelombang =====
function EchoRenderer.onEvent(ev)
	if seen[ev.eventId] then
		return
	end
	seen[ev.eventId] = true
	seenCount += 1
	if seenCount > 2000 then
		seen = { [ev.eventId] = true }
		seenCount = 1
	end
	stats.lastEvent = ev.sourceType

	if #waves >= quality.MaxWaves then
		table.remove(waves, 1)
	end

	local pos: Vector3 = ev.worldPosition
	local radius: number = ev.revealRadius
	local cands = {}
	local lo = pos - Vector3.one * radius
	local hi = pos + Vector3.one * radius
	for ix = math.floor(lo.X / CELL), math.floor(hi.X / CELL) do
		for iy = math.floor(lo.Y / CELL), math.floor(hi.Y / CELL) do
			for iz = math.floor(lo.Z / CELL), math.floor(hi.Z / CELL) do
				local bucket = grid[cellKey(ix, iy, iz)]
				if bucket then
					for _, s in bucket do
						local d = (s.worldMid - pos).Magnitude
						if d <= radius then
							table.insert(cands, { s, d })
						end
					end
				end
			end
		end
	end
	for s in dynamicSegs do
		if s.part.Parent then
			local d = (s.part.CFrame * s.localMid - pos).Magnitude
			if d <= radius then
				table.insert(cands, { s, d })
			end
		end
	end
	table.sort(cands, function(a, b)
		return a[2] < b[2]
	end)

	table.insert(waves, {
		ev = ev,
		cands = cands,
		i = 1,
		duration = ev.duration,
		brightness = ev.brightness,
	})
	spawnMarker(ev)
end

local function updateWaves(now: number)
	if occluderDirty then
		rebuildOccluders()
	end
	local serverNow = Workspace:GetServerTimeNow()
	local budget = quality.RaycastsPerFrame
	local startRaycasts = stats.raycasts
	local w = 1
	while w <= #waves do
		local wave = waves[w]
		local ev = wave.ev
		local r = math.max(0, (serverNow - ev.startedAtServer) * ev.propagationSpeed)
		local cands = wave.cands
		local n = #cands
		while wave.i <= n and stats.raycasts - startRaycasts < budget do
			local c = cands[wave.i]
			if c[2] > r then
				break
			end
			if visibleFrom(ev.worldPosition, c[1]) then
				reveal(c[1], wave, now)
			end
			wave.i += 1
		end
		if wave.i > n then
			table.remove(waves, w)
		else
			w += 1
		end
	end
	stats.raycastsLastFrame = stats.raycasts - startRaycasts
end

-- ===== Lifecycle =====
local function pickQuality()
	local q = R.Quality
	if q == "Auto" then
		q = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "Mobile" else "PC"
	end
	qualityName = q
	quality = R.Presets[q] or R.Presets.PC
	stats.quality = q
end

local function ensureFolder()
	local cam = Workspace.CurrentCamera
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "EchoAdornments"
	end
	folder.Parent = cam
end

function EchoRenderer.init()
	pickQuality()
	ensureFolder()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(ensureFolder)
	for _ = 1, quality.Prewarm do
		table.insert(pool, newAdorn())
	end

	for _, part in CollectionService:GetTagged(TAG) do
		addPart(part)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(addPart)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(removePart)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		updateWaves(now)
		updateFades(now)
		updateMarkers(now)
		stats.active = #active
		stats.waves = #waves
		stats.pool = #pool
	end)
end

-- Dev view: tampilkan / sembunyikan SEMUA wireframe (abaikan oklusi & fade).
function EchoRenderer.setShowAll(on: boolean)
	if on == showAll then
		return
	end
	showAll = on
	for _, segs in partSegs do
		for _, s in segs do
			if on then
				pin(s)
			elseif s.pinned then
				s.pinned = false
				release(s)
			end
		end
	end
end

function EchoRenderer.getStats()
	return stats
end

function EchoRenderer.getQualityName(): string
	return qualityName
end

return EchoRenderer
