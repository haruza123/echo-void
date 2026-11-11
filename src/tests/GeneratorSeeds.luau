-- Tes generator (PRD P2): N seed berturut-turut harus menghasilkan layout valid,
-- terhubung Spawn->Exit, tanpa overlap, dan DETERMINISTIK (seed sama = layout sama).
--
-- Jalankan di command bar Studio (mode Edit). :Clone() supaya modul tes ini juga selalu segar:
--   print(require(game.ServerScriptService.Tests.GeneratorSeeds:Clone()).run(100, 1))
-- Murni data: tidak membuat geometri (hanya salinan sementara modul yang langsung dihapus).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GeneratorSeeds = {}

-- Command bar Studio meng-cache require(); setelah kode diedit, modul lama masih terpakai.
-- Karena itu tes selalu memuat SALINAN segar Config + folder MapGen.
local function freshModules()
	local holder = Instance.new("Folder")
	local mapGen = ServerScriptService:WaitForChild("Echo"):WaitForChild("MapGen"):Clone()
	mapGen.Parent = holder
	local config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):Clone()
	config.Parent = holder
	return holder, require(config), mapGen
end

function GeneratorSeeds.run(count: number?, startSeed: number?): string
	local holder, Config, MapGen = freshModules()
	local MapLayout = require(MapGen.MapLayout)
	local MapValidator = require(MapGen.MapValidator)
	local cfg = Config.MapGen
	local n = count or 100
	local start = startSeed or 1
	local lines = {}
	local pass, fail = 0, 0
	local minRooms, maxRooms, sumRooms, sumLoops, withLoop = math.huge, 0, 0, 0, 0
	local retried, fallbacks, totalFailedSeeds = 0, 0, 0
	local templateUse = {}
	local t0 = os.clock()

	-- Fallback seed sendiri wajib valid di percobaan pertama.
	local fb, fbErr = MapLayout.generateOnce(cfg.FallbackSeed, cfg)
	local fbOk = fb ~= nil and select(1, MapValidator.validate(fb, cfg))
	table.insert(lines, `FallbackSeed {cfg.FallbackSeed}: {if fbOk then "VALID" else "TIDAK VALID " .. tostring(fbErr)}`)

	for seed = start, start + n - 1 do
		local a = MapLayout.generate(seed, cfg)
		local b = MapLayout.generate(seed, cfg)
		local ok, errs = MapValidator.validate(a, cfg)
		local deterministic = a.signature == b.signature
		if ok and deterministic then
			pass += 1
		else
			fail += 1
			table.insert(lines, `GAGAL seed {seed}: valid={ok} deterministik={deterministic} {table.concat(errs, "; ")}`)
		end
		if a.attempt > 1 then
			retried += 1
		end
		if a.fallback then
			fallbacks += 1
		end
		totalFailedSeeds += #a.failures
		local rc = #a.rooms
		minRooms = math.min(minRooms, rc)
		maxRooms = math.max(maxRooms, rc)
		sumRooms += rc
		sumLoops += a.loops
		if a.loops > 0 then
			withLoop += 1
		end
		for _, r in a.rooms do
			templateUse[r.templateId] = (templateUse[r.templateId] or 0) + 1
		end
	end

	local usage = {}
	for _, t in (require(MapGen.RoomCatalog) :: any).Templates do
		table.insert(usage, `{t.id}={templateUse[t.id] or 0}`)
	end
	table.insert(lines, 1, string.format(
		"GeneratorSeeds %d..%d: LULUS %d / GAGAL %d | ruangan min %d max %d rata2 %.1f | loop rata2 %.2f (%d peta) | perlu retry %d | fallback %d | seed gagal tercatat %d | %.0f ms",
		start,
		start + n - 1,
		pass,
		fail,
		minRooms,
		maxRooms,
		sumRooms / n,
		sumLoops / n,
		withLoop,
		retried,
		fallbacks,
		totalFailedSeeds,
		(os.clock() - t0) * 1000
	))
	table.insert(lines, 2, "pemakaian template: " .. table.concat(usage, " "))
	holder:Destroy()
	return table.concat(lines, "\n")
end

return GeneratorSeeds
