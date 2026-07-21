# scenes/ui/boardv2/mulligan_screen.gd
extends Control

signal mulligan_submitted

const CardViewScene := preload("res://scenes/ui/card_view/card_view.tscn")

@onready var cards_row     := $CardsRow
@onready var btn_confirmar := $BtnConfirmar
@onready var title_label   := $TitleLabel

var _selected_indices: Array[int] = []
var _restrict_indices: Array = []   # vazio = sem restrição; tutorial limita a seleção a estes índices

## Tutorial: só permite marcar as cartas nestes índices (re-aplicado a cada rebuild). [] limpa.
func restrict_to(p_indices: Array) -> void:
	_restrict_indices = p_indices.duplicate()
	if is_node_ready() and visible:
		_apply_restriction()

func _apply_restriction() -> void:
	if _restrict_indices.is_empty():
		return
	var wrappers := cards_row.get_children()
	for i in wrappers.size():
		var view := wrappers[i].get_child(0) as CardView
		if view:
			view.set_interactable(i in _restrict_indices, true)

func _ready() -> void:
	btn_confirmar.pressed.connect(_on_btn_confirmar_pressed)
	btn_confirmar.disabled = true
	GameBus.state_synced.connect(_on_state_synced)
	if visible:
		_rebuild_cards()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible and is_node_ready():
		_rebuild_cards()

func _rebuild_cards() -> void:
	if GameState.players.is_empty():
		return
	for child in cards_row.get_children():
		child.queue_free()
	_selected_indices.clear()
	_refresh_confirm_button()
	cards_row.offset_left   = 40.0
	cards_row.offset_right  = -40.0
	cards_row.offset_top    = 280.0
	cards_row.offset_bottom = -280.0
	var hand := GameState.players[NetworkState.local_player_index].hand
	for i in hand.size():
		var wrapper := AspectRatioContainer.new()
		wrapper.ratio = 2.0 / 3.0
		wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrapper.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		var view: CardView = CardViewScene.instantiate()
		view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		view.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		wrapper.add_child(view)
		cards_row.add_child(wrapper)
		view.bind(hand[i])
		view.apply_scale(1.6)
		view.card_clicked.connect(_on_card_clicked.bind(i))
	_apply_restriction()

func _on_card_clicked(_card: Card, hand_index: int) -> void:
	if hand_index in _selected_indices:
		_selected_indices.erase(hand_index)
	elif _selected_indices.size() < 2:
		_selected_indices.append(hand_index)
	_refresh_views()
	_refresh_confirm_button()

func _refresh_views() -> void:
	var wrappers := cards_row.get_children()
	for i in wrappers.size():
		var view := wrappers[i].get_child(0) as CardView
		if view:
			view.set_selected(i in _selected_indices)

func _refresh_confirm_button() -> void:
	btn_confirmar.disabled = (_selected_indices.size() != 2)

func _on_btn_confirmar_pressed() -> void:
	if _selected_indices.size() != 2:
		return
	GameState.rpc_id(1, "rpc_submit_mulligan", _selected_indices[0], _selected_indices[1])
	mulligan_submitted.emit()
	hide()

func _on_state_synced() -> void:
	if not visible:
		return
	var local_idx := NetworkState.local_player_index
	if GameState.has_completed_opening_mulligan(local_idx):
		mulligan_submitted.emit()
		hide()
	else:
		_rebuild_cards()
