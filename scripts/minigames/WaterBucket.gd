extends MinigameBase
## Transporte del cubo de agua: el cubo se tambalea cada vez más con el
## tiempo. Toca "Estabilizar" para bajarlo, pero tiene un cooldown: tocar
## demasiado (spam) no sirve de nada. Puntúa por mantener el tambaleo bajo
## de media durante toda la prueba.

@export var duration_max := 12.0
const WOBBLE_RISE_RATE := 11.0 # por segundo
const STABILIZE_AMOUNT := 22.0
## Estabilizar cuando el cubo casi ni se mueve lo desestabiliza en vez de
## ayudar (te pasas de fuerza y se derrama) — evita que machacar sin mirar
## la barra sea la estrategia óptima.
const OVERCORRECT_THRESHOLD := 32.0
const OVERCORRECT_PENALTY := 16.0
const COOLDOWN := 0.8
const RESULT_DELAY := 1.0

var _bar_bg: ColorRect
var _bar_fill: ColorRect
var _info_label: Label
var _status_label: Label

var _vp := Vector2.ZERO
var _wobble := 0.0
var _cooldown_left := 0.0
var _elapsed := 0.0
var _wobble_accum := 0.0
var _running := false

func get_aggregation_type() -> String:
	return "average"

func get_mechanic_category() -> String:
	return "equilibrio"

func get_display_name() -> String:
	return "Transporte del cubo de agua"

func get_participant_count() -> int:
	return 3

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_info_label = Label.new()
	_info_label.text = "Toca solo cuando tambalee mucho — corregir de más también desestabiliza"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_info_label.position.y = 16
	add_child(_info_label)

	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.15, 0.15, 0.2)
	add_child(_bar_bg)

	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.2, 0.8, 0.3)
	_bar_bg.add_child(_bar_fill)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_status_label.position.y = -32
	add_child(_status_label)

	call_deferred("_layout")

func _layout() -> void:
	_vp = get_viewport_rect().size
	_bar_bg.position = Vector2(24.0, _vp.y / 2.0 - 12.0)
	_bar_bg.size = Vector2(_vp.x - 48.0, 24.0)
	_bar_fill.position = Vector2.ZERO
	_bar_fill.size = Vector2(0.0, 24.0)
	_running = true

func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	_cooldown_left = max(_cooldown_left - delta, 0.0)

	_wobble = clamp(_wobble + WOBBLE_RISE_RATE * delta, 0.0, 100.0)
	_wobble_accum += _wobble * delta

	var bar_width: float = _bar_bg.size.x
	_bar_fill.size.x = bar_width * _wobble / 100.0
	_bar_fill.color = Color(0.2, 0.8, 0.3).lerp(Color(0.9, 0.2, 0.2), _wobble / 100.0)

	_status_label.text = "%s — %.1fs" % [
		("Listo" if _cooldown_left <= 0.0 else "Espera..."), max(duration_max - _elapsed, 0.0)
	]

	if _elapsed >= duration_max:
		_stop()

func _input(event: InputEvent) -> void:
	if not _running:
		return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return
	if _cooldown_left <= 0.0:
		if _wobble >= OVERCORRECT_THRESHOLD:
			_wobble = max(_wobble - STABILIZE_AMOUNT, 0.0)
		else:
			_wobble = min(_wobble + OVERCORRECT_PENALTY, 100.0)
		_cooldown_left = COOLDOWN

func _stop() -> void:
	_running = false
	var avg_wobble: float = _wobble_accum / duration_max
	var score: float = clamp(100.0 - avg_wobble, 0.0, 100.0)
	_info_label.text = "Puntos: %d" % int(round(score))

	var timer := get_tree().create_timer(RESULT_DELAY)
	timer.timeout.connect(func(): _finish(score))
