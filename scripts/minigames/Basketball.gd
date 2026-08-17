extends MinigameBase
## Canastas: mantén pulsado para cargar potencia (oscila sola) y suelta
## para tirar. Si aciertas en el aro, cuenta como canasta y sale otro tiro
## enseguida — encesta tantas veces como puedas antes de que se acabe el
## tiempo. El aro cambia de sitio en cada tiro. Recolección acumulada: se
## suman las canastas de todos los participantes.

@export var duration_max := 7.0
const CHARGE_SPEED := 150.0
const HOOP_WIDTH := 18.0 # en unidades de potencia (0-100)
const HOOP_MARGIN := 12.0 # no pegado a los bordes de la barra
const RESULT_DELAY := 1.0

var _bar: ColorRect
var _hoop_zone: ColorRect
var _marker: ColorRect
var _info_label: Label
var _stat_label: Label

var _bar_width := 0.0
var _power := 0.0
var _direction := 1
var _charging := false
var _elapsed := 0.0
var _made_count := 0
var _hoop_center := 50.0
var _running := false

func get_aggregation_type() -> String:
	return "collect_sum"

func get_unit_label() -> String:
	return "canastas"

func get_mechanic_category() -> String:
	return "carga_suelta"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_info_label = Label.new()
	_info_label.text = "Mantén pulsado para cargar, suelta para tirar a canasta"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_info_label.position.y = 16
	add_child(_info_label)

	_bar = ColorRect.new()
	_bar.color = Color(0.15, 0.15, 0.2)
	add_child(_bar)

	_hoop_zone = ColorRect.new()
	_hoop_zone.color = Color(0.9, 0.5, 0.1)
	_bar.add_child(_hoop_zone)

	_marker = ColorRect.new()
	_marker.color = Color(0.9, 0.9, 0.2)
	_bar.add_child(_marker)

	_stat_label = Label.new()
	_stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stat_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_stat_label.position.y = -32
	add_child(_stat_label)

	call_deferred("_layout")

func _layout() -> void:
	var vp := get_viewport_rect().size
	_bar_width = vp.x - 48.0
	_bar.position = Vector2(24.0, vp.y / 2.0 - 12.0)
	_bar.size = Vector2(_bar_width, 24.0)

	_marker.size = Vector2(6.0, 24.0)
	_hoop_zone.size = Vector2(_bar_width * HOOP_WIDTH / 100.0, 24.0)

	_running = true
	_start_new_shot()

func _start_new_shot() -> void:
	_power = 0.0
	_direction = 1
	_charging = false
	_hoop_center = rng.randf_range(HOOP_MARGIN + HOOP_WIDTH / 2.0, 100.0 - HOOP_MARGIN - HOOP_WIDTH / 2.0)
	_hoop_zone.position.x = _bar_width * _hoop_center / 100.0 - _hoop_zone.size.x / 2.0
	_marker.position.x = 0.0

func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	_stat_label.text = "Canastas: %d — %.1fs" % [_made_count, max(duration_max - _elapsed, 0.0)]

	if _elapsed >= duration_max:
		_stop()
		return

	if _charging:
		_power += CHARGE_SPEED * _direction * delta
		if _power >= 100.0:
			_power = 100.0
			_direction = -1
		elif _power <= 0.0:
			_power = 0.0
			_direction = 1
		_marker.position.x = _bar_width * _power / 100.0

func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	var pressed_now: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	var released_now: bool = (event is InputEventScreenTouch and not event.pressed) \
		or (event is InputEventMouseButton and not event.pressed)
	if pressed_now and not _charging:
		_charging = true
	elif released_now and _charging:
		_resolve_shot()

func _resolve_shot() -> void:
	_charging = false
	if abs(_power - _hoop_center) <= HOOP_WIDTH / 2.0:
		_made_count += 1
	if _running:
		_start_new_shot()

func _stop() -> void:
	_running = false
	_info_label.text = "Canastas encestadas: %d" % _made_count

	var timer := get_tree().create_timer(RESULT_DELAY)
	timer.timeout.connect(func(): _finish(float(_made_count)))
