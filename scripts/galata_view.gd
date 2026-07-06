extends Node2D
## End-of-chapter scene: the cat, fed, looks out at Galata Tower.
## Shows total moves and returns to the overworld on input.

@onready var moves_label: Label = $UI/MovesLabel


func _ready() -> void:
	if moves_label != null:
		moves_label.text = "Chapter 1 complete — %d moves" % GameState.total_moves
	SkinRegistry.apply_skins(self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		GameState.return_to_overworld()
