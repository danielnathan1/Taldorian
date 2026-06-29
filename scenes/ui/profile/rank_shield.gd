# scenes/ui/profile/rank_shield.gd
# Escudo heráldico de rank (desenhado via _draw). Cor vem do tier.
# Presentation-only: não conhece regra de jogo, só desenha o que set_rank manda.
class_name ProfileRankShield
extends Control

# Tabela de cores por tier — fonte única (PeakSeal referencia daqui).
# 7 tiers do ladder rankeado (Madeira → Lenda), espelhando RankedTier no backend.
# c = cor base, d = cor escura (estrela), g = cor de glow.
const TIERS: Dictionary = {
	"Madeira":    { "c": Color("8a6d4b"), "d": Color("4f3a23"), "g": Color(0.541, 0.427, 0.294, 0.50) },
	"Bronze":     { "c": Color("c89058"), "d": Color("6f4a26"), "g": Color(0.784, 0.565, 0.345, 0.55) },
	"Prata":      { "c": Color("cdd2dd"), "d": Color("828998"), "g": Color(0.804, 0.824, 0.867, 0.55) },
	"Ouro":       { "c": Color("f1c659"), "d": Color("a87d1e"), "g": Color(0.945, 0.776, 0.349, 0.60) },
	"Diamante":   { "c": Color("a4d2ff"), "d": Color("4f8ad0"), "g": Color(0.643, 0.824, 1.000, 0.60) },
	"Prismático": { "c": Color("c9a3ff"), "d": Color("7d4fd0"), "g": Color(0.788, 0.639, 1.000, 0.62) },
	"Lenda":      { "c": Color("f7e7a6"), "d": Color("c9a23e"), "g": Color(0.969, 0.906, 0.651, 0.65) },
}

const OUTLINE := Color("14161c")

var _tier: String = "Madeira"
var _div: String = ""
var _div_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_div_label = Label.new()
	_div_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_div_label.add_theme_color_override("font_color", Color("faf6ea"))
	_div_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_div_label.add_theme_constant_override("outline_size", 3)
	_div_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_div_label)
	resized.connect(_layout)
	_layout()

# size: largura do escudo (altura = size * 1.12).
func set_rank(p_tier: String, p_div: String, p_size: float = 78.0) -> void:
	_tier = p_tier
	_div = p_div
	custom_minimum_size = Vector2(p_size, p_size * 1.12)
	if _div_label:
		_div_label.text = p_div
		_div_label.add_theme_font_size_override("font_size", int(maxf(8.0, p_size * 0.16)))
	queue_redraw()
	_layout()

func _layout() -> void:
	if _div_label == null:
		return
	_div_label.add_theme_font_size_override("font_size", int(maxf(8.0, size.x * 0.16)))
	_div_label.reset_size()
	_div_label.position = Vector2((size.x - _div_label.size.x) * 0.5, size.y - _div_label.size.y - 1.0)
	queue_redraw()

func _shield_points() -> PackedVector2Array:
	var w := size.x
	var h := size.y
	return PackedVector2Array([
		Vector2(0.5 * w, 0.0),
		Vector2(1.0 * w, 0.13 * h),
		Vector2(1.0 * w, 0.56 * h),
		Vector2(0.5 * w, 1.0 * h),
		Vector2(0.0,     0.56 * h),
		Vector2(0.0,     0.13 * h),
	])

func _draw() -> void:
	var t: Dictionary = TIERS.get(_tier, TIERS["Bronze"])
	var base: Color = t["c"]
	var dark: Color = t["d"]
	var light: Color = base.lerp(Color.WHITE, 0.45)

	var pts := _shield_points()
	# Gradiente vertical aproximado via cores por vértice (claro topo → base → escuro base).
	var cols := PackedColorArray([
		light, light, base, dark, base, light,
	])
	draw_polygon(pts, cols)

	# Brilho superior (faixa clara translúcida no topo do escudo).
	var sh := PackedVector2Array([
		pts[0], pts[1], Vector2(pts[1].x, size.y * 0.42),
		Vector2(pts[0].x, size.y * 0.42), Vector2(pts[5].x, size.y * 0.42), pts[5],
	])
	draw_colored_polygon(sh, Color(1, 1, 1, 0.16))

	# Estrela central.
	var star := _star_points(Vector2(size.x * 0.5, size.y * 0.45), size.x * 0.24, size.x * 0.10)
	draw_colored_polygon(star, dark.lerp(Color.BLACK, 0.20))

	# Contorno do escudo.
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, OUTLINE, 2.0, true)

func _star_points(center: Vector2, outer_r: float, inner_r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 10:
		var r := outer_r if i % 2 == 0 else inner_r
		var ang := -PI / 2.0 + float(i) * PI / 5.0
		out.append(center + Vector2(cos(ang), sin(ang)) * r)
	return out
