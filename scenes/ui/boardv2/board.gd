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
const HeroPopupScene := preload("res://scenes/ui/hero_popup/hero_popup.tscn")
const PickCardScene       := preload("res://scenes/ui/boardv2/pick_card/PickCard.tscn")
const DiscartCardScene    := preload("res://scenes/ui/boardv2/discart_card/DiscartCard.tscn")
const PickSymbolScene     := preload("res://scenes/ui/boardv2/pick_symbol/PickSymbol.tscn")
const CoreOverloadScene   := preload("res://scenes/ui/boardv2/core_overload/CoreOverload.tscn")
const TurnTransitionScene := preload("res://scenes/ui/boardv2/turn_transaction/turn_transition.tscn")
const GameResultScene     := preload("res://scenes/ui/boardv2/game_result/game_result.tscn")
const CombatResolutionScene := preload("res://scenes/vfx/combat_resolution/CombatResolution.tscn")
const DeckShuffleScene        := preload("res://scenes/ui/deck_shuffle/deck_shuffle.tscn")
const StealthConfirmScene     := preload("res://scenes/ui/boardv2/stealth_confirm/stealth_confirm.tscn")
const DiceRollScene           := preload("res://scenes/ui/boardv2/dice_roll/DiceRoll.tscn")
const FragmentShopScene       := preload("res://scenes/ui/boardv2/fragment_shop/fragment_shop.tscn")
const DeckRevealScene         := preload("res://scenes/ui/boardv2/deck_reveal/deck_reveal.tscn")
const PickHeroScene           := preload("res://scenes/ui/pick_hero/pick_hero.tscn")
const PauseMenuScene          := preload("res://scenes/ui/pausemenu/PauseMenu.tscn")
const ArrowProjectileScene    := preload("res://scenes/ui/skill_animations/arrow_projectile.tscn")
const ArrowRainScene          := preload("res://scenes/vfx/arrow_rain/ArrowRain.tscn")
const HolyHealScene           := preload("res://scenes/vfx/holy_heal/HolyHeal.tscn")
const SingleTargetHealScene   := preload("res://scenes/vfx/single_target_heal/SingleTargetHeal.tscn")
const EmpowerBeamScene        := preload("res://scenes/vfx/empower_beam/EmpowerBeam.tscn")
const StealthSmokeScene       := preload("res://scenes/vfx/stealth_smoke/StealthSmoke.tscn")
const GuardianAegisScene      := preload("res://scenes/vfx/guardian_aegis/GuardianAegis.tscn")
const AssassinAttackScene     := preload("res://scenes/vfx/assassin_attack/AssassinAttack.tscn")
const MagicMissilesScene      := preload("res://scenes/vfx/magic_missiles/MagicMissiles.tscn")
const RosasNegrasScene        := preload("res://scenes/vfx/rosas_negras/RosasNegras.tscn")
const SeloRuinaScene          := preload("res://scenes/vfx/selo_ruina/SeloRuina.tscn")
const AbyssCurseScene         := preload("res://scenes/vfx/abyss_curse/AbyssCurse.tscn")
const FloracaoMortalScene     := preload("res://scenes/vfx/floracao_mortal/FloracaoMortal.tscn")
const ArcaneFragmentsScene    := preload("res://scenes/vfx/arcane_fragments/ArcaneFragments.tscn")
const GraveyardViewerScene    := preload("res://scenes/ui/boardv2/graveyard_viewer/graveyard_viewer.tscn")
const PickAllyScene           := preload("res://scenes/ui/boardv2/pick_ally/PickAlly.tscn")
const DebugCardPickerScript   := preload("res://scenes/ui/boardv2/debug_card_picker/debug_card_picker.gd")

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
var _hero_popup:      CanvasLayer = null
var _pick_card:       Node = null
var _discard_card:    Node = null
var _pick_symbol:     Node = null
var _core_overload:   Node = null
var _pick_ally:       Node = null
var _turn_transition: Control = null
var _game_result:     Control = null
var _combat_vfx:      CombatResolution = null  # VFX one-shot da resolução (em andamento)
# VFX de efeitos AFTER_TURN que chegam DURANTE a resolução de combate são adiados aqui
# e tocados quando a animação de combate termina (evita sobreposição). Ver _on_effect_vfx.
var _deferred_post_combat_vfx: Array[Callable] = []
# Sequenciamento de animações (skill → combate → pós-combate):
# _pending_combat_preview: combate que ESPERA uma skill de herói terminar de encenar.
# _post_combat_active: janela (combate encenando + respiro) em que os VFX pós-combate ficam
#   adiados; some só depois que o combate fecha e "volta ao board". Ver _should_defer_post_combat.
var _pending_combat_preview: Dictionary = {}
var _post_combat_active: bool = false
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
# Égide do Guardião (Muro de Aço da Valkar) persistente por jogador (null = inativa)
var _guardian_aegis: Array[GuardianAegis] = [null, null]
# Registry data-driven de VFX de efeito: chave → handler. Preenchido em _vfx_registry().
var _card_vfx_handlers: Dictionary = {}
var _last_played_source_pos := Vector2.ZERO
var _fly_anim_busy: bool    = false

var _deck_shuffle: Control = null
var _shuffle_intro_done: bool = false
var _deck_shuffle_on_done: Callable = Callable()

var _stealth_confirm:    Control = null
var _dice_roll:          DiceRoll = null
var _dice_anim_played:   Array[bool] = [false, false]
var _dice_setup_done:    bool = false
var _fragment_shop:      Control = null
var _deck_reveal:        Control = null
var _toast_label:        Label = null
var _toast_tween:        Tween = null
# Mini-indicador (canto sup. direito) da quantidade de cartas na mão do oponente.
var _opp_hand_badge:        Control      = null
var _opp_hand_badge_sleeve: TextureRect  = null
var _opp_hand_badge_count:  Label        = null
var _pick_hero:          Control = null
var _graveyard_viewer:   Control = null
var _pause_menu:       PauseMenu = null
# Ferramentas de teste (sala debug): botão + overlay para dar qualquer carta à mão.
var _debug_button:     Button = null
var _debug_picker             = null   # DebugCardPicker (CanvasLayer com sinal card_picked)
var _backline_modal_shown:    bool = false
var _pick_hero_modal_shown:   bool = false
# Quando setado, o StealthConfirm aberto pertence à ativação de uma habilidade do
# herói ativo (ex.: Criar Míssil do Nox), não à retaguarda. Guarda o ability_id a
# disparar caso o jogador confirme quebrar a furtividade.
var _pending_confirm_ability: String = ""
# Se a habilidade pendente do StealthConfirm precisa de alvo (ex.: Selo da Ruína da
# Lilith): ao confirmar, abre o pick de herói em vez de disparar direto.
var _pending_confirm_needs_target: bool = false
var _pending_confirm_label: String = ""
# Guarda se o StealthConfirm da passiva de descarte furtiva (Relicar) já está na tela.
var _stealth_passive_modal_shown: bool = false
var _frontline_modal_shown: bool = false
# Estado do disparo de tokens (mísseis): coleta 1 alvo por míssil e envia tudo junto.
var _missile_fire_active: bool = false
var _missile_targets:     Array = []   # [[player_idx, hero_idx], ...]
var _missile_total:       int = 0
var _missile_fire_id:     String = ""
# Seleção de alvo de uma habilidade ACTION/BONUS com needs_target (ex.: Selo da Ruína da
# Lilith). Reusa o overlay _pick_hero; não-vazio = aguardando o jogador escolher o alvo.
var _ability_target_id:   String = ""
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
	lbl.text = "⚔  Preparando sua partida…"
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

	_hero_popup = HeroPopupScene.instantiate()
	add_child(_hero_popup)
	# Notificação permanente: o popup de habilidade ao terminar tenta avançar a transição pendente
	_hero_popup.connect("popup_finished", _on_blocker_released)

	_pick_card = PickCardScene.instantiate()
	phase_overlay.add_child(_pick_card)
	_discard_card = DiscartCardScene.instantiate()
	phase_overlay.add_child(_discard_card)
	_pick_symbol = PickSymbolScene.instantiate()
	phase_overlay.add_child(_pick_symbol)
	_core_overload = CoreOverloadScene.instantiate()
	phase_overlay.add_child(_core_overload)
	_pick_ally = PickAllyScene.instantiate()
	phase_overlay.add_child(_pick_ally)

	_turn_transition = TurnTransitionScene.instantiate()
	phase_overlay.add_child(_turn_transition)
	_game_result = GameResultScene.instantiate()
	phase_overlay.add_child(_game_result)
	_game_result.result_closed.connect(_on_result_closed)
	# A resolução de combate agora é um VFX one-shot instanciado sob demanda
	# em _on_combat_preview_ready() — não há mais overlay persistente.

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

	# Toast central-superior para avisos rápidos (ex.: uso de Fragmento Arcano).
	_toast_label = Label.new()
	_toast_label.add_theme_font_size_override("font_size", 22)
	_toast_label.add_theme_color_override("font_color", Color(0.86, 0.74, 1.0))
	_toast_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_toast_label.add_theme_constant_override("shadow_offset_x", 2)
	_toast_label.add_theme_constant_override("shadow_offset_y", 2)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_label.position = Vector2(0, 120)
	_toast_label.visible = false
	$UI.add_child(_toast_label)

	_setup_opponent_hand_badge()

	$PhaseOverlay/MulliganScreen.mulligan_submitted.connect(_on_mulligan_submitted)
	$PhaseOverlay/HeroPickScreen.peek_changed.connect(func(_p: bool) -> void: _refresh_dim_overlay())

	_deck_shuffle = DeckShuffleScene.instantiate()
	_deck_shuffle.visible = false
	_deck_shuffle.shuffle_done.connect(_on_deck_shuffle_done)
	phase_overlay.add_child(_deck_shuffle)

	_stealth_confirm = StealthConfirmScene.instantiate()
	phase_overlay.add_child(_stealth_confirm)
	_stealth_confirm.confirmed.connect(_on_stealth_confirm_yes)
	_stealth_confirm.cancelled.connect(_on_stealth_confirm_no)

	_dice_roll = DiceRollScene.instantiate()
	_dice_roll.visible = false
	phase_overlay.add_child(_dice_roll)
	_dice_roll.thrown.connect(_on_dice_thrown)
	_dice_roll.first_player_chosen.connect(_on_dice_first_player_chosen)

	_fragment_shop = FragmentShopScene.instantiate()
	phase_overlay.add_child(_fragment_shop)
	_fragment_shop.buy.connect(_on_fragment_shop_buy)
	_fragment_shop.closed.connect(_on_fragment_shop_closed)
	# Revelação "só olhar" — auto-gerenciada via state_synced.
	# Guardamos a ref para adiar a exibição até o VFX do Fragmento (peek) terminar.
	_deck_reveal = DeckRevealScene.instantiate()
	phase_overlay.add_child(_deck_reveal)

	_pick_hero = PickHeroScene.instantiate()
	phase_overlay.add_child(_pick_hero)
	_pick_hero.hero_picked.connect(_on_backline_hero_picked)

	_graveyard_viewer = GraveyardViewerScene.instantiate()
	add_child(_graveyard_viewer)

	_player_half.graveyard_clicked.connect(_on_graveyard_clicked)
	_opponent_half.graveyard_clicked.connect(_on_graveyard_clicked)
	_player_half.banish_clicked.connect(_on_banish_clicked)
	_opponent_half.banish_clicked.connect(_on_banish_clicked)

	_pause_menu = PauseMenuScene.instantiate()
	add_child(_pause_menu)
	_pause_menu.forfeit_confirmed.connect(_on_forfeit_confirmed)

	_start_battle_music()
	_animator = CardAnimator.new()
	add_child(_animator)
	GameBus.game_over.connect(_on_game_over)
	GameBus.match_rewards.connect(_on_match_rewards)
	_show_loading_overlay()
	_submit_match_deck()   # corrotina: resolve o deck (API ou local) e submete


# Resolve o deck do jogador e o submete ao servidor (gating em rpc_submit_deck).
# Se a Match Room escolheu um deck (DeckStore.match_deck_id), busca as cartas na API
# e converte para o formato local; senão cai no deck local (ex.: fila rápida).
const TutorialDirectorScript := preload("res://scenes/ui/boardv2/tutorial/tutorial_director.gd")
var _tutorial: Node = null   # diretor da partida-tutorial (só em NetworkState.tutorial_mode)

func _submit_match_deck() -> void:
	# Tutorial local/offline: o TutorialDirector monta a partida determinística (decks/mãos/dados),
	# dirige o bot e faz o coaching. is_server() é true (OfflineMultiplayerPeer setado na taverna).
	if NetworkState.tutorial_mode:
		_tutorial = TutorialDirectorScript.new()
		add_child(_tutorial)
		_tutorial.setup(self)
		_tutorial.begin()
		return
	var deck_dict := await _resolve_match_deck()
	DeckStore.match_deck_id = ""   # consome a escolha
	if multiplayer.is_server():
		GameState.rpc_submit_deck(deck_dict)
	else:
		GameState.rpc_id(1, "rpc_submit_deck", deck_dict)


func _resolve_match_deck() -> Dictionary:
	var id := DeckStore.match_deck_id
	if id == "":
		# Fila rápida sem escolha explícita → primeiro deck do jogador (da API).
		return await _first_deck_dict()

	# Heróis vêm como UUID no deck → precisa do inventário para resolver.
	if not Collection.is_inventory_loaded():
		var inv := await ApiClient.get_inventory()
		if inv.ok:
			Collection.load_inventory(inv.data)

	var res := await ApiClient.get_deck(id)
	if not res.ok:
		push_warning("Board: falha ao buscar deck %s (%s) — usando 1º deck" % [id, res.error])
		return await _first_deck_dict()
	return Collection.resolve_api_deck(res.data)


# Primeiro deck do jogador, da API (hidrata o cache do DeckStore se preciso). {} se não houver.
func _first_deck_dict() -> Dictionary:
	await DeckStore.ensure_loaded()
	return DeckStore.decks[0].to_dict() if DeckStore.decks.size() > 0 else {}

# ── GameBus → Board ─────────────────────────────────────────────────────────
func _connect_bus() -> void:
	GameBus.state_synced.connect(_on_state_synced)
	GameBus.phase_changed.connect(_on_phase_changed)
	GameBus.card_drawn.connect(_on_card_drawn)
	GameBus.hero_damaged.connect(_on_hero_damaged)
	GameBus.hero_healed.connect(_on_hero_healed)
	GameBus.effect_vfx.connect(_on_effect_vfx)
	GameBus.card_move_anim.connect(_on_card_move_anim)
	GameBus.empower_anim.connect(_on_empower_anim)
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
	GameBus.missiles_fired.connect(_on_missiles_fired)
	GameBus.roses_fired.connect(_on_roses_fired)
	GameBus.roses_detonated.connect(_on_roses_detonated)
	GameBus.seal_applied.connect(_on_seal_applied)
	GameBus.abyss_curse.connect(_on_abyss_curse)
	GameBus.fragment_used.connect(_on_fragment_used)
	GameBus.fragment_symbol_added.connect(_on_fragment_symbol_added)

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
	_player_active_hero.slot_clicked.connect(_on_active_hero_clicked)
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
			if GameState.battle.current_phase == BattleManager.Phase.END and not _game_over_shown:
				$PhaseOverlay/ArsenalScreen.visible = true
		)
	else:
		$PhaseOverlay/ArsenalScreen.visible = false
	_player_hand.visible = phase not in ["OPENING_MULLIGAN", "OPENING_ROLL"] \
		and not (_tutorial != null and phase == "END")   # tutorial: esconde a mão no arsenal (evita clicar na cópia)
	_center_bar.set_phase(_phase_display_name(phase))
	_refresh_pass_button(phase)
	_refresh_hand_interactivity()
	_refresh_arsenals()
	_refresh_dim_overlay()
	if phase == "END":
		_clear_chain_cards()

func _show_deck_shuffle_intro() -> void:
	_deck_shuffle_on_done = func() -> void:
		var phase := GameState.battle.phase_to_string(GameState.battle.current_phase)
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
	var phase := GameState.battle.phase_to_string(GameState.battle.current_phase)
	if phase not in ["ACTION", "COMBAT"] or _skill_vfx_busy:
		return
	_play_single_target_heal_vfx(hero, amount)

func _play_single_target_heal_vfx(hero: Hero, amount: int) -> void:
	if not _board_initialized:
		return
	var slot := _find_slot_for_hero(hero)
	if slot == null:
		return
	var target_pos  := _slot_center(slot as Control)
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
	var target_pos := _slot_center(active_slot)
	var fx: SingleTargetHeal = SingleTargetHealScene.instantiate()
	add_child(fx)
	fx.play(target_pos, Vector2(90.0, 126.0), null, 0, 0)

## Cura single-target num herói ESPECÍFICO (ex.: heal_ally_pick → aliado escolhido).
func _play_single_target_heal_vfx_for_hero(player_idx: int, hero_idx: int) -> void:
	if not _board_initialized:
		return
	if player_idx < 0 or player_idx >= GameState.players.size():
		return
	var heroes: Array = GameState.players[player_idx].heroes
	if hero_idx < 0 or hero_idx >= heroes.size():
		return
	var slot := _find_slot_for_hero(heroes[hero_idx])
	if slot == null:
		return
	var is_active := slot == _player_active_hero or slot == _opponent_active_hero
	var card_size := Vector2(90.0, 126.0) if is_active else Vector2(70.0, 98.0)
	var fx: SingleTargetHeal = SingleTargetHealScene.instantiate()
	add_child(fx)
	fx.play(_slot_center(slot), card_size, null, 0, 0)

## Cura em área (heal_all): reusa o HolyHeal da Irena, em todos os aliados vivos do
## jogador. Versão de CARTA — não-bloqueante (sem _skill_vfx_busy).
func _play_holy_heal_vfx_for_card(player_idx: int) -> void:
	if not _board_initialized:
		return
	var is_local  := player_idx == NetworkState.local_player_index
	var source_hero: HeroSlot = _player_active_hero if is_local else _opponent_active_hero
	var ally_half:  Control   = _player_half        if is_local else _opponent_half
	var ally_slots: Array     = _player_hero_slots  if is_local else _opponent_hero_slots
	if source_hero == null or not source_hero.visible:
		return
	var source_pos := _slot_center(source_hero)
	var ally_zone  := ally_half.get_global_rect()
	var allies: Array = []
	for slot in ally_slots:
		if slot.visible:
			allies.append({ "pos": _slot_center(slot as HeroSlot) })
	allies.append({ "pos": source_pos })
	var fx: HolyHeal = HolyHealScene.instantiate()
	add_child(fx)
	fx.play(source_pos, ally_zone, allies)

## Feixe de fortalecimento: sai da carta jogada e floresce sobre o herói ativo
## de quem a jogou (self-buff). Cosmético / não-bloqueante.
func _play_empower_beam_vfx(player_idx: int, atk: int, def: int, color_key: String) -> void:
	if not _board_initialized:
		return
	var is_local := player_idx == NetworkState.local_player_index
	var active_slot: Control = _player_active_hero if is_local else _opponent_active_hero
	if active_slot == null or not active_slot.visible:
		return
	var half: Control = _player_half if is_local else _opponent_half
	var source_pos: Vector2 = half.get_combat_cards_global_center()
	var target_pos: Vector2 = _slot_center(active_slot)
	var fx: EmpowerBeam = EmpowerBeamScene.instantiate()
	add_child(fx)
	fx.play(source_pos, target_pos, color_key, atk, def, Vector2(90.0, 126.0))

## Buff de atk/def aplicado por um EFEITO (servidor → GameBus.empower_anim). Mesma "default"
## do play; adia se a animação de combate estiver no ar (efeitos AFTER_TURN).
func _on_empower_anim(player_idx: int, atk: int, def: int, symbols: Array) -> void:
	if not _board_initialized:
		return
	if _should_defer_post_combat():
		_deferred_post_combat_vfx.append(_on_empower_anim.bind(player_idx, atk, def, symbols))
		return
	_play_empower_beam_vfx(player_idx, atk, def, EmpowerBeam.color_key_for_symbols(symbols))

## VFX no momento em que a carta é JOGADA: a "default" (empower) que representa o
## buff de ATK/DEF que quase toda carta dá. O VFX dos EFEITOS (heal, escudo…) NÃO sai
## aqui — sai quando o efeito realmente resolve (ver _on_effect_vfx), respeitando o
## timing (ex.: ACTION resolve só depois da janela de reação).
func _play_card_vfx(player_idx: int, card: Card) -> void:
	if card == null:
		return
	if card.attack_value > 0 or card.defense_value > 0:
		_play_empower_beam_vfx(player_idx, maxi(0, card.attack_value), maxi(0, card.defense_value),
			EmpowerBeam.color_key_for_symbols(card.symbols))

## Registry de VFX de efeito: chave → handler(player_idx, target_hero_idx). DATA-DRIVEN —
## adicionar uma animação nova = 1 linha aqui + 1 método handler. Sem match/if crescente.
## (Handlers que não usam o alvo ignoram target_hero_idx.)
func _vfx_registry() -> Dictionary:
	if _card_vfx_handlers.is_empty():
		_card_vfx_handlers = {
			"draw":        _vfx_draw,
			"heal":        _vfx_heal,
			"heal_all":    _vfx_heal_all,
			"shield":      _vfx_shield,
			"team_shield": _vfx_team_shield,
			"stealth":     _vfx_stealth,
		}
	return _card_vfx_handlers

## VFX no momento em que um EFEITO resolve (servidor → GameBus.effect_vfx, a partir de
## CardEffectContext.request_vfx). Resolve a chave pelo registry. target_hero_idx
## (-1 = ativo/padrão) mira um herói específico (ex.: heal_ally_pick → aliado escolhido).
func _on_effect_vfx(player_idx: int, vfx_key: String, target_hero_idx: int = -1) -> void:
	if not _board_initialized:
		return
	# Efeito resolvendo durante a animação de combate (AFTER_TURN) → adia até ela terminar.
	if _should_defer_post_combat():
		_deferred_post_combat_vfx.append(_on_effect_vfx.bind(player_idx, vfx_key, target_hero_idx))
		return
	var handler: Callable = _vfx_registry().get(vfx_key, Callable())
	if handler.is_valid():
		handler.call(player_idx, target_hero_idx)

# ── Handlers do registry de VFX (um por chave) ───────────────────────────────
func _vfx_heal(player_idx: int, target_hero_idx: int) -> void:
	if target_hero_idx >= 0:
		_play_single_target_heal_vfx_for_hero(player_idx, target_hero_idx)
	else:
		_play_single_target_heal_vfx_for_card(player_idx)

func _vfx_heal_all(player_idx: int, _target_hero_idx: int) -> void:
	_play_holy_heal_vfx_for_card(player_idx)

func _vfx_draw(player_idx: int, _target_hero_idx: int) -> void:
	if _animator == null:
		return
	var is_local := player_idx == NetworkState.local_player_index
	var half = _player_half if is_local else _opponent_half
	var from_pos: Vector2 = half.get_deck_global_center()
	var to_pos: Vector2   = _player_hand.get_global_rect().get_center() if is_local \
		else _opponent_half.get_global_rect().get_center()
	var sleeve: Texture2D = _local_sleeve if is_local else _opponent_sleeve
	_animator.fly_draw(from_pos, to_pos, sleeve)

func _vfx_shield(player_idx: int, _target_hero_idx: int) -> void:
	_play_single_shield_vfx(player_idx)

func _vfx_team_shield(player_idx: int, _target_hero_idx: int) -> void:
	_play_team_shield_vfx(player_idx)

func _vfx_stealth(player_idx: int, _target_hero_idx: int) -> void:
	_play_stealth_smoke_vfx(player_idx)

## VFX one-shot de escudo de equipe (Fluxo Reativo e afins): reusa a Égide do Guardião,
## com domos em TODOS os heróis vivos do dono (inclusive o ativo).
func _play_team_shield_vfx(player_idx: int) -> void:
	if not _board_initialized:
		return
	var local_idx := NetworkState.local_player_index
	var is_local  := player_idx == local_idx
	var active_slot: Control = _player_active_hero if is_local else _opponent_active_hero
	var bench: Array          = _player_hero_slots if is_local else _opponent_hero_slots
	if active_slot == null or not active_slot.visible:
		return
	# Alvos = ativo + retaguarda viva visível (todos recebem escudo).
	var targets: Array[Control] = []
	for s in bench:
		var slot := s as HeroSlot
		if slot != null and slot.visible and slot.hero != null and slot.hero.is_alive():
			targets.append(slot)
	targets.append(active_slot)
	var fx: GuardianAegis = GuardianAegisScene.instantiate()
	fx.show_banner = false
	add_child(fx)
	# one-shot: forma os domos, segura e some sozinho (escudo da carta é passageiro).
	fx.activate(active_slot, targets, not is_local, 2.6)

## Escudo single-target (damage_shield): mesma Égide, 1 domo só no herói ativo.
func _play_single_shield_vfx(player_idx: int) -> void:
	if not _board_initialized:
		return
	var is_local := player_idx == NetworkState.local_player_index
	var active_slot: Control = _player_active_hero if is_local else _opponent_active_hero
	if active_slot == null or not active_slot.visible:
		return
	var fx: GuardianAegis = GuardianAegisScene.instantiate()
	fx.show_banner = false
	add_child(fx)
	fx.activate(active_slot, [active_slot], not is_local, 2.6)

## Movimento animado de uma carta específica (servidor → GameBus.card_move_anim).
## kind: "discard" (mão→centro→corte→cemitério) · "to_deck" (carta → baralho).
func _on_card_move_anim(player_idx: int, art_key: String, kind: String) -> void:
	if not _board_initialized or _animator == null:
		return
	# Descarte/movimento de um efeito AFTER_TURN durante a animação de combate → adia.
	if _should_defer_post_combat():
		_deferred_post_combat_vfx.append(_on_card_move_anim.bind(player_idx, art_key, kind))
		return
	var tex := _card_tex_from_art_key(art_key)
	var dict := _card_dict_from_art_key(art_key)
	var is_local := player_idx == NetworkState.local_player_index
	var half = _player_half if is_local else _opponent_half
	var from_pos: Vector2 = _player_hand.get_global_rect().get_center() if is_local \
		else _opponent_half.get_global_rect().get_center()
	match kind:
		"discard":
			var center: Vector2 = get_viewport_rect().size * 0.5
			_animator.fly_discard_to_graveyard(from_pos, center, half.get_graveyard_global_center(), tex, Callable(), dict)
		"to_deck":
			_animator.fly_card_to_deck(from_pos, half.get_deck_global_center(), tex, Callable(), dict)
		"banish":
			# Banir = deck → pilha de banimento. Reusa a animação de descarte com destino
			# na pilha de banimento (mesma coreografia: sai da origem, corte no centro, cai).
			var bcenter: Vector2 = get_viewport_rect().size * 0.5
			_animator.fly_discard_to_graveyard(half.get_deck_global_center(), bcenter, half.get_banish_global_center(), tex, Callable(), dict)

func _card_tex_from_art_key(art_key: String) -> Texture2D:
	return CardArt.texture_for(art_key)

## Dict do catálogo (Collection.all_card_dicts) da carta com este art_key, para renderizar a
## CardView completa nas animações de voo. {} se não achar (aí a animação cai no ghost só-arte).
func _card_dict_from_art_key(art_key: String) -> Dictionary:
	if art_key == "":
		return {}
	for d in Collection.all_card_dicts:
		if str(d.get("art_key", "")) == art_key:
			return d
	return {}

## VFX de furtividade: bombinha sai das cartas de combate do dono, arremessa até o
## herói ativo e explode em fumaça (o herói ficou furtivo). Cosmético / não-bloqueante.
func _play_stealth_smoke_vfx(player_idx: int) -> void:
	if not _board_initialized:
		return
	var local_idx := NetworkState.local_player_index
	var is_local  := player_idx == local_idx
	var active_slot: Control = _player_active_hero if is_local else _opponent_active_hero
	if active_slot == null or not active_slot.visible:
		return
	var half: Control = _player_half if is_local else _opponent_half
	var source_pos: Vector2 = half.get_combat_cards_global_center()
	var target_pos: Vector2 = _slot_center(active_slot)
	var fx: StealthSmoke = StealthSmokeScene.instantiate()
	add_child(fx)
	fx.play(source_pos, target_pos)

func _on_hero_defeated(hero: Hero) -> void:
	_refresh_hero_slot(hero)

func _on_combat_resolved(_damage_p0: int, _damage_p1: int) -> void:
	for slot in _player_hero_slots:
		slot.refresh()
	for slot in _opponent_hero_slots:
		slot.refresh()
	_refresh_combat_stats()
	# Apaga a aura de fogo (Impacto Sísmico) de todos após o combate resolver.
	for p in GameState.players:
		for h in p.heroes:
			h.skill_fire_active = false
	if _player_active_hero != null and is_instance_valid(_player_active_hero):
		(_player_active_hero as HeroSlot).refresh()
	if _opponent_active_hero != null and is_instance_valid(_opponent_active_hero):
		(_opponent_active_hero as HeroSlot).refresh()

## Dispara o VFX de Resolução de Combate (substitui o antigo overlay).
## Chamado em combat_preview_ready — ANTES de o dano ser aplicado ao modelo,
## então hero.current_hp ainda é o HP pré-golpe (a barra anima a descida).
func _on_combat_preview_ready(data: Dictionary) -> void:
	var h0_idx: int = data.get("hero_0_idx", -1)
	var h1_idx: int = data.get("hero_1_idx", -1)
	if h0_idx < 0 or h1_idx < 0:
		return

	# Sequência: se uma skill de herói ainda está encenando (ex.: a última carta do turno
	# ativou a habilidade), o combate ESPERA. Guarda o preview; _on_skill_vfx_finished o
	# dispara quando a skill terminar (com um respiro INTER_VFX_GAP).
	if _skill_vfx_busy:
		_pending_combat_preview = data
		return
	_pending_combat_preview = {}

	var local_idx := NetworkState.local_player_index
	var enemy_idx := 1 - local_idx
	var ally_hero:  Hero = GameState.players[local_idx].heroes[data["hero_%d_idx" % local_idx]]
	var enemy_hero: Hero = GameState.players[enemy_idx].heroes[data["hero_%d_idx" % enemy_idx]]

	var cfg := CombatResolution.Config.new()
	cfg.ally_hero  = ally_hero
	cfg.enemy_hero = enemy_hero
	cfg.ally_atk   = data["atk_%d" % local_idx]   # totais já resolvidos (com bônus)
	cfg.ally_def   = data["def_%d" % local_idx]
	cfg.enemy_atk  = data["atk_%d" % enemy_idx]
	cfg.enemy_def  = data["def_%d" % enemy_idx]
	# atk1/atk2_type ficam em -1 (auto pela classe do herói, resolvido no VFX)
	cfg.dmg1 = data["dmg_to_%d" % enemy_idx]    # dano que o Aliado causa
	cfg.dmg2 = data["dmg_to_%d" % local_idx]    # dano que o Inimigo causa

	# Substitui qualquer encenação anterior ainda no ar (rodadas em sequência).
	if _combat_vfx != null and is_instance_valid(_combat_vfx):
		_combat_vfx.queue_free()
	var fx: CombatResolution = CombatResolutionScene.instantiate()
	add_child(fx)
	_combat_vfx = fx
	_post_combat_active = true   # abre a janela de adiamento dos VFX pós-combate
	fx.finished.connect(_on_combat_vfx_finished, CONNECT_ONE_SHOT)
	fx.play(cfg)

func _on_combat_vfx_finished() -> void:
	_combat_vfx = null
	# Respiro antes de "voltar ao board": o combate fecha e SÓ ENTÃO os efeitos on-hit
	# (AFTER_TURN) rodam — nunca por cima da resolução de combate.
	await get_tree().create_timer(INTER_VFX_GAP).timeout
	if not is_instance_valid(self):
		return
	# Se outro combate começou nesse meio-tempo (rodadas em sequência), mantém a janela.
	if _combat_vfx_playing():
		return
	_post_combat_active = false
	# Solta os VFX de efeitos AFTER_TURN que ficaram esperando a resolução de combate.
	var queued := _deferred_post_combat_vfx
	_deferred_post_combat_vfx = []
	for cb in queued:
		cb.call()

## True enquanto a animação de resolução de combate está literalmente no ar.
func _combat_vfx_playing() -> bool:
	return _combat_vfx != null and is_instance_valid(_combat_vfx)

## True enquanto uma sequência de combate está "em curso" para fins de adiamento dos VFX
## pós-combate: combate adiado esperando skill, combate encenando, ou o respiro logo após.
## Os efeitos on-hit/pós-combate aguardam isto ficar false para então rodar.
func _should_defer_post_combat() -> bool:
	return _combat_vfx_playing() or _post_combat_active or not _pending_combat_preview.is_empty()

## Tempo do "tell" de conjuração antes da animação do herói rodar (a carta se mexe e
## brilha; ver HeroSlot.play_cast_tell). Também serve de bloqueador de transição no
## lugar do antigo hero_popup.
const CAST_LEAD_IN := 0.42

## Respiro entre passos animados sequenciados (skill → combate → pós-combate): um beat
## curto pra separar as animações e dar tempo de entender cada uma.
const INTER_VFX_GAP := 0.25

## Intervalo entre cada carta banida pela Maldição do Abismo (Lilith) — banimento 1 a 1.
const ABYSS_BANISH_STAGGER := 0.35

func _on_skill_activated(hero: Hero, skill_name: String) -> void:
	var local_idx := NetworkState.local_player_index
	var is_local  := hero in GameState.players[local_idx].heroes

	var anim_key := ""
	if skill_name == hero.skill_desc:
		anim_key = hero.skill_animation
	elif skill_name == hero.passive_desc:
		anim_key = hero.passive_animation

	# A Maldição do Abismo (Lilith) é encenada pelo evento dedicado abyss_curse (que carrega
	# as cartas banidas e dispara ANTES deste sinal). Aqui só ignoramos — o game_log ainda
	# registra normalmente via seu próprio handler de skill_activated.
	if anim_key == "abyss_curse":
		return

	# Buildup: a carta do conjurador se mexe e brilha ANTES de rodar a animação. Segura o
	# gate de transição de fase (via _skill_vfx_busy) durante o lead-in — substitui o
	# antigo popup "Herói X ativou habilidade", que foi removido.
	_skill_vfx_busy = true
	# Espera o popup "Você jogou X carta" fechar antes de começar (evita sobreposição).
	await _await_card_play_sequence()
	if not is_instance_valid(self):
		return
	var caster_slot := _find_slot_for_hero(hero)
	if caster_slot != null:
		(caster_slot as HeroSlot).play_cast_tell()
	_spawn_skill_label(skill_name, is_local)

	await get_tree().create_timer(CAST_LEAD_IN).timeout
	if not is_instance_valid(self):
		return

	if anim_key == "battle_fury":
		# Aura de fogo persistente: liga o flag e o HeroSlot renderiza (slot + preview
		# + resolução de combate). Some no combat_resolved. O "+N ATQ" vem do label acima.
		hero.skill_fire_active = true
		if caster_slot != null:
			(caster_slot as HeroSlot).refresh()
		_on_skill_vfx_finished()
	elif anim_key == "arrow_rain" or anim_key == "holy_heal" or anim_key == "assassin_attack":
		_play_vfx(anim_key, is_local)   # re-seta _skill_vfx_busy e libera no _on_skill_vfx_finished
	else:
		# Habilidade sem VFX dedicado — o tell + label já deram o feedback; libera o gate.
		_on_skill_vfx_finished()

## Label flutuante "⚡ skill!" — confirmação textual leve (não bloqueia a transição).
func _spawn_skill_label(skill_name: String, is_local: bool) -> void:
	var base_y := 600.0 if is_local else 200.0
	var lbl := Label.new()
	lbl.text = "⚡ %s!" % skill_name
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	lbl.position = Vector2(860.0, base_y)
	$UI.add_child(lbl)
	var tween := create_tween()
	tween.tween_property(lbl, "position:y", base_y - 120.0, 1.6).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.6)
	tween.tween_callback(lbl.queue_free)

## Espera o fly da carta (indo para o board) terminar antes de a animação de herói começar,
## pra ela não rodar com a carta ainda no ar.
## IMPORTANTE: o servidor dispara a skill ao ADICIONAR a carta (_on_card_added_to_play) e só
## DEPOIS notifica card_played — então este handler roda ANTES de o fly existir. Por isso a
## espera tem 2 fases: (1) aguarda o fly COMEÇAR (card_played chega em ~1-2 frames e seta
## _fly_anim_busy); (2) aguarda ele TERMINAR. Caps de segurança evitam travar de vez (se a
## skill não veio de uma carta, a fase 1 só expira e segue).
func _await_card_play_sequence() -> void:
	var guard := 0
	while not _fly_anim_busy and guard < 20:
		await get_tree().process_frame
		guard += 1
	guard = 0
	while _fly_anim_busy and guard < 600:
		await get_tree().process_frame
		guard += 1

## Especial "Maldição do Abismo" (Lilith) — evento dedicado (chega ANTES do skill_activated).
## Encena símbolos de Trevas → centro → névoa até o deck do oponente; quando a névoa chega,
## bane as cartas 1 a 1 (deck → banimento). Participa da fila (via _skill_vfx_busy), então o
## combate/pós-combate esperam esta animação terminar.
func _on_abyss_curse(caster_idx: int, opponent_idx: int, banished_art_keys: Array) -> void:
	if not _board_initialized or _animator == null:
		return
	var players: Array = GameState.players
	if caster_idx < 0 or caster_idx >= players.size() or opponent_idx < 0 or opponent_idx >= players.size():
		return
	var local_idx := NetworkState.local_player_index
	_skill_vfx_busy = true
	# Espera o popup "Você jogou X carta" fechar antes de começar (evita sobreposição).
	await _await_card_play_sequence()
	if not is_instance_valid(self):
		return

	# Tell + label na Lilith (conjuradora = herói ativo cuja cadeia disparou).
	var caster_hero: Hero = players[caster_idx].active_hero
	var caster_slot := _find_slot_for_hero(caster_hero) if caster_hero != null else null
	if caster_slot != null:
		(caster_slot as HeroSlot).play_cast_tell()
	_spawn_skill_label("Maldição do Abismo", caster_idx == local_idx)

	var center: Vector2 = get_viewport_rect().size * 0.5
	var caster_pos: Vector2 = _slot_center(caster_slot) if caster_slot != null else center
	# Deck/banimento da VÍTIMA (oponente da Lilith).
	var victim_half: Control = _player_half if opponent_idx == local_idx else _opponent_half
	var deck_pos: Vector2   = victim_half.get_deck_global_center()
	var banish_pos: Vector2 = victim_half.get_banish_global_center()

	var fx: AbyssCurse = AbyssCurseScene.instantiate()
	add_child(fx)
	fx.mist_arrived.connect(
		func() -> void: _run_abyss_banishes(banished_art_keys, deck_pos, center, banish_pos),
		CONNECT_ONE_SHOT
	)
	fx.play(caster_pos, center, deck_pos)

## Bane as cartas da Maldição do Abismo 1 a 1 (deck → centro → pilha de banimento), com um
## intervalo entre cada. Ao terminar, libera o gate da fila de animação (_on_skill_vfx_finished).
func _run_abyss_banishes(art_keys: Array, deck_pos: Vector2, center: Vector2, banish_pos: Vector2) -> void:
	for i in art_keys.size():
		if not is_instance_valid(self) or _animator == null:
			return
		var tex := _card_tex_from_art_key(art_keys[i])
		var dict := _card_dict_from_art_key(art_keys[i])
		_animator.fly_discard_to_graveyard(deck_pos, center, banish_pos, tex, Callable(), dict)
		await get_tree().create_timer(ABYSS_BANISH_STAGGER).timeout
	await get_tree().create_timer(INTER_VFX_GAP).timeout
	if is_instance_valid(self):
		_on_skill_vfx_finished()

func _play_vfx(anim_key: String, is_local: bool) -> void:
	match anim_key:
		"arrow_rain":      _play_arrow_rain_vfx(is_local)
		"holy_heal":       _play_holy_heal_vfx(is_local)
		"assassin_attack": _play_assassin_attack_vfx(is_local)

func _play_arrow_rain_vfx(is_local: bool) -> void:
	if not _board_initialized:
		return
	var source_hero: HeroSlot = _player_active_hero if is_local else _opponent_active_hero
	var target_half: Control  = _opponent_half      if is_local else _player_half
	if source_hero == null or not source_hero.visible:
		return
	var source_pos: Vector2 = _slot_center(source_hero)
	var target_rect: Rect2  = target_half.get_global_rect()
	_skill_vfx_busy = true
	var fx: ArrowRain = ArrowRainScene.instantiate()
	add_child(fx)
	fx.finished.connect(_on_skill_vfx_finished, CONNECT_ONE_SHOT)
	fx.play(source_pos, target_rect)

## VFX fullscreen one-shot (genérico): o mundo se parte ao meio por um corte azul.
## Não depende de posições — cobre a tela inteira e se limpa sozinho.
func _play_assassin_attack_vfx(_is_local: bool) -> void:
	if not _board_initialized:
		return
	_skill_vfx_busy = true
	var fx: AssassinAttack = AssassinAttackScene.instantiate()
	add_child(fx)
	fx.finished.connect(_on_skill_vfx_finished, CONNECT_ONE_SHOT)
	fx.play()

func _play_holy_heal_vfx(is_local: bool) -> void:
	if not _board_initialized:
		return
	var source_hero: HeroSlot  = _player_active_hero   if is_local else _opponent_active_hero
	var ally_half:   Control   = _player_half           if is_local else _opponent_half
	var ally_slots:  Array     = _player_hero_slots     if is_local else _opponent_hero_slots
	if source_hero == null or not source_hero.visible:
		return
	var source_pos: Vector2 = _slot_center(source_hero)
	var ally_zone: Rect2    = ally_half.get_global_rect()
	var allies: Array = []
	for slot in ally_slots:
		if slot.visible:
			allies.append({ "pos": _slot_center(slot as HeroSlot) })
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
	# Se um combate ficou esperando esta skill terminar de encenar, dispara agora (com o
	# respiro). NÃO limpa _pending_combat_preview aqui — manter não-vazio segura o gate de
	# adiamento dos efeitos on-hit no intervalo; _on_combat_preview_ready limpa ao começar.
	if not _pending_combat_preview.is_empty():
		var data: Dictionary = _pending_combat_preview
		await get_tree().create_timer(INTER_VFX_GAP).timeout
		if is_instance_valid(self):
			_on_combat_preview_ready(data)

# ── mão do jogador ───────────────────────────────────────────────────────────
func _rebuild_hand() -> void:
	if not _board_initialized:
		return
	var local_idx := NetworkState.local_player_index
	_player_hand.rebuild(GameState.players[local_idx].hand, _local_sleeve)

# ── interações do jogador ────────────────────────────────────────────────────
func _on_hero_slot_clicked(hero: Hero) -> void:
	var local_idx := NetworkState.local_player_index
	# Ação bônus de retaguarda (ex.: Rosas Negras do Darian) — se disponível agora,
	# ativar clicando no próprio herói de retaguarda.
	var ba := _local_backline_ability(hero)
	if not ba.is_empty():
		var ability_id := str(ba.get("id", ""))
		var needs_target := bool(ba.get("needs_target", false))
		# Se a habilidade quebra a furtividade do PRÓPRIO herói de retaguarda (Darian/Lilith)
		# e ele ainda está oculto, confirma antes (mesma modal do Ieldor/Nox), mostrando o
		# herói clicado. Ao confirmar: se precisa de alvo, abre o pick; senão dispara direto.
		if bool(ba.get("reveals_self", false)) and not hero.is_backline_revealed:
			_pending_confirm_ability      = ability_id
			_pending_confirm_needs_target = needs_target
			_pending_confirm_label        = str(ba.get("label", ""))
			_stealth_confirm.setup(hero, str(ba.get("label", "")), hero.passive_desc)
			return
		# Já revelado (ou não revela): alvo → pick; senão dispara direto.
		if needs_target:
			_ability_target_id = ability_id
			_open_pick_hero_for_ability(str(ba.get("label", "")))
			return
		GameState.rpc_id(1, "rpc_activate_ability", ability_id, [])
		return
	# Caso contrário (fase HERO_SELECTION): escolher este herói como ativo.
	var slot_idx := GameState.players[local_idx].heroes.find(hero)
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
	if _tutorial != null:
		_tutorial.gate_pass(_center_bar)   # no tutorial o jogador nunca passa (o diretor controla)

func _refresh_hand_interactivity() -> void:
	var local_idx    := NetworkState.local_player_index
	var reaction_for := GameState.get_reaction_window_for()
	var is_my_segment := GameState.get_next_action_player_index() == local_idx
	var action_done  := GameState.get_segment_action_done(local_idx)
	var bonus_done   := GameState.get_segment_bonus_done(local_idx)
	var can_action   := not action_done or GameState.get_extra_actions(local_idx) > 0
	var has_priority := (is_my_segment and reaction_for == -1) or reaction_for == local_idx
	for child in _player_hand.get_card_views():
		var view := child as CardView
		if view == null or view.card == null:
			continue
		var playable := false
		match view.card.timing:
			Card.TimingType.ACTION:
				playable = is_my_segment and reaction_for == -1 and can_action
			Card.TimingType.BONUS_ACTION:
				playable = is_my_segment and reaction_for == -1 and not bonus_done
			Card.TimingType.REACTION:
				playable = (reaction_for == local_idx)
		view.set_interactable(playable, has_priority)
	if _tutorial != null:
		_tutorial.gate_hand(_player_hand.get_card_views())

func _on_state_synced() -> void:
	if GameState.players.size() < 2:
		return
	if not _board_initialized:
		_apply_player_cosmetics()
		_spawn_hero_slots()
		_board_initialized = true
		_hide_loading_overlay()
		# Dispara a fase atual agora que o board está pronto
		_on_phase_changed(GameState.battle.phase_to_string(GameState.battle.current_phase))

	# Sala debug: cria o botão DEBUG e PRÉ-CARREGA o picker (grade de todas as cartas) já no
	# load — assim clicar DEBUG abre instantâneo, sem loading. Em partida NORMAL nada disso
	# existe; o único custo aqui é esta checagem booleana (is_debug_match lê _m._debug).
	if GameState.is_debug_match():
		_ensure_debug_button()
		_ensure_debug_picker()

	var phase_str    := GameState.battle.phase_to_string(GameState.battle.current_phase)
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
		# Pisca o slot do herói de retaguarda quando sua ação bônus está disponível
		# (ex.: Rosas Negras do Darian) — mesmo aviso visual do Nox/Lilith.
		slot.set_activable(not _local_backline_ability(slot.hero).is_empty())
	for slot in _opponent_hero_slots:
		slot.refresh()
	_refresh_team_face_down()
	_refresh_active_heroes()
	_refresh_combat_stats()
	_refresh_arsenals()
	_refresh_graveyard()
	_refresh_banish()
	_refresh_tokens()
	_refresh_opponent_hand_badge()

	var phase := GameState.battle.phase_to_string(GameState.battle.current_phase)
	_player_hand.visible = phase not in ["OPENING_MULLIGAN", "OPENING_ROLL"] \
		and not (_tutorial != null and phase == "END")   # tutorial: esconde a mão no arsenal (evita clicar na cópia)
	_refresh_pass_button(phase)
	_refresh_hand_interactivity()
	_refresh_dim_overlay()
	_refresh_backline_ability_ui()
	_refresh_stealth_passive_ui()
	_refresh_frontline_passive_ui()
	_refresh_dice_roll()

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
	# Sobrecarga de Núcleo (escolher tokens / distribuir pontos) também escurece o fundo.
	var my_overload := GameState.get_pending_overload_player() == local_idx
	# HeroPickScreen "espiando" continua visible mas com conteúdo colapsado — não escurece.
	var hero_pick_open: bool = (
		$PhaseOverlay/HeroPickScreen.visible
		and not $PhaseOverlay/HeroPickScreen.is_peeking()
	)
	var any_open: bool = (
		$PhaseOverlay/MulliganScreen.visible or
		hero_pick_open or
		$PhaseOverlay/ArsenalScreen.visible  or
		my_pick or my_overload
	)
	_dim_overlay.visible = any_open
	if _waiting_label:
		if _mulligan_waiting:
			_waiting_label.text = "Aguardando oponente finalizar a preparação..."
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
	if GameState.battle.phase_to_string(GameState.battle.current_phase) != "ACTION":
		return false
	var reaction_for  := GameState.get_reaction_window_for()
	var is_my_segment := GameState.get_next_action_player_index() == player_idx
	var action_done   := GameState.get_segment_action_done(player_idx)
	var bonus_done    := GameState.get_segment_bonus_done(player_idx)
	var can_action    := not action_done or GameState.get_extra_actions(player_idx) > 0
	match card.timing:
		Card.TimingType.ACTION:
			return is_my_segment and reaction_for == -1 and can_action
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
	var phase        := GameState.battle.current_phase

	var local_active      := GameState.players[local_idx].active_hero
	var local_is_revealed := GameState.get_hero_revealed(local_idx) \
						  or phase in [BattleManager.Phase.COMBAT, BattleManager.Phase.END]
	if local_active:
		_player_active_hero.bind(local_active)
		_player_active_hero.set_face_down(not local_is_revealed)
		_player_active_hero.set_activable(not _local_action_ability().is_empty())
		_player_active_hero.visible = true
	else:
		_player_active_hero.visible = false

	var local_heroes := GameState.players[local_idx].heroes
	for i in _player_hero_slots.size():
		var is_active := local_active != null and i < local_heroes.size() and local_heroes[i] == local_active
		_player_hero_slots[i].visible = not is_active

	var opponent_active  := GameState.players[opponent_idx].active_hero
	var is_revealed      := GameState.get_hero_revealed(opponent_idx) \
						 or phase in [BattleManager.Phase.COMBAT, BattleManager.Phase.END]
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

	# Égide do Guardião: liga/desliga a passiva Muro de Aço da Valkar por lado.
	# Dispara só quando o Muro está ativo (wall_active) — que já implica revelada.
	_update_guardian_aegis(local_idx, local_active, _player_active_hero,
		_player_hero_slots, false)
	_update_guardian_aegis(opponent_idx, opponent_active, _opponent_active_hero,
		_opponent_hero_slots, true)

	_refresh_combat_stats()

## Mantém a Égide do Guardião (Muro de Aço) sincronizada com o herói ativo de um
## lado: instancia o VFX quando a Valkar entra na frontline e o remove quando sai.
func _update_guardian_aegis(player_idx: int, active_hero, active_slot: Control,
		ally_slots: Array, mirror: bool) -> void:
	var want: bool = active_hero is HeroValkar \
		and active_hero.is_alive() and active_hero.wall_active \
		and active_slot != null and active_slot.visible
	var cur := _guardian_aegis[player_idx]
	if want:
		if cur == null or not is_instance_valid(cur):
			var visible_allies: Array[Control] = []
			for s in ally_slots:
				if (s as Control).visible:
					visible_allies.append(s as Control)
			var fx: GuardianAegis = GuardianAegisScene.instantiate()
			fx.ability_name = active_hero.passive_name
			# O anúncio textual vem do skill_activated (label + hero popup), como nas
			# outras passivas — desliga o banner da Égide para não duplicar.
			fx.show_banner  = false
			add_child(fx)
			fx.activate(active_slot, visible_allies, mirror)
			fx.deactivated.connect(func() -> void:
				if _guardian_aegis[player_idx] == fx:
					_guardian_aegis[player_idx] = null
			, CONNECT_ONE_SHOT)
			_guardian_aegis[player_idx] = fx
	elif cur != null and is_instance_valid(cur):
		cur.deactivate()

# ── badge de cartas na mão do oponente ───────────────────────────────────────
## Mini-indicador no canto superior direito: verso da carta (sleeve) + "×N".
func _setup_opponent_hand_badge() -> void:
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.offset_right = -14.0
	box.offset_top   = 10.0
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sleeve := TextureRect.new()
	sleeve.custom_minimum_size = Vector2(24, 34)
	sleeve.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	sleeve.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sleeve.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sleeve)
	_opp_hand_badge_sleeve = sleeve

	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 19)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lbl)
	_opp_hand_badge_count = lbl

	box.visible = false
	$UI.add_child(box)
	_opp_hand_badge = box

func _refresh_opponent_hand_badge() -> void:
	if not _board_initialized or _opp_hand_badge == null:
		return
	var opp_idx := 1 - NetworkState.local_player_index
	if GameState.players.size() <= opp_idx:
		_opp_hand_badge.visible = false
		return
	if _opp_hand_badge_sleeve.texture == null:
		_opp_hand_badge_sleeve.texture = _opponent_sleeve
	_opp_hand_badge_count.text = "×%d" % GameState.players[opp_idx].hand.size()
	_opp_hand_badge.visible = true

# ── tokens (Mísseis Mágicos do Alastar e futuros) ────────────────────────────
func _refresh_tokens() -> void:
	if not _board_initialized:
		return
	var local_idx := NetworkState.local_player_index
	var opp_idx   := 1 - local_idx
	_populate_tokens(_player_half,   GameState.players[local_idx], true)
	_populate_tokens(_opponent_half, GameState.players[opp_idx],   false)

## Agrupa tokens idênticos (por token_id) numa única view com contador.
## No lado local, acende o ícone activable e liga o clique de disparo nos tokens
## cujo token_id casa com uma habilidade FREE de alvo disponível agora.
func _populate_tokens(half, pl: Player, is_local: bool) -> void:
	half.clear_tokens()
	var fire := _local_fire_ability() if is_local else {}
	var fire_token_id := str(fire.get("token_id", "")) if not fire.is_empty() else ""
	var shop_open := is_local and _local_fragment_shop_available()
	var groups: Dictionary = {}   # token_id -> { "token": Token, "count": int }
	var order: Array = []
	for t in pl.tokens:
		if not groups.has(t.token_id):
			groups[t.token_id] = { "token": t, "count": 0 }
			order.append(t.token_id)
		groups[t.token_id]["count"] += 1
	for tid in order:
		var g: Dictionary = groups[tid]
		var is_fire: bool = is_local and str(tid) == fire_token_id
		var is_shop: bool = shop_open and str(tid) == GameState.FRAGMENT_TOKEN_ID
		var activable: bool = is_fire or is_shop
		var view: TokenView = half.add_token_view(g["token"], g["count"], activable)
		if is_fire and not _missile_fire_active:
			view.token_clicked.connect(_on_token_clicked.bind(fire))
		elif is_shop:
			view.token_clicked.connect(_on_fragment_token_clicked)

## Retorna o descritor da habilidade ACTION/BONUS que o herói ativo LOCAL pode
## ativar agora (ou {} se nenhuma). Usado pelo ícone activable e pelo clique.
func _local_action_ability() -> Dictionary:
	if not _board_initialized:
		return {}
	var local_idx := NetworkState.local_player_index
	if GameState.battle.phase_to_string(GameState.battle.current_phase) != "ACTION":
		return {}
	if GameState.get_reaction_window_for() != -1:
		return {}
	if GameState.get_next_action_player_index() != local_idx:
		return {}
	var pl := GameState.players[local_idx]
	var hero := pl.active_hero
	if hero == null:
		return {}
	var action_done := GameState.get_segment_action_done(local_idx)
	var bonus_done  := GameState.get_segment_bonus_done(local_idx)
	var can_action  := not action_done or GameState.get_extra_actions(local_idx) > 0
	for a in pl.get_active_abilities(GameState.players[1 - local_idx]):
		# Habilidades de RETAGUARDA (ex.: Darian) piscam/são ativadas no próprio slot
		# do herói de retaguarda (_local_backline_ability), não no herói ativo.
		if bool(a.get("from_backline", false)):
			continue
		var cost := str(a.get("cost", ""))
		if cost == "ACTION" and can_action:
			return a
		if cost == "BONUS" and not bonus_done:
			return a
	return {}

## Retorna o descritor da AÇÃO BÔNUS de retaguarda que ESTE herói de retaguarda local
## pode usar agora (seu segmento de ACTION, sem janela de reação, herói vivo e não
## exausto — get_backline_bonus_ability já checa o estado ACTIVE), ou {}. Usado para
## acender o "activable" no slot do Darian e para ativá-la ao clicar nele.
func _local_backline_ability(hero: Hero) -> Dictionary:
	if not _board_initialized or hero == null:
		return {}
	var local_idx := NetworkState.local_player_index
	if GameState.battle.phase_to_string(GameState.battle.current_phase) != "ACTION":
		return {}
	if GameState.get_reaction_window_for() != -1:
		return {}
	if GameState.get_next_action_player_index() != local_idx:
		return {}
	var pl := GameState.players[local_idx]
	if hero == pl.active_hero or not hero.is_alive():
		return {}
	var ba := hero.get_backline_bonus_ability(pl, GameState.players[1 - local_idx])
	if ba.is_empty():
		return {}
	var cost := str(ba.get("cost", ""))
	if cost == "BONUS" and GameState.get_segment_bonus_done(local_idx):
		return {}
	if cost == "ACTION":
		var can_action := not GameState.get_segment_action_done(local_idx) \
			or GameState.get_extra_actions(local_idx) > 0
		if not can_action:
			return {}
	return ba

func _on_active_hero_clicked(_hero: Hero) -> void:
	var ability := _local_action_ability()
	if ability.is_empty():
		return
	var ability_id := str(ability.get("id", ""))
	var from_backline := bool(ability.get("from_backline", false))
	var needs_target  := bool(ability.get("needs_target", false))
	# Habilidade com alvo (ex.: Selo da Ruína): escolhe o herói-alvo antes de enviar.
	# A ativação revela o herói ativo no servidor — dispensa a confirmação de furtividade.
	if needs_target:
		_ability_target_id = ability_id
		_open_pick_hero_for_ability(str(ability.get("label", "")))
		return
	# Ativar uma habilidade ACTION/BONUS do próprio ativo revela o herói (server:
	# _reveal_active_hero). Se ainda furtivo, confirma antes — ativá-la quebra a furtividade.
	# Habilidades de RETAGUARDA (ex.: Darian) não revelam o ativo → pulam a confirmação.
	var local_idx := NetworkState.local_player_index
	if not from_backline and not GameState.get_hero_revealed(local_idx):
		_pending_confirm_ability = ability_id
		var hero := GameState.players[local_idx].active_hero
		_stealth_confirm.setup(hero, str(ability.get("label", "")), hero.passive_desc)
		return
	GameState.rpc_id(1, "rpc_activate_ability", ability_id, [])

## Abre o overlay _pick_hero para escolher o alvo de uma habilidade com needs_target.
func _open_pick_hero_for_ability(prompt: String) -> void:
	var local_idx := NetworkState.local_player_index
	var opp_idx   := 1 - local_idx
	var ally_heroes := GameState.players[local_idx].heroes
	var opp_heroes  := GameState.players[opp_idx].heroes
	var opp_revealed: Array[bool] = []
	for i in opp_heroes.size():
		var h: Hero = opp_heroes[i]
		if h == GameState.players[opp_idx].active_hero:
			opp_revealed.append(GameState.get_hero_revealed(opp_idx))
		else:
			opp_revealed.append(h.is_backline_revealed or h.state == Hero.State.EXHAUSTED)
	_pick_hero.open(
		prompt,
		ally_heroes,
		_local_sleeve,
		opp_heroes,
		_opponent_sleeve,
		opp_revealed,
		GameState.players[local_idx].active_hero,
		GameState.players[opp_idx].active_hero
	)

## Retorna o descritor da habilidade FREE com alvo (ex.: disparar mísseis) que o
## herói ativo LOCAL pode usar agora (seu segmento, sem janela de reação), ou {}.
func _local_fire_ability() -> Dictionary:
	if not _board_initialized:
		return {}
	var local_idx := NetworkState.local_player_index
	if GameState.battle.phase_to_string(GameState.battle.current_phase) != "ACTION":
		return {}
	if GameState.get_reaction_window_for() != -1:
		return {}
	if GameState.get_next_action_player_index() != local_idx:
		return {}
	if GameState.get_pending_pick_player() >= 0 or GameState.get_pending_symbol_player() >= 0:
		return {}
	var pl := GameState.players[local_idx]
	var hero := pl.active_hero
	if hero == null:
		return {}
	for a in pl.get_active_abilities(GameState.players[1 - local_idx]):
		if str(a.get("cost", "")) == "FREE" and bool(a.get("needs_target", false)):
			return a
	return {}

# ── loja do Fragmento Arcano ─────────────────────────────────────────────────
## Gating client-side da loja (o servidor revalida em can_use_fragment_shop).
func _local_fragment_shop_available() -> bool:
	if not _board_initialized:
		return false
	return GameState.can_use_fragment_shop(NetworkState.local_player_index)

func _on_fragment_token_clicked(_token: Token) -> void:
	if not _local_fragment_shop_available():
		return
	var local_idx := NetworkState.local_player_index
	var count := GameState.players[local_idx].count_tokens(GameState.FRAGMENT_TOKEN_ID)
	_fragment_shop.setup(count)

func _on_fragment_shop_buy(effect_id: String) -> void:
	GameState.rpc_id(1, "rpc_buy_fragment_effect", effect_id)

func _on_fragment_shop_closed() -> void:
	pass

const _FRAGMENT_EFFECT_LABELS := {
	"peek":   "olhou a carta do topo do deck",
	"symbol": "adicionou um símbolo à chain",
	"draw":   "comprou 1 carta",
}

func _on_fragment_used(player_index: int, effect_id: String, cost: int) -> void:
	var who := "Você" if player_index == NetworkState.local_player_index else "Oponente"
	var what := str(_FRAGMENT_EFFECT_LABELS.get(effect_id, effect_id))
	_show_toast("%s %s  (−%d ◈ Fragmento)" % [who, what, cost])

	# Sequenciamento por efeito:
	#   peek   → VFX primeiro; o overlay de revelação só abre QUANDO o VFX termina.
	#   symbol → VFX NÃO aqui; toca em _on_fragment_symbol_added (após escolher o símbolo).
	#   draw   → VFX imediato (destino no deck).
	match effect_id:
		"symbol":
			return
		"peek":
			var is_local := player_index == NetworkState.local_player_index
			var fx := _play_arcane_fragments_vfx(player_index, effect_id)
			if is_local and _deck_reveal != null:
				if fx != null:
					_deck_reveal.hold()
					fx.finished.connect(func() -> void:
						if is_instance_valid(_deck_reveal):
							_deck_reveal.release())
				else:
					_deck_reveal.release()
		_:
			_play_arcane_fragments_vfx(player_index, effect_id)

# effect_id da loja → variante visual do VFX (peek=Impacto, symbol=Colisão, draw=Fusão).
const _FRAGMENT_EFFECT_VARIANT := { "peek": 1, "symbol": 2, "draw": 3 }

## VFX dos Fragmentos Arcanos: as pedras nascem no token do Fragmento e o clímax
## acontece no destino — combat zone (symbol) ou deck (peek/draw). Retorna o nó
## do VFX (ou null). Cosmético; o efeito de gameplay já chegou via sync.
func _play_arcane_fragments_vfx(player_index: int, effect_id: String) -> ArcaneFragments:
	if not _board_initialized:
		return null
	var variant := int(_FRAGMENT_EFFECT_VARIANT.get(effect_id, 0))
	if variant == 0:
		return null
	var is_local := player_index == NetworkState.local_player_index
	var half = _player_half if is_local else _opponent_half
	var origin: Vector2 = half.get_tokens_global_center()
	var dest: Vector2 = half.get_combat_cards_global_center() if effect_id == "symbol" \
			else half.get_deck_global_center()
	var fx: ArcaneFragments = ArcaneFragmentsScene.instantiate()
	add_child(fx)
	fx.play(variant, origin, dest)
	return fx

func _on_fragment_symbol_added(player_index: int, symbol: String) -> void:
	var is_local := player_index == NetworkState.local_player_index
	var half = _player_half if is_local else _opponent_half
	var mirrored := not is_local
	# Opção 2 (symbol): toca o VFX (dispara após a escolha) e só adiciona o símbolo
	# à combat zone no FIM da animação — a colisão "entrega" o símbolo.
	var fx := _play_arcane_fragments_vfx(player_index, "symbol")
	if fx != null:
		fx.finished.connect(func() -> void:
			if is_instance_valid(half):
				half.add_combat_symbol_view(symbol, mirrored))
	else:
		half.add_combat_symbol_view(symbol, mirrored)

## Mostra um aviso rápido no topo da tela (fade in → espera → fade out).
func _show_toast(text: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = text
	_toast_label.visible = true
	_toast_label.modulate.a = 0.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_label, "modulate:a", 1.0, 0.20)
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.45)
	_toast_tween.tween_callback(func() -> void: _toast_label.visible = false)

# ── disparo de mísseis (1 alvo por míssil, split entre quaisquer heróis) ──────
func _on_token_clicked(_token: Token, fire_ability: Dictionary) -> void:
	if _missile_fire_active or fire_ability.is_empty():
		return
	_missile_total = int(fire_ability.get("target_count", 0))
	if _missile_total <= 0:
		return
	_missile_fire_id = str(fire_ability.get("id", ""))
	_missile_targets = []
	_missile_fire_active = true
	_open_pick_hero_for_fire()

func _open_pick_hero_for_fire() -> void:
	var local_idx := NetworkState.local_player_index
	var opp_idx   := 1 - local_idx
	var ally_heroes := GameState.players[local_idx].heroes
	var opp_heroes  := GameState.players[opp_idx].heroes
	var opp_revealed: Array[bool] = []
	for i in opp_heroes.size():
		var h: Hero = opp_heroes[i]
		if h == GameState.players[opp_idx].active_hero:
			opp_revealed.append(GameState.get_hero_revealed(opp_idx))
		else:
			opp_revealed.append(h.is_backline_revealed or h.state == Hero.State.EXHAUSTED)
	var shot := _missile_targets.size() + 1
	_pick_hero.open(
		"Disparar míssil %d/%d — escolha um alvo" % [shot, _missile_total],
		ally_heroes,
		_local_sleeve,
		opp_heroes,
		_opponent_sleeve,
		opp_revealed,
		GameState.players[local_idx].active_hero,
		GameState.players[opp_idx].active_hero
	)

func _on_missile_target_picked(hero: Hero) -> void:
	var target_player := -1
	var target_idx    := -1
	for i in 2:
		var idx := GameState.players[i].heroes.find(hero)
		if idx >= 0:
			target_player = i
			target_idx    = idx
			break
	if target_player < 0:
		_missile_fire_active = false
		return
	_missile_targets.append([target_player, target_idx])

	if _missile_targets.size() < _missile_total:
		_open_pick_hero_for_fire()
	else:
		var targets := _missile_targets.duplicate()
		var fire_id := _missile_fire_id
		_missile_fire_active = false
		_missile_targets = []
		_missile_total = 0
		_missile_fire_id = ""
		# O VFX é disparado pelo servidor via GameBus.missiles_fired (ambos os
		# clientes), não aqui — assim o oponente também vê os feixes.
		GameState.rpc_id(1, "rpc_activate_ability", fire_id, targets)

## Servidor avisou que mísseis foram disparados — toca o VFX em ambos os clientes.
func _on_missiles_fired(caster_idx: int, targets: Array) -> void:
	_play_magic_missiles_vfx(caster_idx, targets)

## VFX dos Mísseis Mágicos: 1 míssil por alvo escolhido, voando do herói ativo
## (caster) até cada herói-alvo. Cosmético — o dano real chega via sync do
## servidor; o VFX apenas apresenta os feixes em arco + impactos + popups "−N".
func _play_magic_missiles_vfx(caster_idx: int, target_refs: Array) -> void:
	if not _board_initialized or target_refs.is_empty():
		return
	var caster_slot := _find_slot_for_hero(GameState.players[caster_idx].active_hero)
	if caster_slot == null:
		return
	# A carta do conjurador reage (mexe + brilha) junto com a carga dos mísseis.
	(caster_slot as HeroSlot).play_cast_tell()
	var source_pos := _slot_center(caster_slot) + Vector2(0.0, -40.0)

	var opp_idx := 1 - caster_idx
	var opp_active: Hero = GameState.players[opp_idx].active_hero

	# Agrupa alvos por herói (chave estável) e monta a lista de mísseis.
	# Curvas modestas: no board real o caster fica num canto e o alvo na diagonal
	# oposta — perpendiculares grandes (como na referência HTML, com caster no
	# centro) jogariam o arco pra fora da tela. Aqui basta uma curva suave.
	const CURVES := [70.0, 95.0, 60.0, 105.0, 80.0]
	const WAVES  := [1.8, 2.2, 1.6, 2.0, 1.9]
	var targets: Dictionary = {}
	var missiles: Array = []
	for i in target_refs.size():
		var tp: int = target_refs[i][0]
		var ti: int = target_refs[i][1]
		var hero: Hero = GameState.players[tp].heroes[ti]
		var key := "%d_%d" % [tp, ti]
		if not targets.has(key):
			var slot := _find_slot_for_hero(hero)
			if slot == null:
				continue
			targets[key] = { "pos": _slot_center(slot), "hp_node": null }
			# Marca a zona-alvo sobre o herói ativo do oponente, se for alvejado.
			if hero == opp_active and not targets.has("active"):
				targets["active"] = targets[key]
		missiles.append({
			"id": i,
			"target": key,
			"side": 1.0 if i % 2 == 0 else -1.0,
			"curve": CURVES[i % CURVES.size()],
			"waves": WAVES[i % WAVES.size()],
			"dmg": 1,
		})

	if missiles.is_empty():
		return
	# Sem alvo ativo entre os escolhidos → marca a zona sobre o primeiro alvo.
	if not targets.has("active"):
		targets["active"] = targets[missiles[0]["target"]]

	var fx: MagicMissiles = MagicMissilesScene.instantiate()
	fx.missiles = missiles
	add_child(fx)
	fx.play(source_pos, targets)

## Servidor avisou que Darian lançou Rosas Negras — toca o VFX em ambos os clientes.
func _on_roses_fired(caster_idx: int, source_hero_idx: int, targets: Array) -> void:
	_play_rosas_negras_vfx(caster_idx, source_hero_idx, targets)

## VFX das Rosas Negras: 3 rosas voando em arco do slot de Darian (retaguarda) até
## os heróis sorteados (podem repetir alvo). Cosmético — não mostra dano: o throw só
## marca (Hero.black_roses), e o marcador do slot exibe a contagem via sync.
func _play_rosas_negras_vfx(caster_idx: int, source_hero_idx: int, target_refs: Array) -> void:
	if not _board_initialized or target_refs.is_empty():
		return
	var players: Array = GameState.players
	if caster_idx < 0 or caster_idx >= players.size():
		return
	var src_heroes: Array = players[caster_idx].heroes
	if source_hero_idx < 0 or source_hero_idx >= src_heroes.size():
		return
	var caster_slot := _find_slot_for_hero(src_heroes[source_hero_idx])
	if caster_slot == null:
		return
	# A carta de Darian reage (mexe + brilha) junto com a carga das rosas.
	(caster_slot as HeroSlot).play_cast_tell()
	var source_pos := _slot_center(caster_slot)

	# Curvas modestas (mesmo motivo dos mísseis: caster num canto, alvo na diagonal).
	const CURVES := [70.0, 95.0, 60.0]
	const WAVES  := [1.8, 2.2, 1.6]
	var targets: Dictionary = {}
	var roses: Array = []
	for i in target_refs.size():
		var tp: int = target_refs[i][0]
		var ti: int = target_refs[i][1]
		var hero: Hero = players[tp].heroes[ti]
		var key := "%d_%d" % [tp, ti]
		if not targets.has(key):
			var slot := _find_slot_for_hero(hero)
			if slot == null:
				continue
			targets[key] = { "pos": _slot_center(slot) }
		roses.append({
			"id": i,
			"target": key,
			"side": 1.0 if i % 2 == 0 else -1.0,
			"curve": CURVES[i % CURVES.size()],
			"waves": WAVES[i % WAVES.size()],
		})

	if roses.is_empty():
		return

	var fx: RosasNegras = RosasNegrasScene.instantiate()
	fx.roses = roses
	add_child(fx)
	fx.play(source_pos, targets)

## Servidor avisou que a Lilith aplicou o Selo da Ruína — toca o VFX em ambos os clientes.
func _on_seal_applied(caster_idx: int, source_hero_idx: int, target_player_idx: int, target_hero_idx: int) -> void:
	_play_selo_ruina_vfx(caster_idx, source_hero_idx, target_player_idx, target_hero_idx)

## VFX do Selo da Ruína: névoa negra voa do slot da Lilith (source) até o herói-alvo.
## Cosmético — a marca (Hero.sealed_ruin) e a emanação contínua chegam via sync; aqui é
## só a névoa que voa e assenta no card.
func _play_selo_ruina_vfx(caster_idx: int, source_hero_idx: int, target_player_idx: int, target_hero_idx: int) -> void:
	if not _board_initialized:
		return
	var players: Array = GameState.players
	if caster_idx < 0 or caster_idx >= players.size() or target_player_idx < 0 or target_player_idx >= players.size():
		return
	var src_heroes: Array = players[caster_idx].heroes
	var tgt_heroes: Array = players[target_player_idx].heroes
	if source_hero_idx < 0 or source_hero_idx >= src_heroes.size():
		return
	if target_hero_idx < 0 or target_hero_idx >= tgt_heroes.size():
		return
	var caster_slot := _find_slot_for_hero(src_heroes[source_hero_idx])
	var target_slot := _find_slot_for_hero(tgt_heroes[target_hero_idx])
	if caster_slot == null or target_slot == null:
		return
	# Buildup: a carta da Lilith se mexe e brilha; depois a névoa voa até o alvo.
	(caster_slot as HeroSlot).play_cast_tell()
	await get_tree().create_timer(CAST_LEAD_IN).timeout
	if not is_instance_valid(self) or not _board_initialized:
		return
	if not is_instance_valid(caster_slot) or not is_instance_valid(target_slot):
		return
	var fx: SeloRuina = SeloRuinaScene.instantiate()
	add_child(fx)
	fx.play(_slot_center(caster_slot), _slot_center(target_slot))

## Servidor avisou que Darian detonou as Rosas Negras (especial) — toca o VFX em ambos.
func _on_roses_detonated(_caster_idx: int, targets: Array) -> void:
	_play_floracao_mortal_vfx(targets)

## VFX da especial (Jardim de Espinhos): rosas varrem o campo da esquerda p/ direita;
## conforme passam por cada herói marcado, a rosa detona com respingo de sangue e o
## popup de dano. Cosmético — dano/estado chegam via sync do servidor.
func _play_floracao_mortal_vfx(target_refs: Array) -> void:
	if not _board_initialized or target_refs.is_empty():
		return
	var targets: Array = []
	for ref in target_refs:
		var tp: int = ref[0]
		var ti: int = ref[1]
		var dmg: int = ref[2]
		if tp < 0 or tp >= GameState.players.size():
			continue
		var heroes: Array = GameState.players[tp].heroes
		if ti < 0 or ti >= heroes.size():
			continue
		var slot := _find_slot_for_hero(heroes[ti])
		if slot == null:
			continue
		targets.append({ "pos": _slot_center(slot), "dmg": dmg })
	if targets.is_empty():
		return
	# Ordena por X (esquerda → direita) — a varredura detona nessa ordem.
	targets.sort_custom(func(a, b): return a["pos"].x < b["pos"].x)
	var fx: FloracaoMortal = FloracaoMortalScene.instantiate()
	add_child(fx)
	fx.play(targets)

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
		_refresh_combat_stats()
		_play_card_vfx(player_index, card)
		# Fly terminou — tenta avançar a transição pendente (pode ainda aguardar hero_popup/skill_vfx)
		_on_blocker_released()

	if _animator != null:
		_fly_anim_busy = true
		if is_local:
			var from_pos: Vector2 = _last_played_source_pos if _last_played_source_pos != Vector2.ZERO \
							else _player_hand.get_global_rect().get_center()
			var to_pos: Vector2   = _player_half.get_combat_cards_global_center()
			_animator.fly_discard(from_pos, to_pos, card.get_texture(), after_anim, Collection.get_card_dict(card.card_name))
			_last_played_source_pos = Vector2.ZERO
		else:
			var from_pos: Vector2 = _opponent_half.get_global_rect().get_center()
			var to_pos: Vector2   = _opponent_half.get_combat_cards_global_center()
			_animator.fly_discard(from_pos, to_pos, card.get_texture(), after_anim, Collection.get_card_dict(card.card_name))
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

func _refresh_banish() -> void:
	if not _board_initialized:
		return
	var local_idx    := NetworkState.local_player_index
	var opponent_idx := 1 - local_idx
	var local_banish    := GameState.players[local_idx].banish_zone
	var opponent_banish := GameState.players[opponent_idx].banish_zone
	_player_half.set_banish_card(
		local_banish.back() if not local_banish.is_empty() else null)
	_opponent_half.set_banish_card(
		opponent_banish.back() if not opponent_banish.is_empty() else null)

func _on_banish_clicked(side: String) -> void:
	var local_idx    := NetworkState.local_player_index
	var player_idx   := local_idx if side == "player" else 1 - local_idx
	var title        := "Banimento — Você" if side == "player" else "Banimento — Oponente"
	var cards: Array = GameState.players[player_idx].banish_zone
	_graveyard_viewer.open(cards, title)

# ── sequenciamento fly → turn_transition ─────────────────────────────────────
func _queue_turn_transition(type: String) -> void:
	if _tutorial != null:
		return   # no tutorial os banners de transição atrapalham/cobrem o coaching — suprime
	_pending_transition_type = type
	_try_play_pending_transition()

## Verifica se todos os bloqueadores terminaram e, se sim, dispara a transição.
## Chamado por qualquer bloqueador ao concluir (_on_blocker_released).
func _try_play_pending_transition() -> void:
	if _pending_transition_type.is_empty():
		return
	var hero_busy: bool = _hero_popup != null and _hero_popup.is_busy()
	if _fly_anim_busy or hero_busy or _skill_vfx_busy:
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
	var phase := GameState.battle.phase_to_string(GameState.battle.current_phase)
	var atk: int
	var def_: int
	if phase in ["ACTION", "COMBAT"]:
		atk  = _calc_attack(player_idx)
		def_ = _calc_defense(player_idx)
	else:
		atk  = pl.active_hero.base_attack + pl.active_hero.get_passive_attack_bonus() \
			 + pl.battle_bonus_attack + pl.next_turn_bonus_attack
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
		var phase := GameState.battle.phase_to_string(GameState.battle.current_phase)
		if phase in ["ACTION", "COMBAT"]:
			preview_slot.set_modified_attack(_calc_attack(i))
			preview_slot.set_modified_defense(_calc_defense(i))
		else:
			preview_slot.set_modified_attack(pl.active_hero.base_attack + pl.active_hero.get_passive_attack_bonus()
				+ pl.battle_bonus_attack + pl.next_turn_bonus_attack)
			preview_slot.set_modified_defense(pl.active_hero.base_defense)
		return

func _calc_attack(player_idx: int) -> int:
	var pl := GameState.players[player_idx]
	var total := pl.active_hero.base_attack
	for card in pl.turn_cards:
		total += card.attack_value
	total += pl.pending_bonus_attack
	total += pl.passive_attack_bonus
	total += pl.battle_bonus_attack          # Frenesi: persiste a batalha inteira
	total += pl.next_turn_bonus_attack    # Guarda Inabalável: acumulado do turno anterior
	total -= pl.battle_attack_penalty     # Finta: debuff de ataque do turno
	return maxi(0, total)

func _calc_defense(player_idx: int) -> int:
	var pl := GameState.players[player_idx]
	var total := pl.active_hero.base_defense
	for card in pl.turn_cards:
		total += card.defense_value
	total -= pl.next_defense_penalty
	total += pl.pending_bonus_defense
	return total

static func _phase_display_name(phase: String) -> String:
	match phase:
		"OPENING_ROLL":      return "Rolagem de Dados"
		"OPENING_MULLIGAN":  return "Preparação"
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
		_stealth_confirm.setup(hero, hero.passive_name, hero.passive_desc)
	elif not awaiting_r:
		_backline_modal_shown = false

	# ── Seleção de alvo ────────────────────────────────────
	if awaiting_t and bl_player == local_idx and not _pick_hero_modal_shown:
		_pick_hero_modal_shown = true
		_schedule_screen(_open_pick_hero_for_backline)
	elif not awaiting_t:
		_pick_hero_modal_shown = false

## Passiva de descarte furtiva (Relicar): o servidor pausou aguardando Sim/Não. Reusa o
## StealthConfirm. Guarda contra reabrir e contra colidir com o confirm de ativação (Nox).
func _refresh_stealth_passive_ui() -> void:
	if not _board_initialized:
		return
	var local_idx := NetworkState.local_player_index
	var sp_player := GameState.get_stealth_passive_player()
	if sp_player == local_idx and not _stealth_passive_modal_shown and _pending_confirm_ability == "":
		_stealth_passive_modal_shown = true
		var h_idx := GameState.get_stealth_passive_hero_idx()
		var hero := GameState.players[local_idx].heroes[h_idx]
		_stealth_confirm.setup(hero, hero.passive_name, hero.passive_desc)
	elif sp_player != local_idx:
		_stealth_passive_modal_shown = false

## Confirmação de passiva de frontline (Muro de Aço da Valkar): o servidor pausou após
## a seleção aguardando Sim/Não. Reusa o StealthConfirm; só abre para quem decide.
func _refresh_frontline_passive_ui() -> void:
	if not _board_initialized:
		return
	var local_idx := NetworkState.local_player_index
	var fp_player := GameState.get_frontline_confirm_player()
	if fp_player == local_idx and not _frontline_modal_shown and _pending_confirm_ability == "":
		_frontline_modal_shown = true
		var h_idx := GameState.get_frontline_confirm_hero_idx()
		var hero := GameState.players[local_idx].heroes[h_idx]
		_stealth_confirm.setup(hero, hero.passive_name, hero.passive_desc)
	elif fp_player != local_idx:
		_frontline_modal_shown = false

## Fase OPENING_ROLL: mostra o overlay dos dados, anima os arremessos sincronizados
## e exibe a escolha de quem começa para o vencedor.
func _refresh_dice_roll() -> void:
	if not _board_initialized or _dice_roll == null:
		return
	var local_idx := NetworkState.local_player_index
	var phase := GameState.battle.phase_to_string(GameState.battle.current_phase)
	if phase != "OPENING_ROLL":
		if _dice_roll.visible:
			_dice_roll.visible = false
		_dice_setup_done = false
		_dice_anim_played = [false, false]
		return

	if not _dice_setup_done:
		_dice_roll.setup(local_idx)
		_dice_setup_done = true
	_dice_roll.visible = true

	var winner := GameState.get_dice_winner()
	# Re-roll por empate: o servidor zerou os arremessos depois de termos animado.
	if winner < 0 and not GameState.get_dice_thrown(0) and not GameState.get_dice_thrown(1) \
			and (_dice_anim_played[0] or _dice_anim_played[1]):
		_dice_anim_played = [false, false]
		_dice_roll.reset_for_reroll()

	# Anima cada jogador que arremessou e ainda não foi animado localmente.
	for p in 2:
		if GameState.get_dice_thrown(p) and not _dice_anim_played[p]:
			_dice_anim_played[p] = true
			_dice_roll.play_roll(p, GameState.get_dice_values(p), GameState.get_dice_throw_vec(p))

	if GameState.get_dice_awaiting_choice():
		_dice_roll.show_winner_choice(winner == local_idx)

	_dice_roll.set_can_throw(
		not GameState.get_dice_thrown(local_idx) and not GameState.get_dice_awaiting_choice())

# is_server() true = autoridade local (tutorial offline ou host-as-player): chama direto, sem RPC.
func _on_dice_thrown(dir: Vector2, force: float) -> void:
	if _tutorial != null:
		_tutorial.on_player_dice_throw(dir.x, dir.y, force)   # tutorial força o resultado roteirado
		return
	if multiplayer.is_server():
		GameState.rpc_submit_dice_throw(dir.x, dir.y, force)
	else:
		GameState.rpc_id(1, "rpc_submit_dice_throw", dir.x, dir.y, force)

func _on_dice_first_player_chosen(idx: int) -> void:
	if multiplayer.is_server():
		GameState.rpc_choose_first_player(idx)
	else:
		GameState.rpc_id(1, "rpc_choose_first_player", idx)

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

## Confirmou no StealthConfirm. O overlay é compartilhado: se há uma ativação de
## habilidade pendente (Nox etc.), dispara-a; senão é a confirmação de retaguarda.
func _on_stealth_confirm_yes() -> void:
	if _frontline_modal_shown:
		_frontline_modal_shown = false
		GameState.rpc_id(1, "rpc_respond_frontline_passive", true)
		return
	if _stealth_passive_modal_shown:
		_stealth_passive_modal_shown = false
		GameState.rpc_id(1, "rpc_respond_stealth_passive", true)
		return
	if _pending_confirm_ability != "":
		var ability_id := _pending_confirm_ability
		var needs_target := _pending_confirm_needs_target
		var label := _pending_confirm_label
		_pending_confirm_ability      = ""
		_pending_confirm_needs_target = false
		_pending_confirm_label        = ""
		# Habilidade com alvo (ex.: Selo da Ruína): agora que confirmou quebrar a
		# furtividade, escolhe o herói-alvo antes de enviar.
		if needs_target:
			_ability_target_id = ability_id
			_open_pick_hero_for_ability(label)
		else:
			GameState.rpc_id(1, "rpc_activate_ability", ability_id, [])
		return
	GameState.rpc_id(1, "rpc_respond_backline_ability", true)

func _on_stealth_confirm_no() -> void:
	if _frontline_modal_shown:
		_frontline_modal_shown = false
		GameState.rpc_id(1, "rpc_respond_frontline_passive", false)
		return
	if _stealth_passive_modal_shown:
		_stealth_passive_modal_shown = false
		GameState.rpc_id(1, "rpc_respond_stealth_passive", false)
		return
	if _pending_confirm_ability != "":
		_pending_confirm_ability      = ""
		_pending_confirm_needs_target = false
		_pending_confirm_label        = ""
		return
	GameState.rpc_id(1, "rpc_respond_backline_ability", false)

## Centro visual global de um slot. Usa o transform real (não get_global_rect),
## que trata corretamente o half board espelhado do oponente (scale -1,-1) —
## get_global_rect() devolve a position no canto errado nesse caso.
func _slot_center(slot: Control) -> Vector2:
	return slot.get_global_transform() * (slot.size * 0.5)

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
	# O mesmo modal (_pick_hero) serve ao disparo de mísseis — roteia se estiver firing.
	if _missile_fire_active:
		_on_missile_target_picked(hero)
		return
	# Alvo de habilidade ACTION/BONUS com needs_target (ex.: Selo da Ruína da Lilith).
	if _ability_target_id != "":
		var aid := _ability_target_id
		_ability_target_id = ""
		var tp := -1
		var th := -1
		for i in 2:
			var idx := GameState.players[i].heroes.find(hero)
			if idx >= 0:
				tp = i
				th = idx
				break
		if tp >= 0:
			GameState.rpc_id(1, "rpc_activate_ability", aid, [[tp, th]])
		return
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
		var from_pos := _slot_center(source_slot)
		var to_pos   := _slot_center(target_slot)
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
		var from_pos := _slot_center(source_slot)
		var to_pos   := _slot_center(target_slot)
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

# ── ferramentas de teste (sala debug) ────────────────────────────────────────
# TUDO aqui é criado SOB DEMANDA e só em partida debug (is_debug_match). Em partida
# normal nenhum desses nós é instanciado — zero impacto em mecânica ou performance.
# Ambos os jogadores da sala debug têm acesso.
func _ensure_debug_button() -> void:
	if _debug_button != null:
		return
	_debug_button = Button.new()
	_debug_button.text = "DEBUG"
	_debug_button.custom_minimum_size = Vector2(96, 34)
	_debug_button.position = Vector2(20, 20)
	_debug_button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_debug_button.pressed.connect(_on_debug_button_pressed)
	$UI.add_child(_debug_button)

# O picker (grade de 100+ cartas) só é construído quando o jogador clica DEBUG pela
# primeira vez — nunca no load do board.
func _ensure_debug_picker() -> void:
	if _debug_picker != null:
		return
	_debug_picker = DebugCardPickerScript.new()
	add_child(_debug_picker)
	_debug_picker.card_picked.connect(_on_debug_card_picked)

func _on_debug_button_pressed() -> void:
	_ensure_debug_picker()
	_debug_picker.open()

func _on_debug_card_picked(card_id: int) -> void:
	if multiplayer.is_server():
		GameState.rpc_debug_give_card(card_id)
	else:
		GameState.rpc_id(1, "rpc_debug_give_card", card_id)

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
	# terminar para só então mostrar o resultado.
	if _combat_vfx != null and is_instance_valid(_combat_vfx):
		_combat_vfx.finished.connect(
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

# Recompensas rankeadas (tier/pontos/ouro) chegam logo após game_over; alimenta a tela de
# resultado para animar o módulo de rank/ouro. Em partidas casuais nunca chega (módulo fica oculto).
func _on_match_rewards(data: Dictionary) -> void:
	if _game_result != null and is_instance_valid(_game_result):
		_game_result.apply_rewards(data)

func _on_result_closed() -> void:
	# Tutorial: volta pra taverna (encerramento do Blauber). Offline → derruba o peer local.
	if NetworkState.tutorial_mode:
		NetworkState.tutorial_mode = false
		NetworkState.tutorial_return = true
		multiplayer.multiplayer_peer = null
		get_tree().change_scene_to_file("res://scenes/world/quests/onboarding/taverna.tscn")
		return
	if NetworkState.match_origin_world:
		# Partida veio do mundo: mantém a conexão ENet com o servidor viva e
		# devolve o jogador ao mundo aberto (Modelo A).
		NetworkState.match_origin_world = false
		get_tree().change_scene_to_file("res://scenes/world/world_root.tscn")
	else:
		multiplayer.multiplayer_peer = null
		get_tree().change_scene_to_file("res://scenes/ui/login/login.tscn")
