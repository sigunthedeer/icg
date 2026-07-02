extends  Node2D

# --- Grid Setup ---
const CELL_SIZE := 64 # pixels per cell
const COLS := 8 # board width, in cells
const ROWS := 6 # board height, in cells

# Where the cat sits, in GRID coordinates (column, row) - not pixels.
var cat_cell := Vector2i(2, 3) # cat starts at street level (bottom)
var pots: Array[Vector2i] = [Vector2i(2, 4)] # a pot just above the cat 
var goal := Vector2i(2, 1) # the goal ledge, up high (near the roof)

# NEW: wall cells = the building's structure. Nothing passes through them.
var walls: Array[Vector2i] = [
	Vector2i(5, 5), Vector2i(5, 4), Vector2i(5, 3), Vector2i(5, 2), Vector2i(5, 1),  # a neighbouring wall
	Vector2i(6, 1), Vector2i(7, 1),   # its roof line
	Vector2i(6, 5), Vector2i(7, 5),   # ground blocks
]

var start_cat: Vector2i
var start_pots: Array[Vector2i]
var moves := 0

@onready var cat: Sprite2D = $Cat
var pot_sprites: Array[Sprite2D] = []
var move_label: Label

func _ready() -> void:
	start_cat = cat_cell
	start_pots = pots.duplicate()
	
	var pot_tex := load("res://icon.svg")
	for i in pots.size():
		var s := Sprite2D.new()
		s.texture = pot_tex
		s.scale = Vector2(0.4, 0.4)
		s.modulate = Color(0.5, 1.0, 0.5)
		add_child(s)
		pot_sprites.append(s)
		
	move_label = Label.new() # on-screen counter
	move_label.position = Vector2(8, 8)
	add_child(move_label)
	
	_refresh()
	
func _unhandled_input(event: InputEvent) -> void:
	# R = reset the puzzle.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_reset()
		return
		
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
	if _blocked(target): # off-board OR a wall
		return
	var pot_index := pots.find(target)
	if pot_index != 1:
		var behind := target + step
		if _blocked(behind) or pots.find(behind) != -1:
			return # wall, edge or another pot behind -> can't push
		pots[pot_index] = behind
	cat_cell = target
	moves += 1 # count each real step
	_refresh()
	_check_win()

# A cell is blocked if it is off the board OR a wall
func _blocked(c: Vector2i) -> bool:
	if c.x < 0 or c.x >= COLS or c.y < 0 or c.y >= ROWS:
		return true
	return walls.has(c)
	
func _reset() -> void:
	cat_cell = start_cat
	pots = start_pots.duplicate()
	moves = 0
	modulate = Color.WHITE # clear the win flash
	_refresh()
	
func _check_win() -> void:
	if pots[0] == goal:
		print("Solved!")
		modulate = Color(1, 1, 0.7) # win flash
		
func _refresh() -> void:
	cat.position = _cell_to_px(cat_cell)
	for i in pots.size():
		pot_sprites[i].position = _cell_to_px(pots[i])
	queue_redraw()
	
func _cell_to_px(c: Vector2i) -> Vector2:
	return Vector2(c) * CELL_SIZE + Vector2(CELL_SIZE, CELL_SIZE) * 0.5
	
func _draw() -> void:
	var line := Color(1, 1, 1, 0.12)
	for x in range(COLS + 1):
		draw_line(Vector2(x * CELL_SIZE, 0), Vector2(x * CELL_SIZE, ROWS * CELL_SIZE), line)
	for y in range(ROWS + 1):
		draw_line(Vector2(0, y * CELL_SIZE), Vector2(COLS * CELL_SIZE, y * CELL_SIZE), line)
	for w in walls:
		var p := _cell_to_px(w) - Vector2(CELL_SIZE, CELL_SIZE) * 0.5
		draw_rect(Rect2(p, Vector2(CELL_SIZE, CELL_SIZE)), Color(0.45, 0.4, 0.42, 0.9), true)
	var g := _cell_to_px(goal) - Vector2(CELL_SIZE, CELL_SIZE) * 0.5
	draw_rect(Rect2(g, Vector2(CELL_SIZE, CELL_SIZE)), Color(1, 0.85, 0.3, 0.3), true)
