extends MinigameBase
## Carrera de sacos: alternar toques entre la zona izquierda y derecha lo
## más rápido posible durante un tiempo fijo. Puntúa por nº de alternancias.

@export var duration_max := 12.0
const TARGET_ALTERNATIONS := 58.0 # ritmo objetivo sin cambiar (~4.8 alternancias/s) a la duración nueva
const RESULT_DELAY := 1.0

var _left_zone: ColorRect
var _right_zone: ColorRect
var _count_label: Label
var _time_label: Label
var _info_label: Label

var _time_left := 0.0
var _last_side := 0 # 0 = ninguno, -1 = izquierda, 1 = derecha
var _count := 0
var _running := true

func get_aggregation_type() -> String:
	return "average"

func get_mechanic_category() -> String:
	return "spam_toques"

func get_display_name() -> String:
	return "Carrera de sacos"

func get_participant_count() -> int:
	return 3

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_time_left = duration_max

	_info_label = Label.new()
	_info_label.text = "¡Alterna izquierda / derecha lo más rápido posible!"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_info_label.position.y = 16
	add_child(_info_label)

	_left_zone = ColorRect.new()
	_left_zone.color = Color(0.2, 0.35, 0.7)
	_left_zone.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_left_zone.anchor_right = 0.5
	add_child(_left_zone)

	_right_zone = ColorRect.new()
	_right_zone.color = Color(0.7, 0.35, 0.2)
	_right_zone.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_right_zone.anchor_left = 0.5
	add_child(_right_zone)

	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.set_anchors_preset(Control.PRESET_CENTER)
	_count_label.add_theme_font_size_override("font_size", 28)
	add_child(_count_label)

	_time_label = Label.new()
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_time_label.position.y = -32
	add_child(_time_label)

	_update_labels()

func _process(delta: float) -> void:
	if not _running:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_time_left = 0.0
		_update_labels()
		_stop()
		return
	_update_labels()

func _update_labels() -> void:
	_count_label.text = "%d" % _count
	_time_label.text = "%.1fs" % _time_left

func _input(event: InputEvent) -> void:
	if not _running:
		return
	var pos := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
		pressed = true
	elif event is InputEventMouseButton and event.pressed:
		pos = event.position
		pressed = true
	if not pressed:
		return
	var side := -1 if pos.x < size.x / 2.0 else 1
	if side != _last_side:
		_last_side = side
		_count += 1
		_update_labels()

func _stop() -> void:
	_running = false
	var score: float = clamp(_count / TARGET_ALTERNATIONS * 100.0, 0.0, 100.0)
	_info_label.text = "Puntos: %d" % int(round(score))

	var timer := get_tree().create_timer(RESULT_DELAY)
	timer.timeout.connect(func(): _finish(score))
