extends MinigameBase
## Cuerda floja: el equilibrio se inclina solo a un lado u otro. Toca el
## lado de la pantalla OPUESTO a la inclinación para corregirla. Aguanta
## sin caerte hasta el final. Pasa/no pasa — el equipo suma cuántos
## participantes cruzan sin caerse.

@export var duration_max := 6.0
const PUSH_INTERVAL_MIN := 0.6
const PUSH_INTERVAL_MAX := 1.1
## Con el ritmo/fuerza anteriores, un par de empujones seguidos en la misma
## dirección casi nunca llegaban al fallo — se podía "cruzar" sin tocar la
## pantalla. Con esto, no corregir durante 2-3 empujones sí que te tira.
const PUSH_RATE := 46.0 # inclinación por segundo mientras empuja
const NUDGE := 18.0 # corrección por toque
const FAIL_THRESHOLD := 100.0
const RESULT_DELAY := 0.8

var _left_zone: ColorRect
var _right_zone: ColorRect
var _bar_bg: ColorRect
var _bar_marker: ColorRect
var _info_label: Label
var _time_label: Label

var _lean := 0.0
var _push_direction := 1
var _push_timer := 0.5
var _elapsed := 0.0
var _running := false

func get_aggregation_type() -> String:
	return "success_count"

func get_mechanic_category() -> String:
	return "equilibrio"

func get_display_name() -> String:
	return "Cuerda floja"

func get_participant_count() -> int:
	return 1

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_left_zone = ColorRect.new()
	_left_zone.color = Color(0.2, 0.25, 0.35)
	_left_zone.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_left_zone.anchor_right = 0.5
	add_child(_left_zone)

	_right_zone = ColorRect.new()
	_right_zone.color = Color(0.35, 0.25, 0.2)
	_right_zone.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_right_zone.anchor_left = 0.5
	add_child(_right_zone)

	_info_label = Label.new()
	_info_label.text = "Toca el lado OPUESTO a la inclinación para no caerte"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_info_label.position.y = 16
	add_child(_info_label)

	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.1, 0.1, 0.15)
	add_child(_bar_bg)

	_bar_marker = ColorRect.new()
	_bar_marker.color = Color(0.2, 0.9, 0.3)
	_bar_bg.add_child(_bar_marker)

	_time_label = Label.new()
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_time_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_time_label.position.y = -32
	add_child(_time_label)

	call_deferred("_layout")

func _layout() -> void:
	var vp := get_viewport_rect().size
	_bar_bg.position = Vector2(24.0, vp.y * 0.35)
	_bar_bg.size = Vector2(vp.x - 48.0, 20.0)
	_bar_marker.size = Vector2(10.0, 20.0)
	_update_marker()
	_running = true

func _update_marker() -> void:
	var ratio: float = (_lean + FAIL_THRESHOLD) / (FAIL_THRESHOLD * 2.0)
	ratio = clamp(ratio, 0.0, 1.0)
	_bar_marker.position.x = ratio * (_bar_bg.size.x - _bar_marker.size.x)
	var danger: float = clamp(abs(_lean) / FAIL_THRESHOLD, 0.0, 1.0)
	_bar_marker.color = Color(0.2, 0.9, 0.3).lerp(Color(0.9, 0.2, 0.2), danger)

func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	_push_timer -= delta
	if _push_timer <= 0.0:
		_push_timer = rng.randf_range(PUSH_INTERVAL_MIN, PUSH_INTERVAL_MAX)
		_push_direction = -1 if rng.randf() < 0.5 else 1

	_lean = clamp(_lean + _push_direction * PUSH_RATE * delta, -140.0, 140.0)
	_update_marker()
	_time_label.text = "%ds" % int(ceil(max(duration_max - _elapsed, 0.0)))

	if abs(_lean) >= FAIL_THRESHOLD:
		_resolve(false)
	elif _elapsed >= duration_max:
		_resolve(true)

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
	if pos.x < size.x / 2.0:
		_lean -= NUDGE
	else:
		_lean += NUDGE
	_lean = clamp(_lean, -140.0, 140.0)
	_update_marker()

func _resolve(success: bool) -> void:
	_running = false
	_info_label.text = "¡Cruzas la cuerda!" if success else "¡Te caes!"

	var timer := get_tree().create_timer(RESULT_DELAY)
	timer.timeout.connect(func(): _finish(1.0 if success else 0.0))
