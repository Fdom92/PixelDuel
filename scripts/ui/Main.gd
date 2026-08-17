extends Control
## Orchestrates the pass-and-play flow: menu -> (pass device -> N intentos
## de participante -> agregación) x2 por ronda -> resultado de ronda ->
## ... -> resultado final.

var _menu_panel: VBoxContainer
var _round_intro_panel: VBoxContainer
var _pass_device_panel: VBoxContainer
var _round_result_panel: VBoxContainer
var _final_result_panel: VBoxContainer
var _minigame_container: Control

var _participants_label: Label
var _round_intro_label: Label
var _start_turn_button: Button
var _pass_device_label: Label
var _round_result_label: Label
var _final_result_label: Label

var _current_minigame: MinigameBase
var _pending_player := 1

var _attempt_index := 0
var _attempt_values: Array[float] = []
var _current_aggregation_type := "average"
var _current_unit_label := "pts"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

	MatchManager.turn_started.connect(_on_turn_started)
	MatchManager.round_finished.connect(_on_round_finished)
	MatchManager.match_finished.connect(_on_match_finished)

	_update_participants_label()
	_show_only(_menu_panel)

func _build_ui() -> void:
	_menu_panel = _make_panel()
	var title := Label.new()
	title.text = "PixelDuel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	_menu_panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "%d pruebas · pasa el móvil entre jugadores" % MatchManager.ROUNDS_TOTAL
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_panel.add_child(subtitle)

	var participants_row := HBoxContainer.new()
	participants_row.alignment = BoxContainer.ALIGNMENT_CENTER
	participants_row.add_theme_constant_override("separation", 12)
	var minus_btn := Button.new()
	minus_btn.text = "-"
	minus_btn.pressed.connect(_on_participants_minus_pressed)
	participants_row.add_child(minus_btn)
	_participants_label = Label.new()
	participants_row.add_child(_participants_label)
	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.pressed.connect(_on_participants_plus_pressed)
	participants_row.add_child(plus_btn)
	_menu_panel.add_child(participants_row)

	var play_btn := Button.new()
	play_btn.text = "Jugar"
	play_btn.pressed.connect(func(): MatchManager.start_match())
	_menu_panel.add_child(play_btn)
	add_child(_menu_panel)

	_round_intro_panel = _make_panel()
	_round_intro_label = Label.new()
	_round_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_intro_panel.add_child(_round_intro_label)
	_start_turn_button = Button.new()
	_start_turn_button.text = "Empezar"
	_start_turn_button.pressed.connect(_launch_minigame)
	_round_intro_panel.add_child(_start_turn_button)
	add_child(_round_intro_panel)

	_pass_device_panel = _make_panel()
	_pass_device_label = Label.new()
	_pass_device_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pass_device_panel.add_child(_pass_device_label)
	var ready_btn := Button.new()
	ready_btn.text = "Listo"
	ready_btn.pressed.connect(_on_pass_device_ready_pressed)
	_pass_device_panel.add_child(ready_btn)
	add_child(_pass_device_panel)

	_round_result_panel = _make_panel()
	_round_result_label = Label.new()
	_round_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_result_panel.add_child(_round_result_label)
	var next_btn := Button.new()
	next_btn.text = "Siguiente"
	next_btn.pressed.connect(func(): MatchManager.advance_to_next_round())
	_round_result_panel.add_child(next_btn)
	add_child(_round_result_panel)

	_final_result_panel = _make_panel()
	_final_result_label = Label.new()
	_final_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_final_result_panel.add_child(_final_result_label)
	var replay_btn := Button.new()
	replay_btn.text = "Jugar de nuevo"
	replay_btn.pressed.connect(func(): MatchManager.start_match())
	_final_result_panel.add_child(replay_btn)
	add_child(_final_result_panel)

	_minigame_container = Control.new()
	_minigame_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_minigame_container)

func _make_panel() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 16)
	return panel

func _show_only(panel: Control) -> void:
	for p in [_menu_panel, _round_intro_panel, _pass_device_panel, _round_result_panel, _final_result_panel, _minigame_container]:
		p.visible = (p == panel)

func _on_participants_minus_pressed() -> void:
	MatchManager.participants_per_player = max(MatchManager.MIN_PARTICIPANTS, MatchManager.participants_per_player - 1)
	_update_participants_label()

func _on_participants_plus_pressed() -> void:
	MatchManager.participants_per_player = min(MatchManager.MAX_PARTICIPANTS, MatchManager.participants_per_player + 1)
	_update_participants_label()

func _update_participants_label() -> void:
	_participants_label.text = "Participantes por jugador: %d" % MatchManager.participants_per_player

func _on_turn_started(player: int) -> void:
	_pending_player = player
	var text := "Pasa el móvil al Jugador %d" % player
	if player == 2:
		var p1_value: float = MatchManager.get_round_score(1)
		text += "\n\nResultado a batir: %s" % _format_value(p1_value)
	_pass_device_label.text = text
	_show_only(_pass_device_panel)

func _on_pass_device_ready_pressed() -> void:
	_attempt_index = 0
	_attempt_values = []
	_show_round_intro()

func _show_round_intro() -> void:
	var text := "Ronda %d/%d\nJugador %d" % [
		MatchManager.round_index() + 1, MatchManager.ROUNDS_TOTAL, _pending_player
	]
	if MatchManager.participants_per_player > 1:
		text += "\nParticipante %d/%d" % [_attempt_index + 1, MatchManager.participants_per_player]
	_round_intro_label.text = text
	_start_turn_button.text = "Empezar" if _attempt_index == 0 else "Siguiente participante"
	_show_only(_round_intro_panel)

func _launch_minigame() -> void:
	var scene: PackedScene = MatchManager.current_minigame_scene()
	_current_minigame = scene.instantiate()
	_current_minigame.set_round_seed(MatchManager.current_round_seed())
	if _attempt_index == 0:
		_current_aggregation_type = _current_minigame.get_aggregation_type()
		_current_unit_label = _current_minigame.get_unit_label()
	_current_minigame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_current_minigame.minigame_finished.connect(_on_minigame_finished)
	_minigame_container.add_child(_current_minigame)
	_show_only(_minigame_container)

func _on_minigame_finished(value: float) -> void:
	_current_minigame.queue_free()
	_current_minigame = null
	_attempt_values.append(value)
	_attempt_index += 1

	if _attempt_index < MatchManager.participants_per_player:
		_show_round_intro()
	else:
		MatchManager.submit_score(_aggregate_attempts())

func _aggregate_attempts() -> float:
	match _current_aggregation_type:
		"best":
			return _attempt_values.max()
		"success_count", "collect_sum":
			var total := 0.0
			for v in _attempt_values:
				total += v
			return total
		_: # "average"
			var sum := 0.0
			for v in _attempt_values:
				sum += v
			return sum / _attempt_values.size()

func _format_value(value: float) -> String:
	match _current_aggregation_type:
		"success_count":
			return "%d/%d" % [int(round(value)), MatchManager.participants_per_player]
		"collect_sum":
			return "%d %s" % [int(round(value)), _current_unit_label]
		_: # "best" / "average"
			return "%d pts" % int(round(value))

func _on_round_finished(round_index: int, winner: int, p1_score: float, p2_score: float) -> void:
	var winner_text := "Empate" if winner == 0 else "Gana el Jugador %d" % winner
	_round_result_label.text = "Ronda %d\nJugador 1: %s\nJugador 2: %s\n%s" % [
		round_index + 1, _format_value(p1_score), _format_value(p2_score), winner_text
	]
	_show_only(_round_result_panel)

func _on_match_finished(winner: int, wins: Dictionary) -> void:
	var winner_text := "¡Empate!" if winner == 0 else "¡Gana el Jugador %d!" % winner
	_final_result_label.text = "Resultado final\nJugador 1: %d rondas\nJugador 2: %d rondas\n%s" % [
		wins[1], wins[2], winner_text
	]
	_show_only(_final_result_panel)
