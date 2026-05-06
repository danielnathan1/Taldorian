# scenes/ui/boardv2/discart_card/discart_card.gd
# Overlay para o jogador escolher cartas da própria mão.
#   HAND         → 1 carta escolhida vai ao fundo do deck (Ajuste Fino)
#   HAND_DISCARD → N cartas escolhidas vão ao cemitério, depois compra M (Descarte Estratégico)
class_name DiscartCard
extends Control

const CardViewScene := preload("res://scenes/ui/card_view/card_view.tscn")

@onready var _cards_container := $VBoxContainer/ScrollContainer/GridContainer
@onready var _confirm_button  := $Button

var _required_count: int      = 1
var _selected_indices: Array[int] = []
var _card_views: Array[CardView]  = []

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
	_selected_indices.clear()
	_confirm_button.disabled = true
	_required_count = GameState.get_pending_pick_count()

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
	if _selected_indices.has(index):
		# Deseleciona
		_selected_indices.erase(index)
		_card_views[index].set_selected(false)
	elif _selected_indices.size() < _required_count:
		# Seleciona (até o limite necessário)
		_selected_indices.append(index)
		_card_views[index].set_selected(true)
	else:
		# Já atingiu o limite — troca a mais antiga seleção
		var old := _selected_indices[0]
		_selected_indices.remove_at(0)
		_card_views[old].set_selected(false)
		_selected_indices.append(index)
		_card_views[index].set_selected(true)

	_confirm_button.disabled = (_selected_indices.size() != _required_count)

func _on_confirm_pressed() -> void:
	if _selected_indices.size() != _required_count:
		return
	GameState.rpc_id(1, "rpc_submit_card_pick", _selected_indices.duplicate())
	visible = false

# ── estado ───────────────────────────────────────────────

func _on_state_synced() -> void:
	var local_idx  := NetworkState.local_player_index
	var is_my_pick := GameState.get_pending_pick_player() == local_idx
	var source     := GameState.get_pending_pick_source()
	var is_hand    := source == GameState.PickSource.HAND \
	               or source == GameState.PickSource.HAND_DISCARD
	visible = is_my_pick and is_hand
