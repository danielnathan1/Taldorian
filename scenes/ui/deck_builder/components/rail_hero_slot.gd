extends PanelContainer

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")

signal remove_pressed(hero_name: String)

var _hero_name: String = ""


func _ready() -> void:
	_set_empty_style()
	_get_remove_btn().pressed.connect(_on_remove_pressed)


func bind_hero(p_hero: Hero) -> void:
	_hero_name = p_hero.hero_name
	var slot := _get_hero_slot()
	slot.set_hp_visible(false)
	slot.bind(p_hero)
	slot.visible = true
	_get_empty_label().visible = false
	_get_remove_btn().visible  = true
	add_theme_stylebox_override("panel", S.panel_surface())
	_schedule_hero_scale()


func _schedule_hero_scale() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_apply_hero_scale()


func bind_empty(slot_index: int) -> void:
	_hero_name = ""
	_get_hero_slot().visible   = false
	_get_empty_label().visible = true
	_get_empty_label().text    = "Slot %d\nvazio" % (slot_index + 1)
	_get_remove_btn().visible  = false
	_set_empty_style()


func _apply_hero_scale() -> void:
	var slot := _get_hero_slot()
	if not is_instance_valid(slot):
		return
	var factor: float = clamp(slot.size.y / 240.0, 0.5, 3.0)
	slot.apply_scale(factor)


func _set_empty_style() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color    = Color(S.C_BG_SURFACE.r, S.C_BG_SURFACE.g, S.C_BG_SURFACE.b, 0.5)
	s.border_color = Color(S.C_GOLD.r, S.C_GOLD.g, S.C_GOLD.b, 0.18)
	s.set_border_width_all(1)
	s.border_blend = true
	add_theme_stylebox_override("panel", s)


func _on_remove_pressed() -> void:
	remove_pressed.emit(_hero_name)


func _get_hero_slot()   -> HeroSlot: return $VBox/HeroWrapper/HeroSlot
func _get_empty_label() -> Label:    return $VBox/EmptyLabel
func _get_remove_btn()  -> Button:   return $VBox/RemoveBtn
