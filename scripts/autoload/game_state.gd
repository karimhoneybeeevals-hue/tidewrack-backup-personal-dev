extends Node
## GameState — global save/load and story flags.
##
## Autoloaded as `GameState`. Holds the narrative flags set by dialogue
## choices and persists them (plus the Journal's discovered entry ids) to
## user://save.json so "Continue" works.
##
## Save format history:
##   v1 — {version, scene, flags}
##   v2 — v1 + "journal": [entry ids]   (a v1 save loads with an empty journal)

signal state_changed

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2

## Story flags set during play, e.g. {"trusted_edith": true}.
var flags: Dictionary = {}
## Path of the scene the player should resume into.
var current_scene: String = "res://scenes/game.tscn"
## Where saves are read/written. Overridable so tests never touch a real save.
var save_path: String = SAVE_PATH


func set_flag(name: String, value: Variant) -> void:
	flags[name] = value
	state_changed.emit()


func get_flag(name: String, default: Variant = false) -> Variant:
	return flags.get(name, default)


func new_game() -> void:
	flags.clear()
	current_scene = "res://scenes/game.tscn"
	var journal := _journal()
	if journal != null:
		journal.clear()
	state_changed.emit()


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_game() -> bool:
	var journal := _journal()
	var payload := {
		"version": SAVE_VERSION,
		"scene": current_scene,
		"flags": flags,
		"journal": journal.to_save() if journal != null else [],
	}

	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("GameState: could not open save file for writing.")
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_error("GameState: could not open save file for reading.")
		return false
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameState: save file is corrupt.")
		return false

	var data: Dictionary = _migrate(parsed)

	var loaded_flags: Variant = data.get("flags", {})
	current_scene = data.get("scene", "res://scenes/game.tscn")
	flags = loaded_flags if typeof(loaded_flags) == TYPE_DICTIONARY else {}
	var journal := _journal()
	if journal != null:
		journal.restore(data.get("journal", []))
	state_changed.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(save_path)


## Bring an older save up to the current shape. Never drops existing keys.
func _migrate(data: Dictionary) -> Dictionary:
	var raw_version: Variant = data.get("version", 1)
	var version := 1
	if typeof(raw_version) == TYPE_INT or typeof(raw_version) == TYPE_FLOAT:
		version = int(raw_version)
	if version > SAVE_VERSION:
		# Save from a newer build: load the fields we know, ignore the rest.
		push_warning("GameState: save version %d is newer than %d; loading known fields only." % [version, SAVE_VERSION])
		return data
	if version < 2 and not data.has("journal"):
		data["journal"] = []  # v1 -> v2: journal didn't exist yet.
	return data


func _journal() -> Node:
	return get_node_or_null("/root/Journal")
