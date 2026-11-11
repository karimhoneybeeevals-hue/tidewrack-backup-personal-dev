extends SceneTree
## Headless save/Continue round-trip test for flags + journal entry ids.
##
## Run from the project root:
##   godot --headless -s tests/test_journal_save.gd
## Exit code 0 = pass, 1 = failure. Uses user://test_save.json, never the real
## save. Relies on the GameState and Journal autoloads from project.godot.

const TEST_SAVE := "user://test_save.json"
const V1_FIXTURE := "res://tests/fixtures/save_v1.json"

var _failures := 0


func _initialize() -> void:
	var gs: Node = root.get_node("GameState")
	var journal: Node = root.get_node("Journal")
	gs.save_path = TEST_SAVE
	_cleanup()

	_test_v1_save_loads_with_empty_journal(gs, journal)
	_test_round_trip(gs, journal)
	_test_new_game_clears_journal(gs, journal)
	_test_bad_journal_data_is_cleaned(gs, journal)
	_test_corrupt_file_leaves_state_untouched(gs, journal)
	_test_restore_does_not_emit_entry_added(journal)

	_cleanup()
	print("FAILED: %d" % _failures if _failures > 0 else "all journal save tests passed")
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures += 1
		printerr("  FAIL: " + label)


func _write(text: String) -> void:
	var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _cleanup() -> void:
	for p in [TEST_SAVE]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _test_v1_save_loads_with_empty_journal(gs: Node, journal: Node) -> void:
	_write(FileAccess.get_file_as_string(V1_FIXTURE))
	journal.discover("stale_entry")  # must not survive a load
	_check(gs.load_game(), "v1 save loads")
	_check(gs.get_flag("skeptic") == true, "v1 flag skeptic kept")
	_check(gs.get_flag("trusted_edith", true) == false, "v1 flag trusted_edith=false kept")
	_check(gs.get_flag("radioed_tom") == true, "v1 flag radioed_tom kept")
	_check(journal.entries().is_empty(), "v1 save -> empty journal (stale entry cleared)")


func _test_round_trip(gs: Node, journal: Node) -> void:
	gs.new_game()
	gs.set_flag("believer", true)
	journal.discover("entry_logbook_1")
	journal.discover("entry_radio_1")
	journal.discover("entry_logbook_1")  # duplicate ignored
	_check(gs.save_game(), "save succeeds")
	gs.flags.clear()
	journal.clear()
	_check(gs.load_game(), "continue loads")
	_check(journal.entries() == ["entry_logbook_1", "entry_radio_1"], "entries + order survive")
	_check(gs.get_flag("believer") == true, "flag survives alongside journal")


func _test_new_game_clears_journal(gs: Node, journal: Node) -> void:
	journal.discover("entry_x")
	gs.new_game()
	_check(journal.entries().is_empty(), "new_game clears journal")


func _test_bad_journal_data_is_cleaned(gs: Node, journal: Node) -> void:
	_write('{"version":2,"scene":"res://scenes/game.tscn","flags":{},"journal":["a",3,null,"","a",["b"],"c"]}')
	_check(gs.load_game(), "load with messy journal succeeds")
	_check(journal.entries() == ["a", "c"], "non-strings, empties, dupes dropped")
	_write('{"version":2,"flags":{},"journal":"not-an-array"}')
	_check(gs.load_game(), "load with non-array journal succeeds")
	_check(journal.entries().is_empty(), "non-array journal -> empty")


func _test_corrupt_file_leaves_state_untouched(gs: Node, journal: Node) -> void:
	gs.new_game()
	gs.set_flag("keep_me", true)
	journal.discover("entry_keep")
	_write('{"version":2,"flags":')  # truncated
	_check(not gs.load_game(), "truncated save is rejected")
	_check(gs.get_flag("keep_me") == true, "flags untouched after failed load")
	_check(journal.entries() == ["entry_keep"], "journal untouched after failed load")


func _test_restore_does_not_emit_entry_added(journal: Node) -> void:
	var fired := [0]
	var cb := func(_id: String): fired[0] += 1
	journal.entry_added.connect(cb)
	journal.restore(["r1", "r2"])
	journal.entry_added.disconnect(cb)
	_check(fired[0] == 0, "restore does not emit entry_added")
