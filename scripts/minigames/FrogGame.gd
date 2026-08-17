extends MinigameBase
## La rana: desliza hacia arriba para lanzar la rana de un salto — cuanto
## más fuerte el gesto, más lejos llega. La boca del tablero (centro) vale
## más pero es estrecha; los bordes valen menos pero son fáciles de tocar.
## El salto se anima con un arco (simula la gravedad) para que se note
## que la potencia del gesto determina dónde cae.

const RESULT_DELAY := 1.0
const MAX_SWIPE_FRACTION := 0.5 # fracción de la altura de pantalla = potencia máxima
const JUMP_DURATION := 0.55
const JUMP_HEIGHT := 40.0

var _bar: ColorRect
var _marker: ColorRect
var _info_label: Label

var _bar_width := 0.0
var _start_pos := Vector2.ZERO
var _dragging := false
var _fired := false
var _jumping := false
var _jump_t := 0.0
var _jump_start_x := 0.0
var _jump_target_x := 0.0

func get_aggregation_type() -> String:
	return "best"

func get_mechanic_category() -> String:
	return "swipe"

func get_display_name() -> String:
	return "La rana"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_info_label = Label.new()
	_info_label.text = "Desliza hacia arriba: más fuerte, más lejos salta"
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
	_jump_start_x = _bar_width / 2.0
	_marker.position = Vector2(_jump_start_x - _marker.size.x / 2.0, 0.0)

func _process(delta: float) -> void:
	if not _jumping:
		return
	_jump_t += delta
	var t: float = clamp(_jump_t / JUMP_DURATION, 0.0, 1.0)
	var x: float = lerp(_jump_start_x, _jump_target_x, t)
	var arc: float = sin(t * PI) * JUMP_HEIGHT # sube y cae, como si la gravedad tirase de ella
	_marker.position = Vector2(x - _marker.size.x / 2.0, -arc)
	if t >= 1.0:
		_jumping = false
		_marker.position.y = 0.0
		_resolve_landing()

func _input(event: InputEvent) -> void:
	if _fired:
		return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			_start_pos = event.position
			_dragging = true
		elif _dragging:
			_dragging = false
			_launch(event.position)

func _launch(end_pos: Vector2) -> void:
	_fired = true
	var vp := get_viewport_rect().size
	var swipe_up: float = _start_pos.y - end_pos.y # positivo si desliza hacia arriba
	var max_swipe: float = vp.y * MAX_SWIPE_FRACTION
	var power: float = clamp(swipe_up / max_swipe, 0.0, 1.0) * 100.0

	_jump_target_x = _bar_width * power / 100.0
	_jump_t = 0.0
	_jumping = true
	_info_label.text = "¡Salta!"

func _resolve_landing() -> void:
	var power: float = _jump_target_x / _bar_width * 100.0
	var dist_from_center: float = abs(power - 50.0)
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
