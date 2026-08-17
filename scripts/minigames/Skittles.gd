extends MinigameBase
## Bolos: haz un swipe hacia arriba para lanzar la bola. Cuanto más recto
## (vertical) el gesto, más bolos derribas; si no llega con suficiente
## fuerza, la bola se queda corta. Recolección acumulada: se suman los
## bolos derribados por todos los participantes.

const NUM_PINS := 9
const PIN_COLS := 3
const MIN_POWER_RATIO := 0.35
const ANGLE_TOLERANCE := 35.0
const RESULT_DELAY := 1.0

var _ball: ColorRect
var _pins: Array[ColorRect] = []
var _info_label: Label

var _start_pos := Vector2.ZERO
var _dragging := false
var _done := false

func get_aggregation_type() -> String:
	return "collect_sum"

func get_unit_label() -> String:
	return "bolos"

func get_mechanic_category() -> String:
	return "swipe"

func get_display_name() -> String:
	return "Bolos"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_info_label = Label.new()
	_info_label.text = "Desliza hacia arriba, lo más recto posible"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_info_label.position.y = 16
	add_child(_info_label)

	for i in NUM_PINS:
		var pin := ColorRect.new()
		pin.color = Color(0.85, 0.85, 0.8)
		pin.size = Vector2(18.0, 26.0)
		add_child(pin)
		_pins.append(pin)

	_ball = ColorRect.new()
	_ball.color = Color(0.3, 0.3, 0.35)
	_ball.size = Vector2(24.0, 24.0)
	add_child(_ball)

	call_deferred("_layout")

func _layout() -> void:
	var vp := get_viewport_rect().size
	var spacing_x := 36.0
	var spacing_y := 32.0
	var start_y := 60.0
	for i in NUM_PINS:
		var col: int = i % PIN_COLS
		@warning_ignore("integer_division")
		var row: int = i / PIN_COLS
		var row_count: int = min(PIN_COLS, NUM_PINS - row * PIN_COLS)
		var row_width: float = (row_count - 1) * spacing_x
		var x: float = vp.x / 2.0 - row_width / 2.0 + col * spacing_x - _pins[i].size.x / 2.0
		var y: float = start_y + row * spacing_y
		_pins[i].position = Vector2(x, y)

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
	var magnitude: float = vector.length()

	var vp := get_viewport_rect().size
	var max_swipe: float = vp.y * 0.6
	var power_ratio: float = clamp(magnitude / max_swipe, 0.0, 1.0)

	var knocked := 0
	if power_ratio >= MIN_POWER_RATIO:
		var degrees: float = rad_to_deg(atan2(vector.y, vector.x))
		var accuracy: float = clamp(100.0 - abs(degrees - 90.0) / ANGLE_TOLERANCE * 100.0, 0.0, 100.0)
		knocked = int(round(NUM_PINS * accuracy / 100.0))

	for i in knocked:
		_pins[i].color = Color(0.35, 0.32, 0.3)

	_info_label.text = "Bolos derribados: %d" % knocked

	var timer := get_tree().create_timer(RESULT_DELAY)
	timer.timeout.connect(func(): _finish(float(knocked)))
