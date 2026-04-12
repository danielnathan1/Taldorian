# Cena mínima para testar o loop Fase 1 (Taldorian TCG): compra, herói, ação alternada, combate, arsenal.
extends Control

var state: GameState
var _mulligan_pidx: int = -1
var _mulligan_sel: Array[int] = []

@onready var _title: Label = $VBox/Title
@onready var _phase_row: Label = $VBox/PhaseRow
@onready var _status: Label = $VBox/Status
@onready var _content: VBoxContainer = $VBox/Scroll/Content

func _ready() -> void:
	_title.text = "Teste de mecânicas — Taldorian TCG (hotseat)"
	GameBus.phase_changed.connect(func(_p): _rebuild())
	GameBus.turn_started.connect(func(_i): _rebuild())
	GameBus.turn_ended.connect(func(_i): _rebuild())
	GameBus.game_over.connect(_on_game_over)
	GameBus.combat_resolved.connect(_on_combat_log)
	_rebuild()

func _on_combat_log(dmg_p0: int, dmg_p1: int) -> void:
	var n0: String = state.players[0].player_name
	var n1: String = state.players[1].player_name
	print("[combate] %s sofre %d | %s sofre %d" % [n0, dmg_p0, n1, dmg_p1])

func _on_game_over(winner_idx: int) -> void:
	for c in _content.get_children():
		c.queue_free()
	_status.text = "Fim — vencedor: %s" % state.players[winner_idx].player_name
	_phase_row.text = ""

func _rebuild() -> void:
	if state.is_game_over():
		_on_game_over(state.get_winner_index())
		return
	for c in _content.get_children():
		c.queue_free()
	var tm: TurnManager = state.turn
	if tm.current_phase == TurnManager.Phase.OPENING_MULLIGAN:
		var who := state.players[0].player_name if not state.has_completed_opening_mulligan(0) else state.players[1].player_name
		_phase_row.text = "Fase: abertura (só no início) — escolher 2 ao fundo | vez: %s" % who
	else:
		var initiative: Player = state.players[tm.current_player_index]
		_phase_row.text = "Fase: %s | Iniciativa do turno: %s" % [
			tm.phase_to_string(tm.current_phase), initiative.player_name,
		]
	_status.text = _build_status_line()
	match tm.current_phase:
		TurnManager.Phase.OPENING_MULLIGAN:
			_build_opening_mulligan_ui()
		TurnManager.Phase.HERO_SELECTION:
			_build_hero_ui()
		TurnManager.Phase.ACTION:
			_build_action_ui()
		TurnManager.Phase.COMBAT:
			pass
		TurnManager.Phase.END:
			_build_end_ui()
		_:
			pass

func _add_label(text: String) -> void:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = text
	_content.add_child(l)

func _build_status_line() -> String:
	var out := ""
	for pl in state.players:
		var hs := ""
		for h in pl.heroes:
			var st: String = str(Hero.State.keys()[h.state])
			hs += " | %s %d/%d [%s]" % [h.hero_name, h.current_hp, h.max_hp, st]
		out += "%s — mão: %d | deck: %d%s\n" % [
			pl.player_name, pl.hand.size(), pl.deck.size(), hs,
		]
	return out.strip_edges()

func _build_opening_mulligan_ui() -> void:
	var pidx := 0 if not state.has_completed_opening_mulligan(0) else 1
	if pidx != _mulligan_pidx:
		_mulligan_pidx = pidx
		_mulligan_sel.clear()
	var pl: Player = state.players[pidx]
	_add_label(
		"Cada jogador começa com 6 cartas. Marque exatamente 2 para enviar ao fundo do baralho (não são descartadas). Depois disso começa o turno 1."
	)
	_add_label("Agora: %s" % pl.player_name)
	for i in pl.hand.size():
		var on := i in _mulligan_sel
		var btn := Button.new()
		var hc: Card = pl.hand[i]
		var hsym := hc.symbols_display()
		btn.text = ("%s " % ("[x]" if on else "[ ]")) + "[%d] %s%s" % [
			i, hc.card_name, ("  (" + hsym + ")") if hsym != "" else "",
		]
		var ci := i
		btn.pressed.connect(func(): _on_opening_toggle(ci))
		_content.add_child(btn)
	var ok := Button.new()
	ok.text = "Confirmar 2 cartas ao fundo"
	ok.disabled = _mulligan_sel.size() != 2
	ok.pressed.connect(_on_opening_confirm)
	_content.add_child(ok)

func _on_opening_toggle(hand_idx: int) -> void:
	if hand_idx in _mulligan_sel:
		_mulligan_sel.erase(hand_idx)
	elif _mulligan_sel.size() < 2:
		_mulligan_sel.append(hand_idx)
	_rebuild()

func _on_opening_confirm() -> void:
	if _mulligan_sel.size() != 2:
		return
	var pidx := 0 if not state.has_completed_opening_mulligan(0) else 1
	var a: int = _mulligan_sel[0]
	var b: int = _mulligan_sel[1]
	if state.submit_opening_mulligan(pidx, a, b):
		_mulligan_sel.clear()
		_mulligan_pidx = -1
		_rebuild()

func _build_hero_ui() -> void:
	var next_p := state.get_next_hero_pick_player_index()
	_add_label(
		"Escolha de herói: um jogador de cada vez (primeiro quem tem a iniciativa do turno)."
	)
	for pidx in 2:
		if state.has_submitted_hero_pick(pidx):
			var pl_done: Player = state.players[pidx]
			var ah := pl_done.active_hero
			var picked := ah.hero_name if ah else "—"
			_add_label("%s já escolheu: %s ✓" % [pl_done.player_name, picked])
	if next_p < 0:
		return
	var pl: Player = state.players[next_p]
	var other := 1 - next_p
	_add_label("Agora escolhe: %s" % pl.player_name)
	if not state.has_submitted_hero_pick(other):
		_add_label("A seguir: %s" % state.players[other].player_name)
	var row := HBoxContainer.new()
	var title := Label.new()
	title.text = "%s — " % pl.player_name
	row.add_child(title)
	for hidx in 3:
		var h: Hero = pl.heroes[hidx]
		var btn := Button.new()
		btn.text = "%s %d/%d" % [h.hero_name, h.current_hp, h.max_hp]
		btn.disabled = h.state != Hero.State.ACTIVE
		var cp := next_p
		var ch := hidx
		btn.pressed.connect(func(): _on_hero_pick(cp, ch))
		row.add_child(btn)
	_content.add_child(row)

func _on_hero_pick(pidx: int, hidx: int) -> void:
	if state.submit_hero_pick(pidx, hidx):
		_rebuild()

func _build_action_ui() -> void:
	var act_idx := state.get_next_action_player_index()
	var pl: Player = state.players[act_idx]
	var ini := state.turn.current_player_index
	var role := "iniciativa" if act_idx == ini else "reage"
	_add_label("Vez: %s (%s). Ambos podem jogar Ataque ou Defesa. Dois passes seguidos → combate." % [
		pl.player_name, role,
	])
	for i in pl.hand.size():
		var card: Card = pl.hand[i]
		var btn := Button.new()
		var sym := card.symbols_display()
		btn.text = "[%d] %s%s" % [i, card.card_name, ("  (" + sym + ")") if sym != "" else ""]
		var ci := i
		var pi := pl.player_index
		btn.pressed.connect(func(): _on_play_card(pi, ci))
		_content.add_child(btn)
	var pass_btn := Button.new()
	pass_btn.text = "Passar"
	pass_btn.pressed.connect(func(): _on_pass(act_idx))
	_content.add_child(pass_btn)

func _on_play_card(pidx: int, hand_idx: int) -> void:
	if state.action_play_card(pidx, hand_idx):
		_rebuild()

func _on_pass(pidx: int) -> void:
	if state.action_pass(pidx):
		_rebuild()

func _build_end_ui() -> void:
	var pl: Player = state.players[state.turn.current_player_index]
	_add_label("%s: 1 carta para o arsenal; depois compra 4. Ambos os heróis de combate ficam exaustos." % pl.player_name)
	if pl.hand.is_empty():
		var skip := Button.new()
		skip.text = "Mão vazia — continuar"
		skip.pressed.connect(func(): _on_end_confirm(0))
		_content.add_child(skip)
		return
	for i in pl.hand.size():
		var card: Card = pl.hand[i]
		var btn := Button.new()
		var asym := card.symbols_display()
		btn.text = "Arsenal: [%d] %s%s" % [
			i, card.card_name, ("  (" + asym + ")") if asym != "" else "",
		]
		var ci := i
		btn.pressed.connect(func(): _on_end_confirm(ci))
		_content.add_child(btn)

func _on_end_confirm(hand_idx: int) -> void:
	if state.finish_end_turn(hand_idx):
		_rebuild()
