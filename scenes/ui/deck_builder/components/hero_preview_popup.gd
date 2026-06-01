extends CanvasLayer

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")


func _ready() -> void:
	_get_panel().add_theme_stylebox_override("panel", S.panel_surface())
	_get_close_btn().pressed.connect(hide_popup)
	S.apply_button_crimson(_get_close_btn())
	_get_dim_bg().gui_input.connect(_on_dim_bg_input)


func show_hero(hero: Hero) -> void:
	var slot := _get_hero_slot()
	slot.set_hp_visible(false)
	slot.bind(hero)
	_schedule_slot_scale()

	_get_name_label().text         = hero.hero_name
	_get_class_label().text        = _class_display(hero.hero_class)
	_get_stats_label().text        = "⚔ %d   🛡 %d   ♥ %d" % [hero.base_attack, hero.base_defense, hero.max_hp]
	_get_symbols_label().text      = " ".join(hero.symbols_required) if hero.symbols_required.size() > 0 else ""
	_get_skill_name_label().text   = hero.skill_name
	_get_skill_desc_label().text   = hero.skill_desc
	_get_passive_name_label().text = "[u]%s[/u]" % hero.passive_name
	_get_passive_desc_label().text = hero.passive_desc
	visible = true


func _schedule_slot_scale() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var slot := _get_hero_slot()
	if not is_instance_valid(slot):
		return
	var factor: float = clamp(slot.size.y / 240.0, 0.5, 3.0)
	slot.apply_scale(factor)


func hide_popup() -> void:
	visible = false


func _on_dim_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_popup()


func _class_display(hero_class: Hero.HeroClass) -> String:
	match hero_class:
		Hero.HeroClass.BARBARIAN: return "Bárbaro"
		Hero.HeroClass.WARRIOR:   return "Guerreiro"
		Hero.HeroClass.MONK:      return "Monge"
		Hero.HeroClass.ROGUE:     return "Ladino"
		Hero.HeroClass.CLERIC:    return "Clérigo"
		Hero.HeroClass.RANGER:    return "Patrulheiro"
		Hero.HeroClass.GUARDIAN:  return "Guardião"
	return ""


func _get_dim_bg()             -> ColorRect:      return $DimBG
func _get_panel()              -> PanelContainer: return $DimBG/Panel
func _get_hero_slot()          -> HeroSlot:       return $DimBG/Panel/HBox/HeroWrapper/HeroSlot
func _get_close_btn()          -> Button:         return $DimBG/Panel/HBox/InfoPad/InfoCol/CloseBtnRow/CloseBtn
func _get_name_label()         -> Label:          return $DimBG/Panel/HBox/InfoPad/InfoCol/NameLabel
func _get_class_label()        -> Label:          return $DimBG/Panel/HBox/InfoPad/InfoCol/ClassLabel
func _get_stats_label()        -> Label:          return $DimBG/Panel/HBox/InfoPad/InfoCol/StatsLabel
func _get_symbols_label()      -> Label:          return $DimBG/Panel/HBox/InfoPad/InfoCol/SymbolsLabel
func _get_skill_name_label()   -> Label:          return $DimBG/Panel/HBox/InfoPad/InfoCol/SkillNameLabel
func _get_skill_desc_label()   -> Label:          return $DimBG/Panel/HBox/InfoPad/InfoCol/SkillDescLabel
func _get_passive_name_label() -> RichTextLabel:  return $DimBG/Panel/HBox/InfoPad/InfoCol/PassiveNameLabel
func _get_passive_desc_label() -> Label:          return $DimBG/Panel/HBox/InfoPad/InfoCol/PassiveDescLabel
