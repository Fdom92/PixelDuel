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

var _basket: ColorRect
var _info_label: Label
var _stat_label: Label
var _ducks: Array[ColorRect] = []

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
	_info_label.text = "Arrastra la cesta para atrapar los patos"
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

	if _elapsed < duration_max:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = SPAWN_INTERVAL
			_spawn_duck()

	if _pointer_down:
		_basket.position.x = clamp(_pointer_x - BASKET_WIDTH / 2.0, 0.0, _vp.x - BASKET_WIDTH)

	for i in range(_ducks.size() - 1, -1, -1):
		var duck := _ducks[i]
		duck.position.y += FALL_SPEED * delta
		if duck.position.y + DUCK_SIZE >= _basket.position.y:
			var duck_center_x: float = duck.position.x + DUCK_SIZE / 2.0
			if duck_center_x >= _basket.position.x and duck_center_x <= _basket.position.x + BASKET_WIDTH:
				_caught += 1
			duck.queue_free()
			_ducks.remove_at(i)

	_stat_label.text = "Atrapados: %d / %d — %.1fs" % [_caught, _spawned, max(duration_max - _elapsed, 0.0)]

	if _elapsed >= duration_max:
		_stop()

func _spawn_duck() -> void:
	var duck := ColorRect.new()
	duck.color = Color(0.95, 0.85, 0.2)
	duck.size = Vector2(DUCK_SIZE, DUCK_SIZE)
	duck.position = Vector2(rng.randf_range(0.0, _vp.x - DUCK_SIZE), 0.0)
	add_child(duck)
	_ducks.append(duck)
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
		duck.queue_free()
	_ducks.clear()

	_info_label.text = "Patos atrapados: %d" % _caught

	var timer := get_tree().create_timer(RESULT_DELAY)
	timer.timeout.connect(func(): _finish(float(_caught)))
