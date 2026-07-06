extends Area2D
## Attach to an Area2D placed at the building face in the overworld.
## When the cat enters and presses "interact", the Chapter 1 puzzle
## sequence begins. After the chapter is complete, entry is blocked
## (the cat has been fed — story state lives in GameState).

@export var interact_action: String = "ui_accept"

var _player_inside: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside:
		return
	if GameState.get_flag("chapter_1_complete"):
		return
	if event.is_action_pressed(interact_action):
		GameState.start_chapter()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
