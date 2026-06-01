extends PanelContainer

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")

signal add_pressed(card_name: String)
signal remove_pressed(card_name: String)
signal preview_requested(card_dict: Dictionary)

var _card_name: String     = ""
var _card_dict: Dictionary = {}


func _ready() -> void:
	add_theme_stylebox_override("panel", S.panel_surface())
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_get_add_btn().pressed.connect(_on_add_pressed)
	_get_remove_btn().pressed.connect(_on_remove_pressed)
	_get_card_view().gui_input.connect(_on_card_input)


func _on_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		preview_requested.emit(_card_dict)


func bind(card_dict: Dictionary, count_in_deck: int, max_copies: int) -> void:
	_card_name = card_dict.get("name", "")
	_card_dict = card_dict

	_get_card_view().bind_dict(card_dict)
	_schedule_card_scale()

	var count_label := _get_count_label()
	var add_btn     := _get_add_btn()
	var remove_btn  := _get_remove_btn()

	if count_in_deck > 0:
		count_label.text    = "×%d/%d" % [count_in_deck, max_copies]
		count_label.visible = true
		remove_btn.visible  = true
	else:
		count_label.visible = false
		remove_btn.visible  = false

	add_btn.disabled = (count_in_deck >= max_copies)
	S.apply_button_gold(add_btn)
	S.apply_button_gold(remove_btn)


func _schedule_card_scale() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var view := _get_card_view()
	if not is_instance_valid(view):
		return
	var factor: float = clamp(view.size.y / 240.0, 0.5, 3.0)
	view.apply_scale(factor)


func _on_add_pressed() -> void:
	add_pressed.emit(_card_name)


func _on_remove_pressed() -> void:
	remove_pressed.emit(_card_name)


func _on_mouse_entered() -> void:
	add_theme_stylebox_override("panel", S.panel_surface2())


func _on_mouse_exited() -> void:
	add_theme_stylebox_override("panel", S.panel_surface())


func _get_card_view() -> Control: return $MarginContainer/VBox/CardWrapper/CardView
func _get_count_label() -> Label:  return $MarginContainer/VBox/BtnRow/CountLabel
func _get_add_btn()    -> Button:  return $MarginContainer/VBox/BtnRow/AddBtn
func _get_remove_btn() -> Button:  return $MarginContainer/VBox/BtnRow/RemoveBtn
