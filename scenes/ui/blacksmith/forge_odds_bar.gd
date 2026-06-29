# Barra de chances da forja aleatória: 4 células (Comum/Rara/Lendária/Mística), cada
# uma com ponto da cor do tier, nome + "Luz <cor>", % com 1 casa e trilha de progresso.
# A célula Mística tem o ponto cromático (cor animada por hue).
class_name ForgeOddsBar
extends HBoxContainer

var _cells: Dictionary = {}   # tier_key -> { value: Label, fill: ColorRect, track_w: float }
var _chroma_dot: ColorRect


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	for tier_key in ForgeService.TIER_ORDER:
		add_child(_build_cell(tier_key, ForgeService.TIERS[tier_key]))
	set_odds({ "comum": 100.0, "rara": 0.0, "lendaria": 0.0, "mistica": 0.0 })


func _build_cell(tier_key: String, tier: Dictionary) -> Control:
	var chromatic: bool = tier.chromatic
	var color: Color = tier.color

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", ForgeTheme.panel_style(
		Color(ForgeTheme.BG_SURFACE.r, ForgeTheme.BG_SURFACE.g, ForgeTheme.BG_SURFACE.b, 0.85),
		ForgeTheme.GOLD_SOFT_A, 1, 0))

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 7)
	vb.add_child(head)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(10, 10)
	dot.color = color
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(dot)
	if chromatic:
		_chroma_dot = dot
	var name_box := VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 0)
	head.add_child(name_box)
	name_box.add_child(ForgeTheme.make_label(str(tier.name), ForgeTheme.font_display(), 15, ForgeTheme.PARCHMENT))
	name_box.add_child(ForgeTheme.make_label("Luz %s" % str(tier.light), ForgeTheme.font_body(), 9, ForgeTheme.PARCHMENT_D))

	var value := ForgeTheme.make_label("0.0%", ForgeTheme.font_display(), 22,
		color if not chromatic else ForgeTheme.RAR_MYSTIC)
	vb.add_child(value)

	# Trilha de progresso.
	var track := PanelContainer.new()
	track.custom_minimum_size = Vector2(0, 6)
	track.add_theme_stylebox_override("panel", ForgeTheme.panel_style(
		Color(0, 0, 0, 0.4), Color(0, 0, 0, 0), 0, 0))
	vb.add_child(track)
	var fill_wrap := Control.new()
	fill_wrap.clip_contents = true
	track.add_child(fill_wrap)
	var fill := ColorRect.new()
	fill.color = color
	# Largura por RATIO de âncora (independe do layout já estar resolvido).
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.anchor_right = 0.0
	fill.anchor_bottom = 1.0
	fill.offset_left = 0.0
	fill.offset_top = 0.0
	fill.offset_right = 0.0
	fill.offset_bottom = 0.0
	fill_wrap.add_child(fill)

	_cells[tier_key] = { "value": value, "fill": fill }
	return panel


func set_odds(odds: Dictionary) -> void:
	for tier_key in _cells:
		var cell: Dictionary = _cells[tier_key]
		var pct := float(odds.get(tier_key, 0.0))
		(cell.value as Label).text = "%.1f%%" % pct
		var fill := cell.fill as ColorRect
		create_tween().tween_property(fill, "anchor_right", clampf(pct / 100.0, 0.0, 1.0), 0.25) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(_delta: float) -> void:
	# Anima o ponto cromático da célula Mística (hue rotativo).
	if _chroma_dot != null and is_instance_valid(_chroma_dot):
		var h := fmod(Time.get_ticks_msec() / 1400.0, 1.0)
		_chroma_dot.color = Color.from_hsv(h, 0.7, 0.95)
