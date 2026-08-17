extends MinigameBase
## Cruzar el río de troncos: en vez de una barra de estabilidad, el tronco
## se mueve de verdad de un lado a otro del río — unos vienen de izquierda
## a derecha, otros al revés, cada uno más rápido que el anterior. Toca
## cuando el tronco esté sobre el punto de salto para cruzarlo. Inspirado
## en el Frogger clásico pero simplificado: cruzas un tronco detrás de
## otro (no varios carriles a la vez), y cada uno se juzga por separado
## — fallar uno no te elimina, solo no suma ese tronco.
## Recolección acumulada: se cuenta cuántos de los 5 troncos cruzas bien.

const NUM_LOGS := 5
const LOG_SPEED_BASE := 130.0
const LOG_SPEED_STEP := 20.0 # cada tronco va más rápido que el anterior
const LANDING_WINDOW := 20.0 # px de margen para que cuente el salto
const RESULT_DELAY := 0.6

var _log_rect: ColorRect
var _landing_marker: ColorRect
var _info_label: Label
var _progress_label: Label

var _vp := Vector2.ZERO
var _landing_x := 0.0
var _log_index := 0
var _log_x := 0.0
var _log_dir := 1
var _log_speed := 0.0
var _running := false
var _log_resolved := false
var _crossed_count := 0

func get_aggregation_type() -> String:
	return "collect_sum"

func get_unit_label() -> String:
	return "troncos"

func get_mechanic_category() -> String:
	return "timing_objetivo"

func get_display_name() -> String:
	return "Cruzar el río de troncos"

func get_participant_count() -> int:
	return 1

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_info_label = Label.new()
	_info_label.text = "Toca cuando el tronco esté sobre el punto de salto"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_info_label.position.y = 16
	add_child(_info_label)

	_landing_marker = ColorRect.new()
	_landing_marker.color = Color(0.9, 0.9, 0.2)
	add_child(_landing_marker)

	_log_rect = ColorRect.new()
	_log_rect.color = Color(0.5, 0.35, 0.2)
	add_child(_log_rect)

	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_progress_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_progress_label.position.y = -32
	add_child(_progress_label)

	call_deferred("_layout")

func _layout() -> void:
	_vp = get_viewport_rect().size
	_landing_x = _vp.x / 2.0
	_landing_marker.size = Vector2(4.0, _vp.y * 0.3)
	_landing_marker.position = Vector2(_landing_x - 2.0, _vp.y / 2.0 - _landing_marker.size.y / 2.0)
	_log_rect.size = Vector2(70.0, 40.0)
	_running = true
	_start_log()

func _start_log() -> void:
	_log_resolved = false
	var from_left: bool = _log_index % 2 == 0
	_log_dir = 1 if from_left else -1
	_log_x = -_log_rect.size.x if from_left else _vp.x
	_log_speed = LOG_SPEED_BASE + _log_index * LOG_SPEED_STEP + rng.randf_range(-10.0, 10.0)
	_log_rect.color = Color(0.5, 0.35, 0.2)
	_log_rect.position = Vector2(_log_x, _vp.y / 2.0 - _log_rect.size.y / 2.0)
	_progress_label.text = "Tronco %d / %d — cruzados: %d" % [_log_index + 1, NUM_LOGS, _crossed_count]

func _process(delta: float) -> void:
	if not _running or _log_resolved:
		return
	_log_x += _log_dir * _log_speed * delta
	_log_rect.position.x = _log_x

	var log_center_x: float = _log_x + _log_rect.size.x / 2.0
	if _log_dir == 1 and log_center_x > _vp.x + _log_rect.size.x:
		_resolve_log(false)
	elif _log_dir == -1 and log_center_x < -_log_rect.size.x:
		_resolve_log(false)

func _input(event: InputEvent) -> void:
	if not _running or _log_resolved:
		return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return

	var log_center_x: float = _log_x + _log_rect.size.x / 2.0
	_resolve_log(abs(log_center_x - _landing_x) <= LANDING_WINDOW)

func _resolve_log(success: bool) -> void:
	_log_resolved = true
	if success:
		_crossed_count += 1
		_log_rect.color = Color(0.3, 0.8, 0.3)
	else:
		_log_rect.color = Color(0.8, 0.2, 0.2)

	var timer := get_tree().create_timer(RESULT_DELAY)
	timer.timeout.connect(func():
		_log_index += 1
		if _log_index >= NUM_LOGS:
			_stop()
		else:
			_start_log()
	)

func _stop() -> void:
	_running = false
	_info_label.text = "Troncos cruzados: %d / %d" % [_crossed_count, NUM_LOGS]

	var timer := get_tree().create_timer(RESULT_DELAY)
	timer.timeout.connect(func(): _finish(float(_crossed_count)))
