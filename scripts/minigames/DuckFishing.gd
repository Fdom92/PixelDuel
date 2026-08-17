extends MinigameBase
## Pesca de patos: arrastra la cesta para atrapar los patos que caen.
## Recolección acumulada — el equipo suma los patos atrapados por todos
## sus participantes.

@export var duration_max := 8.0
const SPAWN_INTERVAL := 0.8
const FALL_SPEED := 160.0
const BASKET_WIDTH := 56.0
const BASKET_HEIGHT := 18.0
const DUCK_SIZE := 20.0
const RESULT_DELAY := 1.0

## La lluvia de patos se acelera con el tiempo (más rápido y más seguido),
## y una parte son patos "malos" que restan si los atrapas — barrer la
## cesta de un lado a otro sin mirar deja de ser gratis.
const SPEED_RAMP := 0.6 # +60% de velocidad de caída al final de la prueba
const SPAWN_RAMP := 0.4 # -40% de intervalo entre patos al final
const BAD_DUCK_CHANCE := 0.25

var _basket: ColorRect
var _info_label: Label
var _stat_label: Label
var _ducks: Array[Dictionary] = []

var _vp := Vector2.ZERO
var _elapsed := 0.0
var _spawn_timer := 0.0
var _caught := 0
var _spawned := 0
var _running := false
var _pointer_down := false
var _pointer_x := 0.0

func get_aggregation_type() -> String:
	return "collect_sum"

func get_unit_label() -> String:
	return "patos"

func get_mechanic_category() -> String:
	return "arrastre"

func get_display_name() -> String:
	return "Pesca de patos"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_info_label = Label.new()
	_info_label.text = "Atrapa los patos amarillos — ¡evita los oscuros, restan!"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_info_label.position.y = 16
	add_child(_info_label)

	_basket = ColorRect.new()
	_basket.color = Color(0.6, 0.4, 0.2)
	add_child(_basket)

	_stat_label = Label.new()
	_stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stat_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_stat_label.position.y = -32
	add_child(_stat_label)

	call_deferred("_layout")

func _layout() -> void:
	_vp = get_viewport_rect().size
	_basket.size = Vector2(BASKET_WIDTH, BASKET_HEIGHT)
	_basket.position = Vector2(_vp.x / 2.0 - BASKET_WIDTH / 2.0, _vp.y - 40.0)
	_running = true

func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta

	var progress: float = clamp(_elapsed / duration_max, 0.0, 1.0)
	var speed: float = FALL_SPEED * (1.0 + progress * SPEED_RAMP)

	if _elapsed < duration_max:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = SPAWN_INTERVAL * (1.0 - progress * SPAWN_RAMP)
			_spawn_duck()

	if _pointer_down:
		_basket.position.x = clamp(_pointer_x - BASKET_WIDTH / 2.0, 0.0, _vp.x - BASKET_WIDTH)

	for i in range(_ducks.size() - 1, -1, -1):
		var duck: Dictionary = _ducks[i]
		var rect: ColorRect = duck["rect"]
		rect.position.y += speed * delta
		if rect.position.y + DUCK_SIZE >= _basket.position.y:
			var duck_center_x: float = rect.position.x + DUCK_SIZE / 2.0
			if duck_center_x >= _basket.position.x and duck_center_x <= _basket.position.x + BASKET_WIDTH:
				if duck["bad"]:
					_caught = max(_caught - 1, 0)
				else:
					_caught += 1
			rect.queue_free()
			_ducks.remove_at(i)

	_stat_label.text = "Atrapados: %d / %d — %.1fs" % [_caught, _spawned, max(duration_max - _elapsed, 0.0)]

	if _elapsed >= duration_max:
		_stop()

func _spawn_duck() -> void:
	var is_bad: bool = rng.randf() < BAD_DUCK_CHANCE
	var duck := ColorRect.new()
	duck.color = Color(0.25, 0.2, 0.15) if is_bad else Color(0.95, 0.85, 0.2)
	duck.size = Vector2(DUCK_SIZE, DUCK_SIZE)
	duck.position = Vector2(rng.randf_range(0.0, _vp.x - DUCK_SIZE), 0.0)
	add_child(duck)
	_ducks.append({"rect": duck, "bad": is_bad})
	_spawned += 1

func _input(event: InputEvent) -> void:
	if not _running:
		return
	if event is InputEventScreenTouch:
		_pointer_down = event.pressed
		if event.pressed:
			_pointer_x = event.position.x
	elif event is InputEventScreenDrag:
		_pointer_x = event.position.x
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer_down = event.pressed
		if event.pressed:
			_pointer_x = event.position.x
	elif event is InputEventMouseMotion and _pointer_down:
		_pointer_x = event.position.x

func _stop() -> void:
	_running = false
	for duck in _ducks:
		var rect: ColorRect = duck["rect"]
		rect.queue_free()
	_ducks.clear()

	_info_label.text = "Patos atrapados: %d" % _caught

	var timer := get_tree().create_timer(RESULT_DELAY)
	timer.timeout.connect(func(): _finish(float(_caught)))
