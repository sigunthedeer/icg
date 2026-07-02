extends  Node2D

# --- Grid Setup ---
const CELL_SIZE := 64 # pixels per cell
const COLS := 8 # board width, in cells
const ROWS := 6 # board height, in cells

# Where the cat sits, in GRID coordinates (column, row) - not pixels.
var cat_cell := Vector2i(2, 3)

@onready var cat: Sprite2D = $Cat

func _ready() -> void:
	_snap_cat() # place the cat at its starting cell
	
func _unhandled_input(event: InputEvent) -> void:
	# one key press = one step. Fires only on the frame the key goes down.
	var step := Vector2i.ZERO
	if event.is_action_pressed("ui_right"): step = Vector2i(1, 0)
	elif event.is_action_pressed("ui_left"): step = Vector2i(-1, 0)
	elif event.is_action_pressed("ui_down"): step = Vector2i(0, 1)
	elif event.is_action_pressed("ui_up"): step = Vector2i(0, -1)
	
	if step != Vector2i.ZERO:
		_try_move(step)
		
func _try_move(step: Vector2i) -> void:
	var target := cat_cell + step
	# step on the board.
	if target.x < 0 or target.x >= COLS or target.y < 0 or target.y >= ROWS:
		return
	cat_cell = target
	_snap_cat()
	
func _snap_cat() -> void:
	# convert grid coords -> pixel location (centered in the cell)
	cat.position = Vector2(cat_cell) * CELL_SIZE + Vector2(CELL_SIZE, CELL_SIZE) * 0.5

func _draw() -> void:
	# Faint grid lines so you can see the cells (visual aid only).
	var c := Color(1, 1, 1, 0.15)
	for x in range(COLS + 1):
		draw_line(Vector2(x * CELL_SIZE, 0), Vector2(x * CELL_SIZE, ROWS * CELL_SIZE), c)
	for y in range(ROWS + 1):
		draw_line(Vector2(0, y * CELL_SIZE), Vector2(COLS * CELL_SIZE, y * CELL_SIZE), c)
