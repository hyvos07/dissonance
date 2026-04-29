## LevelData — Custom Resource that holds parsed level JSON.
## Use: var ld = LevelData.new(); ld.load_from_json("res://levels/example_aria.json")
## Then pass ld to RhythmClock or TrapFactory.
class_name LevelData
extends Resource

## --- Exported for inspector editing (optional) ---
@export var level_name: String = ""
@export var grid_size: Vector2i = Vector2i(6, 6)

## --- Internal data ---
var bpm_map: Array[Dictionary] = []   # [{ "start_sec": float, "bpm": float }]
var traps: Array[Dictionary] = []     # raw trap entries from JSON


# ──────────────────────────────────────────────
# Loading
# ──────────────────────────────────────────────

func load_from_json(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("LevelData: cannot open file %s" % path)
		return false

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("LevelData: JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return false

	var data: Dictionary = json.data
	_parse_dict(data)
	return true


func load_from_dict(data: Dictionary) -> void:
	_parse_dict(data)


func _parse_dict(data: Dictionary) -> void:
	level_name = data.get("level_name", "untitled")

	var gs = data.get("grid_size", [6, 6])
	grid_size = Vector2i(int(gs[0]), int(gs[1]))

	# BPM map — sort by start_sec ascending
	bpm_map.clear()
	var raw_bpm: Array = data.get("bpm_map", [])
	for entry in raw_bpm:
		bpm_map.append({
			"start_sec": float(entry.get("start_sec", 0.0)),
			"bpm": float(entry.get("bpm", 120.0))
		})
	bpm_map.sort_custom(_sort_by_start_sec)

	# Fallback: if no bpm_map, use a single 120 BPM entry
	if bpm_map.is_empty():
		bpm_map.append({ "start_sec": 0.0, "bpm": 120.0 })

	# Traps
	traps.clear()
	var raw_traps: Array = data.get("traps", [])
	for t in raw_traps:
		var trap_entry: Dictionary = {}
		trap_entry["beat"] = float(t.get("beat", 0.0))
		trap_entry["type"] = String(t.get("type", "pulse"))
		trap_entry["warn_beats"] = int(t.get("warn_beats", 2))
		trap_entry["duration_beats"] = int(t.get("duration_beats", 1))

		# Positions — array of [x, y]
		var positions: Array[Vector2i] = []
		for p in t.get("positions", []):
			positions.append(Vector2i(int(p[0]), int(p[1])))
		trap_entry["positions"] = positions

		# Chord direction (optional)
		if t.has("direction"):
			var d = t["direction"]
			trap_entry["direction"] = Vector2i(int(d[0]), int(d[1]))

		traps.append(trap_entry)


# ──────────────────────────────────────────────
# BPM Queries
# ──────────────────────────────────────────────

## Get BPM active at given song second.
func get_bpm_at_second(sec: float) -> float:
	var result_bpm: float = bpm_map[0]["bpm"]
	for entry in bpm_map:
		if sec >= entry["start_sec"]:
			result_bpm = entry["bpm"]
		else:
			break
	return result_bpm


## Get seconds-per-beat at given song second.
func get_seconds_per_beat_at(sec: float) -> float:
	return 60.0 / get_bpm_at_second(sec)


# ──────────────────────────────────────────────
# Auto-Converter: seconds ↔ beat index
# ──────────────────────────────────────────────

## Convert a song position (seconds) into a fractional beat index,
## accounting for BPM changes along the way.
func seconds_to_beat(sec: float) -> float:
	var total_beats: float = 0.0
	var prev_sec: float = 0.0
	var prev_bpm: float = bpm_map[0]["bpm"]

	for i in range(1, bpm_map.size()):
		var change_sec: float = bpm_map[i]["start_sec"]
		if sec <= change_sec:
			break
		# Accumulate beats in previous BPM segment
		total_beats += (change_sec - prev_sec) * (prev_bpm / 60.0)
		prev_sec = change_sec
		prev_bpm = bpm_map[i]["bpm"]

	# Remaining time in current BPM segment
	total_beats += (sec - prev_sec) * (prev_bpm / 60.0)
	return total_beats


## Convert a fractional beat index back into seconds,
## accounting for BPM changes.
func beat_to_seconds(beat: float) -> float:
	var remaining_beats: float = beat
	var prev_sec: float = 0.0
	var prev_bpm: float = bpm_map[0]["bpm"]

	for i in range(1, bpm_map.size()):
		var change_sec: float = bpm_map[i]["start_sec"]
		var segment_duration_sec: float = change_sec - prev_sec
		var segment_beats: float = segment_duration_sec * (prev_bpm / 60.0)

		if remaining_beats <= segment_beats:
			return prev_sec + remaining_beats * (60.0 / prev_bpm)

		remaining_beats -= segment_beats
		prev_sec = change_sec
		prev_bpm = bpm_map[i]["bpm"]

	# Remaining beats in last segment
	return prev_sec + remaining_beats * (60.0 / prev_bpm)


# ──────────────────────────────────────────────
# Trap Queries
# ──────────────────────────────────────────────

## Get all traps whose warning or active phase covers the given beat.
func get_traps_at_beat(beat: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for t in traps:
		var warn_start: float = t["beat"] - float(t["warn_beats"])
		var active_end: float = t["beat"] + float(t["duration_beats"])
		if beat >= warn_start and beat < active_end:
			result.append(t)
	return result


## Get traps that START (activate) exactly at this beat (within tolerance).
func get_traps_activating_at_beat(beat: float, tolerance: float = 0.1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for t in traps:
		if absf(t["beat"] - beat) <= tolerance:
			result.append(t)
	return result


# ──────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────

static func _sort_by_start_sec(a: Dictionary, b: Dictionary) -> bool:
	return a["start_sec"] < b["start_sec"]
