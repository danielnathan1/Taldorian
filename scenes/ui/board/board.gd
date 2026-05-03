# scenes/ui/board/board.gd
class_name Board
extends Node2D

@onready var player_hero_slots    := $TableLayout/PlayerArea/PlayerHeroes
@onready var opponent_hero_slots  := $TableLayout/OpponentArea/OpponentHeroes
@onready var player_active_hero   := $TableLayout/PlayerArea/ActiveHero
@onready var opponent_active_hero := $TableLayout/OpponentArea/ActiveHero
@onready var player_hand_node     := $TableLayout/PlayerArea/PlayerHand
@onready var opponent_hand_node   := $TableLayout/OpponentHand
@onready var phase_label          := $UI/PhaseLabel
@onready var action_button        := $UI/ActionButton
@onready var combat_zone          := $TableLayout/CombatZone
@onready var phase_overlay        := $PhaseOverlay
@onready var _dim_overlay         := $PhaseOverlay/DimOverlay
@onready var pass_button          := $PassButton
@onready var player_playmat       := $TableLayout/PlayerArea/Playmat
@onready var opponent_playmat     := $TableLayout/OpponentArea/Playmat
@onready var _card_preview        := $PreviewLayer/CardPreview
@onready var _player_deck         := $TableLayout/PlayerArea/Deck
@onready var _opponent_deck       := $TableLayout/OpponentArea/Deck
@onready var _player_arsenal      := $TableLayout/PlayerArea/Arsenal
@onready var _opponent_arsenal    := $TableLayout/OpponentArea/Arsenal
@onready var _player_chain_cards      := $TableLayout/PlayerArea/ChainCards/CardsPlayed
@onready var _opponent_chain_cards    := $TableLayout/OpponentArea/ChainCards/CardsPlayed
@onready var _player_graveyard_top   := $TableLayout/PlayerArea/Graveyard/GraveyardTop
@onready var _opponent_graveyard_top := $TableLayout/OpponentArea/Graveyard/GraveyardTop

const HeroSlotScene  := preload("res://scenes/ui/hero_slot/hero_slot.tscn")
const CardViewScene  := preload("res://scenes/ui/card_view/card_view.tscn")
const CardPopupScene := preload("res://scenes/ui/card_popup/card_popup.tscn")
const HeroPopupScene := preload("res://scenes/ui/hero_popup/hero_popup.tscn")
const PickCardScene       := preload("res://scenes/ui/board/pick_card/PickCard.tscn")
const DiscartCardScene    := preload("res://scenes/ui/board/discart_card/DiscartCard.tscn")
const PickSymbolScene     := preload("res://scenes/ui/board/pick_symbol/PickSymbol.tscn")
const TurnTransitionScene := preload("res://scenes/ui/board/turn_transaction/turn_transition.tscn")
const GameResultScene     := preload("res://scenes/ui/board/game_result/game_result.tscn")

var _local_sleeve:    Texture2D
var _opponent_sleeve: Texture2D
var _card_popup:      CanvasLayer = null
var _hero_popup:      CanvasLayer = null
var _pick_card:       PickCard    = null
var _discard_card:    DiscartCard = null
var _pick_symbol:     PickSymbol  = null
var _turn_transition: Control     = null
var _game_result:     Control     = null
var _game_over_shown: bool        = false
var _pending_transition_type: String = ""
var _waiting_label: Label = null
var _prev_reaction_window: int       = -1
var _prev_segment_player: int        = -1
var _battle_music: AudioStreamPlayer = null
var _battle_tracks: Array            = []
var _battle_track_idx: int           = 0

@onready var _player_combat_status   := $TableLayout/PlayerArea/CombatStatus
@onready var _opponent_combat_status := $TableLayout/OpponentArea/CombatStatus

const SLEEVE_BASE_PATH  := "res://assets/sleve/%s.png"
const PLAYMAT_BASE_PATH := "res://assets/playmats/%s.png"
const SLEEVE_DEFAULT    := preload("res://assets/sleve/default.png")
const PLAYMAT_DEFAULT   := preload("res://assets/playmats/default_playmat.png")

static func _load_texture(path: String, fallback: Texture2D) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else fallback

func _ready() -> void:
	# CanvasLayer ignora visibilidade do pai — esconde manualmente quando
	# o Board está embutido em outra cena e ainda não é o ativo.
	if not visible:
		phase_overlay.visible = false
		return
	player_active_hero.visible   = false
	opponent_active_hero.visible = false
	opponent_active_hero.is_opponent = true
	pass_button.visible = false
	pass_button.pressed.connect(_on_pass_button_pressed)
	_connect_bus()
	_apply_player_cosmetics()
	_spawn_hero_slots()
	_rebuild_hand()
	_refresh_arsenals()
	_refresh_graveyard()
	_player_arsenal.gui_input.connect(_on_arsenal_gui_input)
	_player_arsenal.mouse_entered.connect(_on_arsenal_mouse_entered)
	_player_arsenal.mouse_exited.connect(_on_arsenal_mouse_exited)
	_card_popup = CardPopupScene.instantiate()
	add_child(_card_popup)
	_hero_popup = HeroPopupScene.instantiate()
	add_child(_hero_popup)
	_pick_card = PickCardScene.instantiate()
	phase_overlay.add_child(_pick_card)
	_discard_card = DiscartCardScene.instantiate()
	phase_overlay.add_child(_discard_card)
	_pick_symbol = PickSymbolScene.instantiate()
	phase_overlay.add_child(_pick_symbol)
	_turn_transition = TurnTransitionScene.instantiate()
	phase_overlay.add_child(_turn_transition)
	_game_result = GameResultScene.instantiate()
	phase_overlay.add_child(_game_result)
	_game_result.result_closed.connect(_on_result_closed)
	_player_combat_status.visible   = false
	_opponent_combat_status.visible = false
	_waiting_label = Label.new()
	_waiting_label.add_theme_font_size_override("font_size", 26)
	_waiting_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_waiting_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_waiting_label.add_theme_constant_override("shadow_offset_x", 2)
	_waiting_label.add_theme_constant_override("shadow_offset_y", 2)
	_waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_waiting_label.position = Vector2(760, 500)
	_waiting_label.custom_minimum_size = Vector2(400, 60)
	_waiting_label.visible = false
	$UI.add_child(_waiting_label)
	_start_battle_music()
	GameBus.game_over.connect(_on_game_over)
	# O servidor empurra o estado autoritativo para todos (inclusive si mesmo).
	# Isso garante que o cliente veja o baralho correto antes de interagir com o mulligan,
	# já que ambos os peers chamam start_match() de forma independente no autoload
	# antes de o multiplayer estar configurado.
	GameState.broadcast_state()

# ── GameBus → Board ─────────────────────────────────────
func _connect_bus() -> void:
	GameBus.state_synced.connect(_on_state_synced)
	GameBus.phase_changed.connect(_on_phase_changed)
	GameBus.card_drawn.connect(_on_card_drawn)
	GameBus.hero_damaged.connect(_on_hero_damaged)
	GameBus.hero_defeated.connect(_on_hero_defeated)
	GameBus.combat_resolved.connect(_on_combat_resolved)
	GameBus.reaction_window_opened.connect(_on_reaction_window_opened)
	GameBus.hero_revealed.connect(_on_hero_revealed)
	GameBus.card_played.connect(_on_card_played)
	GameBus.skill_activated.connect(_on_skill_activated)

# ── inicialização visual ─────────────────────────────────
func _apply_player_cosmetics() -> void:
	var local_idx    := NetworkState.local_player_index
	var opponent_idx := 1 - local_idx
	var local_p      := GameState.players[local_idx]
	var opponent_p   := GameState.players[opponent_idx]

	# Playmats
	var local_pm_tex    := _load_texture(PLAYMAT_BASE_PATH % local_p.playmat_key,    PLAYMAT_DEFAULT)
	var opponent_pm_tex := _load_texture(PLAYMAT_BASE_PATH % opponent_p.playmat_key, PLAYMAT_DEFAULT)
	player_playmat.texture   = local_pm_tex
	opponent_playmat.texture = opponent_pm_tex

	# Sleeves — cacheados para passar aos slots e decks
	_local_sleeve    = _load_texture(SLEEVE_BASE_PATH % local_p.sleeve_key,    SLEEVE_DEFAULT)
	_opponent_sleeve = _load_texture(SLEEVE_BASE_PATH % opponent_p.sleeve_key, SLEEVE_DEFAULT)
	_player_deck.texture   = _local_sleeve
	_opponent_deck.texture = _opponent_sleeve

func _spawn_hero_slots() -> void:
	var local_idx    := NetworkState.local_player_index
	var opponent_idx := 1 - local_idx

	# PlayerHeroes tem slots estáticos no tscn — bind, sleeve e sinal.
	var player_slots := player_hero_slots.get_children()
	var player_heroes := GameState.players[local_idx].heroes
	for i in min(player_slots.size(), player_heroes.size()):
		player_slots[i].set_sleeve_texture(_local_sleeve)
		player_slots[i].bind(player_heroes[i])
		player_slots[i].slot_clicked.connect(_on_hero_slot_clicked)

	# OpponentHeroes tem slots estáticos no tscn — bind, sleeve do oponente e face-down.
	var opponent_slots := opponent_hero_slots.get_children()
	var opponent_heroes := GameState.players[opponent_idx].heroes
	for i in min(opponent_slots.size(), opponent_heroes.size()):
		opponent_slots[i].is_opponent = true
		opponent_slots[i].set_sleeve_texture(_opponent_sleeve)
		opponent_slots[i].bind(opponent_heroes[i])
		opponent_slots[i].set_face_down(opponent_heroes[i].state == Hero.State.ACTIVE)

	# ActiveHero também recebe o sleeve correto
	player_active_hero.set_sleeve_texture(_local_sleeve)
	opponent_active_hero.set_sleeve_texture(_opponent_sleeve)

# ── reações ao GameBus ───────────────────────────────────
func _on_phase_changed(phase: String) -> void:
	print("Phase: " + phase)
	if phase != "ACTION":
		_prev_segment_player   = -1
		_prev_reaction_window  = -1
	$PhaseOverlay/MulliganScreen.visible = (phase == "OPENING_MULLIGAN")
	$PhaseOverlay/HeroPickScreen.visible = (phase == "HERO_SELECTION")
	$PhaseOverlay/ArsenalScreen.visible  = (phase == "END") and not _game_over_shown
	player_hand_node.visible = (phase != "OPENING_MULLIGAN")
	phase_label.text = phase
	_refresh_action_button(phase)
	_refresh_pass_button(phase)
	_refresh_hand_interactivity()
	_refresh_arsenals()
	_refresh_dim_overlay()
	if phase == "END":
		_clear_chain_cards()

func _on_card_drawn(player_index: int) -> void:
	if player_index == NetworkState.local_player_index:
		_rebuild_hand()

func _on_hero_damaged(hero: Hero, _amount: int) -> void:
	_refresh_hero_slot(hero)

func _on_hero_defeated(hero: Hero) -> void:
	_refresh_hero_slot(hero)

func _on_combat_resolved(_damage_p0: int, _damage_p1: int) -> void:
	for slot in player_hero_slots.get_children():
		slot.refresh()
	for slot in opponent_hero_slots.get_children():
		slot.refresh()
	_refresh_combat_stats()

func _on_skill_activated(hero: Hero, skill_name: String) -> void:
	# Descobre se é herói do jogador local ou do oponente para posicionar a notificação
	var local_idx  := NetworkState.local_player_index
	var is_local   := hero in GameState.players[local_idx].heroes
	var base_y     := 600.0 if is_local else 200.0

	var lbl := Label.new()
	lbl.text = "⚡ %s!" % skill_name
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	lbl.position = Vector2(860.0, base_y)
	$UI.add_child(lbl)

	var tween := create_tween()
	tween.tween_property(lbl, "position:y", base_y - 120.0, 1.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tween.tween_callback(lbl.queue_free)
	_hero_popup.show_skill(hero, skill_name)

# ── mão do jogador ───────────────────────────────────────
func _rebuild_hand() -> void:
	for child in player_hand_node.get_children():
		child.queue_free()

	var local_idx := NetworkState.local_player_index
	var hand := GameState.players[local_idx].hand
	for i in hand.size():
		var view: CardView = CardViewScene.instantiate()
		player_hand_node.add_child(view)
		view.bind(hand[i])
		view.set_sleeve(_local_sleeve)
		view.card_clicked.connect(_on_card_clicked.bind(i))

# ── interações do jogador ────────────────────────────────
func _on_hero_slot_clicked(hero: Hero) -> void:
	var local_idx := NetworkState.local_player_index
	var slot_idx  := GameState.players[local_idx].heroes.find(hero)
	if slot_idx < 0:
		return
	GameState.rpc_id(1, "rpc_submit_hero", slot_idx)

func _on_card_clicked(_card: Card, hand_idx: int) -> void:
	GameState.rpc_id(1, "rpc_play_card", hand_idx)

# ── helpers ──────────────────────────────────────────────
func _refresh_hero_slot(hero: Hero) -> void:
	for slot in player_hero_slots.get_children() + opponent_hero_slots.get_children():
		if slot.hero == hero:
			slot.refresh()
			return

func _refresh_action_button(phase: String) -> void:
	var labels := {
		"DRAW":           "COMPRAR CARTAS",
		"HERO_SELECTION": "CONFIRMAR HERÓI",
		"ACTION":         "JOGAR CARTAS",
		"COMBAT":         "RESOLVER COMBATE",
		"END":            "ENCERRAR TURNO",
	}
	action_button.text = labels.get(phase, phase)

func _on_pass_button_pressed() -> void:
	GameState.rpc_id(1, "rpc_pass")

func _on_hero_revealed(_player_index: int, _hero: Hero) -> void:
	_refresh_active_heroes()

func _on_reaction_window_opened(player_index: int) -> void:
	# Atualiza o pass para refletir que agora é uma janela de reação
	if player_index == NetworkState.local_player_index:
		pass_button.text    = "Passar Reação"
		pass_button.visible = true
	_refresh_hand_interactivity()
	_refresh_arsenals()

func _refresh_pass_button(phase: String) -> void:
	var local_idx     := NetworkState.local_player_index
	var reaction_for  := GameState.get_reaction_window_for()
	var segment_owner := GameState.get_next_action_player_index()

	if phase != "ACTION":
		pass_button.visible = false
		return

	if reaction_for == local_idx:
		pass_button.text    = "Passar Reação"
		pass_button.visible = true
	elif reaction_for == -1 and segment_owner == local_idx:
		pass_button.text    = "Passar Segmento"
		pass_button.visible = true
	else:
		pass_button.visible = false

# Marca cartas na mão como jogáveis ou não conforme o estado da fase
func _refresh_hand_interactivity() -> void:
	var local_idx     := NetworkState.local_player_index
	var reaction_for  := GameState.get_reaction_window_for()
	var is_my_segment := GameState.get_next_action_player_index() == local_idx
	var action_done   := GameState.get_segment_action_done(local_idx)
	var bonus_done    := GameState.get_segment_bonus_done(local_idx)
	# Tem prioridade real apenas quando pode agir agora — não quando a janela é do oponente
	var has_priority  := (is_my_segment and reaction_for == -1) or reaction_for == local_idx
	for child in player_hand_node.get_children():
		var view := child as CardView
		if view == null or view.card == null:
			continue
		var playable := false
		match view.card.timing:
			Card.TimingType.ACTION:
				playable = is_my_segment and reaction_for == -1 and not action_done
			Card.TimingType.BONUS_ACTION:
				playable = is_my_segment and reaction_for == -1 and not bonus_done
			Card.TimingType.REACTION:
				playable = (reaction_for == local_idx)
		view.set_interactable(playable, has_priority)

func _on_state_synced() -> void:
	var phase_str    := GameState.turn.phase_to_string(GameState.turn.current_phase)
	var reaction_for := GameState.get_reaction_window_for()

	if phase_str == "ACTION":
		if reaction_for >= 0 and _prev_reaction_window < 0:
			# Janela de reação acabou de abrir
			var reaction_type := "sua_reacao" if reaction_for == NetworkState.local_player_index else "reacao_oponente"
			_queue_turn_transition(reaction_type)
		elif reaction_for < 0:
			var segment_player := GameState.get_next_action_player_index()
			if segment_player != _prev_segment_player or _prev_reaction_window >= 0:
				# Segmento passou para outro jogador OU reação foi pulada
				var type := "seu_turno" if segment_player == NetworkState.local_player_index else "turno_oponente"
				_queue_turn_transition(type)
			_prev_segment_player = segment_player

	_prev_reaction_window = reaction_for
	_rebuild_hand()
	for slot in player_hero_slots.get_children():
		slot.refresh()
	for slot in opponent_hero_slots.get_children():
		slot.refresh()
	_refresh_team_face_down()
	_refresh_active_heroes()
	_refresh_combat_stats()
	_refresh_arsenals()
	_refresh_graveyard()
	var phase := GameState.turn.phase_to_string(GameState.turn.current_phase)
	player_hand_node.visible = (phase != "OPENING_MULLIGAN")
	_refresh_pass_button(phase)
	_refresh_hand_interactivity()
	_refresh_dim_overlay()

func _refresh_team_face_down() -> void:
	var local_idx    := NetworkState.local_player_index
	var opponent_idx := 1 - local_idx

	var p_slots  := player_hero_slots.get_children()
	var p_heroes := GameState.players[local_idx].heroes
	for i in min(p_slots.size(), p_heroes.size()):
		(p_slots[i] as HeroSlot).set_face_down(p_heroes[i].state == Hero.State.ACTIVE)

	var o_slots  := opponent_hero_slots.get_children()
	var o_heroes := GameState.players[opponent_idx].heroes
	for i in min(o_slots.size(), o_heroes.size()):
		(o_slots[i] as HeroSlot).set_face_down(o_heroes[i].state == Hero.State.ACTIVE)

func _refresh_dim_overlay() -> void:
	var local_idx    := NetworkState.local_player_index
	var opponent_idx := 1 - local_idx
	var pick_player  := GameState.get_pending_pick_player()
	var sym_player   := GameState.get_pending_symbol_player()
	var my_pick      := pick_player == local_idx or sym_player == local_idx
	var opp_pick     := pick_player == opponent_idx or sym_player == opponent_idx

	var any_open: bool = (
		$PhaseOverlay/MulliganScreen.visible or
		$PhaseOverlay/HeroPickScreen.visible or
		$PhaseOverlay/ArsenalScreen.visible  or
		my_pick
	)
	_dim_overlay.visible = any_open

	if _waiting_label:
		if opp_pick:
			_waiting_label.text = "Aguardando oponente escolher símbolos..." \
				if sym_player == opponent_idx \
				else "Aguardando oponente escolher uma carta..."
			_waiting_label.visible = true
		else:
			_waiting_label.visible = false

func _refresh_arsenals() -> void:
	var local_idx    := NetworkState.local_player_index
	var opponent_idx := 1 - local_idx
	var local_arsenal    := GameState.players[local_idx].arsenal
	var opponent_arsenal := GameState.players[opponent_idx].arsenal

	if local_arsenal.is_empty():
		_player_arsenal.visible = false
	else:
		_player_arsenal.texture = _local_sleeve
		_player_arsenal.visible = true

	if opponent_arsenal.is_empty():
		_opponent_arsenal.visible = false
	else:
		_opponent_arsenal.texture = _opponent_sleeve
		_opponent_arsenal.visible = true

func _is_arsenal_playable(player_idx: int, card: Card) -> bool:
	if GameState.turn.phase_to_string(GameState.turn.current_phase) != "ACTION":
		return false
	var reaction_for  := GameState.get_reaction_window_for()
	var is_my_segment := GameState.get_next_action_player_index() == player_idx
	var action_done   := GameState.get_segment_action_done(player_idx)
	var bonus_done    := GameState.get_segment_bonus_done(player_idx)
	match card.timing:
		Card.TimingType.ACTION:
			return is_my_segment and reaction_for == -1 and not action_done
		Card.TimingType.BONUS_ACTION:
			return is_my_segment and reaction_for == -1 and not bonus_done
		Card.TimingType.REACTION:
			return reaction_for == player_idx
	return false

func _on_arsenal_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	var local_idx := NetworkState.local_player_index
	var arsenal   := GameState.players[local_idx].arsenal
	if arsenal.is_empty():
		return
	if not _is_arsenal_playable(local_idx, arsenal[0]):
		return
	GameState.rpc_id(1, "rpc_play_from_arsenal")

func _on_arsenal_mouse_entered() -> void:
	var local_idx := NetworkState.local_player_index
	var arsenal   := GameState.players[local_idx].arsenal
	if arsenal.is_empty():
		return
	GameBus.card_hovered.emit({ "type": "card", "card": arsenal[0] })

func _on_arsenal_mouse_exited() -> void:
	GameBus.card_hover_ended.emit()

func _refresh_active_heroes() -> void:
	var local_idx    := NetworkState.local_player_index
	var opponent_idx := 1 - local_idx
	var phase        := GameState.turn.current_phase

	# Herói ativo do jogador local — face-down até ser revelado (mesmo para o próprio jogador)
	var local_active := GameState.players[local_idx].active_hero
	var local_is_revealed := GameState.get_hero_revealed(local_idx) \
						or phase in [TurnManager.Phase.COMBAT, TurnManager.Phase.END]
	if local_active:
		player_active_hero.bind(local_active)
		player_active_hero.set_face_down(not local_is_revealed)
		player_active_hero.visible = true
	else:
		player_active_hero.visible = false

	# Oculta o slot do herói ativo nos PlayerHeroes para dar sensação de movimento
	var local_heroes := GameState.players[local_idx].heroes
	for i in player_hero_slots.get_child_count():
		var slot := player_hero_slots.get_child(i) as HeroSlot
		var is_active := local_active != null and i < local_heroes.size() and local_heroes[i] == local_active
		slot.visible = not is_active

	# Herói ativo do oponente — sleeve até ser revelado (ACTION não-furtiva ou fase COMBAT/END)
	var opponent_active := GameState.players[opponent_idx].active_hero
	var is_revealed     := GameState.get_hero_revealed(opponent_idx) \
						or phase in [TurnManager.Phase.COMBAT, TurnManager.Phase.END]
	if opponent_active:
		opponent_active_hero.bind(opponent_active)
		opponent_active_hero.set_face_down(not is_revealed)
		opponent_active_hero.visible = true
	else:
		opponent_active_hero.visible = false

	# Oculta o slot do herói ativo nos OpponentHeroes
	var opponent_heroes := GameState.players[opponent_idx].heroes
	for i in opponent_hero_slots.get_child_count():
		var slot := opponent_hero_slots.get_child(i) as HeroSlot
		var is_active := opponent_active != null and i < opponent_heroes.size() and opponent_heroes[i] == opponent_active
		slot.visible = not is_active

	_refresh_combat_stats()

# ── chain cards ─────────────────────────────────────────
func _on_card_played(player_index: int, card: Card) -> void:
	var local_idx := NetworkState.local_player_index
	var container := _player_chain_cards if player_index == local_idx else _opponent_chain_cards
	var view: CardView = CardViewScene.instantiate()
	container.add_child(view)
	view.bind(card)
	if player_index != local_idx:
		view.is_opponent = true
		view.set_sleeve(_opponent_sleeve)
	else:
		view.set_sleeve(_local_sleeve)
	view.set_interactable(true)   # chain cards são só exibição — mantém opacidade cheia
	_card_popup.show_card(player_index, card)
	_refresh_combat_stats()

func _clear_chain_cards() -> void:
	for child in _player_chain_cards.get_children():
		child.queue_free()
	for child in _opponent_chain_cards.get_children():
		child.queue_free()

func _refresh_graveyard() -> void:
	var local_idx    := NetworkState.local_player_index
	var opponent_idx := 1 - local_idx
	var local_discard    := GameState.players[local_idx].discard_pile
	var opponent_discard := GameState.players[opponent_idx].discard_pile
	_player_graveyard_top.texture   = local_discard.back().get_texture()   if not local_discard.is_empty()    else null
	_opponent_graveyard_top.texture = opponent_discard.back().get_texture() if not opponent_discard.is_empty() else null

# ── sequenciamento card_popup → turn_transition ──────────
func _queue_turn_transition(type: String) -> void:
	if _card_popup._busy:
		_pending_transition_type = type
		_card_popup.popup_finished.connect(_on_popup_finished_for_transition, CONNECT_ONE_SHOT)
	else:
		_play_turn_transition_delayed(type)

func _on_popup_finished_for_transition() -> void:
	_play_turn_transition_delayed(_pending_transition_type)
	_pending_transition_type = ""

func _play_turn_transition_delayed(type: String) -> void:
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(_turn_transition.play.bind(type))

# ── painéis de ataque/defesa do herói ativo ──────────────
func _refresh_combat_stats() -> void:
	var local_idx := NetworkState.local_player_index
	_update_combat_status(_player_combat_status,   local_idx,     player_active_hero)
	_update_combat_status(_opponent_combat_status, 1 - local_idx, opponent_active_hero)

func _update_combat_status(status: Control, player_idx: int, slot: HeroSlot) -> void:
	var phase := GameState.turn.phase_to_string(GameState.turn.current_phase)
	if phase not in ["ACTION", "COMBAT"]:
		status.visible = false
		return
	var pl := GameState.players[player_idx]
	if pl.active_hero == null or not slot.visible or slot._face_down:
		status.visible = false
		return

	status.visible = true

	var atk  := _calc_attack(player_idx)
	var def_ := _calc_defense(player_idx)

	var atk_label  := status.get_node("AttackIcon/AttackValue")   as Label
	var def_label  := status.get_node("DefenseIcon/DefenseValue") as Label

	atk_label.text  = str(atk)
	def_label.text  = str(def_)

	atk_label.modulate  = _stat_color(atk,  pl.active_hero.base_attack)
	def_label.modulate  = _stat_color(def_, pl.active_hero.base_defense)

func _stat_color(current: int, base: int) -> Color:
	if current > base:
		return Color.GREEN
	elif current < base:
		return Color.RED
	return Color.WHITE

func _calc_attack(player_idx: int) -> int:
	var pl := GameState.players[player_idx]
	var total := pl.active_hero.base_attack
	for card in pl.round_cards:
		total += card.attack_value
	total += pl.pending_bonus_attack
	total += pl.passive_attack_bonus
	return total

func _calc_defense(player_idx: int) -> int:
	var pl := GameState.players[player_idx]
	var total := pl.active_hero.base_defense
	for card in pl.round_cards:
		total += card.defense_value
	total -= pl.next_defense_penalty
	total += pl.pending_bonus_defense
	return total

# ── música de batalha ────────────────────────────────────
func _start_battle_music() -> void:
	_battle_tracks = [
		load("res://audio/theme/battle_1.mp3"),
		load("res://audio/theme/battle_2.mp3"),
	]
	_battle_track_idx = 0
	_battle_music = AudioStreamPlayer.new()
	add_child(_battle_music)
	_battle_music.finished.connect(_on_battle_track_finished)
	_play_battle_track()

func _play_battle_track() -> void:
	for _i in _battle_tracks.size():
		var track = _battle_tracks[_battle_track_idx]
		if track != null:
			_battle_music.stream = track
			_battle_music.play()
			return
		_battle_track_idx = (_battle_track_idx + 1) % _battle_tracks.size()

func _on_battle_track_finished() -> void:
	_battle_track_idx = (_battle_track_idx + 1) % _battle_tracks.size()
	_play_battle_track()

func _process(_delta: float) -> void:
	if _battle_music != null and not _battle_music.playing and not _game_over_shown:
		_on_battle_track_finished()

func _on_game_over(winner_index: int) -> void:
	_game_over_shown = true
	if _battle_music:
		_battle_music.stop()
	if winner_index == NetworkState.local_player_index:
		_game_result.show_victory()
	else:
		_game_result.show_defeat()

func _on_result_closed() -> void:
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://scenes/ui/lobby/lobby.tscn")
