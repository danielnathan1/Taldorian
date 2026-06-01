extends PanelContainer

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")

signal add_pressed(hero: Hero)
signal preview_requested(hero: Hero)

var _hero: Hero = null


func _ready() -> void:
	add_theme_stylebox_override("panel", S.panel_surface())
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_get_add_btn().pressed.connect(_on_add_pressed)
	_get_hero_slot().slot_clicked.connect(_on_slot_clicked)


func _on_slot_clicked(hero: Hero) -> void:
	if hero != null:
		preview_requested.emit(hero)


func bind(p_hero: Hero, in_deck: bool, at_limit: bool) -> void:
	_hero = p_hero
	var slot := _get_hero_slot()
	slot.set_hp_visible(false)
	slot.bind(p_hero)
	_schedule_hero_scale()

	var add_btn := _get_add_btn()
	if in_deck:
		add_btn.text     = "✓ No deck"
		add_btn.disabled = true
		S.apply_button_gold(add_btn)
		add_btn.modulate = Color(0.6, 0.9, 0.6)
	elif at_limit:
		add_btn.text     = "Deck cheio"
		add_btn.disabled = true
		S.apply_button_gold(add_btn)
		add_btn.modulate = Color(0.5, 0.5, 0.5)
	else:
		add_btn.text     = "+ Adicionar"
		add_btn.disabled = false
		add_btn.modulate = Color.WHITE
		S.apply_button_gold(add_btn)


func _schedule_hero_scale() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_apply_hero_scale()


func _apply_hero_scale() -> void:
	var slot := _get_hero_slot()
	if not is_instance_valid(slot):
		return
	var factor: float = clamp(slot.size.y / 240.0, 0.5, 3.0)
	slot.apply_scale(factor)


func _on_add_pressed() -> void:
	if _hero != null:
		add_pressed.emit(_hero)


func _on_mouse_entered() -> void:
	add_theme_stylebox_override("panel", S.panel_surface2())


func _on_mouse_exited() -> void:
	add_theme_stylebox_override("panel", S.panel_surface())


func _get_hero_slot() -> HeroSlot: return $MarginContainer/VBox/HeroWrapper/HeroSlot
func _get_add_btn()   -> Button:   return $MarginContainer/VBox/AddBtn
