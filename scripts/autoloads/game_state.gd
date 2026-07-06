extends Node
## GameState — Autoload singleton.
## Owns the level list, chapter progression, and story flags for Chapter 1.

signal puzzle_won(level_index: int, moves_used: int)
signal chapter_completed
signal story_flag_changed(flag_name: String, value: bool)

const LEVELS: Array[String] = [
	"res://levels/level_1.tscn",
	"res://levels/level_2.tscn",
	"res://levels/level_3.tscn",
]

const OVERWORLD_SCENE: String = "res://scenes/overworld.tscn"
const CHAPTER_END_SCENE: String = "res://scenes/galata_view.tscn"

## -1 means "not currently inside the puzzle sequence" (i.e. in the overworld).
var current_level_index: int = -1

## Accumulated moves across the whole chapter (for the end screen).
var total_moves: int = 0

## Minimal narrative state for the vertical slice. No inventory, no currency.
var story_flags: Dictionary = {
	"cat_fed": false,
	"chapter_1_complete": false,
}


## Called from the overworld when the player interacts with the building face.
func start_chapter() -> void:
	current_level_index = 0
	total_moves = 0
	_set_flag("cat_fed", false)
	_set_flag("chapter_1_complete", false)
	_load_level(current_level_index)


## Called by puzzle.gd the moment win detection fires.
func on_puzzle_won(moves_used: int) -> void:
	total_moves += moves_used
	puzzle_won.emit(current_level_index, moves_used)

	if current_level_index < LEVELS.size() - 1:
		current_level_index += 1
		_load_level(current_level_index)
	else:
		_complete_chapter()


## Called by puzzle.gd when the player presses R.
## Keeps reset logic centralized so restarting always reloads a clean scene.
func reload_current_level() -> void:
	if current_level_index >= 0:
		_load_level(current_level_index)


## Safe accessor for story flags (returns false for unknown flags).
func get_flag(flag_name: String) -> bool:
	return story_flags.get(flag_name, false)


func return_to_overworld() -> void:
	current_level_index = -1
	get_tree().call_deferred("change_scene_to_file", OVERWORLD_SCENE)


# --- Internal ---

func _load_level(index: int) -> void:
	var path: String = LEVELS[index]
	if not ResourceLoader.exists(path):
		push_error("GameState: missing level scene at %s" % path)
		return
	# Deferred so we never free the current scene mid-physics-frame.
	get_tree().call_deferred("change_scene_to_file", path)


func _complete_chapter() -> void:
	_set_flag("cat_fed", true)
	_set_flag("chapter_1_complete", true)
	current_level_index = -1
	chapter_completed.emit()
	get_tree().call_deferred("change_scene_to_file", CHAPTER_END_SCENE)


func _set_flag(flag_name: String, value: bool) -> void:
	story_flags[flag_name] = value
	story_flag_changed.emit(flag_name, value)
