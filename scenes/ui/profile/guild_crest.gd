# scenes/ui/profile/guild_crest.gd
# Brasão da guild (escudo + estrela), monocromático e tingível.
class_name ProfileGuildCrest
extends Control

var _color: Color = Color("8fd99a")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func setup(p_color: Color, p_size: float = 15.0) -> void:
	_color = p_color
	custom_minimum_size = Vector2(p_size, p_size)
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	# Contorno do escudo (heráldico simples).
	var shield := PackedVector2Array([
		Vector2(0.50 * w, 0.05 * h),
		Vector2(0.92 * w, 0.20 * h),
		Vector2(0.92 * w, 0.55 * h),
		Vector2(0.50 * w, 0.95 * h),
		Vector2(0.08 * w, 0.55 * h),
		Vector2(0.08 * w, 0.20 * h),
	])
	draw_colored_polygon(shield, Color(0, 0, 0, 0.35))
	var outline := shield.duplicate()
	outline.append(shield[0])
	draw_polyline(outline, _color, maxf(1.0, w * 0.08), true)
	# Estrela central.
	var star := _star_points(Vector2(0.5 * w, 0.48 * h), w * 0.28, w * 0.12)
	draw_colored_polygon(star, Color(_color.r, _color.g, _color.b, 0.92))

func _star_points(center: Vector2, outer_r: float, inner_r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 10:
		var r := outer_r if i % 2 == 0 else inner_r
		var ang := -PI / 2.0 + float(i) * PI / 5.0
		out.append(center + Vector2(cos(ang), sin(ang)) * r)
	return out
