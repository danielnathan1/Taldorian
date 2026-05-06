# scenes/ui/boardv2/mulligan_screen.gd
extends Control

const CardViewScene := preload("res://scenes/ui/card_view/card_view.tscn")

@onready var cards_row     := $CardsRow
@onready var btn_confirmar := $BtnConfirmar
@onready var title_label   := $TitleLabel

var _selected_indices: Array[int] = []
var _waiting_label: Label = null

func _ready() -> void:
	btn_confirmar.pressed.connect(_on_btn_confirmar_pressed)
	btn_confirmar.disabled = true
	GameBus.state_synced.connect(_on_state_synced)
	_waiting_label = Label.new()
	_waiting_label.text = "Aguardando oponente escolher cartas..."
	_waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_waiting_label.add_theme_font_size_override("font_size", 28)
	_waiting_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_waiting_label.set_anchors_preset(Control.PRESET_CENTER)
	_waiting_label.position = Vector2(760, 540)
	_waiting_label.custom_minimum_size = Vector2(400, 60)
	_waiting_label.visible = false
	add_child(_waiting_label)
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
		var view: CardView = CardViewScene.instantiate()
		view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		view.size_flags_vertical   = Control.SIZE_FILL
		cards_row.add_child(view)
		view.bind(hand[i])
		view.card_clicked.connect(_on_card_clicked.bind(i))

func _on_card_clicked(_card: Card, hand_index: int) -> void:
	if hand_index in _selected_indices:
		_selected_indices.erase(hand_index)
	elif _selected_indices.size() < 2:
		_selected_indices.append(hand_index)
	_refresh_views()
	_refresh_confirm_button()

func _refresh_views() -> void:
	var views := cards_row.get_children()
	for i in views.size():
		(views[i] as CardView).set_selected(i in _selected_indices)

func _refresh_confirm_button() -> void:
	btn_confirmar.disabled = (_selected_indices.size() != 2)

func _on_btn_confirmar_pressed() -> void:
	if _selected_indices.size() != 2:
		return
	GameState.rpc_id(1, "rpc_submit_mulligan", _selected_indices[0], _selected_indices[1])
	_set_waiting(true)

func _set_waiting(waiting: bool) -> void:
	cards_row.visible      = not waiting
	btn_confirmar.visible  = not waiting
	title_label.visible    = not waiting
	_waiting_label.visible = waiting

func _on_state_synced() -> void:
	if not visible:
		return
	var local_idx := NetworkState.local_player_index
	if GameState.has_completed_opening_mulligan(local_idx):
		_set_waiting(true)
	else:
		_set_waiting(false)
		_rebuild_cards()
