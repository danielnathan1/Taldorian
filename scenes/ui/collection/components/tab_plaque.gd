# scenes/ui/collection/components/tab_plaque.gd
# Placa de aba da Coleção — glifo + rótulo + contagem, clicável.
extends PanelContainer

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")

signal pressed

@export var glyph: String = "✦"
@export var title: String = ""

var _active := false

@onready var _glyph_label: Label = $Margin/HBox/Glyph
@onready var _title_label: Label = $Margin/HBox/VBox/TitleLabel
@onready var _count_label: Label = $Margin/HBox/VBox/CountLabel


func _ready() -> void:
	_glyph_label.text = glyph
	_glyph_label.visible = glyph != ""
	_title_label.text = title
	_title_label.add_theme_font_override("font", S.FONT_BOLD)
	_title_label.add_theme_font_size_override("font_size", 16)
	_count_label.add_theme_font_override("font", S.FONT_REG)
	_count_label.add_theme_font_size_override("font_size", 12)
	_glyph_label.add_theme_font_size_override("font_size", 26)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_refresh_style)
	_refresh_style()


func _on_mouse_entered() -> void:
	if not _active:
		add_theme_stylebox_override("panel", _style_hover())


func set_active(p_active: bool) -> void:
	_active = p_active
	_refresh_style()


func set_count(p_text: String) -> void:
	_count_label.text = p_text


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()


func _refresh_style() -> void:
	add_theme_stylebox_override("panel", _style_active() if _active else _style_normal())
	_glyph_label.add_theme_color_override("font_color", S.C_GOLD if _active else S.C_GOLD_DIM)
	_title_label.add_theme_color_override("font_color", S.C_GOLD_GLOW if _active else S.C_PARCHMENT_D)
	_count_label.add_theme_color_override("font_color", Color(S.C_PARCHMENT_D, 0.8 if _active else 0.55))


func _style_normal() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = S.C_BG_SURFACE
	s.border_color = S.border_gold(0.18)
	s.set_border_width_all(1)
	return s


func _style_hover() -> StyleBoxFlat:
	var s := _style_normal()
	s.border_color = S.border_gold(0.35)
	return s


func _style_active() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(S.C_GOLD.r, S.C_GOLD.g, S.C_GOLD.b, 0.12)
	s.border_color = S.C_GOLD
	s.set_border_width_all(1)
	s.border_width_top = 2
	return s
