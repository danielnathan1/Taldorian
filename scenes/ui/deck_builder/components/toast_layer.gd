extends CanvasLayer

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")


func _ready() -> void:
	layer = 10


func show_toast(message: String, duration: float = 2.8) -> void:
	var lbl := Label.new()
	lbl.text = message
	lbl.add_theme_color_override("font_color", S.C_PARCHMENT)
	lbl.add_theme_font_override("font", S.FONT_REG)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var panel := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color    = Color(S.C_BG_SURFACE.r, S.C_BG_SURFACE.g, S.C_BG_SURFACE.b, 0.96)
	s.border_color = Color(S.C_GOLD.r, S.C_GOLD.g, S.C_GOLD.b, 0.55)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(10.0)
	panel.add_theme_stylebox_override("panel", s)
	panel.add_child(lbl)

	panel.modulate.a = 0.0
	$Container.add_child(panel)

	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.18)
	tw.tween_interval(duration)
	tw.tween_property(panel, "modulate:a", 0.0, 0.25)
	tw.tween_callback(panel.queue_free)
