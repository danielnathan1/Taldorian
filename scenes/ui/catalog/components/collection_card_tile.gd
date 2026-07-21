# scenes/ui/catalog/components/collection_card_tile.gd
# Capa de uma coleção na lista do Catálogo: arte + nome, clicável.
extends PanelContainer

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")

signal pressed

var _art_placeholder: bool = false

@onready var _art: TextureRect = $Margin/VBox/Art
@onready var _name_label: Label = $Margin/VBox/NameLabel


func _ready() -> void:
	add_theme_stylebox_override("panel", S.panel_surface())
	_name_label.add_theme_font_override("font", S.FONT_BOLD)
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_color", S.C_GOLD_GLOW)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void: add_theme_stylebox_override("panel", S.panel_surface2()))
	mouse_exited.connect(func() -> void: add_theme_stylebox_override("panel", S.panel_surface()))
	gui_input.connect(_on_gui_input)


func bind(p_name: String, p_art_path: String) -> void:
	_name_label.text = p_name
	if p_art_path != "" and ResourceLoader.exists(p_art_path):
		_art.texture = load(p_art_path)
	else:
		_art_placeholder = true


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
