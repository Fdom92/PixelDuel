extends Control
class_name MinigameBase
## Base interface every minigame in the bucket must extend.
## Call _finish(value) once, when a single attempt's outcome is decided.
## When participants_per_player > 1, the same scene is instantiated once
## per participant and the raw values are combined according to
## get_aggregation_type():
##   "best"          -> value is a 0-100 score, the highest attempt counts
##   "average"       -> value is a 0-100 score, attempts are averaged
##   "success_count" -> value is 1.0 (pass) or 0.0 (fail) per attempt
##   "collect_sum"   -> value is a raw unit count, attempts are summed

signal minigame_finished(value: float)

## RNG sembrado por ronda: todos los intentos de una misma prueba en una
## misma ronda (los dos jugadores, todos sus participantes) usan la misma
## seed, así que cualquier elemento aleatorio de la prueba (retraso,
## patrón, secuencia...) sale igual para todos. Debe leerse en vez de
## randf()/randi() globales para cualquier cosa que afecte a la dificultad.
var rng := RandomNumberGenerator.new()

var _finished := false

func set_round_seed(seed_value: int) -> void:
	rng.seed = seed_value

func _finish(value: float) -> void:
	if _finished:
		return
	_finished = true
	minigame_finished.emit(value)

func get_aggregation_type() -> String:
	return "average"

func get_unit_label() -> String:
	return "pts"

## Etiqueta de la mecánica de control (p. ej. "spam_toques", "arrastre").
## Se usa para no repetir el mismo tipo de gesto varias veces en una
## misma partida. Ver README para la lista de categorías en uso.
func get_mechanic_category() -> String:
	return "general"

## Nombre visible de la prueba, mostrado en la pantalla de introducción
## de ronda antes de pulsar "Empezar".
func get_display_name() -> String:
	return "Prueba"
