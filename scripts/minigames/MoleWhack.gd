extends MinigameBase
## Caza al topo: en un tablero de agujeros, un topo asoma en uno al azar
## durante un instante — tócalo antes de que se esconda. A diferencia de
## un "mash" simple, importa DÓNDE tocas, no solo cuántas veces.
## Recolección acumulada: se suman los topos cazados por todos los
## participantes.

@export var duration_max := 7.0
const COLS := 2
const ROWS := 3
const NUM_HOLES := COLS * ROWS
const MOLE_UP_TIME := 0.65
const SPAWN_GAP_MIN := 0.35
const SPAWN_GAP_MAX := 0.65
const RESULT_DELAY := 1.0

## El topo se hace más rápido y aparece con más frecuencia según pasa el
## tiempo — al principio va al ritmo de siempre, al final casi se enlazan
## uno con otro sin pausa.
const MOLE_UP_TIME_MIN := 0.35
const SPAWN_GAP_MIN_FLOOR := 0.15
const SPAWN_GAP_MAX_FLOOR := 0.3

const HOLE_COLOR := Color(0.25, 0.18, 0.12)
const MOLE_COLOR := Color(0.55, 0.35, 0.2)

var _holes: Array[ColorRect] = []
var _info_label: Label
var _stat_label: Label

var _active_hole := -1
var _mole_time_left := 0.0
var _spawn_timer := 0.0
var _elapsed := 0.0
var _hit_count := 0
var _running := false

func get_aggregation_type() -> String:
	return "collect_sum"

func get_unit_label() -> String:
	return "topos"

func get_mechanic_category() -> String:
	return "reaccion"

func get_display_name() -> String:
	return "Caza al topo"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_info_label = Label.new()
	_info_label.text = "¡Toca el topo antes de que se esconda!"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_info_label.position.y = 16
	add_child(_info_label)

	for i in NUM_HOLES:
		var hole := ColorRect.new()
		hole.color = HOLE_COLOR
		add_child(hole)
		_holes.append(hole)

	_stat_label = Label.new()
	_stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stat_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_stat_label.position.y = -32
	add_child(_stat_label)

	call_deferred("_layout")

func _layout() -> void:
	var vp := get_viewport_rect().size
	var margin := 16.0
	var top_offset := 64.0
	var bottom_offset := 56.0
	var available_h: float = vp.y - top_offset - bottom_offset
	var hole_w: float = (vp.x - margin * (COLS + 1)) / float(COLS)
	var hole_h: float = (available_h - margin * (ROWS + 1)) / float(ROWS)

	for i in NUM_HOLES:
		var col: int = i % COLS
		@warning_ignore("integer_division")
		var row: int = i / COLS
		var x: float = margin + col * (hole_w + margin)
		var y: float = top_offset + margin + row * (hole_h + margin)
		_holes[i].position = Vector2(x, y)
		_holes[i].size = Vector2(hole_w, hole_h)

	_running = true
	_spawn_timer = _current_spawn_gap()

func _current_progress() -> float:
	return clamp(_elapsed / duration_max, 0.0, 1.0)

func _current_mole_up_time() -> float:
	return lerp(MOLE_UP_TIME, MOLE_UP_TIME_MIN, _current_progress())

func _current_spawn_gap() -> float:
	var progress: float = _current_progress()
	var lo: float = lerp(SPAWN_GAP_MIN, SPAWN_GAP_MIN_FLOOR, progress)
	var hi: float = lerp(SPAWN_GAP_MAX, SPAWN_GAP_MAX_FLOOR, progress)
	return rng.randf_range(lo, hi)

func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta

	if _active_hole == -1:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_mole()
	else:
		_mole_time_left -= delta
		if _mole_time_left <= 0.0:
			_hide_mole()

	_stat_label.text = "Topos: %d — %.1fs" % [_hit_count, max(duration_max - _elapsed, 0.0)]

	if _elapsed >= duration_max:
		_stop()

func _spawn_mole() -> void:
	_active_hole = rng.randi_range(0, NUM_HOLES - 1)
	_mole_time_left = _current_mole_up_time()
	_holes[_active_hole].color = MOLE_COLOR

func _hide_mole() -> void:
	if _active_hole != -1:
		_holes[_active_hole].color = HOLE_COLOR
	_active_hole = -1
	_spawn_timer = _current_spawn_gap()

func _input(event: InputEvent) -> void:
	if not _running or _active_hole == -1:
		return
	var pos := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
		pressed = true
	elif event is InputEventMouseButton and event.pressed:
		pos = event.position
		pressed = true
	if not pressed:
		return

	var hole: ColorRect = _holes[_active_hole]
	if Rect2(hole.position, hole.size).has_point(pos):
		_hit_count += 1
		_hide_mole()

func _stop() -> void:
	_running = false
	_info_label.text = "Topos cazados: %d" % _hit_count

	var timer := get_tree().create_timer(RESULT_DELAY)
	timer.timeout.connect(func(): _finish(float(_hit_count)))
