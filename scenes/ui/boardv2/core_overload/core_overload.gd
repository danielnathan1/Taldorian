# scenes/ui/boardv2/core_overload/core_overload.gd
# Overlay de 2 fases da Sobrecarga de Núcleo (self-managed via state_synced):
#   Fase 1 → escolher quais tokens destruir (multi-seleção, 0..todos).
#   Fase 2 → distribuir os pontos (1 por token destruído) entre ataque e defesa via slider.
class_name CoreOverload
extends Control

const TokenViewScene := preload("res://scenes/ui/token_view/token_view.tscn")

@onready var _instruction      := $VBoxContainer/InstructionLabel
@onready var _tokens_page      := $VBoxContainer/TokensPage
@onready var _tokens_grid      := $VBoxContainer/TokensPage/GridContainer
@onready var _distribute_page  := $VBoxContainer/DistributePage
@onready var _atk_value        := $VBoxContainer/DistributePage/AtkValue
@onready var _atk_minus        := $VBoxContainer/DistributePage/AtkButtons/AtkMinus
@onready var _atk_plus         := $VBoxContainer/DistributePage/AtkButtons/AtkPlus
@onready var _def_value        := $VBoxContainer/DistributePage/DefValue
@onready var _def_minus        := $VBoxContainer/DistributePage/DefButtons/DefMinus
@onready var _def_plus         := $VBoxContainer/DistributePage/DefButtons/DefPlus
@onready var _remaining_label  := $VBoxContainer/DistributePage/RemainingLabel
@onready var _confirm_button   := $Button

var _selected: Array[int]          = []
var _token_views: Array[TokenView] = []
var _points: int                   = 0
var _atk: int                      = 0
var _def: int                      = 0

func _ready() -> void:
	visible = false
	_confirm_button.pressed.connect(_on_confirm)
	_atk_minus.pressed.connect(_on_atk_minus)
	_atk_plus.pressed.connect(_on_atk_plus)
	_def_minus.pressed.connect(_on_def_minus)
	_def_plus.pressed.connect(_on_def_plus)
	GameBus.state_synced.connect(_on_state_synced)

func _on_state_synced() -> void:
	var local := NetworkState.local_player_index
	if GameState.get_pending_overload_player() != local:
		visible = false
		return
	var phase := GameState.get_pending_overload_phase()
	if phase == 1:
		visible = true
		_show_tokens_phase(local)
	elif phase == 2:
		visible = true
		_show_distribute_phase()
	else:
		visible = false

# ── Fase 1: escolher tokens ──────────────────────────────
func _show_tokens_phase(local: int) -> void:
	_tokens_page.visible = true
	_distribute_page.visible = false
	_instruction.text = "Destrua tokens (cada um vira 1 ponto de ataque/defesa)."
	for c in _tokens_grid.get_children():
		c.queue_free()
	_token_views.clear()
	_selected.clear()
	var tokens := GameState.players[local].tokens
	for i in tokens.size():
		var view: TokenView = TokenViewScene.instantiate()
		_tokens_grid.add_child(view)
		view.bind(tokens[i], 1)
		view.apply_scale(1.2)
		view.token_clicked.connect(_on_token_clicked.bind(i))
		_token_views.append(view)
	_confirm_button.text = "Destruir selecionados"
	_confirm_button.disabled = false   # pode confirmar com 0

func _on_token_clicked(_t: Token, index: int) -> void:
	if _selected.has(index):
		_selected.erase(index)
		_token_views[index].modulate = Color.WHITE
	else:
		_selected.append(index)
		_token_views[index].modulate = Color(1.0, 0.85, 0.3)

# ── Fase 2: distribuir pontos ────────────────────────────
func _show_distribute_phase() -> void:
	_tokens_page.visible = false
	_distribute_page.visible = true
	_points = GameState.get_pending_overload_points()
	_atk = 0
	_def = 0
	_instruction.text = "Distribua %d ponto(s) entre ataque e defesa." % _points
	_confirm_button.text = "Confirmar"
	_update_distribute_display()

func _on_atk_plus() -> void:
	if _atk + _def < _points:
		_atk += 1
		_update_distribute_display()

func _on_atk_minus() -> void:
	if _atk > 0:
		_atk -= 1
		_update_distribute_display()

func _on_def_plus() -> void:
	if _atk + _def < _points:
		_def += 1
		_update_distribute_display()

func _on_def_minus() -> void:
	if _def > 0:
		_def -= 1
		_update_distribute_display()

func _update_distribute_display() -> void:
	var remaining := _points - _atk - _def
	_atk_value.text = "Ataque: %d" % _atk
	_def_value.text = "Defesa: %d" % _def
	_remaining_label.text = "Pontos restantes: %d" % remaining
	# Confirmar só libera quando TODOS os pontos foram distribuídos.
	_confirm_button.disabled = remaining != 0
	# Desabilita + quando não há pontos restantes; − quando o valor é 0.
	_atk_plus.disabled = remaining <= 0
	_def_plus.disabled = remaining <= 0
	_atk_minus.disabled = _atk <= 0
	_def_minus.disabled = _def <= 0

# ── confirmar ────────────────────────────────────────────
func _on_confirm() -> void:
	var phase := GameState.get_pending_overload_phase()
	if phase == 1:
		GameState.rpc_id(1, "rpc_submit_overload_tokens", _selected.duplicate())
	elif phase == 2:
		GameState.rpc_id(1, "rpc_submit_overload_distribution", _atk, _def)
	visible = false
