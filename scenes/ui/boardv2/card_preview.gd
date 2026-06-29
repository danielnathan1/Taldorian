# scenes/ui/card_preview/card_preview.gd
extends Control

@onready var _hero_slot  := $HeroSlot
@onready var _card_slot  := $CardView
@onready var _token_slot := $TokenView

var _is_hovering: bool = false

func _ready() -> void:
	visible = false
	GameBus.card_hovered.connect(_on_card_hovered)
	GameBus.card_hover_ended.connect(_on_hover_ended)

func _on_card_hovered(data: Dictionary) -> void:
	_is_hovering = true
	_hero_slot.visible  = false
	_card_slot.visible  = false
	_token_slot.visible = false
	match data["type"]:
		"hero":
			_hero_slot.bind(data["hero"])
			_hero_slot.visible = true
			_hero_slot.apply_scale.call_deferred(2.0)
		"card":
			_card_slot.bind(data["card"])
			_card_slot.apply_scale(2.0)
			_card_slot.visible = true
		"token":
			_token_slot.bind(data["token"], data.get("count", 1))
			_token_slot.apply_scale(2.0)
			_token_slot.visible = true
	visible = true

func _on_hover_ended() -> void:
	_is_hovering = false
	get_tree().create_timer(0.08).timeout.connect(func():
		if not _is_hovering:
			visible = false
	)
