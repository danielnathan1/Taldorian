class_name CardView
extends Control

const SLEEVE_DEFAULT := preload("res://assets/sleve/default.png")

@onready var art_rect  := $Art
@onready var back_rect := $Back

signal card_clicked(card: Card)
signal card_double_clicked(card: Card)

var card: Card = null
var selected: bool = false
var is_opponent: bool = false
var _face_down: bool = false
var _interactable: bool = true

func _ready() -> void:
	back_rect.texture = SLEEVE_DEFAULT
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func bind(p_card: Card) -> void:
	card = p_card
	art_rect.texture = card.get_texture()

func set_sleeve(tex: Texture2D) -> void:
	back_rect.texture = tex if tex else SLEEVE_DEFAULT

func set_selected(value: bool) -> void:
	selected = value
	var base := Color(1.2, 1.2, 0.6) if selected else Color.WHITE
	base.a = modulate.a
	modulate = base

func set_face_down(value: bool) -> void:
	_face_down = value
	art_rect.visible  = not value
	back_rect.visible = value

func set_interactable(value: bool, dim_when_blocked: bool = true) -> void:
	_interactable = value
	modulate.a = 1.0 if (value or not dim_when_blocked) else 0.45

func _on_mouse_entered() -> void:
	if card == null:
		return
	if is_opponent and _face_down:
		return
	GameBus.card_hovered.emit({ "type": "card", "card": card })

func _on_mouse_exited() -> void:
	GameBus.card_hover_ended.emit()

func _gui_input(event: InputEvent) -> void:
	if not _interactable:
		return
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.double_click:
		card_double_clicked.emit(card)
	else:
		card_clicked.emit(card)
