-- EdgeBuilder: mengubah BasePart bertag EchoGeometry menjadi segmen wireframe dalam ruang LOKAL part.
-- Hanya part yang diberi tag yang diproses (bukan semua MeshPart dekoratif, PRD 5.3).
--
-- Atribut pada part:
--   EchoEdges    : "box" (default) | "wedge" (default WedgePart) | "ball" (default Part Shape=Ball)
--                  | "top" | "grid" | "none"
--   EchoGrid     : number, jarak garis grid di permukaan atas (mengaktifkan mode "grid")
--   EchoCategory : "Structure" (default) | "Interactive" | "Valuable" | "Threat"
--   EchoDynamic  : true kalau part bergerak (pintu, batu). Part tidak di-anchor otomatis dinamis.
--   EchoOccludes : false kalau part TIDAK boleh menghalangi gelombang (mis. batu kecil)
-- Rusuk buatan tangan: Attachment anak part dengan atribut EchoEdgeTo = nama Attachment lain.
local EdgeBuilder = {}

export type Segment = {
	part: BasePart,
	a: Vector3,
	b: Vector3,
	cf: CFrame,
	length: number,
	localMid: Vector3,
	category: string,
	dynamic: boolean,
	alive: boolean,
	-- diisi renderer:
	worldMid: Vector3?,
	key: string?,
	cell: number?,
	adorn: LineHandleAdornment?,
	activeIndex: number?,
	t0: number?,
	dur: number?,
	startT: number?,
	lastT: number?,
}

local function push(list, a: Vector3, b: Vector3)
	table.insert(list, { a, b })
end

local function boxEdges(h: Vector3, list)
	local x, y, z = h.X, h.Y, h.Z
	local c = {
		Vector3.new(-x, -y, -z),
		Vector3.new(x, -y, -z),
		Vector3.new(x, -y, z),
		Vector3.new(-x, -y, z),
		Vector3.new(-x, y, -z),
		Vector3.new(x, y, -z),
		Vector3.new(x, y, z),
		Vector3.new(-x, y, z),
	}
	local pairsIdx = { { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 }, { 5, 6 }, { 6, 7 }, { 7, 8 }, { 8, 5 }, { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 } }
	for _, p in pairsIdx do
		push(list, c[p[1]], c[p[2]])
	end
end

local function topEdges(h: Vector3, list)
	local x, y, z = h.X, h.Y, h.Z
	push(list, Vector3.new(-x, y, -z), Vector3.new(x, y, -z))
	push(list, Vector3.new(x, y, -z), Vector3.new(x, y, z))
	push(list, Vector3.new(x, y, z), Vector3.new(-x, y, z))
	push(list, Vector3.new(-x, y, z), Vector3.new(-x, y, -z))
end

local function gridEdges(h: Vector3, spacing: number, list)
	topEdges(h, list)
	local x, y, z = h.X, h.Y, h.Z
	local nx = math.floor((2 * x) / spacing)
	for i = 1, nx do
		local px = -x + i * spacing
		if px < x - 0.05 then
			push(list, Vector3.new(px, y, -z), Vector3.new(px, y, z))
		end
	end
	local nz = math.floor((2 * z) / spacing)
	for i = 1, nz do
		local pz = -z + i * spacing
		if pz < z - 0.05 then
			push(list, Vector3.new(-x, y, pz), Vector3.new(x, y, pz))
		end
	end
end

-- WedgePart Roblox: sisi vertikal tinggi di +Z, permukaan miring turun ke arah -Z.
local function wedgeEdges(h: Vector3, list)
	local x, y, z = h.X, h.Y, h.Z
	local b1, b2 = Vector3.new(-x, -y, -z), Vector3.new(x, -y, -z)
	local b3, b4 = Vector3.new(x, -y, z), Vector3.new(-x, -y, z)
	local t1, t2 = Vector3.new(-x, y, z), Vector3.new(x, y, z)
	push(list, b1, b2)
	push(list, b2, b3)
	push(list, b3, b4)
	push(list, b4, b1)
	push(list, b4, t1)
	push(list, b3, t2)
	push(list, t1, t2)
	push(list, b1, t1)
	push(list, b2, t2)
end

-- Bola: tiga lingkaran (bidang XY, XZ, YZ) supaya terbaca bulat dari segala arah.
local BALL_STEPS = 12
local function ballEdges(h: Vector3, list)
	local r = math.min(h.X, h.Y, h.Z)
	for plane = 1, 3 do
		local prev: Vector3? = nil
		for i = 0, BALL_STEPS do
			local t = (i / BALL_STEPS) * math.pi * 2
			local c, s = math.cos(t) * r, math.sin(t) * r
			local p = if plane == 1
				then Vector3.new(c, s, 0)
				elseif plane == 2 then Vector3.new(c, 0, s)
				else Vector3.new(0, c, s)
			if prev then
				push(list, prev, p)
			end
			prev = p
		end
	end
end

local function authoredEdges(part: BasePart, list)
	for _, child in part:GetChildren() do
		if child:IsA("Attachment") then
			local target = child:GetAttribute("EchoEdgeTo")
			if type(target) == "string" then
				local other = part:FindFirstChild(target)
				if other and other:IsA("Attachment") then
					push(list, child.Position, other.Position)
				else
					warn(`[EdgeBuilder] {child:GetFullName()} EchoEdgeTo '{target}' tidak ditemukan`)
				end
			end
		end
	end
end

function EdgeBuilder.isDynamic(part: BasePart): boolean
	return part:GetAttribute("EchoDynamic") == true or not part.Anchored
end

function EdgeBuilder.category(part: BasePart): string
	local c = part:GetAttribute("EchoCategory")
	if type(c) == "string" then
		return c
	end
	return "Structure"
end

function EdgeBuilder.mode(part: BasePart): string
	local mode = part:GetAttribute("EchoEdges")
	if type(mode) == "string" then
		return mode
	end
	if part:IsA("WedgePart") then
		return "wedge"
	end
	if part:IsA("Part") and part.Shape == Enum.PartType.Ball then
		return "ball"
	end
	if type(part:GetAttribute("EchoGrid")) == "number" then
		return "grid"
	end
	return "box"
end

-- Mengembalikan daftar rusuk mentah {a, b} dalam ruang lokal.
function EdgeBuilder.rawEdges(part: BasePart, inflate: number)
	local list = {}
	local h = part.Size / 2 + Vector3.one * inflate
	local mode = EdgeBuilder.mode(part)
	if mode == "box" then
		boxEdges(h, list)
	elseif mode == "wedge" then
		wedgeEdges(h, list)
	elseif mode == "ball" then
		ballEdges(h, list)
	elseif mode == "top" then
		topEdges(h, list)
	elseif mode == "grid" then
		local spacing = part:GetAttribute("EchoGrid")
		if type(spacing) ~= "number" or spacing < 1 then
			spacing = 8
		end
		gridEdges(h, spacing, list)
	elseif mode ~= "none" then
		warn(`[EdgeBuilder] EchoEdges '{mode}' tidak dikenal pada {part:GetFullName()}, pakai box`)
		boxEdges(h, list)
	end
	authoredEdges(part, list)
	return list
end

-- Memecah rusuk jadi segmen pendek supaya gelombang bisa menyingkap sedikit demi sedikit
-- dan oklusi dihitung per segmen.
function EdgeBuilder.build(part: BasePart, renderConfig): { Segment }
	local segLen = renderConfig.SegmentLength
	local category = EdgeBuilder.category(part)
	local dynamic = EdgeBuilder.isDynamic(part)
	local out = {}
	for _, edge in EdgeBuilder.rawEdges(part, renderConfig.EdgeInflate) do
		local A, B = edge[1], edge[2]
		local len = (B - A).Magnitude
		if len > 0.01 then
			local n = math.max(1, math.ceil(len / segLen))
			for i = 1, n do
				local a = A:Lerp(B, (i - 1) / n)
				local b = A:Lerp(B, i / n)
				table.insert(out, {
					part = part,
					a = a,
					b = b,
					cf = CFrame.lookAt(a, b),
					length = (b - a).Magnitude,
					localMid = (a + b) / 2,
					category = category,
					dynamic = dynamic,
					alive = true,
				})
			end
		end
	end
	return out
end

return EdgeBuilder
