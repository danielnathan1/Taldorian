# scenes/ui/boardv2/arsenal_screen.gd
extends Control

const CardViewScene := preload("res://scenes/ui/card_view/card_view.tscn")

@onready var cards_row     := $CardsRow
@onready var btn_confirmar := $BtnConfirmar
@onready var btn_pular     := $BtnPular
@onready var waiting_label := $WaitingLabel

var _selected_index: int = -1
var _restrict_indices: Array = []   # vazio = sem restrição; tutorial força guardar uma carta específica

## Tutorial: só permite escolher estes índices e OBRIGA guardar (esconde "Pular"). [] limpa.
func restrict_to(p_indices: Array) -> void:
	_restrict_indices = p_indices.duplicate()
	if is_node_ready() and visible:
		_rebuild_cards()

## Tutorial: força TODOS os cards do arsenal como clicáveis (chamado todo frame pelo diretor,
## revertendo qualquer coisa que os desabilite). Só há 1 card (a carta que sobrou).
func tutorial_keep_clickable() -> void:
	for c in cards_row.get_children():
		var v := c as CardView
		if v:
			v.set_interactable(true, true)

func _apply_restriction() -> void:
	if _restrict_indices.is_empty():
		return
	var views := cards_row.get_children()
	for i in views.size():
		var v := views[i] as CardView
		if v:
			v.set_interactable(i in _restrict_indices, true)
	btn_pular.disabled = true
	btn_pular.visible = false   # no tutorial guardar é obrigatório

func _ready() -> void:
	btn_confirmar.pressed.connect(_on_btn_confirmar_pressed)
	btn_pular.pressed.connect(_on_btn_pular_pressed)
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
	_selected_index = -1
	btn_confirmar.disabled = false
	btn_pular.disabled     = false
	var local_idx         := NetworkState.local_player_index
	var already_submitted := GameState.get_end_submitted(local_idx)
	var has_arsenal       := not GameState.players[local_idx].arsenal.is_empty()
	if has_arsenal and not already_submitted:
		GameState.rpc_id(1, "rpc_finish_battle", -1)
		return
	waiting_label.visible = already_submitted
	cards_row.visible     = not already_submitted
	btn_confirmar.visible = not already_submitted
	btn_pular.visible     = not already_submitted
	if already_submitted:
		return
	var hand := GameState.players[local_idx].hand
	var n := hand.size()
	const MAX_CARD_WIDTH := 220.0
	const CARD_ASPECT    := 1.5
	const ROW_WIDTH      := 1400.0
	const SEPARATION     := 20.0
	var card_w := minf(MAX_CARD_WIDTH, (ROW_WIDTH - SEPARATION * maxf(0.0, n - 1)) / maxf(1.0, n))
	var card_h := card_w * CARD_ASPECT
	for i in n:
		var view: CardView = CardViewScene.instantiate()
		view.custom_minimum_size  = Vector2(card_w, card_h)
		view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		view.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
		cards_row.add_child(view)
		view.bind(hand[i])
		view.apply_scale(card_w / 160.0)
		view.card_clicked.connect(_on_card_clicked.bind(i))
	_refresh_confirm_button()
	_apply_restriction()

func _on_card_clicked(_card: Card, hand_index: int) -> void:
	# Tutorial: um clique na carta permitida já guarda (evita depender do 2º passo do botão,
	# que a reconstrução por state_synced poderia resetar).
	if not _restrict_indices.is_empty():
		if hand_index in _restrict_indices:
			# Chamada DIRETA no modo autoridade-local (tutorial offline) — mais confiável que rpc_id.
			if multiplayer.is_server():
				GameState.finish_end_battle(NetworkState.local_player_index, hand_index)
			else:
				GameState.rpc_id(1, "rpc_finish_battle", hand_index)
			btn_confirmar.disabled = true
			btn_pular.disabled = true
		return
	_selected_index = hand_index if _selected_index != hand_index else -1
	_refresh_views()
	_refresh_confirm_button()

func _refresh_views() -> void:
	var views := cards_row.get_children()
	for i in views.size():
		(views[i] as CardView).set_selected(i == _selected_index)

func _refresh_confirm_button() -> void:
	btn_confirmar.disabled = (_selected_index == -1)

func _on_btn_confirmar_pressed() -> void:
	if _selected_index == -1:
		return
	GameState.rpc_id(1, "rpc_finish_battle", _selected_index)
	btn_confirmar.disabled = true
	btn_pular.disabled     = true

func _on_btn_pular_pressed() -> void:
	GameState.rpc_id(1, "rpc_finish_battle", -1)
	btn_confirmar.disabled = true
	btn_pular.disabled     = true

func _on_state_synced() -> void:
	if not visible:
		return
	# Tutorial: com o card já montado, NÃO reconstrói a cada sync — recriar destruiria a carta e
	# resetaria o clique/interatividade (era o motivo de "não dá pra clicar" no arsenal). Só reforça
	# a restrição na carta existente.
	if not _restrict_indices.is_empty() and cards_row.get_child_count() > 0 \
			and not GameState.get_end_submitted(NetworkState.local_player_index):
		_apply_restriction()
		return
	_rebuild_cards()
