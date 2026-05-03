# scenes/ui/board/pick_card/pick_card.gd
# Overlay genérico para o jogador escolher uma carta de uma lista.
# Usado por efeitos que precisam de input do jogador (ex.: tutor, descarte).
class_name PickCard
extends Control

const CardViewScene := preload("res://scenes/ui/card_view/card_view.tscn")

@onready var _cards_container := $VBoxContainer/ScrollContainer/GridContainer
@onready var _confirm_button  := $Button

var _selected_index: int        = -1
var _card_views: Array[CardView] = []

func _ready() -> void:
	visible = false
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(_on_confirm_pressed)
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
	_selected_index      = -1
	_confirm_button.disabled = true

	var local_idx := NetworkState.local_player_index
	var cards     := GameState.get_pending_pick_cards(local_idx)

	for i in cards.size():
		var view: CardView = CardViewScene.instantiate()
		_cards_container.add_child(view)
		view.bind(cards[i])
		view.card_clicked.connect(_on_card_clicked.bind(i))
		_card_views.append(view)

# ── interações ───────────────────────────────────────────

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

# ── estado ───────────────────────────────────────────────

func _on_state_synced() -> void:
	var local_idx  := NetworkState.local_player_index
	var is_my_pick := GameState.get_pending_pick_player() == local_idx
	var source     := GameState.get_pending_pick_source()
	var is_hand    := source == GameState.PickSource.HAND \
	               or source == GameState.PickSource.HAND_DISCARD
	visible = is_my_pick and not is_hand
