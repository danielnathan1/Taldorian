# scenes/ui/boardv2/card_preview.gd
extends Control

@onready var _hero_slot  := $HeroSlot
@onready var _card_slot  := $CardView
@onready var _token_slot := $TokenView

@onready var _status_panel: PanelContainer = $StatusPanel
@onready var _status_vbox: VBoxContainer = $StatusPanel/Margin/VBox
# Linhas de status desenhadas no editor. A de Queimadura serve de TEMPLATE (é duplicada
# para cada status ativo); a do Selo é a segunda linha do layout. Ambas escondidas em runtime,
# pois o painel é preenchido dinamicamente a partir de StatusEffects.active_on.
@onready var _seal_row: Control      = $StatusPanel/Margin/VBox/SeloRuina
@onready var _burn_row: Control      = $StatusPanel/Margin/VBox/Queimadura

var _is_hovering: bool = false
## Linhas de status instanciadas na última atualização (limpas a cada hover).
var _status_rows: Array[Control] = []

func _ready() -> void:
	visible = false
	GameBus.card_hovered.connect(_on_card_hovered)
	GameBus.card_hover_ended.connect(_on_hover_ended)

func _on_card_hovered(data: Dictionary) -> void:
	_is_hovering = true
	_hero_slot.visible  = false
	_card_slot.visible  = false
	_token_slot.visible = false
	_status_panel.visible = false
	match data["type"]:
		"hero":
			_hero_slot.bind(data["hero"])
			_hero_slot.visible = true
			_hero_slot.apply_scale.call_deferred(2.0)
			_update_status_panel(data["hero"])
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
			_status_panel.visible = false
	)

## Painel à esquerda com os efeitos negativos ATIVOS no herói (Selo, Queimadura, Veneno,
## Sangramento, Marca, Ferida, Silêncio). Data-driven: uma linha por status ativo, clonando
## a linha-template do .tscn. Fonte de verdade: StatusEffects.active_on / INFO.
func _update_status_panel(hero: Hero) -> void:
	# As linhas desenhadas no editor viram só template — escondê-las e limpar as dinâmicas.
	_seal_row.visible = false
	_burn_row.visible = false
	for r in _status_rows:
		r.queue_free()
	_status_rows.clear()
	var ids: Array[String] = StatusEffects.active_on(hero)
	for status_id in ids:
		var info: Dictionary = StatusEffects.INFO.get(status_id, {})
		if info.is_empty():
			continue
		var row: Control = _burn_row.duplicate()
		row.visible = true
		(row.get_node("Text/Title") as Label).text = info["label"]
		(row.get_node("Text/Desc") as Label).text   = info["desc"]
		var icon_path: String = info["icon"]
		if ResourceLoader.exists(icon_path):
			(row.get_node("Icon") as TextureRect).texture = load(icon_path)
		_status_vbox.add_child(row)
		_status_rows.append(row)
	_status_panel.visible = not ids.is_empty()
