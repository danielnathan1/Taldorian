# scenes/ui/profile/peak_seal.gd
# Selo circular do maior rank (peak). Reaproveita as cores de ProfileRankShield.TIERS.
class_name ProfilePeakSeal
extends Control

const OUTLINE := Color("14161c")

var _tier: String = "Madeira"
var _div: String = ""
var _div_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_div_label = Label.new()
	_div_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_div_label.add_theme_color_override("font_color", Color("1c1304"))
	_div_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_div_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_div_label)
	resized.connect(_layout)
	_layout()

func set_rank(p_tier: String, p_div: String, p_size: float = 42.0) -> void:
	_tier = p_tier
	_div = p_div
	custom_minimum_size = Vector2(p_size, p_size)
	if _div_label:
		_div_label.text = p_div
	queue_redraw()
	_layout()

func _layout() -> void:
	if _div_label == null:
		return
	_div_label.add_theme_font_size_override("font_size", int(maxf(8.0, size.x * 0.28)))
	_div_label.reset_size()
	_div_label.position = (size - _div_label.size) * 0.5
	queue_redraw()

func _draw() -> void:
	var t: Dictionary = ProfileRankShield.TIERS.get(_tier, ProfileRankShield.TIERS["Bronze"])
	var base: Color = t["c"]
	var dark: Color = t["d"]
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5

	draw_circle(c, r, OUTLINE)                                   # contorno externo
	draw_circle(c, r - 1.0, dark.lerp(Color.BLACK, 0.20))       # anel escuro
	draw_circle(c, r - 3.0, base)                                # disco base
	# Brilho radial (deslocado para cima-esquerda).
	draw_circle(c - Vector2(r * 0.18, r * 0.22), r * 0.55, base.lerp(Color.WHITE, 0.55))

	# Estrela.
	var star := _star_points(c, r * 0.62, r * 0.26)
	draw_colored_polygon(star, dark.lerp(Color.BLACK, 0.25) * Color(1, 1, 1, 0.85))

func _star_points(center: Vector2, outer_r: float, inner_r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 10:
		var rr := outer_r if i % 2 == 0 else inner_r
		var ang := -PI / 2.0 + float(i) * PI / 5.0
		out.append(center + Vector2(cos(ang), sin(ang)) * rr)
	return out
