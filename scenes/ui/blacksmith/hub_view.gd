# Tela-hub do Ferreiro: intro central + 3 cards de opção (2 ativos, 1 locked).
# Emite `option_picked(mode)` para o shell trocar de view. Toda a UI é construída
# em código (mesma linha da BoosterShop), usando ForgeTheme.
class_name HubView
extends Control

signal option_picked(mode: String)

# Descritores dos 3 modos: index, eyebrow, título, descrição, acento, modo, locked.
const OPTIONS := [
	{
		"index": "01", "eyebrow": "Sorte do Metal", "title": "Forjar Carta Aleatória",
		"desc": "Encaixe cartas na pedra-runa e deixe o cataclismo decidir o que emerge das chamas.",
		"accent": ForgeTheme.CRIMSON_GLOW, "mode": "random", "locked": false, "glyph": "🜂",
	},
	{
		"index": "02", "eyebrow": "Ritual Dirigido", "title": "Forjar Carta",
		"desc": "Escolha a carta almejada e ofereça dez ao círculo. O ritual materializa o seu alvo.",
		"accent": ForgeTheme.GOLD_GLOW, "mode": "targeted", "locked": false, "glyph": "✦",
	},
	{
		"index": "03", "eyebrow": "Em Desenvolvimento", "title": "Encantar Carta",
		"desc": "Imbua cartas com encantamentos permanentes. Os segredos da têmpera ainda dormem.",
		"accent": ForgeTheme.PURPLE, "mode": "enchant", "locked": true, "glyph": "❖",
	},
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 34)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)

	col.add_child(_build_intro())

	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 22)
	options.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(options)
	for opt in OPTIONS:
		options.add_child(_build_option_card(opt))


func _build_intro() -> Control:
	var intro := VBoxContainer.new()
	intro.add_theme_constant_override("separation", 10)
	intro.alignment = BoxContainer.ALIGNMENT_CENTER

	var hammer := ForgeTheme.make_label("⚒", ForgeTheme.font_display(), 44, ForgeTheme.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER)
	hammer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	intro.add_child(hammer)

	var eyebrow := ForgeTheme.make_eyebrow("A Fornalha Eterna", ForgeTheme.GOLD_DIM, 12)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_child(eyebrow)

	var title := ForgeTheme.make_label("Forje o seu destino", ForgeTheme.font_display(), 46,
		ForgeTheme.GOLD_GLOW, HORIZONTAL_ALIGNMENT_CENTER)
	intro.add_child(title)

	var sub := ForgeTheme.make_label(
		"Transmute o que você tem no que você almeja — a um custo de ouro e sacrifício.",
		ForgeTheme.font_body(), 14, ForgeTheme.PARCHMENT_D, HORIZONTAL_ALIGNMENT_CENTER)
	intro.add_child(sub)

	intro.add_child(_build_ornament())
	return intro


func _build_ornament() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var line_l := ColorRect.new()
	line_l.color = ForgeTheme.GOLD_SOFT_A
	line_l.custom_minimum_size = Vector2(70, 1)
	line_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line_l)
	var diamond := ForgeTheme.make_label("◆", ForgeTheme.font_body(), 12, ForgeTheme.GOLD)
	row.add_child(diamond)
	var line_r := ColorRect.new()
	line_r.color = ForgeTheme.GOLD_SOFT_A
	line_r.custom_minimum_size = Vector2(70, 1)
	line_r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line_r)
	return row


func _build_option_card(opt: Dictionary) -> Control:
	var locked: bool = opt.locked
	var accent: Color = opt.accent

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 264)
	var base_style := ForgeTheme.panel_style(
		Color(ForgeTheme.BG_MID.r, ForgeTheme.BG_MID.g, ForgeTheme.BG_MID.b, 0.72),
		ForgeTheme.GOLD_SOFT_A, 1, 0)
	panel.add_theme_stylebox_override("panel", base_style)
	if locked:
		panel.modulate = Color(0.62, 0.62, 0.66, 1.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	margin.add_child(vb)

	var idx := ForgeTheme.make_label(opt.index, ForgeTheme.font_body(), 12, ForgeTheme.GOLD_DIM)
	vb.add_child(idx)

	var glyph := ForgeTheme.make_label(opt.glyph, ForgeTheme.font_display(), 40, accent)
	vb.add_child(glyph)

	var eyebrow := ForgeTheme.make_eyebrow(opt.eyebrow, accent, 10)
	vb.add_child(eyebrow)

	var title := ForgeTheme.make_label(opt.title, ForgeTheme.font_display(), 21, ForgeTheme.PARCHMENT)
	vb.add_child(title)

	var desc := ForgeTheme.make_label(opt.desc, ForgeTheme.font_body(), 12, ForgeTheme.PARCHMENT_D)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(0, 56)
	vb.add_child(desc)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	var arrow := ForgeTheme.make_label("🔒  Em breve" if locked else "→",
		ForgeTheme.font_body(), 14, accent if not locked else ForgeTheme.PARCHMENT_D,
		HORIZONTAL_ALIGNMENT_RIGHT)
	vb.add_child(arrow)

	if locked:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		return panel

	# Botão transparente para hover/clique sobre todo o card.
	var hit := Button.new()
	hit.flat = true
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus"]:
		hit.add_theme_stylebox_override(st, empty)
	panel.add_child(hit)

	var hover_style := base_style.duplicate() as StyleBoxFlat
	hover_style.border_color = accent
	hover_style.bg_color = Color(ForgeTheme.BG_MID.r, ForgeTheme.BG_MID.g, ForgeTheme.BG_MID.b, 0.9)

	hit.mouse_entered.connect(func() -> void:
		panel.add_theme_stylebox_override("panel", hover_style)
		create_tween().tween_property(panel, "position:y", -6.0, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		arrow.text = "→  forjar")
	hit.mouse_exited.connect(func() -> void:
		panel.add_theme_stylebox_override("panel", base_style)
		create_tween().tween_property(panel, "position:y", 0.0, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		arrow.text = "→")
	hit.pressed.connect(func() -> void: option_picked.emit(opt.mode))
	return panel
