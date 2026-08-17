extends MinigameBase
## Cruzar el río de troncos: una fila de troncos seguidos. Cada uno pasa
## de inestable (rojo) a estable (verde) y vuelve a hundirse — toca
## cuando esté lo bastante verde para cruzarlo. Si fallas uno te caes y
## se acaba el intento ahí; hay que encadenar todos para que cuente como
## éxito. Pasa/no pasa — el equipo suma cuántos participantes cruzan.

const NUM_LOGS := 5
const LOG_DURATION_MIN := 1.5
const LOG_DURATION_MAX := 2.5
const SUCCESS_THRESHOLD := 60.0 # estabilidad mínima (0-100) para cruzar bien
const RESULT_DELAY := 0.8

## Cada tronco es un poco más exigente que el anterior: sube el umbral de
## estabilidad y se acorta el tiempo en que el tronco está lo bastante
## verde, así que el último tronco exige un timing casi perfecto.
const THRESHOLD_STEP := 5.0
const DURATION_SHRINK_STEP := 0.15
const DURATION_MIN_FLOOR := 1.0

var _log_rect: ColorRect
var _info_label: Label
var _progress_label: Label

var _log_index := 0
var _log_duration := 0.0
var _t := 0.0
var _running := false
var _tap_requested := false

func get_aggregation_type() -> String:
	return "success_count"

func get_mechanic_category() -> String:
	return "timing_objetivo"

func get_display_name() -> String:
	return "Cruzar el río de troncos"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_info_label = Label.new()
	_info_label.text = "Toca cuando el tronco esté más verde (más estable)"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_info_label.position.y = 16
	add_child(_info_label)

	_log_rect = ColorRect.new()
	_log_rect.color = Color(1.0, 0.2, 0.2)
	add_child(_log_rect)

	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_progress_label.position.y = -32
	add_child(_progress_label)

	call_deferred("_layout")

func _layout() -> void:
	var vp := get_viewport_rect().size
	_log_rect.size = Vector2(80.0, 50.0)
	_log_rect.position = Vector2(vp.x / 2.0 - 40.0, vp.y / 2.0 - 25.0)
	_running = true
	_start_log()

func _start_log() -> void:
	_t = 0.0
	var shrink: float = _log_index * DURATION_SHRINK_STEP
	var lo: float = max(LOG_DURATION_MIN - shrink, DURATION_MIN_FLOOR)
	var hi: float = max(LOG_DURATION_MAX - shrink, DURATION_MIN_FLOOR + 0.3)
	_log_duration = rng.randf_range(lo, hi)
	_progress_label.text = "Tronco %d / %d" % [_log_index + 1, NUM_LOGS]

func _current_threshold() -> float:
	return min(SUCCESS_THRESHOLD + _log_index * THRESHOLD_STEP, 92.0)

func _process(delta: float) -> void:
	if not _running:
		return
	_t += delta
	var stability: float = 100.0 * sin(PI * clamp(_t / _log_duration, 0.0, 1.0))
	_log_rect.color = Color(1.0, 0.2, 0.2).lerp(Color(0.2, 0.9, 0.3), stability / 100.0)

	if _tap_requested:
		_tap_requested = false
		if stability >= _current_threshold():
			_advance()
		else:
			_fail()
	elif _t >= _log_duration:
		_fail()

func _input(event: InputEvent) -> void:
	if not _running:
		return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if pressed:
		_tap_requested = true

func _advance() -> void:
	_log_index += 1
	if _log_index >= NUM_LOGS:
		_succeed()
	else:
		_start_log()

func _succeed() -> void:
	_running = false
	_info_label.text = "¡Cruzas el río!"

	var timer := get_tree().create_timer(RESULT_DELAY)
	timer.timeout.connect(func(): _finish(1.0))

func _fail() -> void:
	_running = false
	_info_label.text = "¡Te caes al río! (tronco %d/%d)" % [_log_index + 1, NUM_LOGS]

	var timer := get_tree().create_timer(RESULT_DELAY)
	timer.timeout.connect(func(): _finish(0.0))
