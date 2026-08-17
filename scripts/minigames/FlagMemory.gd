extends MinigameBase
## Memoria de banderines: repite la secuencia de colores que se enciende,
## que crece una posición cada ronda. Puntúa por rondas completadas.

const NUM_FLAGS := 4
const MAX_ROUNDS := 8
const SHOW_DELAY := 0.5
const GAP_DELAY := 0.2
const RESULT_DELAY := 1.0

var _base_colors: Array[Color] = [
	Color(0.8, 0.2, 0.2),
	Color(0.2, 0.4, 0.8),
	Color(0.9, 0.8, 0.2),
	Color(0.2, 0.7, 0.3),
]

var _zones: Array[ColorRect] = []
var _info_label: Label

var _sequence: Array[int] = []
var _input_index := 0
var _round_completed := 0
var _accepting_input := false
var _done := false

func get_aggregation_type() -> String:
	return "average"

func get_mechanic_category() -> String:
	return "memoria"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_info_label = Label.new()
	_info_label.text = "Memoriza la secuencia de banderines"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_info_label.position.y = 16
	add_child(_info_label)

	for i in NUM_FLAGS:
		var zone := ColorRect.new()
		zone.color = _base_colors[i]
		add_child(zone)
		_zones.append(zone)

	call_deferred("_layout")
	_start_round()

func _layout() -> void:
	var vp := get_viewport_rect().size
	var zone_w: float = vp.x / float(NUM_FLAGS)
	var zone_h := 80.0
	for i in NUM_FLAGS:
		_zones[i].position = Vector2(zone_w * i, vp.y / 2.0 - zone_h / 2.0)
		_zones[i].size = Vector2(zone_w - 4.0, zone_h)

func _start_round() -> void:
	_sequence.append(rng.randi_range(0, NUM_FLAGS - 1))
	_input_index = 0
	_accepting_input = false
	_info_label.text = "Ronda %d / %d" % [_sequence.size(), MAX_ROUNDS]
	_play_sequence()

func _play_sequence() -> void:
	for idx in _sequence:
		_set_highlight(idx, true)
		await get_tree().create_timer(SHOW_DELAY).timeout
		_set_highlight(idx, false)
		await get_tree().create_timer(GAP_DELAY).timeout
	if not _done:
		_accepting_input = true

func _set_highlight(idx: int, on: bool) -> void:
	var base: Color = _base_colors[idx]
	_zones[idx].color = base.lightened(0.5) if on else base

func _unhandled_input(event: InputEvent) -> void:
	if not _accepting_input or _done:
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
	var idx: int = clamp(int(pos.x / (size.x / float(NUM_FLAGS))), 0, NUM_FLAGS - 1)
	_on_flag_tapped(idx)

func _on_flag_tapped(idx: int) -> void:
	_set_highlight(idx, true)
	get_tree().create_timer(0.15).timeout.connect(func(): _set_highlight(idx, false))

	if idx != _sequence[_input_index]:
		_stop(_round_completed / float(MAX_ROUNDS) * 100.0)
		return

	_input_index += 1
	if _input_index >= _sequence.size():
		_round_completed += 1
		_accepting_input = false
		if _round_completed >= MAX_ROUNDS:
			_stop(100.0)
		else:
			await get_tree().create_timer(SHOW_DELAY).timeout
			_start_round()

func _stop(score: float) -> void:
	_done = true
	_accepting_input = false
	_info_label.text = "Puntos: %d" % int(round(score))

	var timer := get_tree().create_timer(RESULT_DELAY)
	timer.timeout.connect(func(): _finish(score))
