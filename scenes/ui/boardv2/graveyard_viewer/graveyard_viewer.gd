# scenes/ui/boardv2/graveyard_viewer/graveyard_viewer.gd
extends Control

const CardViewScene := preload("res://scenes/ui/card_view/card_view.tscn")

@onready var _title_label : Label           = $Panel/MarginContainer/VBox/Header/TitleLabel
@onready var _close_btn   : Button          = $Panel/MarginContainer/VBox/Header/CloseBtn
@onready var _card_grid   : HFlowContainer  = $Panel/MarginContainer/VBox/Scroll/CardGrid
@onready var _empty_label : Label           = $Panel/MarginContainer/VBox/Scroll/EmptyLabel
@onready var _dim_bg      : ColorRect       = $DimBG


func _ready() -> void:
	visible = false
	_close_btn.pressed.connect(_close)
	_dim_bg.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_close()
	)


func open(cards: Array, title: String) -> void:
	_title_label.text = title

	for child in _card_grid.get_children():
		child.queue_free()

	_empty_label.visible = cards.is_empty()

	for card in cards:
		var view: CardView = CardViewScene.instantiate()
		view.custom_minimum_size = Vector2(130, 195)
		_card_grid.add_child(view)
		view.bind(card)
		view.apply_scale(1.2)
		view.set_interactable(false, false)

	visible = true


func _close() -> void:
	visible = false
