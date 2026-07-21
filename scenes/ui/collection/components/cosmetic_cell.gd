# scenes/ui/collection/components/cosmetic_cell.gd
# Célula de cosmético (sleeve/playmat) da Coleção — arte + nome, só exibição.
extends PanelContainer

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")


func _ready() -> void:
	add_theme_stylebox_override("panel", S.panel_surface())
	var nl := _get_name_label()
	nl.add_theme_color_override("font_color", S.C_PARCHMENT_D)
	nl.add_theme_font_size_override("font_size", 11)


## p_size: tamanho da arte (sleeves 72×100, playmats 192×108, como no cosmetics_panel).
func bind(p_name: String, p_tex_path: String, p_size: Vector2) -> void:
	var tex := _get_tex()
	tex.custom_minimum_size = p_size
	if ResourceLoader.exists(p_tex_path):
		tex.texture = load(p_tex_path)
	_get_name_label().text = p_name


func _get_tex() -> TextureRect:   return $MarginContainer/VBox/Tex
func _get_name_label() -> Label:  return $MarginContainer/VBox/NameLabel
