# Journal save/Continue — regression checks

Covers how discovered journal entry ids persist through `GameState.save_game()` /
`load_game()` (save version 2, `"journal"` key in `user://save.json`).

## How to run

**Automated** (from the project root; uses `user://test_save.json`, never the real save):

```
godot --headless -s tests/test_journal_save.gd
```

Exit code 0 = all checks pass. The test covers every section below.

**Manual.** Nothing in the game calls `Journal.discover()` yet (no dialogue hook),
so for manual runs trigger discovery temporarily, e.g. add
`Journal.discover("entry_test_1")` in `game.gd` `_ready()` and remove it afterwards.
Open the save with *Project > Open User Data Folder* and inspect `save.json`.

---

## 1. Normal save / Continue

1. New Game. Discover `entry_a`, then `entry_b`. Set a story flag (e.g. take a
   logbook choice that sets `skeptic`).
2. Pause > Save. Open `save.json`.
3. Quit to the main menu (or the app), then Continue.

**Expect**
- `save.json` has `"version": 2` and `"journal": ["entry_a", "entry_b"]` (discovery order).
- After Continue, the journal holds exactly `entry_a`, `entry_b` in that order.
- The flag set in step 1 is still set; `scene` resumes where the save was made.
- No `entry_added` signal fires during Continue (restoring is not "discovering").

## 2. Old v1 save with no journal data

Fixture: `tests/fixtures/save_v1.json` (`"version": 1`, flags only, no `journal` key).

1. Copy the fixture over `user://save.json`.
2. Continue.

**Expect**
- Continue works; no error in the output log.
- Flags match the fixture: `skeptic` true, `trusted_edith` false, `radioed_tom` true.
- Journal is empty (including any entries held in memory before loading).
- Saving again writes `"version": 2` with `"journal": []`; flags unchanged.

## 3. New Game reset

1. Continue from a save that has journal entries (section 1).
2. Return to the main menu and press New Game.

**Expect**
- Journal is empty; flags are cleared; scene is `res://scenes/game.tscn`.
- Saving immediately afterwards writes `"journal": []` (nothing carried over from the previous run).
- The earlier save is untouched until the player saves over it.

## 4. Discovering the same entry twice

1. Discover `entry_a`, then `entry_a` again, then `entry_b`.
2. Save and Continue.

**Expect**
- `entry_added` fires once for `entry_a`, not twice.
- Journal is `["entry_a", "entry_b"]`; `entry_a` keeps its first position.
- `save.json` lists `entry_a` once.
- `Journal.discover("")` (empty id) is ignored.

## 5. Broken journal data in the save

Edit `save.json` by hand, then Continue. Each case should load without errors and
leave flags and scene intact.

| `"journal"` value in the save | Expect after Continue |
|---|---|
| `["a", 3, null, "", "a", ["b"], "c"]` | Journal is `["a", "c"]` (non-strings, empty strings and duplicates dropped) |
| `"not-an-array"` | Journal is empty |
| `null` or key missing (with `"version": 2`) | Journal is empty |
| `{"a": 1}` (object) | Journal is empty |

Also check a truncated file (e.g. `{"version":2,"flags":`): Continue is rejected
("save file is corrupt") and the game's current flags and journal are left
unchanged.

---

## Known gaps (not covered by these checks)

- Nothing records entries in normal play yet; a dialogue hook is still needed.
- Saving is only available from the ground-floor pause menu, not the lamp room.
- Writes are not atomic and a missing saved scene path has no fallback.
- Entry ids that no longer exist in content are kept as-is.
