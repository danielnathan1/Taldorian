# scenes/ui/collection/components/collection_card_cell.gd
# Célula da grade de cartas da Coleção — CardView + "Possui N" + foil.
# Versão de exibição do picker_card_row (sem os botões de deck).
extends PanelContainer

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")

signal preview_requested(card_dict: Dictionary)

var _card_dict: Dictionary = {}


func _ready() -> void:
	add_theme_stylebox_override("panel", S.panel_surface())
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_get_card_view().gui_input.connect(_on_card_input)
	var fl := _get_foil_label()
	fl.add_theme_color_override("font_color", S.C_GOLD_GLOW)
	fl.add_theme_font_size_override("font_size", 13)
	var ol := _get_owned_label()
	ol.add_theme_color_override("font_color", S.C_PARCHMENT_D)
	ol.add_theme_font_size_override("font_size", 13)


func bind(p_card: Dictionary) -> void:
	_card_dict = p_card
	_get_card_view().bind_dict(p_card)
	_schedule_card_scale()

	# owned_quantity / foil_quantity vêm enriquecidos de Collection.query_cards.
	_get_owned_label().text = "Possui %d" % int(p_card.get("owned_quantity", 0))
	var foil_qty := int(p_card.get("foil_quantity", 0))
	var foil_label := _get_foil_label()
	foil_label.visible = foil_qty > 0
	if foil_qty > 0:
		foil_label.text = "✦ %d foil" % foil_qty


func _on_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		preview_requested.emit(_card_dict)


func _schedule_card_scale() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var view := _get_card_view()
	if not is_instance_valid(view):
		return
	var factor: float = clamp(view.size.y / 240.0, 0.5, 3.0)
	view.apply_scale(factor)


func _on_mouse_entered() -> void:
	add_theme_stylebox_override("panel", S.panel_surface2())


func _on_mouse_exited() -> void:
	add_theme_stylebox_override("panel", S.panel_surface())


func _get_card_view() -> Control: return $MarginContainer/VBox/CardWrapper/CardView
func _get_owned_label() -> Label: return $MarginContainer/VBox/OwnedLabel
func _get_foil_label() -> Label:  return $MarginContainer/VBox/FoilLabel
