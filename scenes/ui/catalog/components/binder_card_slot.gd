# scenes/ui/catalog/components/binder_card_slot.gd
# Uma célula 4×4 do fichário: a carta (colorida se possuída, P&B se não) ou vazia.
# A divisão entre células (linhas douradas) é desenhada pela página, não aqui.
extends AspectRatioContainer

signal preview_requested(card_dict: Dictionary)

var _card_dict: Dictionary = {}

@onready var _card_view: CardView = $Margin/CardView


func _ready() -> void:
	ratio = 0.6667
	# Zera o min do CardView (160×240 no .tscn) para o slot poder encolher e caber
	# as 4 linhas do grid sem empurrar a barra de navegação p/ fora da tela.
	_card_view.custom_minimum_size = Vector2.ZERO
	_card_view.set_preview_enabled(false)
	_card_view.gui_input.connect(_on_card_input)
	if not _card_view.resized.is_connected(_apply_scale):
		_card_view.resized.connect(_apply_scale)


## Célula com carta. p_owned = jogador possui (ou já teve) → colorida; senão P&B.
func bind(p_card: Dictionary, p_owned: bool) -> void:
	_card_dict = p_card
	_card_view.visible = true
	_card_view.bind_dict(p_card)
	_card_view.set_grayscale(not p_owned)
	_apply_scale()


## Célula vazia (posição do fichário sem carta neste spread).
func set_empty() -> void:
	_card_dict = {}
	_card_view.visible = false


func _apply_scale() -> void:
	if not is_instance_valid(_card_view) or not _card_view.visible or _card_view.size.y <= 1.0:
		return
	_card_view.apply_scale(clamp(_card_view.size.y / 240.0, 0.5, 3.0))


func _on_card_input(event: InputEvent) -> void:
	if _card_dict.is_empty():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		preview_requested.emit(_card_dict)
