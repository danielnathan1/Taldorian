class_name TokenView
extends Control

## Cena reutilizável para exibir um Token — no estilo da CardView, porém com os
## atributos próprios de token: arte, título, descrição e CONTADOR. O ícone
## "activable" acende quando o token pode ser acionado (ex.: disparar mísseis).

@onready var _content        := $TokenContent
@onready var _art            := $TokenContent/Art
@onready var _title_lbl      := $TokenContent/TitleLabel
@onready var _desc_lbl       := $TokenContent/DescLabel
@onready var _counter_bg     := $TokenContent/CounterBadge
@onready var _counter_lbl    := $TokenContent/CounterBadge/CounterLabel
@onready var _activable_icon := $TokenContent/ActivableIcon
@onready var _activable_glow := $TokenContent/ActivableGlow

signal token_clicked(token: Token)

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	if token != null:
		GameBus.card_hovered.emit({ "type": "token", "token": token, "count": _count })

func _on_mouse_exited() -> void:
	GameBus.card_hover_ended.emit()

var token: Token = null
var _count: int = 1
var _interactable: bool = true

func bind(p_token: Token, p_count: int = 1) -> void:
	token = p_token
	_art.texture    = p_token.get_texture()
	_title_lbl.text = p_token.token_name
	_desc_lbl.text  = p_token.description
	set_count(p_count)

func set_count(n: int) -> void:
	_count = n
	_counter_lbl.text = "x%d" % n
	_counter_bg.visible = n > 0

## Acende/apaga o indicador de que este token pode ser acionado agora
## (ícone + halo pulsante via shader activable_glow).
func set_activable(value: bool) -> void:
	_activable_icon.visible = value
	_activable_glow.visible = value

func set_interactable(value: bool) -> void:
	_interactable = value
	modulate.a = 1.0 if value else 0.6

func apply_scale(factor: float) -> void:
	_title_lbl.add_theme_font_size_override("font_size", int(9 * factor))
	_desc_lbl.add_theme_font_size_override("font_size", int(8 * factor))
	_counter_lbl.add_theme_font_size_override("font_size", int(11 * factor))

func _gui_input(event: InputEvent) -> void:
	if not _interactable:
		return
	if event is InputEventMouseButton and event.pressed and not event.double_click:
		token_clicked.emit(token)
