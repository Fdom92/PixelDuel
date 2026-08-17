extends MinigameBase
## La cucaña: toca sin parar para trepar por el palo engrasado — si dejas
## de tocar, resbalas hacia abajo. Recoge todos los premios que puedas
## antes de que se acabe el tiempo. Recolección acumulada — el equipo
## suma los premios cogidos por todos sus participantes.

@export var duration_max := 12.0
const CLIMB_PER_TAP := 12.0
const SLIDE_BACK_RATE := 11.0
## Cerca de la cima el palo resbala mucho más (más grasa/cansancio) — los
## primeros premios son fáciles, el de arriba exige tocar sin parar de verdad.
const SLIDE_BACK_HEIGHT_FACTOR := 3.0
const PRIZE_COUNT := 5
const RESULT_DELAY := 0.8

var _pole_track: ColorRect
var _climber: ColorRect
var _prizes: Array[ColorRect] = []
var _prize_collected: Array[bool] = []
var _info_label: Label
var _time_label: Label

var _vp := Vector2.ZERO
var _margin_top := 60.0
var _track_height := 0.0
var _height := 0.0
var _elapsed := 0.0
var _collected_count := 0
var _running := false

func get_aggregation_type() -> String:
	return "collect_sum"

func get_unit_label() -> String:
	return "premios"

func get_mechanic_category() -> String:
	return "spam_toques"

func get_display_name() -> String:
	return "La cucaña"

func get_participant_count() -> int:
	return 1

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_info_label = Label.new()
	_info_label.text = "¡Toca sin parar para trepar y coger premios!"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_info_label.position.y = 16
	add_child(_info_label)

	_pole_track = ColorRect.new()
	_pole_track.color = Color(0.4, 0.3, 0.15)
	add_child(_pole_track)

	_climber = ColorRect.new()
	_climber.color = Color(0.9, 0.5, 0.2)
	add_child(_climber)

	_time_label = Label.new()
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_time_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_time_label.position.y = -32
	add_child(_time_label)

	call_deferred("_layout")

func _layout() -> void:
	_vp = get_viewport_rect().size
	var track_w := 30.0
	var margin_bottom := 60.0
	_track_height = _vp.y - _margin_top - margin_bottom
	_pole_track.position = Vector2(_vp.x / 2.0 - track_w / 2.0, _margin_top)
	_pole_track.size = Vector2(track_w, _track_height)

	_climber.size = Vector2(24.0, 24.0)

	for i in PRIZE_COUNT:
		var prize := ColorRect.new()
		prize.color = Color(0.95, 0.8, 0.2)
		prize.size = Vector2(20.0, 10.0)
		var frac: float = float(i + 1) / float(PRIZE_COUNT)
		var y: float = _margin_top + _track_height * (1.0 - frac) - prize.size.y / 2.0
		prize.position = Vector2(_vp.x / 2.0 + track_w / 2.0 + 6.0, y)
		add_child(prize)
		_prizes.append(prize)
		_prize_collected.append(false)

	_running = true
	_update_climber()

func _update_climber() -> void:
	var y: float = _margin_top + _track_height - _height
	_climber.position = Vector2(_vp.x / 2.0 - _climber.size.x / 2.0, y - _climber.size.y / 2.0)

func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	var height_frac: float = _height / _track_height if _track_height > 0.0 else 0.0
	var slide_rate: float = SLIDE_BACK_RATE * (1.0 + height_frac * height_frac * SLIDE_BACK_HEIGHT_FACTOR)
	_height = clamp(_height - slide_rate * delta, 0.0, _track_height)
	_check_prizes()
	_update_climber()
	_time_label.text = "Premios: %d — %ds" % [_collected_count, int(ceil(max(duration_max - _elapsed, 0.0)))]

	if _elapsed >= duration_max or _height >= _track_height:
		_stop()

func _input(event: InputEvent) -> void:
	if not _running:
		return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if pressed:
		_height = clamp(_height + CLIMB_PER_TAP, 0.0, _track_height)
		_check_prizes()
		_update_climber()

func _check_prizes() -> void:
	for i in PRIZE_COUNT:
		if _prize_collected[i]:
			continue
		var frac: float = float(i + 1) / float(PRIZE_COUNT)
		if _height >= _track_height * frac:
			_prize_collected[i] = true
			_collected_count += 1
			_prizes[i].color = Color(0.3, 0.3, 0.3)

func _stop() -> void:
	_running = false
	_info_label.text = "Premios cogidos: %d" % _collected_count

	var timer := get_tree().create_timer(RESULT_DELAY)
	timer.timeout.connect(func(): _finish(float(_collected_count)))
