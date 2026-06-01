# Constantes de cor e factories de StyleBox para o DeckBuilder.
# Uso: const S := preload("res://scenes/ui/deck_builder/db_styles.gd")
#      panel.add_theme_stylebox_override("panel", S.panel_mid())

const C_GOLD        := Color(0.784, 0.616, 0.290)       # #c89d4a
const C_GOLD_DIM    := Color(0.604, 0.455, 0.204)       # #9a7434
const C_GOLD_GLOW   := Color(0.902, 0.706, 0.333)       # #e6b455
const C_CRIMSON     := Color(0.541, 0.165, 0.165)       # #8a2a2a
const C_CRIMSON_BR  := Color(0.659, 0.239, 0.239)       # #a83d3d
const C_GREEN       := Color(0.227, 0.627, 0.333)       # #3aa055
const C_GREEN_DIM   := Color(0.176, 0.482, 0.259)       # #2d7b42
const C_PARCHMENT   := Color(0.910, 0.863, 0.796)       # #e8dccb
const C_PARCHMENT_D := Color(0.714, 0.655, 0.561)       # #b6a78f
const C_BG_DEEP     := Color(0.039, 0.039, 0.094)       # #0a0a18
const C_BG_MID      := Color(0.071, 0.071, 0.122)       # #12121f
const C_BG_SURFACE  := Color(0.090, 0.090, 0.141)       # #171724
const C_BG_SURFACE2 := Color(0.118, 0.118, 0.169)       # #1e1e2b

const FONT_BOLD  := preload("res://assets/fonts/palatino/fonnts.com-Palatino-LT-Bold.ttf")
const FONT_BLACK := preload("res://assets/fonts/palatino/fonnts.com-Palatino-LT-Bold.ttf")
const FONT_REG   := preload("res://assets/fonts/palatino/palr45w.ttf")


static func border_gold(alpha: float = 0.18) -> Color:
	return Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, alpha)


static func panel_deep() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = C_BG_DEEP
	s.border_color = border_gold(0.18)
	s.set_border_width_all(1)
	s.set_corner_radius_all(0)
	return s


static func panel_mid() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = C_BG_MID
	s.border_color = border_gold(0.22)
	s.set_border_width_all(1)
	s.set_corner_radius_all(0)
	return s


static func panel_surface() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = C_BG_SURFACE
	s.border_color = border_gold(0.30)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	return s


static func panel_surface2() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = C_BG_SURFACE2
	s.border_color = border_gold(0.35)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	return s


static func chip_normal() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(C_BG_SURFACE2.r, C_BG_SURFACE2.g, C_BG_SURFACE2.b, 1.0)
	s.border_color = border_gold(0.25)
	s.set_border_width_all(1)
	s.set_corner_radius_all(20)
	s.set_content_margin(SIDE_LEFT, 12.0)
	s.set_content_margin(SIDE_RIGHT, 12.0)
	s.set_content_margin(SIDE_TOP, 5.0)
	s.set_content_margin(SIDE_BOTTOM, 5.0)
	return s


static func chip_active() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.20)
	s.border_color = border_gold(0.65)
	s.set_border_width_all(1)
	s.set_corner_radius_all(20)
	s.set_content_margin(SIDE_LEFT, 12.0)
	s.set_content_margin(SIDE_RIGHT, 12.0)
	s.set_content_margin(SIDE_TOP, 5.0)
	s.set_content_margin(SIDE_BOTTOM, 5.0)
	return s


static func button_gold_normal() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.35)
	s.border_color = border_gold(0.65)
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.set_content_margin_all(8.0)
	return s


static func button_gold_hover() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.28)
	s.border_color = border_gold(0.70)
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.set_content_margin_all(8.0)
	return s


static func button_gold_pressed() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.40)
	s.border_color = border_gold(0.90)
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.set_content_margin_all(8.0)
	return s


static func button_crimson_normal() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(C_CRIMSON.r, C_CRIMSON.g, C_CRIMSON.b, 0.30)
	s.border_color = Color(C_CRIMSON_BR.r, C_CRIMSON_BR.g, C_CRIMSON_BR.b, 0.60)
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.set_content_margin_all(8.0)
	return s


static func button_crimson_hover() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(C_CRIMSON.r, C_CRIMSON.g, C_CRIMSON.b, 0.55)
	s.border_color = Color(C_CRIMSON_BR.r, C_CRIMSON_BR.g, C_CRIMSON_BR.b, 0.90)
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.set_content_margin_all(8.0)
	return s


static func row_normal() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(C_BG_SURFACE.r, C_BG_SURFACE.g, C_BG_SURFACE.b, 0.0)
	s.set_border_width_all(0)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(6.0)
	return s


static func row_hover() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.08)
	s.border_color = border_gold(0.20)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(6.0)
	return s


static func apply_button_gold(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal",   button_gold_normal())
	btn.add_theme_stylebox_override("hover",    button_gold_hover())
	btn.add_theme_stylebox_override("pressed",  button_gold_pressed())
	btn.add_theme_stylebox_override("focus",    button_gold_hover())
	btn.add_theme_stylebox_override("disabled", button_gold_normal())
	btn.add_theme_color_override("font_color",          C_PARCHMENT)
	btn.add_theme_color_override("font_hover_color",    C_GOLD_GLOW)
	btn.add_theme_color_override("font_pressed_color",  C_GOLD_GLOW)
	btn.add_theme_color_override("font_disabled_color", C_PARCHMENT_D)
	btn.add_theme_font_override("font", FONT_REG)
	btn.add_theme_font_size_override("font_size", 12)


static func apply_button_crimson(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal",  button_crimson_normal())
	btn.add_theme_stylebox_override("hover",   button_crimson_hover())
	btn.add_theme_stylebox_override("pressed", button_crimson_hover())
	btn.add_theme_stylebox_override("focus",   button_crimson_hover())
	btn.add_theme_color_override("font_color",       C_PARCHMENT)
	btn.add_theme_color_override("font_hover_color", Color(1, 0.8, 0.8))
	btn.add_theme_font_override("font", FONT_REG)
	btn.add_theme_font_size_override("font_size", 12)


static func apply_chip(btn: Button, active: bool) -> void:
	var style := chip_active() if active else chip_normal()
	btn.add_theme_stylebox_override("normal",  style)
	btn.add_theme_stylebox_override("hover",   chip_active())
	btn.add_theme_stylebox_override("pressed", chip_active())
	btn.add_theme_stylebox_override("focus",   style)
	var col := C_GOLD_GLOW if active else C_PARCHMENT_D
	btn.add_theme_color_override("font_color",       col)
	btn.add_theme_color_override("font_hover_color", C_GOLD_GLOW)
	btn.add_theme_font_override("font", FONT_REG)
	btn.add_theme_font_size_override("font_size", 11)
