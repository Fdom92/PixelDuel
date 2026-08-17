extends MinigameBase
## Huevo en la cuchara: arrastra la cuchara para mantenerla bajo el huevo,
## que se mueve solo. Puntúa según qué tan cerca la mantengas, de media.

@export var duration_max := 6.0
const TRACK_MARGIN := 24.0
const TRACK_HEIGHT := 24.0
const SPOON_WIDTH := 16.0
const EGG_RADIUS := 8.0
const RESULT_DELAY := 1.0

var _track: ColorRect
var _egg: ColorRect
var _spoon: ColorRect
var _info_label: Label
var _time_label: Label

var _track_width := 0.0
var _spoon_x := 0.0
var _elapsed := 0.0
var _error_accum := 0.0
var _running := true
var _pointer_down := false
var _pointer_x := 0.0
var _phase_a := 0.0
var _phase_b := 0.0

func get_aggregation_type() -> String:
	return "average"

func get_mechanic_category() -> String:
	return "arrastre"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_phase_a = rng.randf_range(0.0, TAU)
	_phase_b = rng.randf_range(0.0, TAU)

	_info_label = Label.new()
	_info_label.text = "Arrastra la cuchara para seguir al huevo"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_info_label.position.y = 16
	add_child(_info_label)

	_track = ColorRect.new()
	_track.color = Color(0.15, 0.15, 0.2)
	add_child(_track)

	_spoon = ColorRect.new()
	_spoon.color = Color(0.6, 0.4, 0.2)
	_track.add_child(_spoon)

	_egg = ColorRect.new()
	_egg.color = Color(0.95, 0.9, 0.7)
	_track.add_child(_egg)

	_time_label = Label.new()
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_time_label.position.y = -32
	add_child(_time_label)

	call_deferred("_layout")

func _layout() -> void:
	var vp := get_viewport_rect().size
	_track_width = vp.x - TRACK_MARGIN * 2.0
	_track.position = Vector2(TRACK_MARGIN, vp.y / 2.0 - TRACK_HEIGHT / 2.0)
	_track.size = Vector2(_track_width, TRACK_HEIGHT)

	_spoon.size = Vector2(SPOON_WIDTH, TRACK_HEIGHT)
	_spoon_x = _track_width / 2.0
	_spoon.position = Vector2(_spoon_x - SPOON_WIDTH / 2.0, 0.0)

	_egg.size = Vector2(EGG_RADIUS * 2.0, EGG_RADIUS * 2.0)

func _process(delta: float) -> void:
	if not _running or _track_width <= 0.0:
		return

	_elapsed += delta
	var target_x := _current_target_x()
	_egg.position = Vector2(target_x - EGG_RADIUS, TRACK_HEIGHT / 2.0 - EGG_RADIUS)

	if _pointer_down:
		var local_x: float = _pointer_x - _track.global_position.x
		_spoon_x = clamp(local_x, SPOON_WIDTH / 2.0, _track_width - SPOON_WIDTH / 2.0)
		_spoon.position.x = _spoon_x - SPOON_WIDTH / 2.0

	_error_accum += abs(_spoon_x - target_x) * delta
	_time_label.text = "%.1fs" % max(duration_max - _elapsed, 0.0)

	if _elapsed >= duration_max:
		_stop()

func _current_target_x() -> float:
	var base: float = _track_width / 2.0
	var amp: float = _track_width / 2.0 - EGG_RADIUS - 4.0
	return base + amp * sin(_elapsed * 0.9 + _phase_a) * 0.6 + amp * sin(_elapsed * 1.7 + _phase_b) * 0.4

func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	if event is InputEventScreenTouch:
		_pointer_down = event.pressed
		if event.pressed:
			_pointer_x = event.position.x
	elif event is InputEventScreenDrag:
		_pointer_x = event.position.x
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer_down = event.pressed
		if event.pressed:
			_pointer_x = event.position.x
	elif event is InputEventMouseMotion and _pointer_down:
		_pointer_x = event.position.x

func _stop() -> void:
	_running = false
	var avg_error: float = _error_accum / duration_max
	var half_width: float = _track_width / 2.0
	var score: float = clamp(100.0 - (avg_error / half_width) * 100.0, 0.0, 100.0)
	_info_label.text = "Puntos: %d" % int(round(score))

	var timer := get_tree().create_timer(RESULT_DELAY)
	timer.timeout.connect(func(): _finish(score))
