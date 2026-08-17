extends Node
## Autoload. Owns the minigame bucket, turn order and scoring for one match.
## Flow per round: turn_started(1) -> submit_score -> turn_started(2) -> submit_score -> round_finished.
## The UI must call advance_to_next_round() when the player is ready to continue.

signal round_started(round_index: int, total_rounds: int, minigame_name: String)
signal turn_started(player: int)
signal turn_finished(player: int, score: float)
signal round_finished(round_index: int, winner: int, p1_score: float, p2_score: float, is_double: bool)
signal match_finished(winner: int, points: Dictionary)

const ROUNDS_TOTAL := 5
const MIN_PARTICIPANTS := 1
const MAX_PARTICIPANTS := 5

## Puntos de partida por ronda: quien gana la ronda suma POINTS_WIN, quien
## la pierde suma POINTS_LOSE igualmente (punto de participación). En un
## empate nadie gana, así que ambos suman solo la parte de "perder".
## Una ronda al azar por partida vale el doble (POINTS_*_DOUBLE).
const POINTS_WIN := 2
const POINTS_LOSE := 1
const POINTS_WIN_DOUBLE := 4
const POINTS_LOSE_DOUBLE := 2

## Nº de "vecinos" que juega cada jugador por prueba; sus intentos se
## combinan según el tipo de agregación de la prueba. Configurable desde
## el menú antes de empezar la partida.
var participants_per_player := 3

## Add new minigame scenes here to include them in the random pool.
var bucket: Array[PackedScene] = [
	preload("res://scenes/minigames/SackRace.tscn"),
	preload("res://scenes/minigames/MoleWhack.tscn"),
	preload("res://scenes/minigames/EggAndSpoon.tscn"),
	preload("res://scenes/minigames/FlagMemory.tscn"),
	preload("res://scenes/minigames/ObstacleRun.tscn"),
	preload("res://scenes/minigames/DuckFishing.tscn"),
	preload("res://scenes/minigames/RiverCrossing.tscn"),
	preload("res://scenes/minigames/WaterBucket.tscn"),
	preload("res://scenes/minigames/TightropeWalk.tscn"),
	preload("res://scenes/minigames/GreasyPole.tscn"),
	preload("res://scenes/minigames/FrogGame.tscn"),
	preload("res://scenes/minigames/Handkerchief.tscn"),
	preload("res://scenes/minigames/AppleBite.tscn"),
	preload("res://scenes/minigames/Skittles.tscn"),
	preload("res://scenes/minigames/Basketball.tscn"),
	preload("res://scenes/minigames/DanceMachine.tscn"),
	preload("res://scenes/minigames/Pinball.tscn"),
]

var _selected_minigames: Array[PackedScene] = []
var _round_index := 0
var _current_player := 1
var _round_scores := {1: 0.0, 2: 0.0}
var _points := {1: 0, 2: 0}
var _round_seed := 0
var _double_round_index := -1

func start_match() -> void:
	_selected_minigames = _pick_minigames(ROUNDS_TOTAL)
	_round_index = 0
	_points = {1: 0, 2: 0}
	_double_round_index = randi_range(0, ROUNDS_TOTAL - 1)
	_start_round()

func current_minigame_scene() -> PackedScene:
	return _selected_minigames[_round_index]

func current_player() -> int:
	return _current_player

func round_index() -> int:
	return _round_index

func points() -> Dictionary:
	return _points.duplicate()

## Si la ronda actual es la ronda de puntos dobles de esta partida.
func is_current_round_double() -> bool:
	return _round_index == _double_round_index

## Seed compartida por los dos jugadores (y todos sus participantes) para
## la prueba de la ronda actual — así todo el mundo se enfrenta exactamente
## al mismo patrón aleatorio, si la prueba tiene alguno.
func current_round_seed() -> int:
	return _round_seed

## Resultado agregado del jugador en la ronda actual (0.0 si aún no ha
## jugado). Se usa para mostrar "resultado a batir" en el handoff.
func get_round_score(player: int) -> float:
	return _round_scores[player]

func submit_score(score: float) -> void:
	_round_scores[_current_player] = score
	turn_finished.emit(_current_player, score)
	if _current_player == 1:
		_current_player = 2
		turn_started.emit(_current_player)
	else:
		_resolve_round()

## Called by the UI once the player has seen the round result and is ready to continue.
func advance_to_next_round() -> void:
	_round_index += 1
	if _round_index >= ROUNDS_TOTAL:
		var match_winner := 0
		if _points[1] > _points[2]:
			match_winner = 1
		elif _points[2] > _points[1]:
			match_winner = 2
		match_finished.emit(match_winner, _points.duplicate())
	else:
		_start_round()

## Elige `count` pruebas evitando repetir categoria_mecanica mientras
## queden categorías sin usar; si count supera el nº de categorías
## disponibles, a partir de ahí ya permite repetir.
func _pick_minigames(count: int) -> Array[PackedScene]:
	var available := bucket.duplicate()
	available.shuffle()
	var picked: Array[PackedScene] = []
	var used_categories: Array[String] = []

	while picked.size() < count and not available.is_empty():
		var index := _index_with_unused_category(available, used_categories)
		if index == -1:
			index = 0
		var scene: PackedScene = available[index]
		available.remove_at(index)
		picked.append(scene)
		used_categories.append(_category_of(scene))

	return picked

func _index_with_unused_category(pool: Array[PackedScene], used_categories: Array[String]) -> int:
	for i in pool.size():
		if not used_categories.has(_category_of(pool[i])):
			return i
	return -1

## Instancia la escena fuera del árbol solo para leer su categoría/tipo y
## la libera al momento — no dispara _ready() ni _process().
func _category_of(scene: PackedScene) -> String:
	var temp: MinigameBase = scene.instantiate()
	var category := temp.get_mechanic_category()
	temp.free()
	return category

func _start_round() -> void:
	_current_player = 1
	_round_scores = {1: 0.0, 2: 0.0}
	_round_seed = randi()
	round_started.emit(_round_index, ROUNDS_TOTAL, current_minigame_scene().resource_path.get_file())
	turn_started.emit(_current_player)

func _resolve_round() -> void:
	var p1: float = _round_scores[1]
	var p2: float = _round_scores[2]
	var is_double := is_current_round_double()
	var win_points: int = POINTS_WIN_DOUBLE if is_double else POINTS_WIN
	var lose_points: int = POINTS_LOSE_DOUBLE if is_double else POINTS_LOSE

	var winner := 0
	if p1 > p2:
		winner = 1
	elif p2 > p1:
		winner = 2

	# Empate: nadie gana, pero ambos suman el punto de participación.
	_points[1] += win_points if winner == 1 else lose_points
	_points[2] += win_points if winner == 2 else lose_points

	round_finished.emit(_round_index, winner, p1, p2, is_double)
