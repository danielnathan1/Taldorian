# scenes/ui/boardv2/pick_symbol/pick_symbol.gd
# Overlay para o jogador escolher N símbolos (permite repetição).
class_name PickSymbol
extends Control

@onready var _label          := $VBoxContainer/Label
@onready var _buttons_row    := $VBoxContainer/HBoxContainer
@onready var _selection_row  := $VBoxContainer/SelectionRow
@onready var _confirm_button := $VBoxContainer/Confirm

const SYMBOL_LABELS := {
	"fogo":  "🔥 Fogo",
	"terra": "🌿 Terra",
	"agua":  "💧 Água",
	"ar":    "💨 Ar",
}

var _required_count: int     = 2
var _selected: Array[String] = []

func _ready() -> void:
	visible = false
	_confirm_button.pressed.connect(_on_confirm_pressed)
	GameBus.state_synced.connect(_on_state_synced)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready():
		if visible:
			_rebuild()

# ── rebuild ──────────────────────────────────────────────

func _rebuild() -> void:
	_selected.clear()
	_required_count = GameState.get_pending_symbol_count()
	_label.text = "Escolha %d elemento%s" % [_required_count, "s" if _required_count != 1 else ""]
	_confirm_button.disabled = true

	# Botões de símbolo — cria uma vez, fica reusável enquanto visível
	for child in _buttons_row.get_children():
		child.queue_free()
	for sym_id in GameSymbols.ALL:
		var btn := Button.new()
		btn.text = SYMBOL_LABELS.get(sym_id, sym_id.capitalize())
		btn.custom_minimum_size = Vector2(160, 60)
		btn.pressed.connect(_on_symbol_pressed.bind(sym_id))
		_buttons_row.add_child(btn)

	_refresh_selection_display()

# ── interações ───────────────────────────────────────────

func _on_symbol_pressed(sym_id: String) -> void:
	if _selected.size() >= _required_count:
		return
	_selected.append(sym_id)
	_refresh_selection_display()
	_confirm_button.disabled = (_selected.size() != _required_count)

func _refresh_selection_display() -> void:
	# Limpa chips antigos
	for child in _selection_row.get_children():
		child.queue_free()

	# Cria um chip por símbolo selecionado (clicável para remover)
	for i in _selected.size():
		var sym_id: String = _selected[i]
		var chip := Button.new()
		chip.text = SYMBOL_LABELS.get(sym_id, sym_id) + "  ✕"
		chip.custom_minimum_size = Vector2(140, 44)
		chip.pressed.connect(_on_chip_removed.bind(i))
		_selection_row.add_child(chip)

	# Slots vazios como placeholders
	for _j in range(_selected.size(), _required_count):
		var placeholder := Panel.new()
		placeholder.custom_minimum_size = Vector2(140, 44)
		_selection_row.add_child(placeholder)

func _on_chip_removed(index: int) -> void:
	if index < _selected.size():
		_selected.remove_at(index)
	_refresh_selection_display()
	_confirm_button.disabled = (_selected.size() != _required_count)

func _on_confirm_pressed() -> void:
	if _selected.size() != _required_count:
		return
	GameState.rpc_id(1, "rpc_submit_symbol_pick", _selected.duplicate())
	visible = false

# ── estado ───────────────────────────────────────────────

func _on_state_synced() -> void:
	var local_idx := NetworkState.local_player_index
	visible = (GameState.get_pending_symbol_player() == local_idx)
