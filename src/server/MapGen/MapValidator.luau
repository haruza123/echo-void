-- MapValidator: invarian keras layout (PRD 6.3) yang bisa dicek tanpa geometri.
-- Cek jalur fisik (pathfinding) dilakukan MapService setelah geometri dibangun.
local MapValidator = {}

local DIRS = { [0] = { 0, 1 }, [1] = { 1, 0 }, [2] = { 0, -1 }, [3] = { -1, 0 } }

local function ckey(x: number, z: number): string
	return x .. "," .. z
end

function MapValidator.validate(layout, cfg): (boolean, { string })
	local errs = {}
	local rooms = layout.rooms

	-- Jumlah ruangan
	if #rooms < cfg.RoomCountMin or #rooms > cfg.RoomCountMax then
		table.insert(errs, `jumlah ruangan {#rooms} di luar {cfg.RoomCountMin}-{cfg.RoomCountMax}`)
	end

	-- Tidak ada tumpang tindih
	local occ = {}
	for _, r in rooms do
		for _, c in r.cells do
			local k = ckey(c.x, c.z)
			if occ[k] then
				table.insert(errs, `overlap di sel {k} (ruang {occ[k]} & {r.index})`)
			end
			occ[k] = r.index
		end
	end

	-- Setiap sambungan valid: sel bersebelahan, socket berhadapan, tercatat di kedua ruangan
	for i, c in layout.connections do
		local dv = DIRS[c.dir]
		if occ[ckey(c.ax, c.az)] ~= c.a or occ[ckey(c.ax + dv[1], c.az + dv[2])] ~= c.b then
			table.insert(errs, `sambungan {i} tidak menghubungkan sel bersebelahan`)
		end
		if rooms[c.a].connected[c.aKey] ~= i or rooms[c.b].connected[c.bKey] ~= i then
			table.insert(errs, `sambungan {i} tidak tercatat di kedua ruangan`)
		end
		local bSock
		for _, s in rooms[c.b].sockets do
			if s.key == c.bKey then
				bSock = s
			end
		end
		if not bSock or bSock.dir ~= (c.dir + 2) % 4 then
			table.insert(errs, `sambungan {i}: socket tidak berhadapan`)
		end
	end

	-- Tidak ada pintu "mengambang": setiap socket yang terhubung harus punya sambungan nyata
	for _, r in rooms do
		for key, idx in r.connected do
			local c = layout.connections[idx]
			if not c or not ((c.a == r.index and c.aKey == key) or (c.b == r.index and c.bKey == key)) then
				table.insert(errs, `ruang {r.index} socket {key} mengambang`)
			end
		end
	end

	-- Tag wajib, satu Spawn, minimal satu Exit dengan ruang cukup
	local counts = {}
	for _, r in rooms do
		for _, tag in r.tags do
			counts[tag] = (counts[tag] or 0) + 1
		end
	end
	if counts.Spawn ~= 1 then
		table.insert(errs, `jumlah Spawn = {counts.Spawn or 0}`)
	end
	if (counts.Exit or 0) < 1 then
		table.insert(errs, "tidak ada Exit")
	end
	for _, req in cfg.Required do
		if (counts[req.tag] or 0) < req.count then
			table.insert(errs, `tag {req.tag} kurang`)
		end
	end
	local exitRoom = rooms[layout.exitRoom]
	if not exitRoom or #exitRoom.cells < cfg.ExitMinCells then
		table.insert(errs, "ruang Exit terlalu kecil untuk 4 pemain")
	end

	-- Konektivitas: semua ruangan (termasuk Exit) terjangkau dari Spawn tanpa item khusus
	local adj = {}
	for _, r in rooms do
		adj[r.index] = {}
	end
	for _, c in layout.connections do
		table.insert(adj[c.a], c.b)
		table.insert(adj[c.b], c.a)
	end
	local seen = { [layout.spawnRoom] = true }
	local queue = { layout.spawnRoom }
	local head = 1
	while head <= #queue do
		local cur = queue[head]
		head += 1
		for _, nb in adj[cur] or {} do
			if not seen[nb] then
				seen[nb] = true
				table.insert(queue, nb)
			end
		end
	end
	if not seen[layout.exitRoom] then
		table.insert(errs, "Exit tidak terjangkau dari Spawn")
	end
	if #queue ~= #rooms then
		table.insert(errs, `{#rooms - #queue} ruangan terisolasi`)
	end

	return #errs == 0, errs
end

return MapValidator
