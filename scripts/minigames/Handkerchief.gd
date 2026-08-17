extends MinigameBase
## El pañuelo: espera la señal sin tocar. En cuanto aparezca, toca lo
## antes posible. Si tocas antes de tiempo, falsa salida y puntúas 0.

const MIN_DELAY := 1.2
const MAX_DELAY := 3.2
const MAX_REACTION_MS := 700.0
const RESULT_DELAY := 1.0

var _cue_rect: ColorRect
var _info_label: Label

var _state := "waiting" # "waiting" -> "go" -> "done"
var _go_time_ms := 0

func get_aggregation_type() -> String:
	return "best"

func get_mechanic_category() -> String:
	return "reaccion"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_info_label = Label.new()
	_info_label.text = "Espera la señal... ¡no toques antes de tiempo!"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_info_label.position.y = 16
	add_child(_info_label)

	_cue_rect = ColorRect.new()
	_cue_rect.color = Color(0.4, 0.4, 0.45)
	add_child(_cue_rect)

	call_deferred("_layout")

	var delay: float = rng.randf_range(MIN_DELAY, MAX_DELAY)
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(_on_cue)

func _layout() -> void:
	var vp := get_viewport_rect().size
	_cue_rect.size = Vector2(140.0, 140.0)
	_cue_rect.position = Vector2(vp.x / 2.0 - 70.0, vp.y / 2.0 - 70.0)

func _on_cue() -> void:
	if _state != "waiting":
		return
	_state = "go"
	_go_time_ms = Time.get_ticks_msec()
	_cue_rect.color = Color(0.9, 0.85, 0.2)
	_info_label.text = "¡YA! ¡Toca!"

func _unhandled_input(event: InputEvent) -> void:
	if _state == "done":
		return
	var pressed := (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return

	if _state == "waiting":
		_finish_with(0.0, "¡Demasiado pronto! (falsa salida)")
	elif _state == "go":
		var reaction_ms: float = float(Time.get_ticks_msec() - _go_time_ms)
		var score: float = clamp(100.0 - (reaction_ms / MAX_REACTION_MS) * 100.0, 0.0, 100.0)
		_finish_with(score, "¡Cogido en %d ms! Puntos: %d" % [int(reaction_ms), int(round(score))])

func _finish_with(score: float, message: String) -> void:
	_state = "done"
	_info_label.text = message

	var timer := get_tree().create_timer(RESULT_DELAY)
	timer.timeout.connect(func(): _finish(score))
