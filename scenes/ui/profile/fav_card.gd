# scenes/ui/profile/fav_card.gd
# Miniatura da carta preferida (arte real + contorno dourado + rodapé atk/elemento).
# Inclinação aplicada via rotation. Emite `pressed` ao clicar (host abre a carta).
class_name ProfileFavCard
extends Control

signal pressed

const ASPECT := 1328.0 / 912.0
const GOLD   := Color("e0b04a")
const DANGER := Color("e0795f")
const GOLD_BRIGHT := Color("f5cf6a")
const FRAME_DARK  := Color("0c0d11")

var _w: float = 104.0
var _art_h: float = 0.0
var _frame: Control
var _art: TextureRect
var _atk_lbl: Label
var _el_lbl: Label
var _has_art: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	_frame = Control.new()
	_frame.clip_contents = true
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.add_child(_art)

	var foot := HBoxContainer.new()
	foot.name = "Foot"
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(foot)
	_atk_lbl = Label.new()
	_atk_lbl.add_theme_color_override("font_color", DANGER)
	_atk_lbl.add_theme_font_size_override("font_size", 11)
	_atk_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_atk_lbl)
	_el_lbl = Label.new()
	_el_lbl.add_theme_color_override("font_color", GOLD_BRIGHT)
	_el_lbl.add_theme_font_size_override("font_size", 8)
	_el_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.add_child(_el_lbl)
	foot.set_meta("ref", true)

	resized.connect(_layout)

# data: { name, element(String), atk(int), art(Texture2D|null) }
func set_card(p_data: Dictionary, p_width: float = 104.0, p_tilt: float = -5.0) -> void:
	_w = p_width
	_art_h = p_width * ASPECT
	custom_minimum_size = Vector2(_w, _art_h + 22.0)
	pivot_offset = custom_minimum_size * 0.5
	rotation_degrees = p_tilt

	var tex: Variant = p_data.get("art", null)
	_has_art = tex != null
	_art.texture = tex if _has_art else null
	_art.visible = _has_art
	_atk_lbl.text = "+%d" % int(p_data.get("atk", 0))
	_el_lbl.text = str(p_data.get("element", "")).to_upper()
	_layout()
	queue_redraw()

func _layout() -> void:
	if _frame == null:
		return
	_frame.position = Vector2.ZERO
	_frame.size = Vector2(_w, _art_h)
	var foot := get_node_or_null("Foot") as Control
	if foot:
		foot.position = Vector2(2, _art_h + 4)
		foot.size = Vector2(_w - 4, 16)
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(0, 0, _w, _art_h)
	if not _has_art:
		# Miolo neutro quando sem arte.
		draw_rect(rect, Color("181b22"), true)
	# Gloss diagonal no canto superior-esquerdo.
	if _has_art:
		var gloss := PackedVector2Array([
			Vector2(0, 0), Vector2(_w * 0.7, 0), Vector2(0, _art_h * 0.55),
		])
		draw_colored_polygon(gloss, Color(1, 1, 1, 0.10))
	# Contorno: dark interno + dourado externo.
	draw_rect(rect, FRAME_DARK, false, 2.0)
	draw_rect(rect.grow(2.0), GOLD, false, 2.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
