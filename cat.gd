extends CharacterBody2D

# Movement speed in pixels per second. @export shows it in the
# Inspector so I can tweak it without touching code.
@export var speed: float = 200.0

@warning_ignore("unused_parameter")
func _physics_process(delta: float) -> void:
		# Reads arrow keys and returns a direction (a Vector2).
		# It is pre-normalized, so diagonals are not faster than straight lines.
		var direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		
		# Velocity = which way x how fast.
		velocity = direction * speed
		
		# Move, and slide along anything we bump into.
		move_and_slide()
