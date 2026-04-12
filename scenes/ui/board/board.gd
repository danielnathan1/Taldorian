# scenes/ui/board/board.gd
class_name Board
extends Node2D

# referências aos slots de herói
@onready var player_hero_slots   := $TableLayout/PlayerArea/PlayerHeroes
@onready var opponent_hero_slots := $TableLayout/OpponentArea/OpponentHeroes
@onready var player_hand_node    := $TableLayout/PlayerArea/PlayerHand
@onready var opponent_hand_node  := $TableLayout/OpponentArea/OpponentHand
@onready var phase_label         := $UI/PhaseLabel
@onready var action_button       := $UI/ActionButton
@onready var combat_zone         := $TableLayout/CombatZone

const HeroSlotScene := preload("res://scenes/ui/hero_slot/hero_slot.tscn")
const CardViewScene := preload("res://scenes/ui/card_view/card_view.tscn")

func _ready() -> void:
	_connect_bus()
	_spawn_hero_slots()
	_rebuild_hand()
	print("iniciou")

# ── GameBus → Board ─────────────────────────────────────
func _connect_bus() -> void:
	GameBus.state_synced.connect(_on_state_synced)
	GameBus.phase_changed.connect(_on_phase_changed)
	GameBus.turn_started.connect(_on_phase_changed)
	GameBus.card_drawn.connect(_on_card_drawn)
	GameBus.hero_damaged.connect(_on_hero_damaged)
	GameBus.hero_defeated.connect(_on_hero_defeated)
	GameBus.combat_resolved.connect(_on_combat_resolved)

# ── inicialização visual ─────────────────────────────────
func _spawn_hero_slots() -> void:
	var local_idx    := NetworkState.local_player_index
	var opponent_idx := 1 - local_idx

	for hero in GameState.players[local_idx].heroes:
		var slot: HeroSlot = HeroSlotScene.instantiate()
		player_hero_slots.add_child(slot)
		slot.bind(hero)
		slot.slot_clicked.connect(_on_hero_slot_clicked)

	for hero in GameState.players[opponent_idx].heroes:
		var slot: HeroSlot = HeroSlotScene.instantiate()
		opponent_hero_slots.add_child(slot)
		slot.bind(hero)

# ── reações ao GameBus ───────────────────────────────────
func _on_phase_changed(phase: String) -> void:
	$PhaseOverlay/MulliganScreen.visible = (phase == "OPENING_MULLIGAN")
	phase_label.text = phase
	_refresh_action_button(phase)

func _on_card_drawn(player_index: int) -> void:
	if player_index == 0:
		_rebuild_hand()

func _on_hero_damaged(hero: Hero, _amount: int) -> void:
	_refresh_hero_slot(hero)

func _on_hero_defeated(hero: Hero) -> void:
	_refresh_hero_slot(hero)

func _on_combat_resolved(ctx: BattleContext) -> void:
	# atualiza os dois lados
	_refresh_hero_slot(ctx.attacker)
	_refresh_hero_slot(ctx.defender)

# ── mão do jogador ───────────────────────────────────────
func _rebuild_hand() -> void:
	for child in player_hand_node.get_children():
		child.queue_free()

	var hand := GameState.players[0].hand
	for card in hand:
		var view: CardView = CardViewScene.instantiate()
		player_hand_node.add_child(view)
		view.bind(card)
		view.card_clicked.connect(_on_card_clicked)

# ── interações do jogador ────────────────────────────────
func _on_hero_slot_clicked(player_index: int, hero: Hero) -> void:
	# emite pro GameBus — a lógica decide se é válido
	print("teste")
	GameBus.hero_chosen.emit(player_index, hero)

func _on_card_clicked(card: Card) -> void:
	GameBus.card_played.emit(card)

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

func _on_state_synced() -> void:
	# redesenha tudo com o estado atual
	_rebuild_hand()
	for slot in player_hero_slots.get_children():
		slot.refresh()
	for slot in opponent_hero_slots.get_children():
		slot.refresh()
