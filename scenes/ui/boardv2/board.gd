# scenes/ui/boardv2/board.gd
extends Control

@onready var _player_half     := $VBox/PlayerHalf
@onready var _opponent_half   := $VBox/OpponentHalf
@onready var _center_bar      := $VBox/CenterBar
@onready var phase_overlay    := $PhaseOverlay
@onready var _dim_overlay     := $PhaseOverlay/DimOverlay
@onready var _card_preview := $PreviewLayer/CardPreview
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
const DeckShuffleScene        := preload("res://scenes/ui/deck_shuffle/deck_shuffle.tscn")
const BacklineAbilityScene    := preload("res://scenes/ui/boardv2/backline_ability/backline_ability.tscn")
const PickHeroScene           := preload("res://scenes/ui/pick_hero/pick_hero.tscn")
const PauseMenuScene          := preload("res://scenes/ui/pausemenu/PauseMenu.tscn")
const ArrowProjectileScene    := preload("res://scenes/ui/skill_animations/arrow_projectile.tscn")
const ArrowRainScene          := preload("res://scenes/vfx/arrow_rain/ArrowRain.tscn")
const HolyHealScene           := preload("res://scenes/vfx/holy_heal/HolyHeal.tscn")
const BattleFuryScene         := preload("res://scenes/vfx/battle_fury/BattleFury.tscn")
const SingleTargetHealScene   := preload("res://scenes/vfx/single_target_heal/SingleTargetHeal.tscn")
const GraveyardViewerScene    := preload("res://scenes/ui/boardv2/graveyard_viewer/graveyard_viewer.tscn")
const PickAllyScene           := preload("res://scenes/ui/boardv2/pick_ally/PickAlly.tscn")

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
var _pick_ally:       Node = null
var _turn_transition: Control = null
var _game_result:     Control = null
var _combat_resolve:  Control = null
var _game_over_shown: bool = false
var _pending_transition_type: String = ""
# Callable guardado quando uma tela precisa abrir mas o popup de habilidade ainda está rodando.
# Executado em _open_pending_screen(), chamado pelo sinal popup_finished + delay 0.33s.
var _pending_screen_opener: Callable = Callable()
var _waiting_label:   Label = null
var _mulligan_waiting: bool = false
var _board_initialized: bool = false
var _loading_overlay: CanvasLayer = null
var _prev_reaction_window: int = -1
var _prev_segment_player:  int = -1
var _battle_music:    AudioStreamPlayer = null
var _battle_tracks:   Array = []
var _battle_track_idx: int = 0

var _animator: CardAnimator = null
# BattleFury persistente por jogador (null = sem buff ativo)
var _battle_fury: Array[BattleFury] = [null, null]
var _last_played_source_pos := Vector2.ZERO
var _fly_anim_busy: bool    = false

var _deck_shuffle: Control = null
var _shuffle_intro_done: bool = false
var _deck_shuffle_on_done: Callable = Callable()

var _backline_ability:   Control = null
var _pick_hero:          Control = null
var _graveyard_viewer:   Control = null
var _pause_menu:       PauseMenu = null
var _backline_modal_shown:    bool = false
var _pick_hero_modal_shown:   bool = false
# true enquanto uma animação de habilidade (ex: ArrowRain) está rodando
var _skill_vfx_busy: bool = false

static func _load_texture(path: String, fallback: Texture2D) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else fallback

func _show_loading_overlay() -> void:
	_loading_overlay = CanvasLayer.new()
	_loading_overlay.layer = 20
	var bg := ColorRect.new()
	bg.color = Color(0.039, 0.039, 0.094, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.add_child(bg)
	var lbl := Label.new()
	lbl.text = "Aguardando partida..."
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(0.784, 0.616, 0.290))
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_overlay.add_child(lbl)
	add_child(_loading_overlay)

func _hide_loading_overlay() -> void:
	if _loading_overlay != null:
		_loading_overlay.queue_free()
		_loading_overlay = null

func _ready() -> void:

	_center_bar.pass_pressed.connect(_on_pass_button_pressed)
	_center_bar.time_expired.connect(_on_pass_button_pressed)
	_center_bar.stop_timer()

	_connect_bus()

	_player_hand.card_clicked.connect(_on_card_clicked)
	_connect_arsenal_events()

	_card_popup = CardPopupScene.instantiate()
	add_child(_card_popup)
	_hero_popup = HeroPopupScene.instantiate()
	add_child(_hero_popup)
	# Notificação permanente: qualquer popup ao terminar tenta avançar a transição pendente
	_card_popup.popup_finished.connect(_on_blocker_released)
	_hero_popup.connect("popup_finished", _on_blocker_released)

	_pick_card = PickCardScene.instantiate()
	phase_overlay.add_child(_pick_card)
	_discard_card = DiscartCardScene.instantiate()
	phase_overlay.add_child(_discard_card)
	_pick_symbol = PickSymbolScene.instantiate()
	phase_overlay.add_child(_pick_symbol)
	_pick_ally = PickAllyScene.instantiate()
	phase_overlay.add_child(_pick_ally)

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

	$PhaseOverlay/MulliganScreen.mulligan_submitted.connect(_on_mulligan_submitted)

	_deck_shuffle = DeckShuffleScene.instantiate()
	_deck_shuffle.visible = false
	_deck_shuffle.shuffle_done.connect(_on_deck_shuffle_done)
	phase_overlay.add_child(_deck_shuffle)

	_backline_ability = BacklineAbilityScene.instantiate()
	phase_overlay.add_child(_backline_ability)
	_backline_ability.ability_confirmed.connect(_on_backline_ability_confirmed)
	_backline_ability.ability_skipped.connect(_on_backline_ability_skipped)

	_pick_hero = PickHeroScene.instantiate()
	phase_overlay.add_child(_pick_hero)
	_pick_hero.hero_picked.connect(_on_backline_hero_picked)

	_graveyard_viewer = GraveyardViewerScene.instantiate()
	add_child(_graveyard_viewer)

	_player_half.graveyard_clicked.connect(_on_graveyard_clicked)
	_opponent_half.graveyard_clicked.connect(_on_graveyard_clicked)

	_pause_menu = PauseMenuScene.instantiate()
	add_child(_pause_menu)
	_pause_menu.forfeit_confirmed.connect(_on_forfeit_confirmed)

	_start_battle_music()
	_animator = CardAnimator.new()
	add_child(_animator)
	GameBus.game_over.connect(_on_game_over)
	_show_loading_overlay()

	var _deck_dict: Dictionary = {}
	if DeckStore.decks.size() > 0:
		_deck_dict = DeckStore.decks[0].to_dict()
	if multiplayer.is_server():
		# Standalone ou host: chama diretamente (offline peer não processa rpc_id)
		GameState.rpc_submit_deck(_deck_dict)
	else:
		# Cliente: envia ao servidor e aguarda o sync dele
		GameState.rpc_id(1, "rpc_submit_deck", _deck_dict)

# ── GameBus → Board ─────────────────────────────────────────────────────────
func _connect_bus() -> void:
	GameBus.state_synced.connect(_on_state_synced)
	GameBus.phase_changed.connect(_on_phase_changed)
	GameBus.card_drawn.connect(_on_card_drawn)
	GameBus.hero_damaged.connect(_on_hero_damaged)
	GameBus.hero_healed.connect(_on_hero_healed)
	GameBus.hero_defeated.connect(_on_hero_defeated)
	GameBus.combat_resolved.connect(_on_combat_resolved)
	GameBus.combat_preview_ready.connect(_on_combat_preview_ready)
	GameBus.reaction_window_opened.connect(_on_reaction_window_opened)
	GameBus.hero_revealed.connect(_on_hero_revealed)
	GameBus.card_played.connect(_on_card_played)
	GameBus.skill_activated.connect(_on_skill_activated)
	GameBus.card_hovered.connect(_on_hero_preview_hovered)
	GameBus.deck_shuffled.connect(_on_deck_shuffled)
	GameBus.backline_arrow_fired.connect(_on_backline_arrow_fired)

# ── inicialização visual ─────────────────────────────────────────────────────
func _apply_player_cosmetics() -> void:
	var local_idx    := NetworkState.local_player_index
	var opponent_idx := 1 - local_idx
	_local_sleeve    = _load_texture(SLEEVE_BASE_PATH % GameState.players[local_idx].sleeve_key,    SLEEVE_DEFAULT)
	_opponent_sleeve = _load_texture(SLEEVE_BASE_PATH % GameState.players[opponent_idx].sleeve_key, SLEEVE_DEFAULT)
	_player_half.set_playmat(_load_texture(PLAYMAT_BASE_PATH % GameState.players[local_idx].playmat_key,    PLAYMAT_DEFAULT))
	_opponent_half.set_playmat(_load_texture(PLAYMAT_BASE_PATH % GameState.players[opponent_idx].playmat_key, PLAYMAT_DEFAULT))
	$PhaseOverlay/HeroPickScreen.sleeve = _local_sleeve

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
func _on_mulligan_submitted() -> void:
	_mulligan_waiting = true
	_refresh_dim_overlay()

func _on_phase_changed(phase: String) -> void:
	if not _board_initialized:
		return
	if phase != "OPENING_MULLIGAN":
		_mulligan_waiting = false
	if phase != "ACTION":
		_prev_segment_player  = -1
		_prev_reaction_window = -1
	var local_mulligan_done := GameState.has_completed_opening_mulligan(NetworkState.local_player_index)
	if phase == "OPENING_MULLIGAN" and not _shuffle_intro_done:
		$PhaseOverlay/MulliganScreen.visible = false
		_show_deck_shuffle_intro()
	else:
		$PhaseOverlay/MulliganScreen.visible = (phase == "OPENING_MULLIGAN") and not local_mulligan_done
	# BACKLINE_ABILITY é uma fase interna: HeroPickScreen deve fechar; o modal de backline cuida da UI
	$PhaseOverlay/HeroPickScreen.visible = (phase == "HERO_SELECTION") and not GameState.has_submitted_hero_pick(NetworkState.local_player_index)
	if phase == "END" and not _game_over_shown:
		_schedule_screen(func() -> void:
			if GameState.turn.current_phase == TurnManager.Phase.END and not _game_over_shown:
				$PhaseOverlay/ArsenalScreen.visible = true
		)
	else:
		$PhaseOverlay/ArsenalScreen.visible = false
	_player_hand.visible = (phase != "OPENING_MULLIGAN")
	_center_bar.set_phase(_phase_display_name(phase))
	_refresh_pass_button(phase)
	_refresh_hand_interactivity()
	_refresh_arsenals()
	_refresh_dim_overlay()
	if phase == "END":
		_clear_chain_cards()

func _show_deck_shuffle_intro() -> void:
	_deck_shuffle_on_done = func() -> void:
		var phase := GameState.turn.phase_to_string(GameState.turn.current_phase)
		if phase == "OPENING_MULLIGAN":
			var done := GameState.has_completed_opening_mulligan(NetworkState.local_player_index)
			$PhaseOverlay/MulliganScreen.visible = not done
			_refresh_dim_overlay()
	_show_deck_shuffle(_local_sleeve)

func _show_deck_shuffle(sleeve: Texture2D) -> void:
	_deck_shuffle.card_back_texture = sleeve
	_deck_shuffle.visible = true
	_deck_shuffle.play_once()

func _on_deck_shuffle_done() -> void:
	_shuffle_intro_done = true
	_deck_shuffle.visible = false
	if _deck_shuffle_on_done.is_valid():
		_deck_shuffle_on_done.call()
	_deck_shuffle_on_done = Callable()

func _on_deck_shuffled(player_index: int) -> void:
	var local_idx := NetworkState.local_player_index
	var sleeve := _local_sleeve if player_index == local_idx else _opponent_sleeve
	_show_deck_shuffle(sleeve)

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

func _on_hero_healed(hero: Hero, amount: int) -> void:
	_refresh_hero_slot(hero)
	# END = Irena passive usa HolyHeal VFX separado; ACTION/COMBAT usam SingleTargetHeal
	var phase := GameState.turn.phase_to_string(GameState.turn.current_phase)
	if phase not in ["ACTION", "COMBAT"] or _skill_vfx_busy:
		return
	_play_single_target_heal_vfx(hero, amount)

func _play_single_target_heal_vfx(hero: Hero, amount: int) -> void:
	if not _board_initialized:
		return
	var slot := _find_slot_for_hero(hero)
	if slot == null:
		return
	var target_pos  := (slot as Control).get_global_rect().get_center()
	var card_size   := Vector2(90.0, 126.0) \
		if slot == _player_active_hero or slot == _opponent_active_hero \
		else Vector2(70.0, 98.0)
	var end_hp   := hero.current_hp
	var start_hp := maxi(0, end_hp - amount)
	var fx: SingleTargetHeal = SingleTargetHealScene.instantiate()
	add_child(fx)
	fx.play(target_pos, card_size, null, start_hp, end_hp)

func _play_single_target_heal_vfx_for_card(player_idx: int) -> void:
	if not _board_initialized:
		return
	var local_idx := NetworkState.local_player_index
	var active_slot: Control = _player_active_hero if player_idx == local_idx else _opponent_active_hero
	if active_slot == null or not active_slot.visible:
		return
	var target_pos := active_slot.get_global_rect().get_center()
	var fx: SingleTargetHeal = SingleTargetHealScene.instantiate()
	add_child(fx)
	fx.play(target_pos, Vector2(90.0, 126.0), null, 0, 0)

func _on_hero_defeated(hero: Hero) -> void:
	_refresh_hero_slot(hero)

func _on_combat_resolved(_damage_p0: int, _damage_p1: int) -> void:
	for slot in _player_hero_slots:
		slot.refresh()
	for slot in _opponent_hero_slots:
		slot.refresh()
	_refresh_combat_stats()
	# Encerra auras de Impacto Sísmico de ambos os lados após o combate resolver
	_remove_battle_fury(0)
	_remove_battle_fury(1)

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

	var anim_key := ""
	if skill_name == hero.skill_desc:
		anim_key = hero.skill_animation
	elif skill_name == hero.passive_desc:
		anim_key = hero.passive_animation
	_play_vfx(anim_key, is_local)

	var base_y := 600.0 if is_local else 200.0
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

func _play_vfx(anim_key: String, is_local: bool) -> void:
	match anim_key:
		"arrow_rain":   _play_arrow_rain_vfx(is_local)
		"battle_fury":  _play_battle_fury_vfx(is_local)
		"holy_heal":    _play_holy_heal_vfx(is_local)

func _play_arrow_rain_vfx(is_local: bool) -> void:
	if not _board_initialized:
		return
	var source_hero: HeroSlot = _player_active_hero if is_local else _opponent_active_hero
	var target_half: Control  = _opponent_half      if is_local else _player_half
	if source_hero == null or not source_hero.visible:
		return
	var source_pos: Vector2 = source_hero.get_global_rect().get_center()
	var target_rect: Rect2  = target_half.get_global_rect()
	_skill_vfx_busy = true
	var fx: ArrowRain = ArrowRainScene.instantiate()
	add_child(fx)
	fx.finished.connect(_on_skill_vfx_finished, CONNECT_ONE_SHOT)
	fx.play(source_pos, target_rect)

func _play_holy_heal_vfx(is_local: bool) -> void:
	if not _board_initialized:
		return
	var source_hero: HeroSlot  = _player_active_hero   if is_local else _opponent_active_hero
	var ally_half:   Control   = _player_half           if is_local else _opponent_half
	var ally_slots:  Array     = _player_hero_slots     if is_local else _opponent_hero_slots
	if source_hero == null or not source_hero.visible:
		return
	var source_pos: Vector2 = source_hero.get_global_rect().get_center()
	var ally_zone: Rect2    = ally_half.get_global_rect()
	var allies: Array = []
	for slot in ally_slots:
		if slot.visible:
			allies.append({ "pos": (slot as HeroSlot).get_global_rect().get_center() })
	if source_hero.visible:
		allies.append({ "pos": source_pos })
	_skill_vfx_busy = true
	var fx: HolyHeal = HolyHealScene.instantiate()
	add_child(fx)
	fx.finished.connect(_on_skill_vfx_finished, CONNECT_ONE_SHOT)
	fx.play(source_pos, ally_zone, allies)

func _on_skill_vfx_finished() -> void:
	_skill_vfx_busy = false
	_on_blocker_released()
	# Verifica se há tela de fase aguardando o VFX terminar
	if _pending_screen_opener.is_valid():
		var hero_busy: bool = _hero_popup != null \
			and _hero_popup.has_method("is_busy") \
			and _hero_popup.call("is_busy")
		if not hero_busy:
			_open_pending_screen()

## Ativa a aura persistente de Impacto Sísmico ao redor do slot ativo de Poppy.
## Não bloqueia o fluxo de jogo — apenas VFX cosmético até o combat_resolved.
func _play_battle_fury_vfx(is_local: bool) -> void:
	if not _board_initialized:
		return
	var player_idx: int  = NetworkState.local_player_index if is_local \
		else (1 - NetworkState.local_player_index)
	# Evita duplicata: remove aura anterior do mesmo jogador, se houver
	if is_instance_valid(_battle_fury[player_idx]):
		_battle_fury[player_idx].deactivate()
		_battle_fury[player_idx] = null

	var source_slot: HeroSlot = _player_active_hero if is_local else _opponent_active_hero
	if source_slot == null or not source_slot.visible:
		return

	var fx: BattleFury = BattleFuryScene.instantiate()
	# Configura os valores da habilidade de Poppy
	fx.ability_name     = "IMPACTO SÍSMICO"
	fx.ability_subtitle = "Habilidade Ativa"
	fx.atk_base         = 0
	fx.atk_buffed       = 3
	add_child(fx)
	# card_size fixo da carta ativa (90×126 px) — o slot pode ter padding extra
	fx.activate(source_slot, Vector2(90.0, 126.0))
	_battle_fury[player_idx] = fx

	fx.deactivated.connect(func() -> void:
		_battle_fury[player_idx] = null
	, CONNECT_ONE_SHOT)

## Remove a aura de Poppy de um lado (chamado no combat_resolved).
func _remove_battle_fury(player_idx: int) -> void:
	if is_instance_valid(_battle_fury[player_idx]):
		_battle_fury[player_idx].deactivate()
		_battle_fury[player_idx] = null

# ── mão do jogador ───────────────────────────────────────────────────────────
func _rebuild_hand() -> void:
	if not _board_initialized:
		return
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

	if phase not in ["ACTION"]:
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
	if GameState.players.size() < 2:
		return
	if not _board_initialized:
		_apply_player_cosmetics()
		_spawn_hero_slots()
		_board_initialized = true
		_hide_loading_overlay()
		# Dispara a fase atual agora que o board está pronto
		_on_phase_changed(GameState.turn.phase_to_string(GameState.turn.current_phase))

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

	var local_idx      := NetworkState.local_player_index
	var segment_player := GameState.get_next_action_player_index()
	if phase_str == "ACTION":
		if reaction_for == local_idx:
			_center_bar.set_turn_label("Sua Reação", Color("55cc77"))
		elif reaction_for == 1 - local_idx:
			_center_bar.set_turn_label("Reação do Oponente", Color(0.8, 0.314, 0.133))
		elif segment_player == local_idx:
			_center_bar.set_turn_label("Seu Turno", Color("55cc77"))
		else:
			_center_bar.set_turn_label("Turno do Oponente", Color(0.8, 0.314, 0.133))
	else:
		_center_bar.set_turn_indicator(segment_player == local_idx)
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
	_refresh_backline_ability_ui()

func _refresh_team_face_down() -> void:
	var local_idx    := NetworkState.local_player_index
	var opponent_idx := 1 - local_idx
	var p_heroes := GameState.players[local_idx].heroes
	for i in min(_player_hero_slots.size(), p_heroes.size()):
		var h: Hero = p_heroes[i]
		(_player_hero_slots[i] as HeroSlot).set_face_down(
				h.state == Hero.State.ACTIVE and not h.is_backline_revealed)
	var o_heroes := GameState.players[opponent_idx].heroes
	for i in min(_opponent_hero_slots.size(), o_heroes.size()):
		var h: Hero = o_heroes[i]
		(_opponent_hero_slots[i] as HeroSlot).set_face_down(
				h.state == Hero.State.ACTIVE and not h.is_backline_revealed)

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
		if _mulligan_waiting:
			_waiting_label.text = "Aguardando oponente finalizar mulligan..."
			_waiting_label.visible = true
		elif opp_pick:
			_waiting_label.text = "Aguardando oponente escolher símbolos..." \
				if sym_player == opponent_idx \
				else "Aguardando oponente escolher uma carta..."
			_waiting_label.visible = true
		else:
			_waiting_label.visible = false

## Agenda a abertura de uma tela respeitando popups de habilidade e VFX ativos.
## Se há bloqueador: guarda o Callable e aguarda; caso contrário executa imediatamente.
func _schedule_screen(opener: Callable) -> void:
	_pending_screen_opener = Callable()
	var hero_busy: bool = _hero_popup != null \
		and _hero_popup.has_method("is_busy") \
		and _hero_popup.call("is_busy")
	if hero_busy or _skill_vfx_busy:
		_pending_screen_opener = opener
		if _skill_vfx_busy:
			# _on_skill_vfx_finished chamará _open_pending_screen via _check_pending_screen
			pass
		else:
			_hero_popup.connect("popup_finished", _open_pending_screen, CONNECT_ONE_SHOT)
	else:
		opener.call()

## Chamado pelo sinal popup_finished. Espera 0.33s e executa a tela pendente.
func _open_pending_screen() -> void:
	var opener := _pending_screen_opener
	_pending_screen_opener = Callable()
	if not opener.is_valid():
		return
	await get_tree().create_timer(0.33).timeout
	opener.call()

func _refresh_arsenals() -> void:
	if not _board_initialized:
		return
	var local_idx    := NetworkState.local_player_index
	var opponent_idx := 1 - local_idx
	var local_p    := GameState.players[local_idx]
	var opponent_p := GameState.players[opponent_idx]
	# Por padrão o arsenal exibe o sleeve (face-down).
	# Apenas quando arsenal_face_up == true (efeito explícito) exibe a CardView completa.
	if local_p.arsenal.is_empty():
		_player_half.set_arsenal_visible(false)
	elif local_p.arsenal_face_up:
		_player_half.set_arsenal_face_up(local_p.arsenal[0])
	else:
		_player_half.set_arsenal_sleeve(_local_sleeve)
	if opponent_p.arsenal.is_empty():
		_opponent_half.set_arsenal_visible(false)
	elif opponent_p.arsenal_face_up:
		_opponent_half.set_arsenal_face_up(opponent_p.arsenal[0])
	else:
		_opponent_half.set_arsenal_sleeve(_opponent_sleeve)

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
	var sleeve    := _local_sleeve if is_local else _opponent_sleeve

	var after_anim := func() -> void:
		_fly_anim_busy = false
		if is_local:
			_player_half.add_combat_card_view(card, sleeve, false)
		else:
			_opponent_half.add_combat_card_view(card, sleeve, true)
		_card_popup.show_card(player_index, card)
		_refresh_combat_stats()
		if card.is_heal:
			_play_single_target_heal_vfx_for_card(player_index)
		# Fly terminou — tenta avançar a transição pendente (pode ainda aguardar card_popup/hero_popup/skill_vfx)
		_on_blocker_released()

	if _animator != null:
		_fly_anim_busy = true
		if is_local:
			var from_pos: Vector2 = _last_played_source_pos if _last_played_source_pos != Vector2.ZERO \
							else _player_hand.get_global_rect().get_center()
			var to_pos: Vector2   = _player_half.get_combat_cards_global_center()
			_animator.fly_discard(from_pos, to_pos, card.get_texture(), after_anim)
			_last_played_source_pos = Vector2.ZERO
		else:
			var from_pos: Vector2 = _opponent_half.get_global_rect().get_center()
			var to_pos: Vector2   = _opponent_half.get_combat_cards_global_center()
			_animator.fly_discard(from_pos, to_pos, card.get_texture(), after_anim)
	else:
		after_anim.call()

func _clear_chain_cards() -> void:
	_player_half.clear_combat_cards()
	_opponent_half.clear_combat_cards()

func _refresh_graveyard() -> void:
	if not _board_initialized:
		return
	var local_idx    := NetworkState.local_player_index
	var opponent_idx := 1 - local_idx
	var local_discard    := GameState.players[local_idx].discard_pile
	var opponent_discard := GameState.players[opponent_idx].discard_pile
	_player_half.set_graveyard_card(
		local_discard.back() if not local_discard.is_empty() else null)
	_opponent_half.set_graveyard_card(
		opponent_discard.back() if not opponent_discard.is_empty() else null)

func _on_graveyard_clicked(side: String) -> void:
	var local_idx    := NetworkState.local_player_index
	var player_idx   := local_idx if side == "player" else 1 - local_idx
	var title        := "Cemitério — Você" if side == "player" else "Cemitério — Oponente"
	var cards: Array = GameState.players[player_idx].discard_pile
	_graveyard_viewer.open(cards, title)

# ── sequenciamento fly → card_popup → turn_transition ────────────────────────
func _queue_turn_transition(type: String) -> void:
	_pending_transition_type = type
	_try_play_pending_transition()

## Verifica se todos os bloqueadores terminaram e, se sim, dispara a transição.
## Chamado por qualquer bloqueador ao concluir (_on_blocker_released).
func _try_play_pending_transition() -> void:
	if _pending_transition_type.is_empty():
		return
	var hero_busy: bool = _hero_popup != null and _hero_popup.is_busy()
	if _fly_anim_busy or _card_popup._busy or hero_busy or _skill_vfx_busy:
		return  # ainda há bloqueadores — será chamado novamente quando eles terminarem
	var t := _pending_transition_type
	_pending_transition_type = ""
	_play_turn_transition_delayed(t)

## Ponto único chamado quando qualquer bloqueador de transição termina.
func _on_blocker_released() -> void:
	_try_play_pending_transition()

func _play_turn_transition_delayed(type: String) -> void:
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(_turn_transition.play.bind(type))

# ── badges de ataque/defesa do herói ativo ───────────────────────────────────
func _refresh_combat_stats() -> void:
	var local_idx := NetworkState.local_player_index
	_update_slot_combat_stats(local_idx,       _player_active_hero)
	_update_slot_combat_stats(1 - local_idx,   _opponent_active_hero)

func _update_slot_combat_stats(player_idx: int, slot) -> void:
	if slot == null or not is_instance_valid(slot):
		return
	var pl := GameState.players[player_idx]
	if pl.active_hero == null:
		return
	var phase := GameState.turn.phase_to_string(GameState.turn.current_phase)
	var atk: int
	var def_: int
	if phase in ["ACTION", "COMBAT"]:
		atk  = _calc_attack(player_idx)
		def_ = _calc_defense(player_idx)
	else:
		atk  = pl.active_hero.base_attack + pl.active_hero.get_passive_attack_bonus() \
			 + pl.turn_bonus_attack + pl.next_round_bonus_attack
		def_ = pl.active_hero.base_defense
	(slot as HeroSlot).set_modified_attack(atk)
	(slot as HeroSlot).set_modified_defense(def_)

func _on_hero_preview_hovered(data: Dictionary) -> void:
	if data.get("type") != "hero":
		return
	var preview_slot := _card_preview.get_node_or_null("HeroSlot") as HeroSlot
	if preview_slot == null:
		return
	var hero: Hero = data["hero"]
	for i in 2:
		var pl := GameState.players[i]
		if pl.active_hero != hero:
			continue
		var phase := GameState.turn.phase_to_string(GameState.turn.current_phase)
		if phase in ["ACTION", "COMBAT"]:
			preview_slot.set_modified_attack(_calc_attack(i))
			preview_slot.set_modified_defense(_calc_defense(i))
		else:
			preview_slot.set_modified_attack(pl.active_hero.base_attack + pl.active_hero.get_passive_attack_bonus()
				+ pl.turn_bonus_attack + pl.next_round_bonus_attack)
			preview_slot.set_modified_defense(pl.active_hero.base_defense)
		return

func _calc_attack(player_idx: int) -> int:
	var pl := GameState.players[player_idx]
	var total := pl.active_hero.base_attack
	for card in pl.round_cards:
		total += card.attack_value
	total += pl.pending_bonus_attack
	total += pl.passive_attack_bonus
	total += pl.turn_bonus_attack          # Frenesi: persiste o turno inteiro
	total += pl.next_round_bonus_attack    # Guarda Inabalável: acumulado do round anterior
	return total

func _calc_defense(player_idx: int) -> int:
	var pl := GameState.players[player_idx]
	var total := pl.active_hero.base_defense
	for card in pl.round_cards:
		total += card.defense_value
	total -= pl.next_defense_penalty
	total += pl.pending_bonus_defense
	return total

static func _phase_display_name(phase: String) -> String:
	match phase:
		"OPENING_MULLIGAN":  return "Mulligan"
		"DRAW":              return "Compra"
		"HERO_SELECTION":    return "Escolha de Herói"
		"BACKLINE_ABILITY":  return "Retaguarda"
		"ACTION":            return "Ação"
		"COMBAT":            return "Combate"
		"END":               return "Fim de Turno"
		_:                   return phase

# ── habilidades de retaguarda ────────────────────────────────────────────────

func _refresh_backline_ability_ui() -> void:
	if not _board_initialized:
		return
	var local_idx   := NetworkState.local_player_index
	var awaiting_r  := GameState.get_backline_awaiting_response()
	var awaiting_t  := GameState.get_backline_awaiting_target()
	var bl_player   := GameState.get_backline_current_player()
	var bl_hero_idx := GameState.get_backline_current_hero_idx()

	# ── Pergunta de confirmação (Sim/Não) ──────────────────
	if awaiting_r and bl_player == local_idx and not _backline_modal_shown:
		_backline_modal_shown = true
		var hero := GameState.players[local_idx].heroes[bl_hero_idx]
		_backline_ability.setup(hero)
	elif not awaiting_r:
		_backline_modal_shown = false

	# ── Seleção de alvo ────────────────────────────────────
	if awaiting_t and bl_player == local_idx and not _pick_hero_modal_shown:
		_pick_hero_modal_shown = true
		_schedule_screen(_open_pick_hero_for_backline)
	elif not awaiting_t:
		_pick_hero_modal_shown = false

func _open_pick_hero_for_backline() -> void:
	var local_idx := NetworkState.local_player_index
	var opp_idx   := 1 - local_idx
	var ally_heroes := GameState.players[local_idx].heroes
	var opp_heroes  := GameState.players[opp_idx].heroes

	# Revela heróis do oponente apenas se marcados como backline_revealed
	var opp_revealed: Array[bool] = []
	for i in opp_heroes.size():
		var h: Hero = opp_heroes[i]
		if h == GameState.players[opp_idx].active_hero:
			opp_revealed.append(GameState.get_hero_revealed(opp_idx))
		else:
			# Exausto = já jogou este turno, identidade conhecida → face-up
			opp_revealed.append(h.is_backline_revealed or h.state == Hero.State.EXHAUSTED)

	_pick_hero.open(
		"Escolha um herói para receber 1 de dano",
		ally_heroes,
		_local_sleeve,
		opp_heroes,
		_opponent_sleeve,
		opp_revealed,
		GameState.players[local_idx].active_hero,
		GameState.players[opp_idx].active_hero
	)

func _on_backline_ability_confirmed() -> void:
	GameState.rpc_id(1, "rpc_respond_backline_ability", true)

func _on_backline_ability_skipped() -> void:
	GameState.rpc_id(1, "rpc_respond_backline_ability", false)

func _find_slot_for_hero(hero: Hero) -> Control:
	if _player_active_hero != null and is_instance_valid(_player_active_hero) \
			and (_player_active_hero as HeroSlot).hero == hero:
		return _player_active_hero
	if _opponent_active_hero != null and is_instance_valid(_opponent_active_hero) \
			and (_opponent_active_hero as HeroSlot).hero == hero:
		return _opponent_active_hero
	for slot in _player_hero_slots + _opponent_hero_slots:
		if (slot as HeroSlot).hero == hero:
			return slot
	return null

func _spawn_damage_number(pos: Vector2, amount: int) -> void:
	var lbl := Label.new()
	lbl.text = "-%d" % amount
	lbl.add_theme_font_size_override("font_size", 38)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.18, 0.18))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.position = pos - Vector2(24, 24)
	$UI.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 80.0, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.tween_callback(lbl.queue_free)

func _on_backline_hero_picked(hero: Hero) -> void:
	var target_player := -1
	var target_idx    := -1
	for i in 2:
		var idx := GameState.players[i].heroes.find(hero)
		if idx >= 0:
			target_player = i
			target_idx    = idx
			break
	if target_player < 0:
		return

	var local_idx   := NetworkState.local_player_index
	var bl_hero_idx := GameState.get_backline_current_hero_idx()
	var source_hero := GameState.players[local_idx].heroes[bl_hero_idx]
	var source_slot := _find_slot_for_hero(source_hero)
	var target_slot := _find_slot_for_hero(hero)

	if source_slot != null and target_slot != null:
		var from_pos := source_slot.get_global_rect().get_center()
		var to_pos   := target_slot.get_global_rect().get_center()
		var arrow    := ArrowProjectileScene.instantiate()
		$UI.add_child(arrow)
		arrow.animation_finished.connect(func() -> void:
			_spawn_damage_number(to_pos, 1)
			GameState.rpc_id(1, "rpc_submit_backline_target", target_player, target_idx)
		)
		arrow.play(from_pos, to_pos)
	else:
		GameState.rpc_id(1, "rpc_submit_backline_target", target_player, target_idx)

func _on_backline_arrow_fired(source_player_idx: int, source_hero_idx: int, target_player_idx: int, target_hero_idx: int) -> void:
	var local_idx := NetworkState.local_player_index
	# Local player already animated in _on_backline_hero_picked; only animate for opponent
	if source_player_idx == local_idx:
		return
	if source_hero_idx < 0 or source_hero_idx >= GameState.players[source_player_idx].heroes.size():
		return
	if target_hero_idx < 0 or target_hero_idx >= GameState.players[target_player_idx].heroes.size():
		return
	var source_hero := GameState.players[source_player_idx].heroes[source_hero_idx]
	var target_hero := GameState.players[target_player_idx].heroes[target_hero_idx]
	var source_slot := _find_slot_for_hero(source_hero)
	var target_slot := _find_slot_for_hero(target_hero)
	if source_slot != null and target_slot != null:
		var from_pos := source_slot.get_global_rect().get_center()
		var to_pos   := target_slot.get_global_rect().get_center()
		var arrow    := ArrowProjectileScene.instantiate()
		$UI.add_child(arrow)
		arrow.animation_finished.connect(func() -> void:
			_spawn_damage_number(to_pos, 1)
		)
		arrow.play(from_pos, to_pos)

# ── pause / forfeit ──────────────────────────────────────────────────────────

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_ESCAPE:
		return
	if _pause_menu == null or _game_over_shown:
		return
	get_viewport().set_input_as_handled()
	if _pause_menu.is_open():
		_pause_menu.close()
	else:
		_pause_menu.open()

func _on_forfeit_confirmed() -> void:
	if multiplayer.is_server():
		GameState.rpc_forfeit()
	else:
		GameState.rpc_id(1, "rpc_forfeit")

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
	_battle_music.bus = "Music"
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
	# Se a animação de resolução de combate ainda está rodando, espera ela
	# terminar (botão "Continuar" é clicado) para só então mostrar o resultado.
	if _combat_resolve != null and _combat_resolve._busy:
		_combat_resolve.animation_finished.connect(
			func() -> void: _show_game_result(winner_index),
			CONNECT_ONE_SHOT
		)
	else:
		_show_game_result(winner_index)

func _show_game_result(winner_index: int) -> void:
	if winner_index == NetworkState.local_player_index:
		_game_result.show_victory()
	else:
		_game_result.show_defeat()

func _on_result_closed() -> void:
	if NetworkState.match_origin_world:
		# Partida veio do mundo: mantém a conexão ENet com o servidor viva e
		# devolve o jogador ao mundo aberto (Modelo A).
		NetworkState.match_origin_world = false
		get_tree().change_scene_to_file("res://scenes/world/world_root.tscn")
	else:
		multiplayer.multiplayer_peer = null
		get_tree().change_scene_to_file("res://scenes/ui/lobby/lobby.tscn")
