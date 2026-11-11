-- RoomCatalog: template ruangan biome industrial (PRD 6.2: 6-8+ template untuk generator proof).
--
-- Data (size, sockets, tags, weight, minDepth) dipakai MapLayout (murni, tanpa Instance).
-- Fungsi build(ctx) dipakai MapBuilder untuk membuat prop di dalam ruangan.
--
-- Koordinat:
--   size     = {w, d} dalam sel grid (Config.MapGen.CellSize stud per sel)
--   sockets  = {cx, cz, dir}: sel lokal + arah dinding tempat pintu boleh ada
--              dir 0 = N (+Z), 1 = E (+X), 2 = S (-Z), 3 = W (-X)
--   ctx.part posisi lokal dalam stud, relatif TENGAH ruangan; y = 0 adalah permukaan lantai.
-- Aturan prop: jangan menutupi titik pintu (tengah tiap sisi sel yang punya socket).
local RoomCatalog = {}

local N, E, S, W = 0, 1, 2, 3
local V = Vector3.new

local function stones(ctx, list)
	for _, p in list do
		ctx.stone(p)
	end
end

RoomCatalog.Templates = {
	{
		id = "Spawn",
		tags = { "Spawn" },
		size = { 2, 2 },
		sockets = { { 0, 1, N }, { 1, 1, E }, { 1, 0, S }, { 0, 0, W } },
		weight = 0, -- hanya ditempatkan khusus
		minDepth = 0,
		build = function(ctx)
			ctx.spawn(V(0, 0, 0))
			ctx.part("StoneTable", V(6, 3, 3), V(8, 1.5, -8))
			stones(ctx, { V(6, 3.6, -8), V(8, 3.6, -8), V(10, 3.6, -8) })
			ctx.part("Crate", V(5, 5, 5), V(-10, 2.5, 10))
			ctx.part("Locker", V(2, 7, 6), V(28, 3.5, -24))
		end,
	},
	{
		id = "Exit",
		tags = { "Exit" },
		size = { 2, 1 },
		sockets = { { 0, 0, W }, { 1, 0, E }, { 0, 0, S } },
		weight = 0,
		minDepth = 0,
		build = function(ctx)
			ctx.exitPad(V(10, 0, 0), 14)
			for _, c in { V(3, 0, -7), V(17, 0, -7), V(3, 0, 7), V(17, 0, 7) } do
				ctx.part("ExitPost", V(1, 10, 1), c + V(0, 5, 0), { attributes = { EchoCategory = "Exit" } })
			end
		end,
	},
	{
		id = "CorridorStraight",
		tags = { "Corridor" },
		size = { 1, 1 },
		sockets = { { 0, 0, N }, { 0, 0, S } },
		weight = 3,
		minDepth = 0,
		build = function(ctx)
			for _, x in { -13, 13 } do
				ctx.part("Pipe", V(1, 1, 30), V(x, 10, 0))
				ctx.part("Pipe", V(1, 1, 30), V(x, 11.5, 0))
			end
			local side = if ctx.rng:NextInteger(0, 1) == 0 then -10 else 10
			ctx.part("Crate", V(3, 3, 3), V(side, 1.5, ctx.rng:NextInteger(-8, 8)))
		end,
	},
	{
		id = "CorridorCorner",
		tags = { "Corridor" },
		size = { 1, 1 },
		sockets = { { 0, 0, N }, { 0, 0, E } },
		weight = 2,
		minDepth = 0,
		build = function(ctx)
			ctx.part("CornerPillar", V(4, 14, 4), V(-10, 7, -10))
			ctx.part("Pipe", V(1, 14, 1), V(-13, 7, 4))
		end,
	},
	{
		id = "JunctionT",
		tags = { "Junction" },
		size = { 1, 1 },
		sockets = { { 0, 0, N }, { 0, 0, E }, { 0, 0, W } },
		weight = 2,
		minDepth = 0,
		build = function(ctx)
			ctx.part("Column", V(4, 14, 4), V(0, 7, -9))
		end,
	},
	{
		id = "JunctionX",
		tags = { "Junction", "Loop" },
		size = { 1, 1 },
		sockets = { { 0, 0, N }, { 0, 0, E }, { 0, 0, S }, { 0, 0, W } },
		weight = 1,
		minDepth = 1,
		build = function(ctx)
			for _, p in { V(-7, 7, -7), V(7, 7, -7), V(-7, 7, 7), V(7, 7, 7) } do
				ctx.part("Pillar", V(2, 14, 2), p)
			end
		end,
	},
	{
		id = "MachineRoom",
		tags = { "Machine" },
		size = { 2, 2 },
		sockets = { { 0, 0, S }, { 1, 1, N }, { 1, 0, E } },
		weight = 1.5,
		minDepth = 1,
		floor = "Metal",
		build = function(ctx)
			ctx.part("Generator", V(8, 6, 6), V(0, 3, 0), {
				material = Enum.Material.Metal,
				tags = { "EchoEmitter" },
				attributes = {
					RevealRadius = ctx.rng:NextInteger(25, 40),
					Strength = 60,
					Duration = 2,
					IntervalMin = 5,
					IntervalMax = 9,
				},
			})
			ctx.part("PipeColumn", V(2, 14, 2), V(8, 7, 8))
			ctx.part("Catwalk", V(10, 4, 10), V(-20, 2, 20))
			ctx.wedge("CatwalkRamp", V(6, 4, 10), V(-20, 2, 10))
		end,
	},
	{
		id = "Storage",
		tags = { "Loot" },
		size = { 2, 1 },
		sockets = { { 0, 0, W }, { 1, 0, E } },
		weight = 2,
		minDepth = 2,
		build = function(ctx)
			for _, p in { V(-14, 3, 9), V(14, 3, 9), V(-14, 3, -9), V(14, 3, -9) } do
				ctx.part("Shelf", V(20, 6, 2), p)
			end
			ctx.part("Crate", V(4, 4, 4), V(-26, 2, -11))
			ctx.part("Crate", V(4, 4, 4), V(26, 2, 11))
			stones(ctx, { V(0, 0.6, -5), V(5, 0.6, 5) })
		end,
	},
	{
		id = "PillarHall",
		tags = { "Danger" },
		size = { 2, 2 },
		sockets = { { 0, 0, W }, { 1, 0, E }, { 0, 1, N } },
		weight = 1.5,
		minDepth = 2,
		build = function(ctx)
			for _, x in { -16, 0, 16 } do
				for _, z in { -16, 0, 16 } do
					if not (x == 0 and z == 0) then
						ctx.part("Pillar", V(4, 14, 4), V(x, 7, z))
					end
				end
			end
			ctx.part("LowCover", V(10, 3, 1.5), V(8, 1.5, 24))
			ctx.part("Puddle", V(12, 0.2, 10), V(8, 0.1, 8), {
				canCollide = false,
				material = Enum.Material.Glass,
				attributes = { EchoEdges = "top", EchoOccludes = false, SurfaceProfile = "Water" },
			})
		end,
	},
	{
		id = "DeadEnd",
		tags = { "DeadEnd" },
		size = { 1, 1 },
		sockets = { { 0, 0, S } },
		weight = 1,
		minDepth = 2,
		build = function(ctx)
			ctx.part("Crate", V(5, 5, 5), V(8, 2.5, 8))
			ctx.part("Crate", V(3, 3, 3), V(-8, 1.5, 9))
			ctx.part("Crate", V(3, 3, 3), V(-8, 4.5, 9))
			stones(ctx, { V(0, 0.6, 4) })
		end,
	},
}

RoomCatalog.ById = {}
for _, t in RoomCatalog.Templates do
	RoomCatalog.ById[t.id] = t
end

return RoomCatalog
