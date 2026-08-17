extends MinigameBase
## Máquina de baile: las notas caen por 4 carriles hacia la línea de
## abajo — toca el carril correcto justo cuando la nota la cruza. A
## diferencia de Memoria de banderines (memorizar y repetir después),
## aquí lees y reaccionas en varios carriles a la vez, en directo.
## Recolección acumulada: se suman las notas acertadas por todos los
## participantes.

@export var duration_max := 8.0
const NUM_LANES := 4
const NOTE_SPEED := 220.0
const HIT_LINE_Y_FRAC := 0.78
const HIT_WINDOW := 24.0
const SPAWN_INTERVAL := 0.55
const RESULT_DELAY := 1.0

var _lane_colors: Array[Color] = [
	Color(0.8, 0.2, 0.2),
	Color(0.2, 0.4, 0.8),
	Color(0.9, 0.8, 0.2),
	Color(0.2, 0.7, 0.3),
]

var _lanes: Array[ColorRect] = []
var _hit_line: ColorRect
var _info_label: Label
var _stat_label: Label
var _notes: Array[Dictionary] = []

var _vp := Vector2.ZERO
var _lane_w := 0.0
var _hit_line_y := 0.0
var _spawn_timer := 0.4
var _elapsed := 0.0
var _hit_count := 0
var _running := false

func get_aggregation_type() -> String:
	return "collect_sum"

func get_unit_label() -> String:
	return "notas"

func get_mechanic_category() -> String:
	return "ritmo"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_info_label = Label.new()
	_info_label.text = "¡Toca el carril justo cuando la nota cruce la línea!"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_info_label.position.y = 16
	add_child(_info_label)

	for i in NUM_LANES:
		var lane := ColorRect.new()
		lane.color = _lane_colors[i].darkened(0.75)
		add_child(lane)
		_lanes.append(lane)

	_hit_line = ColorRect.new()
	_hit_line.color = Color(0.9, 0.9, 0.9)
	add_child(_hit_line)

	_stat_label = Label.new()
	_stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stat_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_stat_label.position.y = -32
	add_child(_stat_label)

	call_deferred("_layout")

func _layout() -> void:
	_vp = get_viewport_rect().size
	_lane_w = _vp.x / float(NUM_LANES)
	_hit_line_y = _vp.y * HIT_LINE_Y_FRAC

	for i in NUM_LANES:
		_lanes[i].position = Vector2(_lane_w * i, 0.0)
		_lanes[i].size = Vector2(_lane_w - 3.0, _vp.y)

	_hit_line.position = Vector2(0.0, _hit_line_y - 2.0)
	_hit_line.size = Vector2(_vp.x, 4.0)

	_running = true

func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta

	if _elapsed < duration_max:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = SPAWN_INTERVAL
			_spawn_note()

	for i in range(_notes.size() - 1, -1, -1):
		var note: Dictionary = _notes[i]
		var rect: ColorRect = note["rect"]
		rect.position.y += NOTE_SPEED * delta
		if rect.position.y > _vp.y:
			rect.queue_free()
			_notes.remove_at(i)

	_stat_label.text = "Notas: %d — %.1fs" % [_hit_count, max(duration_max - _elapsed, 0.0)]

	if _elapsed >= duration_max and _notes.is_empty():
		_stop()

func _spawn_note() -> void:
	var lane: int = rng.randi_range(0, NUM_LANES - 1)
	var note := ColorRect.new()
	note.color = _lane_colors[lane]
	note.size = Vector2(_lane_w - 16.0, 20.0)
	note.position = Vector2(lane * _lane_w + 8.0, -20.0)
	add_child(note)
	_notes.append({"rect": note, "lane": lane})

func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	var pos := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
		pressed = true
	elif event is InputEventMouseButton and event.pressed:
		pos = event.position
		pressed = true
	if not pressed or size.x <= 0.0:
		return

	var lane: int = clamp(int(pos.x / _lane_w), 0, NUM_LANES - 1)
	for i in range(_notes.size() - 1, -1, -1):
		var note: Dictionary = _notes[i]
		if note["lane"] != lane:
			continue
		var rect: ColorRect = note["rect"]
		if abs(rect.position.y - _hit_line_y) <= HIT_WINDOW:
			_hit_count += 1
			rect.queue_free()
			_notes.remove_at(i)
			return

func _stop() -> void:
	_running = false
	_info_label.text = "Notas acertadas: %d" % _hit_count

	var timer := get_tree().create_timer(RESULT_DELAY)
	timer.timeout.connect(func(): _finish(float(_hit_count)))
