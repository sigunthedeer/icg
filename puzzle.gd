extends Node2D

const CELL_SIZE := 64
const COLS := 8
const ROWS := 6
const MOVE_TIME := 0.10   # seconds for a sprite to glide one cell

# --- LEVELS: the puzzle is DATA. Add or reorder freely. ---
# Each: where the cat starts, its pots, the goal tile, and the walls.
const LEVELS := [
	{ "cat": Vector2i(2,2), "pots": [Vector2i(1,2)], "goal": Vector2i(4,5),
	  "walls": [Vector2i(0,5), Vector2i(2,0), Vector2i(4,4), Vector2i(7,5)] },
	{ "cat": Vector2i(4,3), "pots": [Vector2i(3,3)], "goal": Vector2i(6,2),
	  "walls": [Vector2i(1,1), Vector2i(3,4), Vector2i(4,2), Vector2i(6,3), Vector2i(7,4)] },
	{ "cat": Vector2i(3,1), "pots": [Vector2i(2,4)], "goal": Vector2i(0,0),
	  "walls": [Vector2i(0,3), Vector2i(2,0), Vector2i(2,5), Vector2i(4,1), Vector2i(6,4)] },
	{ "cat": Vector2i(2,0), "pots": [Vector2i(3,2)], "goal": Vector2i(7,2),
	  "walls": [Vector2i(1,1), Vector2i(3,1), Vector2i(4,0), Vector2i(5,2), Vector2i(7,4)] },
	{ "cat": Vector2i(1,2), "pots": [Vector2i(2,3)], "goal": Vector2i(7,3),
	  "walls": [Vector2i(0,5), Vector2i(1,1), Vector2i(2,2), Vector2i(2,5), Vector2i(4,4), Vector2i(5,0), Vector2i(5,3), Vector2i(7,1)] },
	{ "cat": Vector2i(1,2), "pots": [Vector2i(6,3)], "goal": Vector2i(2,0),
	  "walls": [Vector2i(0,5), Vector2i(1,4), Vector2i(2,1), Vector2i(3,4), Vector2i(4,0), Vector2i(4,4), Vector2i(5,5), Vector2i(6,2), Vector2i(7,2)] },
]

var level_index := 0
var cat_cell: Vector2i
var pots: Array = []
var goal: Vector2i
var walls: Array = []
var _tween: Tween
var moves := 0
var solved := false
var legs_done := 0
var journey_label: Label
var meow_sfx: AudioStreamPlayer
var win_sfx: AudioStreamPlayer
var fail_sfx: AudioStreamPlayer
var _prev_cell: Vector2i

@onready var cat: AnimatedSprite2D = $Cat
var pot_sprites: Array = []
var info_label: Label

func _ready() -> void:
	meow_sfx = AudioStreamPlayer.new()
	meow_sfx.stream = load("res://audio/meow.wav")
	add_child(meow_sfx)
	win_sfx = AudioStreamPlayer.new()
	win_sfx.stream = load("res://audio/win.wav")
	add_child(win_sfx)
	fail_sfx = AudioStreamPlayer.new()
	fail_sfx.stream = load("res://audio/fail.wav")
	add_child(fail_sfx)
	info_label = Label.new()
	info_label.position = Vector2(8, 8)
	add_child(info_label)
	journey_label = Label.new()
	journey_label.position = Vector2(8, 34)
	add_child(journey_label)
	_load_level(0)
	# Center the whole board in the window.
	var board_px := Vector2(COLS, ROWS) * CELL_SIZE
	position = (get_viewport_rect().size - board_px) * 0.5
	cat.play("default")

func _load_level(i: int) -> void:
	level_index = i
	legs_done = i
	var data = LEVELS[i]
	cat_cell = data["cat"]
	pots = data["pots"].duplicate()
	goal = data["goal"]
	walls = data["walls"]
	moves = 0
	solved = false
	modulate = Color.WHITE

	for s in pot_sprites:
		s.queue_free()
	pot_sprites.clear()
	for j in pots.size():
		var s := Sprite2D.new()
		s.texture = load("res://icon.svg")     # green placeholder pot (her art later)
		s.scale = Vector2(0.4, 0.4)
		s.modulate = Color(0.5, 1.0, 0.5)
		add_child(s)
		pot_sprites.append(s)

	cat.flip_h = false
	_snap_positions()
	_refresh_ui()
	
func _update_journey() -> void:
	var filled := "🐾".repeat(legs_done)
	var empty := "·".repeat(LEVELS.size() - legs_done)
	journey_label.text = "To Galata: %s%s 🗼" % [filled, empty]
	
func _unhandled_input(event: InputEvent) -> void:
	if solved:
		# Levels auto-advance after a short beat. On the final screen, R replays.
		if level_index + 1 >= LEVELS.size() \
		and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
			_load_level(0)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		meow_sfx.play()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_load_level(level_index)
		return

	var step := Vector2i.ZERO
	if event.is_action_pressed("ui_right"):   step = Vector2i(1, 0)
	elif event.is_action_pressed("ui_left"):  step = Vector2i(-1, 0)
	elif event.is_action_pressed("ui_down"):  step = Vector2i(0, 1)
	elif event.is_action_pressed("ui_up"):    step = Vector2i(0, -1)
	if step != Vector2i.ZERO:
		_try_move(step)

func _try_move(step: Vector2i) -> void:
	if step.x > 0: cat.flip_h = false
	elif step.x < 0: cat.flip_h = true

	var target := cat_cell + step
	if _blocked(target):
		return
	var pot_index := pots.find(target)
	if pot_index != -1:                        # ← the fixed line
		var behind := target + step
		if _blocked(behind) or pots.find(behind) != -1:
			return
		pots[pot_index] = behind
	_prev_cell = cat_cell
	cat_cell = target
	moves += 1
	_animate_positions()
	_refresh_ui()
	_check_win()

func _blocked(c: Vector2i) -> bool:
	if c.x < 0 or c.x >= COLS or c.y < 0 or c.y >= ROWS:
		return true
	return walls.has(c)
	
func _shake(amount: float, time: float) -> void:
	var start := position
	var steps := 8
	var t := create_tween()
	for i in steps:
		var off := Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
		t.tween_property(self, "position", start + off, time / steps)
	t.tween_property(self, "position", start, time / steps)

func _check_win() -> void:
	if pots[0] == goal:
		solved = true
		win_sfx.play()
		var winning_pot: Sprite2D = pot_sprites[0]
		_shake(6.0, 0.25)
		var t := create_tween()
		t.tween_property(winning_pot, "scale", Vector2(0.6, 0.6), 0.12)
		t.tween_property(winning_pot, "scale", Vector2(0.4, 0.4), 0.12)
		legs_done = level_index + 1
		modulate = Color(1, 1, 0.7)
		_update_journey()
		if level_index + 1 < LEVELS.size():
			info_label.text = "The cat eats. 🐟  One leg closer…"
			await get_tree().create_timer(1.0).timeout   # the pause before advancing
			if solved and level_index + 1 < LEVELS.size():  # still solved? then go
				_load_level(level_index + 1)
		else:
			info_label.text = "The cat eats, and Galata comes into view. 🐾🗼  (R to replay)"

func _refresh_ui() -> void:
	if not solved:
		info_label.text = "Level %d / %d    Moves: %d    (R reset)" % [level_index + 1, LEVELS.size(), moves]
	_update_journey()
	queue_redraw()

func _snap_positions() -> void:            # instant (used on level load)
	cat.position = _cell_to_px(cat_cell)
	for i in pots.size():
		pot_sprites[i].position = _cell_to_px(pots[i])

func _animate_positions() -> void:         # glide (used on each move)
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(cat, "position", _cell_to_px(cat_cell), MOVE_TIME)
	for i in pots.size():
		_tween.tween_property(pot_sprites[i], "position", _cell_to_px(pots[i]), MOVE_TIME)
	# little squash toward the direction of movement
	var dir := Vector2(cat_cell - _prev_cell)
	cat.scale = Vector2(0.35, 0.35)   # your normal scale
	_tween.tween_property(cat, "scale", Vector2(0.4, 0.31), MOVE_TIME * 0.4)
	_tween.chain().tween_property(cat, "scale", Vector2(0.35, 0.35), MOVE_TIME * 0.6)

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
