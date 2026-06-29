# scenes/ui/profile/win_bar.gd
# Barra de vitórias/derrotas com winrate. Constrói os nós em código.
class_name ProfileWinBar
extends VBoxContainer

const GUILD  := Color("8fd99a")
const DANGER := Color("e0795f")
const INK    := Color("e7e3da")

var _meta: HBoxContainer
var _w_lbl: Label
var _rate_lbl: Label
var _l_lbl: Label
var _track: Control
var _fill: ColorRect
var _show_meta: bool = true

func _ready() -> void:
	add_theme_constant_override("separation", 4)

	_meta = HBoxContainer.new()
	_meta.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_meta)

	_w_lbl = _mk_label(GUILD, 10)
	_w_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_w_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_meta.add_child(_w_lbl)

	_rate_lbl = _mk_label(INK, 11)
	_rate_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meta.add_child(_rate_lbl)

	_l_lbl = _mk_label(DANGER, 10)
	_l_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_l_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_meta.add_child(_l_lbl)

	_track = ColorRect.new()
	_track.color = Color("11131a")
	_track.custom_minimum_size = Vector2(0, 8)
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_track)

	_fill = ColorRect.new()
	_fill.color = GUILD
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_track.add_child(_fill)
	_track.resized.connect(_update_fill)

var _w: int = 0
var _l: int = 0

func set_record(p_w: int, p_l: int) -> void:
	_w = p_w
	_l = p_l
	var wr := _winrate()
	_w_lbl.text = "%d V" % _w
	_l_lbl.text = "%d D" % _l
	_rate_lbl.text = "%d%%" % wr
	_update_fill()

func show_meta(p_show: bool) -> void:
	_show_meta = p_show
	if _meta:
		_meta.visible = p_show

func _winrate() -> int:
	var total := _w + _l
	if total <= 0:
		return 0
	return int(round(float(_w) / float(total) * 100.0))

func _update_fill() -> void:
	if _fill == null or _track == null:
		return
	var ratio := float(_winrate()) / 100.0
	_fill.size = Vector2(_track.size.x * ratio, _track.size.y)
	_fill.position = Vector2.ZERO

func _mk_label(p_color: Color, p_size: int) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", p_color)
	l.add_theme_font_size_override("font_size", p_size)
	return l
