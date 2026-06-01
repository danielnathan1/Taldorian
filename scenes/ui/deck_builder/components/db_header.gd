extends PanelContainer

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")

signal save_requested
signal discard_requested
signal delete_requested
signal name_changed(new_name: String)
signal back_requested


func _ready() -> void:
	add_theme_stylebox_override("panel", S.panel_mid())

	S.apply_button_gold(_get_back_btn())
	S.apply_button_gold(_get_save_btn())
	S.apply_button_gold(_get_discard_btn())
	S.apply_button_crimson(_get_delete_btn())

	_get_title_label().add_theme_font_override("font", S.FONT_BOLD)
	_get_title_label().add_theme_font_size_override("font_size", 13)
	_get_title_label().add_theme_color_override("font_color", S.C_GOLD)

	_get_name_input().text_changed.connect(_on_name_changed)
	_get_back_btn().pressed.connect(func() -> void: back_requested.emit())
	_get_save_btn().pressed.connect(func() -> void: save_requested.emit())
	_get_discard_btn().pressed.connect(func() -> void: discard_requested.emit())
	_get_delete_btn().pressed.connect(func() -> void: delete_requested.emit())

	set_dirty(false)


func set_deck_name(deck_name: String) -> void:
	_get_name_input().text = deck_name


func set_dirty(dirty: bool) -> void:
	_get_save_btn().modulate    = Color.WHITE if dirty else Color(1, 1, 1, 0.45)
	_get_discard_btn().visible  = dirty
	_get_status_label().text    = "● não salvo" if dirty else "✓ salvo"
	_get_status_label().add_theme_color_override("font_color", S.C_GOLD_GLOW if dirty else S.C_GREEN)


func _on_name_changed(text: String) -> void:
	name_changed.emit(text)


func _get_back_btn()     -> Button:   return $MarginContainer/HBox/BackBtn
func _get_title_label()  -> Label:    return $MarginContainer/HBox/TitleLabel
func _get_name_input()   -> LineEdit: return $MarginContainer/HBox/NameInput
func _get_status_label() -> Label:    return $MarginContainer/HBox/StatusLabel
func _get_save_btn()     -> Button:   return $MarginContainer/HBox/SaveBtn
func _get_discard_btn()  -> Button:   return $MarginContainer/HBox/DiscardBtn
func _get_delete_btn()   -> Button:   return $MarginContainer/HBox/DeleteBtn
