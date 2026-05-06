# scenes/ui/boardv2/board.gd
extends Control

@onready var _player_half     := $VBox/PlayerHalf
@onready var _opponent_half   := $VBox/OpponentHalf
@onready var _center_bar      := $VBox/CenterBar
@onready var phase_overlay    := $PhaseOverlay
@onready var _dim_overlay     := $PhaseOverlay/DimOverlay
@onready var _card_preview    := $PreviewLayer/CardPreview
@onready var _player_combat_status   := $PlayerCombatStatus
@onready var _opponent_combat_status := $OpponentCombatStatus
@onready var _player_hand: PlayerHand = $VBox/PlayerHalf/PlayerHand

const HeroSlotScene  := preload("res://scenes/ui/hero_slot/hero_slot.tscn")
const CardViewScene  := preload("res://scenes/ui/card_view/card_view.tscn")
const CardPopupScene := preload("res://scenes/ui/card_popup/card_popup.tscn")
const HeroPopupScene := preload("res://scenes/ui/hero_popup/hero_popup.tscn")
const PickCardScene       := preload("res://scenes/ui/boardv2/pick_card/PickCard.tscn")
const DiscartCardScene    := preload("res://scenes/ui/boardv2/discart_card/DiscartCard.tscn")
const PickSymbolScene     := preload("res://scenes/ui/boardv2/pick_symbol/PickSymbol.tscn")
const TurnTransitionScene := preload("res://scenes/ui/boardv2/turn_transaction/turn_transition.tscn")
const GameResultScene     := preload("res://scenes/ui/boardv2/game_result/game_result.tscn")
const CombatResolveScene  := preload("res://scenes/ui/boardv2/combat_resolve/combat_resolve.tscn")

const SLEEVE_BASE_PATH  := "res://assets/sleve/%s.png"
const SLEEVE_DEFAULT    := preload("res://assets/sleve/default.png")
const PLAYMAT_BASE_PATH := "res://assets/playmats/%s.png"
const PLAYMAT_DEFAULT   := preload("res://assets/playmats/default.png")

# Referências populadas em _ready() via half_board API
var _player_hero_slots:   Array = []
var _opponent_hero_slots: Array = []
var _player_active_hero:  Node  = null  # HeroSlot
var _opponent_active_hero: Node = null  # HeroSlot

var _local_sleeve:    Texture2D
var _opponent_sleeve: Texture2D
var _card_popup:      CanvasLayer = null
var _hero_popup:      CanvasLayer = null
var _pick_card:       Node = null
var _discard_card:    Node = null
var _pick_symbol:     Node = null
var _turn_transition: Control = null
var _game_result:     Control = null
var _combat_resolve:  Control = null
var _game_over_shown: bool = false
var _pending_transition_type: String = ""
var _waiting_label:   Label = null
var _prev_reaction_window: int = -1
var _prev_segment_player:  int = -1
var _battle_music:    AudioStreamPlayer = null
var _battle_tracks:   Array = []
var _battle_track_idx: int = 0

var _animator: CardAnimator = null
var _last_played_source_pos := Vector2.ZERO

static func _load_texture(path: String, fallback: Texture2D) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else fallback

func _ready() -> void:
	_player_combat_status.visible   = false
	_opponent_combat_status.visible = false

	_center_bar.pass_pressed.connect(_on_pass_button_pressed)
	_center_bar.time_expired.connect(_on_pass_button_pressed)
	_center_bar.stop_timer()

	_connect_bus()
	_apply_player_cosmetics()
	_spawn_hero_slots()
	_rebuild_hand()
	_refresh_arsenals()
	_refresh_graveyard()

	_player_hand.card_clicked.connect(_on_card_clicked)
	_connect_arsenal_events()

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
	_combat_resolve = CombatResolveScene.instantiate()
	phase_overlay.add_child(_combat_resolve)

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
	_animator = CardAnimator.new()
	add_child(_animator)
	GameBus.game_over.connect(_on_game_over)
	GameState.broadcast_state()

# ── GameBus → Board ─────────────────────────────────────────────────────────
func _connect_bus() -> void:
	GameBus.state_synced.connect(_on_state_synced)
	GameBus.phase_changed.connect(_on_phase_changed)
	GameBus.card_drawn.connect(_on_card_drawn)
	GameBus.hero_damaged.connect(_on_hero_damaged)
	GameBus.hero_defeated.connect(_on_hero_defeated)
	GameBus.combat_resolved.connect(_on_combat_resolved)
	GameBus.combat_preview_ready.connect(_on_combat_preview_ready)
	GameBus.reaction_window_opened.connect(_on_reaction_window_opened)
	GameBus.hero_revealed.connect(_on_hero_revealed)
	GameBus.card_played.connect(_on_card_played)
	GameBus.skill_activated.connect(_on_skill_activated)

# ── inicialização visual ─────────────────────────────────────────────────────
func _apply_player_cosmetics() -> void:
	var local_idx    := NetworkState.local_player_index
	var opponent_idx := 1 - local_idx
	_local_sleeve    = _load_texture(SLEEVE_BASE_PATH % GameState.players[local_idx].sleeve_key,    SLEEVE_DEFAULT)
	_opponent_sleeve = _load_texture(SLEEVE_BASE_PATH % GameState.players[opponent_idx].sleeve_key, SLEEVE_DEFAULT)
	_player_half.set_playmat(_load_texture(PLAYMAT_BASE_PATH % GameState.players[local_idx].playmat_key,    PLAYMAT_DEFAULT))
	_opponent_half.set_playmat(_load_texture(PLAYMAT_BASE_PATH % GameState.players[opponent_idx].playmat_key, PLAYMAT_DEFAULT))

func _spawn_hero_slots() -> void:
	var local_idx    := NetworkState.local_player_index
	var opponent_idx := 1 - local_idx

	_player_hero_slots   = _player_half.spawn_hero_slots(GameState.players[local_idx].heroes)
	_opponent_hero_slots = _opponent_half.spawn_hero_slots(GameState.players[opponent_idx].heroes)

	for slot in _player_hero_slots:
		slot.set_sleeve_texture(_local_sleeve)
		slot.slot_clicked.connect(_on_hero_slot_clicked)

	for i in _opponent_hero_slots.size():
		var slot = _opponent_hero_slots[i]
		slot.is_opponent = true
		slot.set_sleeve_texture(_opponent_sleeve)
		slot.bind(GameState.players[opponent_idx].heroes[i])
		slot.set_face_down(GameState.players[opponent_idx].heroes[i].state == Hero.State.ACTIVE)

	_player_active_hero   = _player_half.get_active_hero_view()
	_opponent_active_hero = _opponent_half.get_active_hero_view()
	_player_active_hero.visible   = false
	_opponent_active_hero.visible = false
	_player_active_hero.set_sleeve_texture(_local_sleeve)
	_opponent_active_hero.is_opponent = true
	_opponent_active_hero.set_sleeve_texture(_opponent_sleeve)

	_player_half.set_deck_sleeve(_local_sleeve)
	_opponent_half.set_deck_sleeve(_opponent_sleeve)

func _connect_arsenal_events() -> void:
	var arsenal_panel: Control = _player_half.get_arsenal_panel()
	arsenal_panel.gui_input.connect(_on_arsenal_gui_input)
	arsenal_panel.mouse_entered.connect(_on_arsenal_mouse_entered)
	arsenal_panel.mouse_exited.connect(_on_arsenal_mouse_exited)

# ── reações ao GameBus ───────────────────────────────────────────────────────
func _on_phase_changed(phase: String) -> void:
	print("Phase: " + phase)
	if phase != "ACTION":
		_prev_segment_player  = -1
		_prev_reaction_window = -1
	$PhaseOverlay/MulliganScreen.visible = (phase == "OPENING_MULLIGAN")
	$PhaseOverlay/HeroPickScreen.visible = (phase == "HERO_SELECTION")
	$PhaseOverlay/ArsenalScreen.visible  = (phase == "END") and not _game_over_shown
	_player_hand.visible = (phase != "OPENING_MULLIGAN")
	_center_bar.set_phase(phase)
	_refresh_pass_button(phase)
	_refresh_hand_interactivity()
	_refresh_arsenals()
	_refresh_dim_overlay()
	if phase == "END":
		_clear_chain_cards()

func _on_card_drawn(player_index: int) -> void:
	var local_idx := NetworkState.local_player_index
	if player_index == local_idx:
		var from_pos: Vector2 = _player_half.get_deck_global_center()
		_rebuild_hand()
		call_deferred("_animate_draw_to_hand", from_pos)
	else:
		if _animator != null:
			var from_pos: Vector2 = _opponent_half.get_deck_global_center()
			var to_pos: Vector2   = _opponent_half.get_global_rect().get_center()
			_animator.fly_draw(from_pos, to_pos, _opponent_sleeve)

func _animate_draw_to_hand(from_pos: Vector2) -> void:
	if _animator == null:
		return
	var views := _player_hand.get_card_views()
	if views.is_empty():
		return
	var last := views.back() as Control
	if not is_instance_valid(last):
		return
	var to_pos: Vector2 = last.get_global_rect().get_center()
	_animator.fly_draw(from_pos, to_pos, _local_sleeve)

func _on_hero_damaged(hero: Hero, _amount: int) -> void:
	_refresh_hero_slot(hero)

func _on_hero_defeated(hero: Hero) -> void:
	_refresh_hero_slot(hero)

func _on_combat_resolved(_damage_p0: int, _damage_p1: int) -> void:
	for slot in _player_hero_slots:
		slot.refresh()
	for slot in _opponent_hero_slots:
		slot.refresh()
	_refresh_combat_stats()

func _on_combat_preview_ready(data: Dictionary) -> void:
	var h0_idx: int = data.get("hero_0_idx", -1)
	var h1_idx: int = data.get("hero_1_idx", -1)
	if h0_idx < 0 or h1_idx < 0:
		return
	var hero0: Hero = GameState.players[0].heroes[h0_idx]
	var hero1: Hero = GameState.players[1].heroes[h1_idx]
	_combat_resolve.show_resolve(
		hero0, hero1,
		data["dmg_to_0"], data["dmg_to_1"],
		data["atk_0"],    data["def_0"],
		data["atk_1"],    data["def_1"],
	)

func _on_skill_activated(hero: Hero, skill_name: String) -> void:
	var local_idx := NetworkState.local_player_index
	var is_local  := hero in GameState.players[local_idx].heroes
	var base_y    := 600.0 if is_local else 200.0
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

# ── mão do jogador ───────────────────────────────────────────────────────────
func _rebuild_hand() -> void:
	var local_idx := NetworkState.local_player_index
	_player_hand.rebuild(GameState.players[local_idx].hand, _local_sleeve)

# ── interações do jogador ────────────────────────────────────────────────────
func _on_hero_slot_clicked(hero: Hero) -> void:
	var local_idx := NetworkState.local_player_index
	var slot_idx  := GameState.players[local_idx].heroes.find(hero)
	if slot_idx < 0:
		return
	GameState.rpc_id(1, "rpc_submit_hero", slot_idx)

func _on_card_clicked(_card: Card, hand_idx: int) -> void:
	var views := _player_hand.get_card_views()
	if hand_idx < views.size():
		var cv := views[hand_idx] as Control
		if cv != null:
			_last_played_source_pos = cv.get_global_rect().get_center()
	GameState.rpc_id(1, "rpc_play_card", hand_idx)

func _on_pass_button_pressed() -> void:
	GameState.rpc_id(1, "rpc_pass")

# ── helpers ──────────────────────────────────────────────────────────────────
func _refresh_hero_slot(hero: Hero) -> void:
	for slot in _player_hero_slots + _opponent_hero_slots:
		if slot.hero == hero:
			slot.refresh()
			return

func _on_hero_revealed(_player_index: int, _hero: Hero) -> void:
	_refresh_active_heroes()

func _on_reaction_window_opened(player_index: int) -> void:
	if player_index == NetworkState.local_player_index:
		_center_bar.set_pass_state(true, "Passar Reação")
	_refresh_hand_interactivity()
	_refresh_arsenals()

func _refresh_pass_button(phase: String) -> void:
	var local_idx    := NetworkState.local_player_index
	var reaction_for := GameState.get_reaction_window_for()
	var segment_owner := GameState.get_next_action_player_index()

	if phase != "ACTION":
		_center_bar.set_pass_state(false)
		return

	if reaction_for == local_idx:
		_center_bar.set_pass_state(true, "Passar Reação")
	elif reaction_for == -1 and segment_owner == local_idx:
		_center_bar.set_pass_state(true, "Passar Segmento")
	else:
		_center_bar.set_pass_state(false)

func _refresh_hand_interactivity() -> void:
	var local_idx    := NetworkState.local_player_index
	var reaction_for := GameState.get_reaction_window_for()
	var is_my_segment := GameState.get_next_action_player_index() == local_idx
	var action_done  := GameState.get_segment_action_done(local_idx)
	var bonus_done   := GameState.get_segment_bonus_done(local_idx)
	var has_priority := (is_my_segment and reaction_for == -1) or reaction_for == local_idx
	for child in _player_hand.get_card_views():
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
			var reaction_type := "sua_reacao" if reaction_for == NetworkState.local_player_index else "reacao_oponente"
			_queue_turn_transition(reaction_type)
		elif reaction_for < 0:
			var segment_player := GameState.get_next_action_player_index()
			if segment_player != _prev_segment_player or _prev_reaction_window >= 0:
				var type := "seu_turno" if segment_player == NetworkState.local_player_index else "turno_oponente"
				_queue_turn_transition(type)
			_prev_segment_player = segment_player

	_prev_reaction_window = reaction_for

	var is_my_turn := GameState.get_next_action_player_index() == NetworkState.local_player_index
	_center_bar.set_turn_indicator(is_my_turn)
	_center_bar.start_timer()

	_rebuild_hand()
	for slot in _player_hero_slots:
		slot.refresh()
	for slot in _opponent_hero_slots:
		slot.refresh()
	_refresh_team_face_down()
	_refresh_active_heroes()
	_refresh_combat_stats()
	_refresh_arsenals()
	_refresh_graveyard()

	var phase := GameState.turn.phase_to_string(GameState.turn.current_phase)
	_player_hand.visible = (phase != "OPENING_MULLIGAN")
	_refresh_pass_button(phase)
	_refresh_hand_interactivity()
	_refresh_dim_overlay()

func _refresh_team_face_down() -> void:
	var local_idx    := NetworkState.local_player_index
	var opponent_idx := 1 - local_idx
	var p_heroes := GameState.players[local_idx].heroes
	for i in min(_player_hero_slots.size(), p_heroes.size()):
		(_player_hero_slots[i] as HeroSlot).set_face_down(p_heroes[i].state == Hero.State.ACTIVE)
	var o_heroes := GameState.players[opponent_idx].heroes
	for i in min(_opponent_hero_slots.size(), o_heroes.size()):
		(_opponent_hero_slots[i] as HeroSlot).set_face_down(o_heroes[i].state == Hero.State.ACTIVE)

func _refresh_dim_overlay() -> void:
	var local_idx    := NetworkState.local_player_index
	var opponent_idx := 1 - local_idx
	var pick_player  := GameState.get_pending_pick_player()
	var sym_player   := GameState.get_pending_symbol_player()
	var my_pick  := pick_player == local_idx or sym_player == local_idx
	var opp_pick := pick_player == opponent_idx or sym_player == opponent_idx
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
		_player_half.set_arsenal_visible(false)
	else:
		_player_half.set_arsenal_texture(_local_sleeve)
	if opponent_arsenal.is_empty():
		_opponent_half.set_arsenal_visible(false)
	else:
		_opponent_half.set_arsenal_texture(_opponent_sleeve)

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
	_last_played_source_pos = _player_half.get_arsenal_global_center() as Vector2
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
	if _player_active_hero == null or _opponent_active_hero == null:
		return
	var local_idx    := NetworkState.local_player_index
	var opponent_idx := 1 - local_idx
	var phase        := GameState.turn.current_phase

	var local_active      := GameState.players[local_idx].active_hero
	var local_is_revealed := GameState.get_hero_revealed(local_idx) \
						  or phase in [TurnManager.Phase.COMBAT, TurnManager.Phase.END]
	if local_active:
		_player_active_hero.bind(local_active)
		_player_active_hero.set_face_down(not local_is_revealed)
		_player_active_hero.visible = true
	else:
		_player_active_hero.visible = false

	var local_heroes := GameState.players[local_idx].heroes
	for i in _player_hero_slots.size():
		var is_active := local_active != null and i < local_heroes.size() and local_heroes[i] == local_active
		_player_hero_slots[i].visible = not is_active

	var opponent_active  := GameState.players[opponent_idx].active_hero
	var is_revealed      := GameState.get_hero_revealed(opponent_idx) \
						 or phase in [TurnManager.Phase.COMBAT, TurnManager.Phase.END]
	if opponent_active:
		_opponent_active_hero.bind(opponent_active)
		_opponent_active_hero.set_face_down(not is_revealed)
		_opponent_active_hero.visible = true
	else:
		_opponent_active_hero.visible = false

	var opponent_heroes := GameState.players[opponent_idx].heroes
	for i in _opponent_hero_slots.size():
		var is_active := opponent_active != null and i < opponent_heroes.size() and opponent_heroes[i] == opponent_active
		_opponent_hero_slots[i].visible = not is_active

	_refresh_combat_stats()

# ── chain / combate cards ────────────────────────────────────────────────────
func _on_card_played(player_index: int, card: Card) -> void:
	var local_idx := NetworkState.local_player_index
	var is_local  := player_index == local_idx

	if _animator != null:
		if is_local:
			var from_pos: Vector2 = _last_played_source_pos if _last_played_source_pos != Vector2.ZERO \
							else _player_hand.get_global_rect().get_center()
			var to_pos: Vector2   = _player_half.get_combat_cards_global_center()
			_animator.fly_discard(from_pos, to_pos, card.get_texture())
			_last_played_source_pos = Vector2.ZERO
		else:
			var from_pos: Vector2 = _opponent_half.get_global_rect().get_center()
			var to_pos: Vector2   = _opponent_half.get_combat_cards_global_center()
			_animator.fly_discard(from_pos, to_pos, card.get_texture())

	var sleeve := _local_sleeve if is_local else _opponent_sleeve
	if is_local:
		_player_half.add_combat_card_view(card, sleeve, false)
	else:
		_opponent_half.add_combat_card_view(card, sleeve, true)
	_card_popup.show_card(player_index, card)
	_refresh_combat_stats()

func _clear_chain_cards() -> void:
	_player_half.clear_combat_cards()
	_opponent_half.clear_combat_cards()

func _refresh_graveyard() -> void:
	var local_idx    := NetworkState.local_player_index
	var opponent_idx := 1 - local_idx
	var local_discard    := GameState.players[local_idx].discard_pile
	var opponent_discard := GameState.players[opponent_idx].discard_pile
	_player_half.set_graveyard_texture(
		local_discard.back().get_texture() if not local_discard.is_empty() else null)
	_opponent_half.set_graveyard_texture(
		opponent_discard.back().get_texture() if not opponent_discard.is_empty() else null)

# ── sequenciamento card_popup → turn_transition ──────────────────────────────
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

# ── painéis de ataque/defesa do herói ativo ──────────────────────────────────
func _refresh_combat_stats() -> void:
	var local_idx := NetworkState.local_player_index
	_update_combat_status(_player_combat_status,   local_idx,       _player_active_hero)
	_update_combat_status(_opponent_combat_status, 1 - local_idx,   _opponent_active_hero)

func _update_combat_status(status: Control, player_idx: int, slot) -> void:
	var phase := GameState.turn.phase_to_string(GameState.turn.current_phase)
	if phase not in ["ACTION", "COMBAT"]:
		status.visible = false
		return
	var pl := GameState.players[player_idx]
	if pl.active_hero == null or slot == null or not slot.visible or slot._face_down:
		status.visible = false
		return
	status.visible = true
	var atk  := _calc_attack(player_idx)
	var def_ := _calc_defense(player_idx)
	var atk_label  := status.get_node("AttackIcon/AttackValue")  as Label
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

# ── música de batalha ────────────────────────────────────────────────────────
func _start_battle_music() -> void:
	var candidates := [
		"res://audio/theme/battle_1.mp3",
		"res://audio/theme/battle_2.mp3",
	]
	for path in candidates:
		if ResourceLoader.exists(path):
			_battle_tracks.append(load(path))
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

# ── fim de jogo ───────────────────────────────────────────────────────────────
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
