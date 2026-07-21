# scenes/ui/card_preview/card_preview.gd
extends Control

@onready var _hero_slot: HeroSlot = $HeroSlot
@onready var _card_slot: CardView = $CardView

@onready var _status_panel: PanelContainer = $StatusPanel
@onready var _seal_row: Control          = $StatusPanel/Margin/VBox/SeloRuina
@onready var _seal_icon: TextureRect     = $StatusPanel/Margin/VBox/SeloRuina/Icon
@onready var _seal_title: Label          = $StatusPanel/Margin/VBox/SeloRuina/Text/Title
@onready var _seal_desc: Label           = $StatusPanel/Margin/VBox/SeloRuina/Text/Desc

var _hide_pending: bool = false

func _ready() -> void:
	visible = false
	GameBus.card_hovered.connect(_on_card_hovered)
	GameBus.card_hover_ended.connect(_on_hover_ended)

func _on_card_hovered(data: Dictionary) -> void:
	_hide_pending = false
	match data["type"]:
		"hero":
			_hero_slot.bind(data["hero"])
			_hero_slot.apply_scale(2.5)
			if data.has("atk"):
				_hero_slot.set_modified_attack(data["atk"])
			if data.has("def"):
				_hero_slot.set_modified_defense(data["def"])
			_hero_slot.visible = true
			_card_slot.visible = false
			_update_status_panel(data["hero"])
		"card":
			_card_slot.bind(data["card"])
			_card_slot.apply_scale(2.0)
			_card_slot.visible = true
			_hero_slot.visible = false
			_status_panel.visible = false
	visible = true

func _on_hover_ended() -> void:
	_hide_pending = true
	get_tree().create_timer(0.08).timeout.connect(func():
		if _hide_pending:
			_hide_pending = false
			visible = false
			_status_panel.visible = false
	)

## Painel à esquerda com os efeitos negativos ATIVOS no herói (agora: Selo da Ruína).
## Só existe uma linha estática; quando surgirem mais status, adiciona-se outra linha
## (ou extrai-se um status_row.tscn). Ver StatusEffects.INFO.
func _update_status_panel(hero: Hero) -> void:
	var sealed: bool = hero != null and hero.sealed_ruin
	_seal_row.visible = sealed
	if sealed:
		var info: Dictionary = StatusEffects.INFO[StatusEffects.SEAL]
		_seal_title.text = info["label"]
		_seal_desc.text  = info["desc"]
		var icon_path: String = info["icon"]
		if ResourceLoader.exists(icon_path):
			_seal_icon.texture = load(icon_path)
	_status_panel.visible = sealed
