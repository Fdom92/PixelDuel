extends MinigameBase
## Carrera de obstáculos: corres hacia la derecha y los obstáculos se te
## acercan desde el otro lado, cada uno un poco más rápido que el
## anterior. Haz un swipe hacia arriba (saltar de verdad, no solo tocar)
## justo cuando lleguen a tu altura. Si fallas uno —por mal timing o por
## un swipe flojo/torcido— tropiezas y se acaba el intento ahí; hay que
## encadenarlos todos para que cuente como éxito. Pasa/no pasa — el
## equipo suma cuántos participantes lo consiguen.

const NUM_OBSTACLES := 5
const BASE_SPEED := 150.0
const SPEED_STEP := 18.0
const SUCCESS_WINDOW := 26.0 # px de margen alrededor de la línea para contar como salto válido
const MISS_MARGIN := 60.0
const MIN_SWIPE_DISTANCE := 36.0 # swipes más cortos no cuentan como salto
const ANGLE_TOLERANCE := 40.0 # grados de margen respecto a 90 (recto hacia arriba)
const RESULT_DELAY := 0.8

var _runner: ColorRect
var _obstacle: ColorRect
var _hit_line: ColorRect
var _info_label: Label
var _progress_label: Label

var _vp := Vector2.ZERO
var _hit_line_x := 0.0
var _ground_y := 0.0
var _obstacle_index := 0
var _obstacle_x := 0.0
var _speed := 0.0
var _start_pos := Vector2.ZERO
var _dragging := false
var _running := false

func get_aggregation_type() -> String:
	return "success_count"

func get_mechanic_category() -> String:
	return "swipe"

func get_display_name() -> String:
	return "Carrera de obstáculos"

func get_participant_count() -> int:
	return 1

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_info_label = Label.new()
	_info_label.text = "¡Swipe hacia arriba justo cuando el obstáculo llegue a ti!"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_info_label.position.y = 16
	add_child(_info_label)

	_hit_line = ColorRect.new()
	_hit_line.color = Color(0.9, 0.9, 0.2)
	add_child(_hit_line)

	_runner = ColorRect.new()
	_runner.color = Color(0.3, 0.6, 0.9)
	add_child(_runner)

	_obstacle = ColorRect.new()
	_obstacle.color = Color(0.8, 0.3, 0.3)
	add_child(_obstacle)

	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_progress_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_progress_label.position.y = -32
	add_child(_progress_label)

	call_deferred("_layout")

func _layout() -> void:
	_vp = get_viewport_rect().size
	_hit_line_x = _vp.x * 0.25
	_ground_y = _vp.y * 0.6
	_hit_line.position = Vector2(_hit_line_x - 2.0, 0.0)
	_hit_line.size = Vector2(4.0, _vp.y)
	_runner.size = Vector2(24.0, 28.0)
	_runner.position = Vector2(_hit_line_x - _runner.size.x / 2.0, _ground_y - _runner.size.y / 2.0)
	_obstacle.size = Vector2(28.0, 28.0)
	_running = true
	_start_obstacle()

func _start_obstacle() -> void:
	_obstacle_x = _vp.x
	_speed = BASE_SPEED + _obstacle_index * SPEED_STEP + rng.randf_range(-15.0, 15.0)
	_obstacle.position = Vector2(_obstacle_x, _ground_y - _obstacle.size.y / 2.0)
	_progress_label.text = "Obstáculo %d / %d" % [_obstacle_index + 1, NUM_OBSTACLES]

func _process(delta: float) -> void:
	if not _running:
		return
	_obstacle_x -= _speed * delta
	_obstacle.position.x = _obstacle_x

	if _obstacle_x < _hit_line_x - MISS_MARGIN:
		_fail()

func _input(event: InputEvent) -> void:
	if not _running:
		return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			_start_pos = event.position
			_dragging = true
		elif _dragging:
			_dragging = false
			_on_swipe_released(event.position)

func _on_swipe_released(end_pos: Vector2) -> void:
	var vector: Vector2 = _start_pos - end_pos # y positivo = hacia arriba
	var valid_swipe := vector.length() >= MIN_SWIPE_DISTANCE
	if valid_swipe:
		var degrees: float = rad_to_deg(atan2(vector.y, vector.x))
		valid_swipe = abs(degrees - 90.0) <= ANGLE_TOLERANCE

	var timing_ok: bool = abs(_obstacle_x - _hit_line_x) <= SUCCESS_WINDOW

	if valid_swipe and timing_ok:
		_advance()
	else:
		_fail()

func _advance() -> void:
	_obstacle_index += 1
	if _obstacle_index >= NUM_OBSTACLES:
		_succeed()
	else:
		_start_obstacle()

func _succeed() -> void:
	_running = false
	_info_label.text = "¡Superas la carrera!"

	var timer := get_tree().create_timer(RESULT_DELAY)
	timer.timeout.connect(func(): _finish(1.0))

func _fail() -> void:
	_running = false
	_info_label.text = "¡Tropiezas! (obstáculo %d/%d)" % [_obstacle_index + 1, NUM_OBSTACLES]

	var timer := get_tree().create_timer(RESULT_DELAY)
	timer.timeout.connect(func(): _finish(0.0))
