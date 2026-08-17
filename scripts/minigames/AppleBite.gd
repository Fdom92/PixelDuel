extends MinigameBase
## Morder la manzana: la manzana se balancea sola de lado a lado. Toca
## justo cuando pase por el centro (la "boca") para darle un mordisco.
## Cada toque tiene un pequeño cooldown, así que no vale machacar sin
## parar — hay que cronometrar. Recolección acumulada: se suman los
## mordiscos de todos los participantes.

@export var duration_max := 12.0
const SWING_PERIOD := 1.6
const SUCCESS_WINDOW := 18.0
const TAP_COOLDOWN := 0.3
const RESULT_DELAY := 1.0

## Cada mordisco acierta más rápido y con menos margen: la manzana se
## balancea más deprisa y la ventana de acierto se va cerrando, hasta un
## mínimo, para que no valga solo con esperar cómodamente en el centro.
const SWING_PERIOD_MIN := 0.85
const WINDOW_MIN := 8.0
const DIFFICULTY_PERIOD_STEP := 0.09
const DIFFICULTY_WINDOW_STEP := 1.4

var _mouth_marker: ColorRect
var _apple: ColorRect
var _info_label: Label
var _stat_label: Label

var _vp := Vector2.ZERO
var _track_width := 0.0
var _elapsed := 0.0
var _cooldown_left := 0.0
var _bite_count := 0
var _running := false
var _phase := 0.0
var _angle := 0.0

func get_aggregation_type() -> String:
	return "collect_sum"

func get_unit_label() -> String:
	return "mordiscos"

func get_mechanic_category() -> String:
	return "timing_objetivo"

func get_display_name() -> String:
	return "Morder la manzana"

func get_participant_count() -> int:
	return 3

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_phase = rng.randf_range(0.0, TAU)

	_info_label = Label.new()
	_info_label.text = "Toca cuando la manzana pase por el centro"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_info_label.position.y = 16
	add_child(_info_label)

	_mouth_marker = ColorRect.new()
	_mouth_marker.color = Color(0.8, 0.3, 0.3)
	add_child(_mouth_marker)

	_apple = ColorRect.new()
	_apple.color = Color(0.8, 0.15, 0.15)
	add_child(_apple)

	_stat_label = Label.new()
	_stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stat_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_stat_label.position.y = -32
	add_child(_stat_label)

	call_deferred("_layout")

func _layout() -> void:
	_vp = get_viewport_rect().size
	_track_width = _vp.x - 64.0

	_mouth_marker.size = Vector2(10.0, 40.0)
	_mouth_marker.position = Vector2(_vp.x / 2.0 - 5.0, _vp.y / 2.0 - 20.0)

	_apple.size = Vector2(26.0, 26.0)
	_running = true

func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	_cooldown_left = max(_cooldown_left - delta, 0.0)

	_angle += (TAU / _current_swing_period()) * delta
	var offset: float = sin(_angle + _phase) * (_track_width / 2.0)
	var apple_center_x: float = _vp.x / 2.0 + offset
	_apple.position = Vector2(apple_center_x - _apple.size.x / 2.0, _vp.y / 2.0 - _apple.size.y / 2.0)

	_stat_label.text = "Mordiscos: %d — %.1fs" % [_bite_count, max(duration_max - _elapsed, 0.0)]

	if _elapsed >= duration_max:
		_stop()

func _input(event: InputEvent) -> void:
	if not _running:
		return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if not pressed or _cooldown_left > 0.0:
		return

	_cooldown_left = TAP_COOLDOWN
	var apple_center_x: float = _apple.position.x + _apple.size.x / 2.0
	var mouth_center_x: float = _mouth_marker.position.x + _mouth_marker.size.x / 2.0
	if abs(apple_center_x - mouth_center_x) <= _current_success_window():
		_bite_count += 1

func _current_swing_period() -> float:
	return max(SWING_PERIOD - _bite_count * DIFFICULTY_PERIOD_STEP, SWING_PERIOD_MIN)

func _current_success_window() -> float:
	return max(SUCCESS_WINDOW - _bite_count * DIFFICULTY_WINDOW_STEP, WINDOW_MIN)

func _stop() -> void:
	_running = false
	_info_label.text = "Mordiscos conseguidos: %d" % _bite_count

	var timer := get_tree().create_timer(RESULT_DELAY)
	timer.timeout.connect(func(): _finish(float(_bite_count)))
