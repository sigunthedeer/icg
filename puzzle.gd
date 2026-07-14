extends Node2D

const CELL_SIZE := 64
const COLS := 11
const ROWS := 7
const MOVE_TIME := 0.10   # seconds for a sprite to glide one cell
const BG_SCALE := 0.65
const BG_OFFSET := Vector2(-329, -135)

# --- LEVELS: the puzzle is DATA. Add or reorder freely. ---
# Each: where the cat starts, its pots, the goal tile, and the walls.
const LEVELS := [
	{ "cat": Vector2i(2,0), "pots": [Vector2i(3,1)], "goal": Vector2i(7,5),
	  "walls": [],
	  "furniture": [ {"cell": Vector2i(0,2), "w": 3}, {"cell": Vector2i(2,4), "w": 2}, {"cell": Vector2i(6,2), "w": 2}, {"cell": Vector2i(5,0), "w": 3} ] },
	{ "cat": Vector2i(4,5), "pots": [Vector2i(2,4)], "goal": Vector2i(7,0),
	  "walls": [],
	  "furniture": [ {"cell": Vector2i(5,3), "w": 3}, {"cell": Vector2i(1,0), "w": 3}, {"cell": Vector2i(1,1), "w": 2} ] },
	{ "cat": Vector2i(2,2), "pots": [Vector2i(3,3)], "goal": Vector2i(1,0),
	  "walls": [],
	  "furniture": [ {"cell": Vector2i(2,1), "w": 3}, {"cell": Vector2i(0,3), "w": 3}, {"cell": Vector2i(5,4), "w": 3} ] },
	{ "cat": Vector2i(7,0), "pots": [Vector2i(2,4)], "goal": Vector2i(6,3),
	  "walls": [],
	  "furniture": [ {"cell": Vector2i(3,1), "w": 2}, {"cell": Vector2i(0,3), "w": 2}, {"cell": Vector2i(5,4), "w": 2}, {"cell": Vector2i(3,5), "w": 2} ] },
	{ "cat": Vector2i(3,2), "pots": [Vector2i(3,4)], "goal": Vector2i(6,0),
	  "walls": [],
	  "furniture": [ {"cell": Vector2i(2,1), "w": 3}, {"cell": Vector2i(1,5), "w": 3}, {"cell": Vector2i(5,3), "w": 3} ] },
	{ "cat": Vector2i(3,5), "pots": [Vector2i(5,4)], "goal": Vector2i(1,0),
	  "walls": [],
	  "furniture": [ {"cell": Vector2i(3,2), "w": 3}, {"cell": Vector2i(5,0), "w": 2}, {"cell": Vector2i(5,5), "w": 2}, {"cell": Vector2i(1,4), "w": 3} ] },
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
var furniture_sprites: Array = []

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
	# Tu Anh's room, behind the grid.
	var bg := Sprite2D.new()
	bg.texture = load("res://bg.png")
	bg.centered = false
	bg.scale = Vector2(BG_SCALE, BG_SCALE)
	bg.position = BG_OFFSET
	bg.z_index = -10          # sits behind the grid, cat, and pots
	add_child(bg)
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
	walls = data["walls"].duplicate()      # was: walls = data["walls"]]
	moves = 0
	solved = false
	modulate = Color.WHITE

	for s in pot_sprites:
		s.queue_free()
	pot_sprites.clear()
	for j in pots.size():
		var s := Sprite2D.new()
		s.texture = load("res://pot.png")     # was icon.svg
		s.scale = Vector2(0.5, 0.5)           # 108px art → ~54px, fits a cell
		add_child(s)
		pot_sprites.append(s)
		
	# Furniture: immovable multi-tile plants (art + collision).
	for s in furniture_sprites:
		s.queue_free()
	furniture_sprites.clear()
	for item in data.get("furniture", []):
		var c: Vector2i = item["cell"]
		var wdt: int = item["w"]
		for dx in range(wdt):                       # block every cell it covers
			var wc := Vector2i(c.x + dx, c.y)
			if not walls.has(wc):
				walls.append(wc)
		var spr := Sprite2D.new()                   # one wide image across them
		spr.texture = load("res://plant_wall.png")
		var target_w := wdt * CELL_SIZE
		spr.scale = Vector2(
			float(wdt * CELL_SIZE) / spr.texture.get_width(),
			float(CELL_SIZE) / spr.texture.get_height()
		)
		spr.position = _cell_to_px(c) + Vector2((wdt - 1) * CELL_SIZE * 0.5, 0)
		spr.z_index = -1                            # above floor, below cat
		add_child(spr)
		furniture_sprites.append(spr)

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
	# Face the direction of movement (rotation for up/down, flip for left/right).
	if step.x > 0:
		cat.flip_h = false
		cat.rotation_degrees = 0
	elif step.x < 0:
		cat.flip_h = true
		cat.rotation_degrees = 0
	elif step.y < 0:                 # up
		cat.flip_h = false
		cat.rotation_degrees = -90
	elif step.y > 0:                 # down
		cat.flip_h = false
		cat.rotation_degrees = 90

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
	cat.scale = Vector2(0.6, 0.6)   # your normal scale
	_tween.tween_property(cat, "scale", Vector2(0.57, 0.44), MOVE_TIME * 0.4)  
	_tween.chain().tween_property(cat, "scale", Vector2(0.5, 0.5), MOVE_TIME * 0.6)

func _cell_to_px(c: Vector2i) -> Vector2:
	return Vector2(c) * CELL_SIZE + Vector2(CELL_SIZE, CELL_SIZE) * 0.5

func _draw() -> void:
	# Walls are furniture art now; just the goal tile remains.
	var g := _cell_to_px(goal) - Vector2(CELL_SIZE, CELL_SIZE) * 0.5
	draw_rect(Rect2(g, Vector2(CELL_SIZE, CELL_SIZE)), Color(1, 0.85, 0.3, 0.3), true)
