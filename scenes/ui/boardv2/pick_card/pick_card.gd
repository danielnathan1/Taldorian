# scenes/ui/boardv2/pick_card/pick_card.gd
# Overlay genérico para o jogador escolher uma carta de uma lista.
# Usado por efeitos que precisam de input do jogador (ex.: tutor, descarte).
# DECK_PEEK usa layout dedicado: label de instrução + dois botões explícitos.
class_name PickCard
extends Control

const CardViewScene := preload("res://scenes/ui/card_view/card_view.tscn")

@onready var _cards_container    := $VBoxContainer/ScrollContainer/GridContainer
@onready var _confirm_button     := $Button
@onready var _instruction_label  := $VBoxContainer/InstructionLabel
@onready var _peek_buttons       := $VBoxContainer/PeekButtons
@onready var _btn_keep           := $VBoxContainer/PeekButtons/BtnKeep
@onready var _btn_bottom         := $VBoxContainer/PeekButtons/BtnBottom

var _selected_index: int         = -1
var _card_views: Array[CardView] = []

func _ready() -> void:
	visible = false
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_btn_keep.pressed.connect(_on_keep_pressed)
	_btn_bottom.pressed.connect(_on_bottom_pressed)
	GameBus.state_synced.connect(_on_state_synced)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready():
		if visible:
			_rebuild()

# ── rebuild ──────────────────────────────────────────────

func _rebuild() -> void:
	for child in _cards_container.get_children():
		child.queue_free()
	_card_views.clear()
	_selected_index          = -1
	_confirm_button.disabled = true

	var local_idx   := NetworkState.local_player_index
	var source      := GameState.get_pending_pick_source()
	var cards       := GameState.get_pending_pick_cards(local_idx)
	var is_peek     := source == GameState.PickSource.DECK_PEEK
	var instruction := GameState.get_pending_pick_instruction()

	# Instrução: mostrar se vier do efeito ou se for DECK_PEEK (tem texto padrão no .tscn)
	if instruction != "":
		_instruction_label.text = instruction
	_instruction_label.visible = is_peek or instruction != ""

	_peek_buttons.visible   = is_peek
	_confirm_button.visible = not is_peek

	for i in cards.size():
		var view: CardView = CardViewScene.instantiate()
		_cards_container.add_child(view)
		view.bind(cards[i])
		view.apply_scale(1.0)
		# Em DECK_PEEK a carta é só exibição — a ação é feita pelos dois botões
		if not is_peek:
			view.card_clicked.connect(_on_card_clicked.bind(i))
		_card_views.append(view)

# ── interações (modo genérico) ────────────────────────────

func _on_card_clicked(_card: Card, index: int) -> void:
	_selected_index = index
	for i in _card_views.size():
		_card_views[i].set_selected(i == index)
	_confirm_button.disabled = false

func _on_confirm_pressed() -> void:
	if _selected_index < 0:
		return
	GameState.rpc_id(1, "rpc_submit_card_pick", [_selected_index])
	visible = false

# ── interações (modo DECK_PEEK) ───────────────────────────

func _on_keep_pressed() -> void:
	# Array vazio → servidor mantém carta no topo (no-op)
	GameState.rpc_id(1, "rpc_submit_card_pick", [])
	visible = false

func _on_bottom_pressed() -> void:
	# [0] → servidor move deck[0] ao fundo
	GameState.rpc_id(1, "rpc_submit_card_pick", [0])
	visible = false

# ── estado ───────────────────────────────────────────────

func _on_state_synced() -> void:
	var local_idx  := NetworkState.local_player_index
	var is_my_pick := GameState.get_pending_pick_player() == local_idx
	var source     := GameState.get_pending_pick_source()
	var is_hand    := source == GameState.PickSource.HAND \
	               or source == GameState.PickSource.HAND_DISCARD
	visible = is_my_pick and not is_hand
