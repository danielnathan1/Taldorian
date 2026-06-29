extends PanelContainer

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")

const _ELEMENT_ICONS := {
	"fogo":  "res://assets/icons/elements/fire.png",
	"terra": "res://assets/icons/elements/earth.png",
	"agua":  "res://assets/icons/elements/water.png",
	"wind":  "res://assets/icons/elements/wind.png",
	"lightning": "res://assets/icons/elements/lightning.png",
}

signal remove_pressed(card_name: String)
signal foil_pressed(card_name: String)

var _card_name: String = ""


func _ready() -> void:
	add_theme_stylebox_override("panel", S.row_normal())
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_get_remove_btn().pressed.connect(_on_remove_pressed)
	_get_foil_btn().pressed.connect(_on_foil_pressed)


# foil    = quantas cópias deste card no deck são foil (escolha do jogador)
# max_foil= teto = min(cópias no deck, foil possuídas). 0 → jogador não tem foil → some.
func bind(p_card_name: String, count: int, atk: int, def_v: int, symbols: Array = [], foil: int = 0, max_foil: int = 0) -> void:
	_card_name = p_card_name
	_get_count_label().text = "×%d" % count
	_get_name_label().text  = p_card_name
	_get_stats_label().text = "⚔ %+d  🛡 %+d" % [atk, def_v]
	S.apply_button_crimson(_get_remove_btn())
	_get_element_icon().texture = _load_element_icon(symbols)
	var foil_btn := _get_foil_btn()
	foil_btn.visible = max_foil > 0
	if max_foil > 0:
		foil_btn.text = "✦%d" % foil
		foil_btn.tooltip_text = "Cópias foil: %d/%d (clique para alternar)" % [foil, max_foil]
		S.apply_chip(foil_btn, foil > 0)


func _load_element_icon(symbols: Array) -> Texture2D:
	for sym in symbols:
		var path: String = _ELEMENT_ICONS.get(str(sym), "")
		if path != "" and ResourceLoader.exists(path):
			return load(path)
	return null


func _on_remove_pressed() -> void:
	remove_pressed.emit(_card_name)


func _on_foil_pressed() -> void:
	foil_pressed.emit(_card_name)


func _on_mouse_entered() -> void:
	add_theme_stylebox_override("panel", S.row_hover())


func _on_mouse_exited() -> void:
	add_theme_stylebox_override("panel", S.row_normal())


func _get_count_label()   -> Label:       return $MarginContainer/HBox/CountLabel
func _get_name_label()    -> Label:       return $MarginContainer/HBox/NameLabel
func _get_element_icon()  -> TextureRect: return $MarginContainer/HBox/ElementIcon
func _get_stats_label()   -> Label:       return $MarginContainer/HBox/StatsLabel
func _get_foil_btn()      -> Button:      return $MarginContainer/HBox/FoilBtn
func _get_remove_btn()    -> Button:      return $MarginContainer/HBox/RemoveBtn
