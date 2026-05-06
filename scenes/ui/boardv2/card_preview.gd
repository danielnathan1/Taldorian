# scenes/ui/card_preview/card_preview.gd
extends Control

@onready var _hero_slot := $HeroSlot
@onready var _card_slot := $CardView

var _is_hovering: bool = false

func _ready() -> void:
	visible = false
	GameBus.card_hovered.connect(_on_card_hovered)
	GameBus.card_hover_ended.connect(_on_hover_ended)

func _on_card_hovered(data: Dictionary) -> void:
	_is_hovering = true
	match data["type"]:
		"hero":
			_hero_slot.bind(data["hero"])
			_hero_slot.visible = true
			_card_slot.visible = false
		"card":
			_card_slot.bind(data["card"])
			_card_slot.visible = true
			_hero_slot.visible = false
	visible = true

func _on_hover_ended() -> void:
	_is_hovering = false
	get_tree().create_timer(0.08).timeout.connect(func():
		if not _is_hovering:
			visible = false
	)
