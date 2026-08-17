extends MinigameBase
## Petaco: carga y suelta para lanzar la bola. Una vez en juego, mantén
## pulsado el lado izquierdo/derecho de la pantalla para levantar ese
## flipper y golpear la bola antes de que caiga por el hueco central.
## Cada tope que golpeas suma puntos. Es la única prueba con física de
## rebote de verdad — todas las demás son temporizador + input.
## Recolección acumulada: se suman los puntos de todos los participantes.

@export var duration_max := 14.0
const GRAVITY := 520.0
const BALL_RADIUS := 8.0
const WALL_BOUNCE_DAMPING := 0.85
const LAUNCH_CHARGE_SPEED := 150.0
const LAUNCH_MAX_SPEED := 420.0
const FLIP_Y_STRENGTH := 380.0
const FLIP_X_STRENGTH := 140.0
const BUMPER_RADIUS := 20.0
const BUMPER_MIN_BOUNCE_SPEED := 260.0
const BUMPER_COOLDOWN := 0.15
const FLIPPER_ZONE_HEIGHT := 34.0
const RESULT_DELAY := 1.0

var _ball: ColorRect
var _left_flipper: ColorRect
var _right_flipper: ColorRect
var _launch_bar: ColorRect
var _launch_marker: ColorRect
var _info_label: Label
var _stat_label: Label
var _bumpers: Array[Dictionary] = []

var _vp := Vector2.ZERO
var _flipper_y := 0.0
var _ball_pos := Vector2.ZERO
var _ball_vel := Vector2.ZERO
var _state := "launching" # "launching" -> "playing" -> "done"
var _charging := false
var _power := 0.0
var _direction := 1
var _active_touches := {} # index (o -1 para ratón) -> "left"/"right"
var _left_held := false
var _right_held := false
var _score := 0
var _elapsed := 0.0

func get_aggregation_type() -> String:
	return "collect_sum"

func get_unit_label() -> String:
	return "puntos"

func get_mechanic_category() -> String:
	return "flippers"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_info_label = Label.new()
	_info_label.text = "Carga y suelta para lanzar la bola"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_info_label.position.y = 16
	add_child(_info_label)

	for points in [10, 10, 20]:
		var bumper := ColorRect.new()
		bumper.color = Color(0.7, 0.2, 0.7)
		add_child(bumper)
		_bumpers.append({"node": bumper, "pos": Vector2.ZERO, "points": points, "cooldown": 0.0})

	_left_flipper = ColorRect.new()
	_left_flipper.color = Color(0.3, 0.5, 0.8)
	add_child(_left_flipper)

	_right_flipper = ColorRect.new()
	_right_flipper.color = Color(0.3, 0.5, 0.8)
	add_child(_right_flipper)

	_ball = ColorRect.new()
	_ball.color = Color(0.95, 0.95, 0.9)
	_ball.size = Vector2(BALL_RADIUS * 2.0, BALL_RADIUS * 2.0)
	add_child(_ball)

	_launch_bar = ColorRect.new()
	_launch_bar.color = Color(0.15, 0.15, 0.2)
	add_child(_launch_bar)

	_launch_marker = ColorRect.new()
	_launch_marker.color = Color(0.9, 0.9, 0.2)
	_launch_bar.add_child(_launch_marker)

	_stat_label = Label.new()
	_stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stat_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_stat_label.position.y = -32
	add_child(_stat_label)

	call_deferred("_layout")

func _layout() -> void:
	_vp = get_viewport_rect().size
	_flipper_y = _vp.y - FLIPPER_ZONE_HEIGHT

	var bumper_defs := [
		Vector2(_vp.x * 0.3, _vp.y * 0.22),
		Vector2(_vp.x * 0.7, _vp.y * 0.22),
		Vector2(_vp.x * 0.5, _vp.y * 0.38),
	]
	for i in _bumpers.size():
		_bumpers[i]["pos"] = bumper_defs[i]
		var node: ColorRect = _bumpers[i]["node"]
		node.size = Vector2(BUMPER_RADIUS * 2.0, BUMPER_RADIUS * 2.0)
		node.position = bumper_defs[i] - node.size / 2.0

	_left_flipper.size = Vector2(_vp.x * 0.5 - 4.0, 10.0)
	_left_flipper.position = Vector2(0.0, _flipper_y)
	_right_flipper.size = Vector2(_vp.x * 0.5 - 4.0, 10.0)
	_right_flipper.position = Vector2(_vp.x * 0.5 + 4.0, _flipper_y)

	_launch_bar.position = Vector2(24.0, _vp.y - 56.0)
	_launch_bar.size = Vector2(_vp.x - 48.0, 16.0)
	_launch_marker.size = Vector2(6.0, 16.0)

	_ball_pos = Vector2(_vp.x / 2.0, _flipper_y - BALL_RADIUS - 4.0)
	_update_ball_visual()

func _process(delta: float) -> void:
	if _state == "done":
		return
	_elapsed += delta
	if _elapsed >= duration_max:
		_finish_run()
		return

	if _state == "launching":
		if _charging:
			_power += LAUNCH_CHARGE_SPEED * _direction * delta
			if _power >= 100.0:
				_power = 100.0
				_direction = -1
			elif _power <= 0.0:
				_power = 0.0
				_direction = 1
			_launch_marker.position.x = _launch_bar.size.x * _power / 100.0
	elif _state == "playing":
		_update_physics(delta)

	_stat_label.text = "Puntos: %d — %.1fs" % [_score, max(duration_max - _elapsed, 0.0)]

func _update_physics(delta: float) -> void:
	_ball_vel.y += GRAVITY * delta
	_ball_pos += _ball_vel * delta

	if _ball_pos.x < BALL_RADIUS:
		_ball_pos.x = BALL_RADIUS
		_ball_vel.x = abs(_ball_vel.x) * WALL_BOUNCE_DAMPING
	elif _ball_pos.x > _vp.x - BALL_RADIUS:
		_ball_pos.x = _vp.x - BALL_RADIUS
		_ball_vel.x = -abs(_ball_vel.x) * WALL_BOUNCE_DAMPING
	if _ball_pos.y < BALL_RADIUS:
		_ball_pos.y = BALL_RADIUS
		_ball_vel.y = abs(_ball_vel.y) * WALL_BOUNCE_DAMPING

	for bumper in _bumpers:
		bumper["cooldown"] = max(0.0, float(bumper["cooldown"]) - delta)
		if bumper["cooldown"] > 0.0:
			continue
		var to_ball: Vector2 = _ball_pos - bumper["pos"]
		var dist: float = to_ball.length()
		if dist < BUMPER_RADIUS + BALL_RADIUS:
			var normal: Vector2 = to_ball.normalized() if dist > 0.001 else Vector2.UP
			_ball_pos = bumper["pos"] + normal * (BUMPER_RADIUS + BALL_RADIUS + 1.0)
			var speed: float = max(_ball_vel.length(), BUMPER_MIN_BOUNCE_SPEED)
			_ball_vel = normal * speed
			_score += int(bumper["points"])
			bumper["cooldown"] = BUMPER_COOLDOWN

	if _ball_pos.y >= _flipper_y - BALL_RADIUS:
		if _ball_pos.x < _vp.x * 0.5:
			if _left_held:
				_ball_vel = Vector2(FLIP_X_STRENGTH, -FLIP_Y_STRENGTH)
				_ball_pos.y = _flipper_y - BALL_RADIUS - 1.0
		else:
			if _right_held:
				_ball_vel = Vector2(-FLIP_X_STRENGTH, -FLIP_Y_STRENGTH)
				_ball_pos.y = _flipper_y - BALL_RADIUS - 1.0

	if _ball_pos.y > _vp.y + BALL_RADIUS * 2.0:
		_finish_run()
		return

	_update_ball_visual()

func _update_ball_visual() -> void:
	_ball.position = _ball_pos - Vector2(BALL_RADIUS, BALL_RADIUS)

func _launch() -> void:
	_state = "playing"
	_charging = false
	_ball_vel = Vector2(rng.randf_range(-30.0, 30.0), -(LAUNCH_MAX_SPEED * _power / 100.0 + 80.0))

func _unhandled_input(event: InputEvent) -> void:
	if _state == "done":
		return

	if _state == "launching":
		var pressed_now := (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventMouseButton and event.pressed)
		var released_now := (event is InputEventScreenTouch and not event.pressed) \
			or (event is InputEventMouseButton and not event.pressed)
		if pressed_now and not _charging:
			_charging = true
		elif released_now and _charging:
			_launch()
		return

	if _state == "playing":
		if event is InputEventScreenTouch:
			var side := "left" if event.position.x < size.x / 2.0 else "right"
			if event.pressed:
				_active_touches[event.index] = side
			else:
				_active_touches.erase(event.index)
			_recompute_flipper_state()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			var side := "left" if event.position.x < size.x / 2.0 else "right"
			if event.pressed:
				_active_touches[-1] = side
			else:
				_active_touches.erase(-1)
			_recompute_flipper_state()

func _recompute_flipper_state() -> void:
	_left_held = false
	_right_held = false
	for side in _active_touches.values():
		if side == "left":
			_left_held = true
		elif side == "right":
			_right_held = true
	_left_flipper.color = Color(0.5, 0.8, 1.0) if _left_held else Color(0.3, 0.5, 0.8)
	_right_flipper.color = Color(0.5, 0.8, 1.0) if _right_held else Color(0.3, 0.5, 0.8)

func _finish_run() -> void:
	if _state == "done":
		return
	_state = "done"
	_info_label.text = "Puntos: %d" % _score

	var timer := get_tree().create_timer(RESULT_DELAY)
	timer.timeout.connect(func(): _finish(float(_score)))
