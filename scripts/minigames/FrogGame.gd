extends MinigameBase
## La rana: mantén pulsado para cargar el indicador (oscila solo a lo
## largo del tablero) y suelta sobre la zona que quieras. La boca vale
## más pero es estrecha; los bordes valen menos pero son fáciles.

const CHARGE_SPEED := 150.0
const RESULT_DELAY := 1.0

var _bar: ColorRect
var _marker: ColorRect
var _info_label: Label

var _bar_width := 0.0
var _power := 0.0
var _direction := 1
var _charging := false
var _fired := false

func get_aggregation_type() -> String:
	return "best"

func get_mechanic_category() -> String:
	return "carga_suelta"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_info_label = Label.new()
	_info_label.text = "Mantén pulsado para cargar, suelta sobre el tablero"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_info_label.position.y = 16
	add_child(_info_label)

	_bar = ColorRect.new()
	_bar.color = Color(0.15, 0.15, 0.2)
	add_child(_bar)

	# Zonas del tablero, de fuera hacia el centro: resto(5) - puente(10) - molino(25) - boca(50) - molino(25) - puente(10) - resto(5)
	var zone_specs := [
		{"value": 5, "width": 0.15, "color": Color(0.5, 0.5, 0.55)},
		{"value": 10, "width": 0.15, "color": Color(0.35, 0.55, 0.35)},
		{"value": 25, "width": 0.15, "color": Color(0.25, 0.65, 0.3)},
		{"value": 50, "width": 0.1, "color": Color(0.15, 0.8, 0.25)},
		{"value": 25, "width": 0.15, "color": Color(0.25, 0.65, 0.3)},
		{"value": 10, "width": 0.15, "color": Color(0.35, 0.55, 0.35)},
		{"value": 5, "width": 0.15, "color": Color(0.5, 0.5, 0.55)},
	]
	for spec in zone_specs:
		var zone := ColorRect.new()
		zone.color = spec["color"]
		_bar.add_child(zone)

	_marker = ColorRect.new()
	_marker.color = Color(0.9, 0.9, 0.2)
	_bar.add_child(_marker)

	call_deferred("_layout", zone_specs)

func _layout(zone_specs: Array) -> void:
	var vp := get_viewport_rect().size
	_bar_width = vp.x - 48.0
	_bar.position = Vector2(24.0, vp.y / 2.0 - 12.0)
	_bar.size = Vector2(_bar_width, 24.0)

	var x := 0.0
	for i in zone_specs.size():
		var zone: ColorRect = _bar.get_child(i)
		var w: float = _bar_width * zone_specs[i]["width"]
		zone.position = Vector2(x, 0.0)
		zone.size = Vector2(w, 24.0)
		x += w

	_marker.size = Vector2(6.0, 24.0)
	_marker.position = Vector2(0.0, 0.0)

func _process(delta: float) -> void:
	if _fired or not _charging or _bar_width <= 0.0:
		return
	_power += CHARGE_SPEED * _direction * delta
	if _power >= 100.0:
		_power = 100.0
		_direction = -1
	elif _power <= 0.0:
		_power = 0.0
		_direction = 1
	_marker.position.x = _bar_width * _power / 100.0

func _unhandled_input(event: InputEvent) -> void:
	if _fired:
		return
	var pressed_now: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	var released_now: bool = (event is InputEventScreenTouch and not event.pressed) \
		or (event is InputEventMouseButton and not event.pressed)
	if pressed_now and not _charging:
		_charging = true
	elif released_now and _charging:
		_fire()

func _fire() -> void:
	_fired = true
	_charging = false
	var dist_from_center: float = abs(_power - 50.0)
	var score := 5.0
	if dist_from_center <= 5.0:
		score = 50.0
	elif dist_from_center <= 20.0:
		score = 25.0
	elif dist_from_center <= 35.0:
		score = 10.0
	_info_label.text = "Puntos: %d" % int(score)

	var timer := get_tree().create_timer(RESULT_DELAY)
	timer.timeout.connect(func(): _finish(score))
