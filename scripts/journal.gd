extends Node
## Journal — discovered-logs system (Public Demo scaffold).
##
## Autoloaded as `Journal` (see project.godot). As the player examines objects,
## the dialogue hooks will record discovered entries here; the journal screen
## renders them. Scaffold only: storage + persistence helpers, no UI yet.
##
## Persistence: GameState.save_game() writes `to_save()` under the "journal" key
## and GameState.load_game() hands the raw value back to `restore()`.

signal entry_added(id: String)
## Emitted after the whole list is replaced (load, new game). Not per-entry, so
## a future UI can rebuild once instead of toasting every restored entry.
signal entries_reset

var _entries: Array[String] = []


func discover(id: String) -> void:
	if id.is_empty() or id in _entries:
		return
	_entries.append(id)
	entry_added.emit(id)


func entries() -> Array[String]:
	return _entries.duplicate()


func has(id: String) -> bool:
	return id in _entries


func clear() -> void:
	_entries.clear()
	entries_reset.emit()


## Plain Array of ids, in discovery order, ready for JSON.
func to_save() -> Array:
	return Array(_entries)


## Replace entries from untrusted save data. Anything that is not a non-empty
## string is dropped, duplicates keep their first position, and a non-array
## value yields an empty journal rather than an error.
func restore(raw: Variant) -> void:
	var cleaned: Array[String] = []
	if typeof(raw) == TYPE_ARRAY:
		for item in raw:
			if typeof(item) != TYPE_STRING:
				continue
			var id: String = item
			if id.is_empty() or id in cleaned:
				continue
			cleaned.append(id)
	_entries = cleaned
	entries_reset.emit()
