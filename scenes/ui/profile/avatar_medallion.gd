# scenes/ui/profile/avatar_medallion.gd
# Avatar redondo: anel metálico (cor customizável), miolo cinza quando sem foto,
# foto recortada em círculo (circle_mask.gdshader) e badge de nível embaixo.
class_name ProfileAvatarMedallion
extends Control

const CIRCLE_MASK := preload("res://scenes/ui/profile/circle_mask.gdshader")
const OUTLINE     := Color("14161c")
const FILLER      := Color("2c313c")
const GOLD        := Color("e0b04a")
const GOLD_BRIGHT := Color("f5cf6a")

const RING_W := 5.0

var _ring_color: Color = GOLD
var _glow: bool = false
var _photo: TextureRect
var _badge: PanelContainer
var _badge_lbl: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(104, 104)

	_photo = TextureRect.new()
	_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_photo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo.visible = false
	var mat := ShaderMaterial.new()
	mat.shader = CIRCLE_MASK
	_photo.material = mat
	add_child(_photo)

	# Badge de nível (fundo dourado).
	_badge = PanelContainer.new()
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = GOLD
	sb.set_content_margin_all(2.0)
	sb.content_margin_left = 7.0
	sb.content_margin_right = 7.0
	sb.set_border_width_all(2)
	sb.border_color = OUTLINE
	_badge.add_theme_stylebox_override("panel", sb)
	_badge_lbl = Label.new()
	_badge_lbl.add_theme_color_override("font_color", Color("1a1205"))
	_badge_lbl.add_theme_font_size_override("font_size", 9)
	_badge_lbl.text = "LV 1"
	_badge.add_child(_badge_lbl)
	add_child(_badge)

	resized.connect(_layout)
	_layout.call_deferred()

func set_ring_color(p_color: Color) -> void:
	_ring_color = p_color
	queue_redraw()

func set_glow(p_on: bool) -> void:
	_glow = p_on
	queue_redraw()

func set_level(p_level: int) -> void:
	if _badge_lbl:
		_badge_lbl.text = "LV %d" % p_level
	_layout.call_deferred()

func set_photo(p_tex: Texture2D) -> void:
	if _photo == null:
		return
	_photo.texture = p_tex
	_photo.visible = p_tex != null
	_layout()

func _layout() -> void:
	if _photo == null:
		return
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	var inner := r - 2.0 - RING_W
	var d := inner * 2.0
	_photo.size = Vector2(d, d)
	_photo.position = c - Vector2(inner, inner)
	if _badge:
		_badge.reset_size()
		_badge.position = Vector2((size.x - _badge.size.x) * 0.5, size.y - _badge.size.y * 0.5)
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	if _glow:
		draw_circle(c, r + 4.0, Color(_ring_color.r, _ring_color.g, _ring_color.b, 0.22))
	draw_circle(c, r, OUTLINE)                                          # contorno externo
	draw_circle(c, r - 2.0, _ring_color)                               # banda do anel
	# Toque metálico: brilho no topo-esquerda, sombra na base-direita.
	var mid := r - 2.0 - RING_W * 0.5
	draw_arc(c, mid, deg_to_rad(195), deg_to_rad(345), 24, _ring_color.lerp(Color.WHITE, 0.6), RING_W)
	draw_arc(c, mid, deg_to_rad(15), deg_to_rad(165), 24, _ring_color.lerp(Color.BLACK, 0.4), RING_W)
	draw_circle(c, r - 2.0 - RING_W, FILLER)                           # miolo cinza
