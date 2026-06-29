# scenes/ui/boardv2/deck_reveal/deck_reveal.gd
# Overlay "só olhar": revela a carta do topo do deck para o jogador (efeito de 1
# fragmento da loja do Fragmento Arcano). Pura informação — ao fechar, envia
# rpc_ack_reveal. Auto-gerenciado via state_synced, como o PickSymbol.
extends Control

const CardViewScene := preload("res://scenes/ui/card_view/card_view.tscn")

var _card_holder: Control
var _card_view: CardView = null
var _shown_card: Card = null
# Quando true, segura a exibição (ex.: enquanto o VFX do Fragmento toca primeiro).
var _held: bool = false

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	GameBus.state_synced.connect(_on_state_synced)

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	add_child(vbox)

	var header := Label.new()
	header.text = "Topo do seu deck"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(0.78, 0.62, 1.0))
	vbox.add_child(header)

	_card_holder = CenterContainer.new()
	_card_holder.custom_minimum_size = Vector2(260, 380)
	vbox.add_child(_card_holder)

	var ok := Button.new()
	ok.text = "Entendi"
	ok.custom_minimum_size = Vector2(160, 46)
	ok.add_theme_font_size_override("font_size", 18)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(_on_ok_pressed)
	vbox.add_child(ok)

func _bind_card(card: Card) -> void:
	if _card_view == null:
		_card_view = CardViewScene.instantiate()
		_card_view.custom_minimum_size = Vector2(240, 360)
		_card_holder.add_child(_card_view)
		_card_view.set_interactable(false, false)
		_card_view.set_preview_enabled(false)
		# CardView nasce com fontes tamanho 1 — apply_scale dimensiona o texto.
		# Fator 1.5 = 240/160 (tamanho base do CardView), pra ficar proporcional.
		_card_view.apply_scale(1.5)
	_card_view.bind(card)

func _on_ok_pressed() -> void:
	visible = false
	GameState.rpc_id(1, "rpc_ack_reveal")

## Segura a exibição até release() (o board toca o VFX do Fragmento antes).
func hold() -> void:
	_held = true
	visible = false

## Libera e reavalia o estado atual (mostra a carta se ainda houver reveal pendente).
func release() -> void:
	_held = false
	_on_state_synced()

func _on_state_synced() -> void:
	if _held:
		visible = false
		return
	var local_idx := NetworkState.local_player_index
	var show := GameState.get_pending_reveal_player() == local_idx
	if show:
		var card := GameState.get_pending_reveal_card()
		if card != null and card != _shown_card:
			_shown_card = card
			_bind_card(card)
	else:
		_shown_card = null
	visible = show
