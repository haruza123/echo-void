-- MapBuilder: mengubah layout (data) menjadi geometri nyata di folder "RuntimeMap".
-- Setiap ruangan: lantai (grid echo), plafon, dinding batas dengan celah pintu di socket yang
-- tersambung, lalu prop dari RoomCatalog. Pintu geser dibuat per sambungan di garis batas sel.
-- Semua part diberi tag EchoGeometry; sistem lain (darkness, pintu, batu, mesin, renderer)
-- menangkapnya otomatis lewat tag.
local CollectionService = game:GetService("CollectionService")

local RoomCatalog = require(script.Parent.RoomCatalog)
local MapLayout = require(script.Parent.MapLayout)

local MapBuilder = {}

local DIRS = MapLayout.DIRS
local GRAY = Color3.fromRGB(150, 150, 155)

export type PartOpts = {
	class: string?,
	material: Enum.Material?,
	color: Color3?,
	shape: Enum.PartType?,
	anchored: boolean?,
	canCollide: boolean?,
	geometry: boolean?, -- false = tanpa tag EchoGeometry
	tags: { string }?,
	attributes: { [string]: any }?,
	rotY: number?, -- derajat
}

local function makePart(parent: Instance, name: string, size: Vector3, cf: CFrame, opts: PartOpts?): BasePart
	local o: PartOpts = opts or {}
	local p = Instance.new(o.class or "Part") :: BasePart
	p.Name = name
	if o.shape then
		(p :: Part).Shape = o.shape
	end
	p.Size = size
	p.CFrame = cf
	p.Anchored = o.anchored ~= false
	p.Color = o.color or GRAY
	p.Material = o.material or Enum.Material.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if o.canCollide == false then
		p.CanCollide = false
	end
	if o.geometry ~= false then
		CollectionService:AddTag(p, "EchoGeometry")
	end
	for _, tag in o.tags or {} do
		CollectionService:AddTag(p, tag)
	end
	if o.attributes then
		for k, v in o.attributes do
			p:SetAttribute(k, v)
		end
	end
	p.Parent = parent
	return p
end

local function buildWalls(folder: Folder, base: CFrame, room, t, cfg)
	local C, H, T = cfg.CellSize, cfg.RoomHeight, cfg.WallThickness
	local DW, DH = cfg.DoorWidth, cfg.DoorHeight
	local w, d = t.size[1], t.size[2]
	local W, D = w * C, d * C
	local inFoot = {}
	for cx = 0, w - 1 do
		for cz = 0, d - 1 do
			inFoot[cx .. "," .. cz] = true
		end
	end
	for cx = 0, w - 1 do
		for cz = 0, d - 1 do
			for dir = 0, 3 do
				local dv = DIRS[dir]
				if not inFoot[(cx + dv[1]) .. "," .. (cz + dv[2])] then
					local lx = (cx + 0.5) * C - W / 2
					local lz = (cz + 0.5) * C - D / 2
					local px = lx + dv[1] * (C / 2 - T / 2)
					local pz = lz + dv[2] * (C / 2 - T / 2)
					local alongX = dv[1] == 0 -- dinding N/S membentang di sumbu X
					local open = room.connected[MapLayout.socketKey(cx, cz, dir)] ~= nil
					local function piece(name: string, len: number, offset: number, y: number, h: number)
						local size = if alongX then Vector3.new(len, h, T) else Vector3.new(T, h, len)
						local pos = if alongX then Vector3.new(px + offset, y, pz) else Vector3.new(px, y, pz + offset)
						makePart(folder, name, size, base * CFrame.new(pos))
					end
					if open then
						local side = (C - DW) / 2
						piece("Wall", side, -(DW / 2 + side / 2), H / 2, H)
						piece("Wall", side, DW / 2 + side / 2, H / 2, H)
						piece("DoorLintel", DW, 0, DH + (H - DH) / 2, H - DH)
					else
						piece("Wall", C, 0, H / 2, H)
					end
				end
			end
		end
	end
end

local function buildRoom(root: Folder, room, layout, cfg, info)
	local t = RoomCatalog.ById[room.templateId]
	local C, H = cfg.CellSize, cfg.RoomHeight
	local W, D = t.size[1] * C, t.size[2] * C
	local folder = Instance.new("Folder")
	folder.Name = string.format("%02d_%s", room.index, t.id)
	folder:SetAttribute("Template", t.id)
	folder:SetAttribute("Depth", room.depth)
	folder:SetAttribute("Tags", table.concat(t.tags, ","))

	local base = CFrame.new(cfg.Origin + Vector3.new(room.centerX * C, 0, room.centerZ * C))
		* CFrame.Angles(0, room.rot * math.pi / 2, 0)

	local metal = t.floor == "Metal"
	makePart(folder, "Floor", Vector3.new(W, 1, D), base * CFrame.new(0, -0.5, 0), {
		material = if metal then Enum.Material.DiamondPlate else Enum.Material.Concrete,
		attributes = { EchoGrid = 8, SurfaceProfile = t.floor or "Concrete" },
	})
	makePart(folder, "Ceiling", Vector3.new(W, 1, D), base * CFrame.new(0, H + 0.5, 0), {
		attributes = { EchoEdges = "none" },
	})
	buildWalls(folder, base, room, t, cfg)

	-- ctx untuk prop template
	local ctx = { rng = Random.new((layout.usedSeed * 31 + room.index) % 2147483647), W = W, D = D, H = H }
	function ctx.part(name: string, size: Vector3, pos: Vector3, opts: PartOpts?)
		local rotY = if opts and opts.rotY then math.rad(opts.rotY) else 0
		return makePart(folder, name, size, base * CFrame.new(pos) * CFrame.Angles(0, rotY, 0), opts)
	end
	function ctx.wedge(name: string, size: Vector3, pos: Vector3, opts: PartOpts?)
		local o: PartOpts = opts and table.clone(opts) or {}
		o.class = "WedgePart"
		return ctx.part(name, size, pos, o)
	end
	function ctx.stone(pos: Vector3)
		return ctx.part("Stone", Vector3.new(1.2, 1.2, 1.2), pos, {
			anchored = false,
			shape = Enum.PartType.Ball,
			material = Enum.Material.Slate,
			tags = { "EchoThrowable" },
			attributes = {
				EchoCategory = "Interactive",
				EchoDynamic = true,
				EchoOccludes = false,
				DisplayName = "Stone",
				ItemWeight = 1,
			},
		})
	end
	function ctx.spawn(pos: Vector3)
		local s = Instance.new("SpawnLocation")
		s.Name = "SpawnLocation"
		s.Size = Vector3.new(6, 1, 6)
		s.CFrame = base * CFrame.new(pos + Vector3.new(0, -0.45, 0))
		s.Anchored = true
		s.CanCollide = false
		s.Transparency = 1
		s.Duration = 0
		s.Neutral = true
		s.Parent = folder
		info.spawnPos = (base * CFrame.new(pos)).Position
	end
	function ctx.exitPad(pos: Vector3, size: number)
		local pad = ctx.part("ExtractionZone", Vector3.new(size, 0.2, size), pos + Vector3.new(0, 0.1, 0), {
			canCollide = false,
			tags = { "EchoExit" },
			attributes = { EchoCategory = "Exit", EchoEdges = "top", EchoOccludes = false },
		})
		info.exitPos = pad.Position
	end

	t.build(ctx)
	folder.Parent = root
end

local function buildDoors(root: Folder, layout, cfg)
	local C, DW, DH = cfg.CellSize, cfg.DoorWidth, cfg.DoorHeight
	local doors = Instance.new("Folder")
	doors.Name = "Doors"
	for i, c in layout.connections do
		if c.door then
			local dv = DIRS[c.dir]
			local x = (c.ax + 0.5 + dv[1] * 0.5) * C
			local z = (c.az + 0.5 + dv[2] * 0.5) * C
			local rot = if dv[1] ~= 0 then CFrame.Angles(0, math.pi / 2, 0) else CFrame.identity
			local panel = makePart(doors, `Door{i}`, Vector3.new(DW, DH, 0.8), CFrame.new(cfg.Origin + Vector3.new(x, DH / 2, z)) * rot, {
				material = Enum.Material.Metal,
				tags = { "EchoDoor" },
				attributes = {
					EchoCategory = "Interactive",
					EchoDynamic = true,
					SurfaceProfile = "Metal",
					OpenOffset = Vector3.new(DW + 0.2, 0, 0),
				},
			})
			-- Pintu bisa dibuka, jadi pathfinding (validasi & monster nanti) boleh melewatinya.
			local mod = Instance.new("PathfindingModifier")
			mod.PassThrough = true
			mod.Parent = panel
		end
	end
	doors.Parent = root
end

-- Mengembalikan folder RuntimeMap (BELUM di-parent) dan info posisi penting.
function MapBuilder.build(layout, cfg): (Folder, { spawnPos: Vector3?, exitPos: Vector3? })
	local root = Instance.new("Folder")
	root.Name = "RuntimeMap"
	local info = {}
	for _, room in layout.rooms do
		buildRoom(root, room, layout, cfg, info)
	end
	buildDoors(root, layout, cfg)
	return root, info
end

return MapBuilder
