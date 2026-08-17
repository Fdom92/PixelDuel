extends MinigameBase
## Bolos: haz un swipe hacia arriba para lanzar la bola. Los bolos están en
## triángulo, como en los bolos de verdad — la punta más cerca de la bola,
## la fila del fondo más lejos. Cuánto derribas depende de dónde apunta el
## swipe (deriva horizontal del gesto) y de la potencia: más potencia =
## radio de impacto más grande, como una reacción en cadena de verdad.
## Recolección acumulada: se suman los bolos derribados por todos los
## participantes.

const PIN_ROWS := [1, 2, 3, 4] # de la punta (cerca de la bola) al fondo
const NUM_PINS := 10
const MIN_POWER_RATIO := 0.35
const RESULT_DELAY := 1.0
const KNOCK_RADIUS_BASE := 34.0 # radio de impacto a potencia mínima
const KNOCK_RADIUS_MAX := 130.0 # radio de impacto a máxima potencia

var _ball: ColorRect
var _pins: Array[ColorRect] = []
var _info_label: Label

var _start_pos := Vector2.ZERO
var _dragging := false
var _done := false
var _apex_y := 0.0

func get_aggregation_type() -> String:
	return "collect_sum"

func get_unit_label() -> String:
	return "bolos"

func get_mechanic_category() -> String:
	return "swipe"

func get_display_name() -> String:
	return "Bolos"

func get_participant_count() -> int:
	return 4

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_info_label = Label.new()
	_info_label.text = "Desliza hacia arriba para lanzar, apunta con la deriva"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_info_label.position.y = 16
	add_child(_info_label)

	for i in NUM_PINS:
		var pin := ColorRect.new()
		pin.color = Color(0.85, 0.85, 0.8)
		pin.size = Vector2(16.0, 22.0)
		add_child(pin)
		_pins.append(pin)

	_ball = ColorRect.new()
	_ball.color = Color(0.3, 0.3, 0.35)
	_ball.size = Vector2(24.0, 24.0)
	add_child(_ball)

	call_deferred("_layout")

func _layout() -> void:
	var vp := get_viewport_rect().size
	var spacing_x := 26.0
	var spacing_y := 26.0
	var start_y := 56.0
	var num_rows := PIN_ROWS.size()

	var pin_index := 0
	for row_i in num_rows:
		var row_count: int = PIN_ROWS[row_i]
		# row_i = 0 es la punta, más cerca de la bola (abajo); las filas
		# siguientes se alejan hacia arriba de la pantalla.
		var row_y: float = start_y + (num_rows - 1 - row_i) * spacing_y
		var row_width: float = (row_count - 1) * spacing_x
		for c in row_count:
			var x: float = vp.x / 2.0 - row_width / 2.0 + c * spacing_x - _pins[pin_index].size.x / 2.0
			_pins[pin_index].position = Vector2(x, row_y)
			pin_index += 1

	_apex_y = start_y + (num_rows - 1) * spacing_y
	_ball.position = Vector2(vp.x / 2.0 - _ball.size.x / 2.0, vp.y - 64.0)

func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			_start_pos = event.position
			_dragging = true
			_ball.position = event.position - _ball.size / 2.0
		elif _dragging:
			_dragging = false
			_on_release(event.position)
	elif _dragging and (event is InputEventScreenDrag or event is InputEventMouseMotion):
		_ball.position = event.position - _ball.size / 2.0

func _on_release(end_pos: Vector2) -> void:
	_done = true
	var vector: Vector2 = _start_pos - end_pos # y positivo = hacia arriba

	var vp := get_viewport_rect().size
	var max_swipe: float = vp.y * 0.6
	var power_ratio: float = clamp(vector.length() / max_swipe, 0.0, 1.0)

	var knocked := 0
	if power_ratio >= MIN_POWER_RATIO:
		var aim_x: float = vp.x / 2.0 + vector.x
		var impact_radius: float = lerp(KNOCK_RADIUS_BASE, KNOCK_RADIUS_MAX, power_ratio)
		var impact_point := Vector2(aim_x, _apex_y)
		for pin in _pins:
			var pin_center: Vector2 = pin.position + pin.size / 2.0
			if pin_center.distance_to(impact_point) <= impact_radius:
				pin.color = Color(0.35, 0.32, 0.3)
				knocked += 1

	_info_label.text = "Bolos derribados: %d" % knocked

	var timer := get_tree().create_timer(RESULT_DELAY)
	timer.timeout.connect(func(): _finish(float(knocked)))
