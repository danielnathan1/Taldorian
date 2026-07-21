extends CanvasLayer

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")


func _ready() -> void:
	_get_panel().add_theme_stylebox_override("panel", S.panel_surface())
	_get_close_btn().pressed.connect(hide_popup)
	S.apply_button_crimson(_get_close_btn())
	_get_dim_bg().gui_input.connect(_on_dim_bg_input)


func show_card(card_dict: Dictionary) -> void:
	var card_view := _get_card_view()
	card_view.bind_dict(card_dict)
	card_view.apply_scale(1.75)

	_get_name_label().text   = card_dict.get("name", "")
	_get_timing_label().text = _timing_display(card_dict.get("timing", "ACTION"))

	var syms: Variant = card_dict.get("symbols", [])
	_get_symbols_label().text = " ".join(syms) if syms is Array and (syms as Array).size() > 0 else "—"

	var atk:   int = int(card_dict.get("attack_value",  0))
	var def_v: int = int(card_dict.get("defense_value", 0))
	var stats := ""
	if atk   != 0: stats += "⚔ %+d   " % atk
	if def_v != 0: stats += "🛡 %+d"   % def_v
	_get_stats_label().text = stats.strip_edges() if stats != "" else "—"

	_get_rarity_label().text = _rarity_display(card_dict.get("rarity", "COMMON"))
	_get_copies_label().text = "Limite: %d cópia(s) por deck" % int(card_dict.get("copies", 3))

	var stealth: bool = card_dict.get("stealth", false)
	_get_stealth_label().visible = stealth

	var icon_px := maxi(1, _get_desc_label().get_theme_font_size("normal_font_size"))
	_get_desc_label().text = TextMarkup.to_bbcode(card_dict.get("description", ""), icon_px)

	visible = true


func hide_popup() -> void:
	visible = false


func _on_dim_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_popup()


func _timing_display(timing: String) -> String:
	match timing:
		"ACTION":       return "⚡ Ação"
		"BONUS_ACTION": return "✦ Ação Bônus"
		"REACTION":     return "🛡 Reação"
	return timing


func _rarity_display(rarity: String) -> String:
	match rarity:
		"COMMON":    return "⬜ Comum"
		"RARE":      return "🔵 Rara"
		"LEGENDARY": return "🟡 Lendária"
		"MYSTIC":    return "🟣 Mística"
	return rarity


func _get_dim_bg()        -> ColorRect:      return $DimBG
func _get_panel()         -> PanelContainer: return $DimBG/Panel
func _get_card_view()     -> Control:        return $DimBG/Panel/HBox/CardWrapper/CardView
func _get_close_btn()     -> Button:         return $DimBG/Panel/HBox/InfoPad/InfoCol/CloseBtnRow/CloseBtn
func _get_name_label()    -> Label:          return $DimBG/Panel/HBox/InfoPad/InfoCol/NameLabel
func _get_timing_label()  -> Label:          return $DimBG/Panel/HBox/InfoPad/InfoCol/TimingLabel
func _get_symbols_label() -> Label:          return $DimBG/Panel/HBox/InfoPad/InfoCol/SymbolsLabel
func _get_stats_label()   -> Label:          return $DimBG/Panel/HBox/InfoPad/InfoCol/StatsLabel
func _get_rarity_label()  -> Label:          return $DimBG/Panel/HBox/InfoPad/InfoCol/RarityLabel
func _get_copies_label()  -> Label:          return $DimBG/Panel/HBox/InfoPad/InfoCol/CopiesLabel
func _get_stealth_label() -> Label:          return $DimBG/Panel/HBox/InfoPad/InfoCol/StealthLabel
func _get_desc_label()    -> RichTextLabel:  return $DimBG/Panel/HBox/InfoPad/InfoCol/DescLabel
