## --- Add to the top of puzzle.gd if not present ---
## (your existing extends line stays as-is)

## --- Add to (or merge into) your existing _ready() ---
func _ready() -> void:
	# Existing setup code stays above this line.
	SkinRegistry.apply_skins(self)


## --- Call this from your existing win-detection code, replacing whatever
## --- currently happens on victory. `move_count` is your existing counter.
func _on_level_won() -> void:
	set_process_input(false)  # Freeze input so the cat can't move mid-transition.
	GameState.on_puzzle_won(move_count)


## --- Replace the body of your R-key reset with this call ---
func _reset_level() -> void:
	GameState.reload_current_level()
