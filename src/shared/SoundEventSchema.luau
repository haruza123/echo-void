-- Kontrak SoundEvent (PRD 5.1). Satu event per suara; TIDAK ada data per-garis lewat jaringan.
local Schema = {}

export type SoundEvent = {
	eventId: number,
	sourceType: string,
	worldPosition: Vector3,
	startedAtServer: number,
	revealRadius: number,
	soundStrength: number,
	propagationSpeed: number,
	duration: number,
	materialProfile: string,
	brightness: number,
	actorId: number?,
}

Schema.SourceType = {
	CrouchStep = "CrouchStep",
	WalkStep = "WalkStep",
	RunStep = "RunStep",
	ManualPing = "ManualPing",
	ItemImpact = "ItemImpact",
	Machine = "Machine",
	DoorMove = "DoorMove",
}

local function finiteNumber(n: any): boolean
	return type(n) == "number" and n == n and n > -1e7 and n < 1e7
end

function Schema.isFiniteVector(v: any): boolean
	return typeof(v) == "Vector3" and finiteNumber(v.X) and finiteNumber(v.Y) and finiteNumber(v.Z)
end

-- Validasi event yang diterima client (pertahanan terhadap data rusak, bukan keamanan).
function Schema.isValid(ev: any): boolean
	if type(ev) ~= "table" then
		return false
	end
	return finiteNumber(ev.eventId)
		and type(ev.sourceType) == "string"
		and Schema.SourceType[ev.sourceType] ~= nil
		and Schema.isFiniteVector(ev.worldPosition)
		and type(ev.startedAtServer) == "number"
		and ev.startedAtServer == ev.startedAtServer -- timestamp (~1.7e9), jangan pakai batas 1e7
		and finiteNumber(ev.revealRadius)
		and ev.revealRadius > 0
		and ev.revealRadius <= 200
		and finiteNumber(ev.propagationSpeed)
		and ev.propagationSpeed > 0
		and finiteNumber(ev.duration)
		and ev.duration > 0
		and finiteNumber(ev.brightness)
		and type(ev.materialProfile) == "string"
end

return Schema
