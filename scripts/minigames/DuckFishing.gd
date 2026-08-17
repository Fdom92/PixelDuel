extends MinigameBase
## Pesca de patos: estilo caseta de feria — los patos cruzan el río en
## horizontal por 3 carriles, cada uno a su velocidad y con su propio
## valor. Arrastra la red arriba/abajo para colocarte en el carril
## correcto justo cuando el pato pasa por el centro. Los patos dorados
## valen más pero van más rápido; los podridos restan si los pescas.
## Recolección acumulada: se suman los puntos de todos los participantes.

@export var duration_max := 12.0
const NUM_LANES := 3
const LANE_MARGIN_TOP := 66.0
const LANE_MARGIN_BOTTOM := 60.0
const SPAWN_INTERVAL := 0.7
const BASE_SPEED := 90.0 # px/s en horizontal
const SPEED_RAMP := 0.5 # +50% de velocidad al final de la prueba
const SPAWN_RAMP := 0.3 # -30% de intervalo entre patos al final
const NET_WIDTH := 30.0
const NET_HEIGHT := 24.0
const DUCK_SIZE := 22.0
const CATCH_X_TOLERANCE := 18.0 # margen extra sobre el ancho de la red
const WOBBLE_AMPLITUDE := 8.0
const WOBBLE_FREQ := 2.2
const RESULT_DELAY := 1.0

## Tipos de pato: value = puntos que da (o resta), weight = probabilidad
## relativa de aparecer, speed_mult = cuánto más rápido va (más valor,
## más difícil de pescar), size_mult = tamaño relativo en pantalla.
const DUCK_TIERS := [
	{"value": 1, "weight": 0.55, "color": Color(0.95, 0.85, 0.2), "speed_mult": 1.0, "size_mult": 1.0},
	{"value": 3, "weight": 0.25, "color": Color(0.95, 0.55, 0.15), "speed_mult": 1.2, "size_mult": 0.9},
	{"value": 5, "weight": 0.10, "color": Color(1.0, 0.84, 0.2), "speed_mult": 1.4, "size_mult": 0.8},
	{"value": -2, "weight": 0.10, "color": Color(0.3, 0.25, 0.15), "speed_mult": 1.0, "size_mult": 1.1},
]

var _net: ColorRect
var _info_label: Label
var _stat_label: Label
var _ducks: Array[Dictionary] = []

var _vp := Vector2.ZERO
var _band_top := 0.0
var _band_bottom := 0.0
var _net_x := 0.0
var _pointer_y := 0.0
var _pointer_down := false
var _elapsed := 0.0
var _spawn_timer := 0.0
var _caught_points := 0
var _running := false

func get_aggregation_type() -> String:
	return "collect_sum"

func get_unit_label() -> String:
	return "puntos"

func get_mechanic_category() -> String:
	return "arrastre"

func get_display_name() -> String:
	return "Pesca de patos"

func get_participant_count() -> int:
	return 1

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_info_label = Label.new()
	_info_label.text = "Arrastra la red arriba/abajo: los dorados valen más, ¡evita los podridos!"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_info_label.position.y = 12
	add_child(_info_label)

	_net = ColorRect.new()
	_net.color = Color(0.6, 0.4, 0.2)
	add_child(_net)

	_stat_label = Label.new()
	_stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stat_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_stat_label.position.y = -32
	add_child(_stat_label)

	call_deferred("_layout")

func _layout() -> void:
	_vp = get_viewport_rect().size
	_band_top = LANE_MARGIN_TOP
	_band_bottom = _vp.y - LANE_MARGIN_BOTTOM
	_net_x = _vp.x / 2.0
	_net.size = Vector2(NET_WIDTH, NET_HEIGHT)
	_net.position = Vector2(_net_x - NET_WIDTH / 2.0, (_band_top + _band_bottom) / 2.0 - NET_HEIGHT / 2.0)
	_running = true

func _lane_y(lane: int) -> float:
	var band_h: float = _band_bottom - _band_top
	return _band_top + band_h * (float(lane) + 0.5) / float(NUM_LANES)

func _pick_tier() -> Dictionary:
	var roll: float = rng.randf()
	var cumulative := 0.0
	for tier in DUCK_TIERS:
		cumulative += float(tier["weight"])
		if roll <= cumulative:
			return tier
	return DUCK_TIERS[0]

func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	var progress: float = clamp(_elapsed / duration_max, 0.0, 1.0)

	if _elapsed < duration_max:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = SPAWN_INTERVAL * (1.0 - progress * SPAWN_RAMP)
			_spawn_duck(progress)

	if _pointer_down:
		var net_center_y: float = clamp(_pointer_y, _band_top, _band_bottom)
		_net.position.y = net_center_y - NET_HEIGHT / 2.0

	var net_center := Vector2(_net_x, _net.position.y + NET_HEIGHT / 2.0)

	for i in range(_ducks.size() - 1, -1, -1):
		var duck: Dictionary = _ducks[i]
		var rect: ColorRect = duck["rect"]
		rect.position.x += float(duck["dir"]) * float(duck["speed"]) * delta
		var wobble: float = sin(_elapsed * WOBBLE_FREQ + float(duck["phase"])) * WOBBLE_AMPLITUDE
		var size: float = rect.size.x
		rect.position.y = float(duck["base_y"]) + wobble - size / 2.0

		var duck_center := Vector2(rect.position.x + size / 2.0, rect.position.y + size / 2.0)
		if abs(duck_center.x - net_center.x) <= CATCH_X_TOLERANCE and abs(duck_center.y - net_center.y) <= (NET_HEIGHT / 2.0 + size / 2.0):
			_caught_points = max(_caught_points + int(duck["value"]), 0)
			rect.queue_free()
			_ducks.remove_at(i)
			continue

		if rect.position.x < -size - 10.0 or rect.position.x > _vp.x + 10.0:
			rect.queue_free()
			_ducks.remove_at(i)

	_stat_label.text = "Puntos: %d — %ds" % [_caught_points, int(ceil(max(duration_max - _elapsed, 0.0)))]

	if _elapsed >= duration_max and _ducks.is_empty():
		_stop()
	elif _elapsed >= duration_max + 1.5:
		_stop()

func _spawn_duck(progress: float) -> void:
	var tier: Dictionary = _pick_tier()
	var lane: int = rng.randi_range(0, NUM_LANES - 1)
	var from_left: bool = rng.randf() < 0.5
	var speed: float = BASE_SPEED * float(tier["speed_mult"]) * (1.0 + progress * SPEED_RAMP)
	var size: float = DUCK_SIZE * float(tier["size_mult"])

	var duck := ColorRect.new()
	duck.color = tier["color"]
	duck.size = Vector2(size, size)
	duck.position.x = -size if from_left else _vp.x
	add_child(duck)

	_ducks.append({
		"rect": duck,
		"base_y": _lane_y(lane),
		"dir": 1 if from_left else -1,
		"speed": speed,
		"value": int(tier["value"]),
		"phase": rng.randf_range(0.0, TAU),
	})

func _input(event: InputEvent) -> void:
	if not _running:
		return
	if event is InputEventScreenTouch:
		_pointer_down = event.pressed
		if event.pressed:
			_pointer_y = event.position.y
	elif event is InputEventScreenDrag:
		_pointer_y = event.position.y
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer_down = event.pressed
		if event.pressed:
			_pointer_y = event.position.y
	elif event is InputEventMouseMotion and _pointer_down:
		_pointer_y = event.position.y

func _stop() -> void:
	_running = false
	for duck in _ducks:
		var rect: ColorRect = duck["rect"]
		rect.queue_free()
	_ducks.clear()

	_info_label.text = "Puntos pescados: %d" % _caught_points

	var timer := get_tree().create_timer(RESULT_DELAY)
	timer.timeout.connect(func(): _finish(float(_caught_points)))
