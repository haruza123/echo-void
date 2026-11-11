-- MapLayout: generator layout MURNI (tanpa Instance) dan deterministik dari seed (PRD 6.1).
--
-- Langkah:
--   1. Spawn ditempatkan di sel (0,0); ruang Exit langsung disambung ke Spawn
--      (PRD: titik ekstraksi dekat spawn).
--   2. Tumbuh: ambil socket terbuka secara acak (rng seed), pilih template yang cocok
--      (bobot, minDepth, kuota tag wajib), coba 4 rotasi, cek tumpang tindih di grid.
--   3. Socket yang berhadapan antar ruangan yang bersebelahan disambung jadi loop (LoopChance).
--   4. Sebagian sambungan diberi pintu (DoorChance). Socket sisa = dinding tertutup.
--   5. Divalidasi (MapValidator). Gagal -> coba seed turunan; habis -> seed fallback.
-- Hanya array yang di-iterasi (bukan pairs pada dictionary) supaya urutan selalu sama.
local RoomCatalog = require(script.Parent.RoomCatalog)
local MapValidator = require(script.Parent.MapValidator)

local MapLayout = {}

local routeLoop -- didefinisikan di bawah (dipakai generateOnce)

local DIRS = { [0] = { 0, 1 }, [1] = { 1, 0 }, [2] = { 0, -1 }, [3] = { -1, 0 } }
MapLayout.DIRS = DIRS

local function ckey(x: number, z: number): string
	return x .. "," .. z
end
MapLayout.cellKey = ckey

local function skey(cx: number, cz: number, dir: number): string
	return cx .. "," .. cz .. "," .. dir
end
MapLayout.socketKey = skey

-- Offset sel lokal dari tengah footprint (satuan sel), diputar r x 90 derajat.
-- Rotasi (x, z) -> (z, -x) sama dengan CFrame.Angles(0, pi/2, 0) yang dipakai MapBuilder.
local function rotOffset(cx: number, cz: number, w: number, d: number, r: number): (number, number)
	local ox, oz = cx + 0.5 - w / 2, cz + 0.5 - d / 2
	for _ = 1, r do
		ox, oz = oz, -ox
	end
	return ox, oz
end

local function shuffle(rng: Random, list)
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- Urutan template acak berbobot (tanpa pengembalian).
local function weightedOrder(rng: Random, pool)
	local items = table.clone(pool)
	local out = {}
	while #items > 0 do
		local total = 0
		for _, t in items do
			total += t.weight
		end
		local pick = rng:NextNumber() * total
		local idx = #items
		for i, t in items do
			pick -= t.weight
			if pick <= 0 then
				idx = i
				break
			end
		end
		table.insert(out, table.remove(items, idx))
	end
	return out
end

local function placeRoom(st, t, r: number, centerX: number, centerZ: number, depth: number)
	local w, d = t.size[1], t.size[2]
	local cells = {}
	for cx = 0, w - 1 do
		for cz = 0, d - 1 do
			local ox, oz = rotOffset(cx, cz, w, d, r)
			local x, z = math.floor(centerX + ox), math.floor(centerZ + oz)
			if st.occ[ckey(x, z)] then
				return nil
			end
			table.insert(cells, { cx = cx, cz = cz, x = x, z = z })
		end
	end
	local room = {
		index = #st.rooms + 1,
		templateId = t.id,
		tags = t.tags,
		rot = r,
		centerX = centerX,
		centerZ = centerZ,
		cells = cells,
		depth = depth,
		connected = {}, -- socketKey lokal -> index sambungan
		sockets = {},
	}
	for _, s in t.sockets do
		local ox, oz = rotOffset(s[1], s[2], w, d, r)
		table.insert(room.sockets, {
			room = room.index,
			key = skey(s[1], s[2], s[3]),
			x = math.floor(centerX + ox),
			z = math.floor(centerZ + oz),
			dir = (s[3] + r) % 4,
		})
	end
	table.insert(st.rooms, room)
	for _, c in cells do
		st.occ[ckey(c.x, c.z)] = room.index
	end
	for _, tag in t.tags do
		st.tagCount[tag] = (st.tagCount[tag] or 0) + 1
	end
	return room
end

local function connect(st, a, b, isLoop: boolean)
	table.insert(st.connections, {
		a = a.room,
		aKey = a.key,
		ax = a.x,
		az = a.z,
		dir = a.dir,
		b = b.room,
		bKey = b.key,
		loop = isLoop,
		door = false,
	})
	local idx = #st.connections
	st.rooms[a.room].connected[a.key] = idx
	st.rooms[b.room].connected[b.key] = idx
end

local function addOpen(st, room, except)
	for _, s in room.sockets do
		if s ~= except then
			table.insert(st.open, s)
		end
	end
end

-- Coba tempelkan template t ke socket terbuka `open`. Berhasil -> room baru.
local function tryAttach(st, open, t)
	local want = (open.dir + 2) % 4
	local dv = DIRS[open.dir]
	local tx, tz = open.x + dv[1], open.z + dv[2]
	if st.occ[ckey(tx, tz)] then
		return nil
	end
	local w, d = t.size[1], t.size[2]
	for _, r in shuffle(st.rng, { 0, 1, 2, 3 }) do
		for _, s in t.sockets do
			if (s[3] + r) % 4 == want then
				local ox, oz = rotOffset(s[1], s[2], w, d, r)
				local room = placeRoom(st, t, r, tx + 0.5 - ox, tz + 0.5 - oz, st.rooms[open.room].depth + 1)
				if room then
					local key = skey(s[1], s[2], s[3])
					local mine
					for _, rs in room.sockets do
						if rs.key == key then
							mine = rs
							break
						end
					end
					connect(st, open, mine, false)
					addOpen(st, room, mine)
					return room
				end
			end
		end
	end
	return nil
end

-- Koridor 1x1 (lurus/belok) + rotasi yang punya socket tepat di arah inDir dan outDir.
local function connectorFor(inDir: number, outDir: number)
	for _, id in { "CorridorStraight", "CorridorCorner" } do
		local t = RoomCatalog.ById[id]
		for r = 0, 3 do
			local has = {}
			for _, s in t.sockets do
				has[(s[3] + r) % 4] = true
			end
			if has[inDir] and has[outDir] then
				return t, r
			end
		end
	end
	return nil, nil
end

local function dirTo(fromCell, toCell): number
	local dx, dz = toCell[1] - fromCell[1], toCell[2] - fromCell[2]
	if dz == 1 then
		return 0
	elseif dx == 1 then
		return 1
	elseif dz == -1 then
		return 2
	end
	return 3
end

-- Loop: dari socket `a` yang belum terpakai, cari jalur lewat sel KOSONG (<= maxLen sel)
-- ke sel yang ditunjuk socket ruangan lain, lalu isi jalurnya dengan koridor.
-- Karena semua ruangan sudah terhubung, sambungan baru ini selalu membentuk siklus.
function routeLoop(st, cfg, a, pending, used): boolean
	local dv = DIRS[a.dir]
	local sx, sz = a.x + dv[1], a.z + dv[2]
	local startKey = ckey(sx, sz)
	if st.occ[startKey] then
		return false
	end
	local targets = {}
	for _, b in pending do
		if not used[b] and b ~= a and b.room ~= a.room then
			local bv = DIRS[b.dir]
			local k = ckey(b.x + bv[1], b.z + bv[2])
			if not targets[k] then
				targets[k] = b
			end
		end
	end
	-- BFS urutan arah tetap (0..3) -> deterministik
	local prev = { [startKey] = false }
	local dist = { [startKey] = 1 }
	local queue = { { sx, sz } }
	local head, found = 1, nil
	while head <= #queue do
		local c = queue[head]
		head += 1
		local k = ckey(c[1], c[2])
		if targets[k] then
			found = c
			break
		end
		if dist[k] < cfg.LoopMaxLength then
			for dir = 0, 3 do
				local v = DIRS[dir]
				local nx, nz = c[1] + v[1], c[2] + v[2]
				local nk = ckey(nx, nz)
				if dist[nk] == nil and not st.occ[nk] then
					dist[nk] = dist[k] + 1
					prev[nk] = c
					table.insert(queue, { nx, nz })
				end
			end
		end
	end
	if not found then
		return false
	end
	local b = targets[ckey(found[1], found[2])]
	local path = {}
	local cur = found
	while cur do
		table.insert(path, 1, cur)
		cur = prev[ckey(cur[1], cur[2])] or nil
	end
	if #st.rooms + #path > cfg.RoomCountMax then
		return false
	end
	-- Tentukan koridor tiap sel dulu; baru tempatkan kalau semuanya cocok.
	local plan = {}
	for i, c in path do
		local inDir = if i == 1 then (a.dir + 2) % 4 else dirTo(c, path[i - 1])
		local outDir = if i == #path then (b.dir + 2) % 4 else dirTo(c, path[i + 1])
		if inDir == outDir then
			return false
		end
		local t, r = connectorFor(inDir, outDir)
		if not t then
			return false
		end
		table.insert(plan, { c = c, t = t, r = r, inDir = inDir, outDir = outDir })
	end
	local depth = st.rooms[a.room].depth
	local prevSock = a
	for i, p in plan do
		local room = placeRoom(st, p.t, p.r, p.c[1] + 0.5, p.c[2] + 0.5, depth + i)
		local sIn, sOut
		for _, s in room.sockets do
			if s.dir == p.inDir then
				sIn = s
			elseif s.dir == p.outDir then
				sOut = s
			end
		end
		connect(st, prevSock, sIn, false)
		prevSock = sOut
	end
	connect(st, prevSock, b, true)
	used[a] = true
	used[b] = true
	return true
end

local function missingTags(st, cfg)
	local missing = {}
	for _, req in cfg.Required do
		if (st.tagCount[req.tag] or 0) < req.count then
			table.insert(missing, req.tag)
		end
	end
	return missing
end

local function candidates(st, cfg, depth: number, target: number)
	local missing = missingTags(st, cfg)
	local remaining = target - #st.rooms
	local onlyMissing = remaining <= #missing
	local pool = {}
	for _, t in RoomCatalog.Templates do
		if t.weight > 0 and depth >= t.minDepth then
			local provides = false
			for _, tag in missing do
				if table.find(t.tags, tag) then
					provides = true
				end
			end
			if not onlyMissing or provides then
				table.insert(pool, t)
			end
		end
	end
	return weightedOrder(st.rng, pool)
end

local function signature(st): string
	local parts = {}
	for _, r in st.rooms do
		table.insert(parts, `{r.templateId}@{r.centerX},{r.centerZ}r{r.rot}`)
	end
	for _, c in st.connections do
		table.insert(parts, `{c.a}-{c.b}{if c.loop then "L" else ""}{if c.door then "D" else ""}`)
	end
	return table.concat(parts, ";")
end

-- Satu percobaan generate. Mengembalikan layout atau nil + alasan.
function MapLayout.generateOnce(seed: number, cfg)
	local st = {
		rng = Random.new(seed),
		rooms = {},
		occ = {},
		open = {},
		dead = {},
		connections = {},
		tagCount = {},
	}
	local rng = st.rng
	-- Sisakan slot untuk koridor loop supaya total tetap <= RoomCountMax.
	local target = rng:NextInteger(cfg.RoomCountMin, math.max(cfg.RoomCountMin, cfg.RoomCountMax - cfg.LoopRoomBudget))

	-- 1. Spawn di sel (0,0)
	local spawnT = RoomCatalog.ById.Spawn
	local r0 = rng:NextInteger(0, 3)
	local sw, sd = spawnT.size[1], spawnT.size[2]
	if r0 % 2 == 1 then
		sw, sd = sd, sw
	end
	local spawnRoom = placeRoom(st, spawnT, r0, sw / 2, sd / 2, 0)
	addOpen(st, spawnRoom, nil)

	-- Exit langsung menempel ke Spawn
	local exitRoom
	local order = {}
	for i = 1, #st.open do
		table.insert(order, i)
	end
	for _, i in shuffle(rng, order) do
		exitRoom = tryAttach(st, st.open[i], RoomCatalog.ById.Exit)
		if exitRoom then
			table.remove(st.open, i)
			break
		end
	end
	if not exitRoom then
		return nil, "exit tidak bisa ditempatkan"
	end

	-- 2. Tumbuh
	local guard = 0
	while #st.rooms < target and #st.open > 0 and guard < 500 do
		guard += 1
		local idx = rng:NextInteger(1, #st.open)
		local open = st.open[idx]
		local depth = st.rooms[open.room].depth + 1
		local placed = false
		for _, t in candidates(st, cfg, depth, target) do
			if tryAttach(st, open, t) then
				placed = true
				break
			end
		end
		table.remove(st.open, idx)
		if not placed then
			table.insert(st.dead, open)
		end
	end

	if #st.rooms < cfg.RoomCountMin then
		return nil, `terlalu sedikit ruangan ({#st.rooms})`
	end
	local missing = missingTags(st, cfg)
	if #missing > 0 then
		return nil, "tag wajib kurang: " .. table.concat(missing, ",")
	end

	-- 3. Loop
	local pending = {}
	for _, s in st.open do
		table.insert(pending, s)
	end
	for _, s in st.dead do
		table.insert(pending, s)
	end
	local used = {}
	local loops = 0

	-- 3a. Koridor loop: sambungkan socket bebas ke ruangan lain lewat sel kosong.
	for _, a in pending do
		if loops >= cfg.MaxLoops or #st.rooms >= cfg.RoomCountMax then
			break
		end
		if not used[a] and rng:NextNumber() < cfg.LoopChance then
			if routeLoop(st, cfg, a, pending, used) then
				loops += 1
			end
		end
	end

	-- 3b. Socket bebas yang kebetulan saling berhadapan di sel bersebelahan
	for i, a in pending do
		if not used[a] then
			local dv = DIRS[a.dir]
			local nx, nz = a.x + dv[1], a.z + dv[2]
			local bi = st.occ[ckey(nx, nz)]
			if bi and bi ~= a.room then
				for j = i + 1, #pending do
					local b = pending[j]
					if not used[b] and b.room == bi and b.x == nx and b.z == nz and b.dir == (a.dir + 2) % 4 then
						if rng:NextNumber() < cfg.LoopChance then
							connect(st, a, b, true)
							used[a] = true
							used[b] = true
							loops += 1
						end
						break
					end
				end
			end
		end
	end

	-- 4. Pintu (tidak di sambungan ke ruang Exit supaya jalur pulang selalu terbuka)
	for _, c in st.connections do
		local exitConn = c.a == exitRoom.index or c.b == exitRoom.index
		c.door = not exitConn and rng:NextNumber() < cfg.DoorChance
	end

	return {
		usedSeed = seed,
		rooms = st.rooms,
		connections = st.connections,
		loops = loops,
		target = target,
		spawnRoom = spawnRoom.index,
		exitRoom = exitRoom.index,
		signature = signature(st),
	}
end

local function deriveSeed(seed: number, attempt: number): number
	return (seed * 31 + attempt * 7919) % 2147483647
end

-- Generate dengan retry + fallback. layout.failures berisi seed yang gagal beserta alasannya.
function MapLayout.generate(seed: number, cfg)
	local failures = {}
	for attempt = 1, cfg.MaxAttempts do
		local s = if attempt == 1 then seed else deriveSeed(seed, attempt)
		local layout, err = MapLayout.generateOnce(s, cfg)
		if layout then
			local ok, errs = MapValidator.validate(layout, cfg)
			if ok then
				layout.seed = seed
				layout.attempt = attempt
				layout.failures = failures
				layout.fallback = false
				return layout
			end
			err = table.concat(errs, "; ")
		end
		table.insert(failures, `seed {s}: {err}`)
	end
	local fb, err = MapLayout.generateOnce(cfg.FallbackSeed, cfg)
	assert(fb, `[MapGen] FallbackSeed {cfg.FallbackSeed} tidak valid: {err}`)
	local ok, errs = MapValidator.validate(fb, cfg)
	assert(ok, `[MapGen] FallbackSeed {cfg.FallbackSeed} gagal validasi: {table.concat(errs or {}, "; ")}`)
	fb.seed = seed
	fb.attempt = cfg.MaxAttempts + 1
	fb.failures = failures
	fb.fallback = true
	return fb
end

return MapLayout
