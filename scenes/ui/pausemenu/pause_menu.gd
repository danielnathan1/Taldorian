class_name PauseMenu extends CanvasLayer

signal resumed
signal forfeit_requested
signal forfeit_confirmed
signal settings_changed(music_pct: int, fx_pct: int)
signal quit_to_menu_requested

enum View { MAIN, SETTINGS, CONFIRM }

## Modo mundo aberto: troca "Desistir da Partida" por "Voltar ao Menu" (sem
## confirmação de render). Definir ANTES de adicionar o nó à árvore.
var world_mode: bool = false

const SETTINGS_PATH := "user://settings.cfg"

const FONT_DECO    := preload("res://assets/fonts/CinzelDecorative-Bold.ttf")
const FONT_REGULAR := preload("res://assets/fonts/CinzelDecorative-Regular.ttf")
const FONT_ITALIC  := preload("res://assets/fonts/palatino/palr45w.ttf")

const C_GOLD      := Color(1.000, 0.839, 0.463)
const C_GOLD_MID  := Color(0.902, 0.722, 0.392)
const C_GOLD_DIM  := Color(0.627, 0.490, 0.227)
const C_RED       := Color(0.843, 0.337, 0.251)
const C_RED_DIM   := Color(0.557, 0.200, 0.145)
const C_BG_DEEP   := Color(0.055, 0.047, 0.122, 1.0)
const C_PANEL_BG  := Color(0.086, 0.086, 0.165, 0.92)

var _root:          Control
var _backdrop:      ColorRect
var _pause_card:    Control
var _main_view:     Control
var _settings_view: Control
var _confirm_modal: Control

# settings sliders
var _music_slider: HSlider
var _fx_slider:    HSlider
var _music_value_label: Label
var _fx_value_label:    Label

var _current_view: View  = View.MAIN
var _is_open:      bool  = false
var _music_pct:    int   = 70
var _fx_pct:       int   = 85

# ── Public API ────────────────────────────────────────────────────────────────

func open() -> void:
	_is_open = true
	_show_view(View.MAIN)
	visible = true
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_animate_in()

func close() -> void:
	_is_open = false
	_animate_out()
	await get_tree().create_timer(0.25).timeout
	visible = false
	get_tree().paused = false
	emit_signal("resumed")

func is_open() -> bool:
	return _is_open

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 15
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	_ensure_audio_buses()
	_build_ui()
	_load_settings()
	_sync_slider_labels()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	match _current_view:
		View.MAIN:
			if _is_open:
				close()
			else:
				open()
		View.SETTINGS:
			_show_view(View.MAIN)
		View.CONFIRM:
			_show_view(View.MAIN)

# ── UI Construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Root blocker
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# Backdrop
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.04, 0.035, 0.09, 0.88)
	_root.add_child(_backdrop)

	# Views
	_main_view     = _build_main_view()
	_settings_view = _build_settings_view()
	_confirm_modal = _build_confirm_modal()

	_root.add_child(_main_view)
	_root.add_child(_settings_view)
	_root.add_child(_confirm_modal)

# ── Main View ─────────────────────────────────────────────────────────────────

func _build_main_view() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)

	_pause_card = _build_pause_card()
	center.add_child(_pause_card)
	return center

func _build_pause_card() -> Control:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(440, 0)
	vbox.add_theme_constant_override("separation", 0)

	# Crest
	var crest := _build_crest_control(76)
	crest.custom_minimum_size = Vector2(76, 76)
	var crest_center := CenterContainer.new()
	crest_center.add_child(crest)
	crest_center.add_theme_constant_override("margin_bottom", 0)
	vbox.add_child(crest_center)

	# Panel
	var panel := PanelContainer.new()
	var panel_style := _make_panel_style(C_GOLD_MID, 0.32)
	panel.add_theme_stylebox_override("panel", panel_style)
	vbox.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   38)
	margin.add_theme_constant_override("margin_right",  42)
	margin.add_theme_constant_override("margin_top",    35)
	margin.add_theme_constant_override("margin_bottom", 42)
	panel.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 0)
	margin.add_child(inner)

	# Eyebrow
	var eyebrow := _make_label("PAUSA", FONT_REGULAR, 9, C_GOLD_DIM)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_constant_override("outline_size", 0)
	inner.add_child(eyebrow)

	var sp0 := Control.new(); sp0.custom_minimum_size = Vector2(0, 6); inner.add_child(sp0)

	# Title
	var title := _make_label("Em Repouso", FONT_DECO, 36, C_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(title)

	var sp1 := Control.new(); sp1.custom_minimum_size = Vector2(0, 10); inner.add_child(sp1)

	# Divider
	inner.add_child(_build_divider())

	var sp2 := Control.new(); sp2.custom_minimum_size = Vector2(0, 24); inner.add_child(sp2)

	# Buttons
	var btn_list := VBoxContainer.new()
	btn_list.add_theme_constant_override("separation", 11)
	inner.add_child(btn_list)

	var btn_resume   := _make_menu_button("Voltar ao Mundo" if world_mode else "Voltar ao Jogo", false)
	var btn_settings := _make_menu_button("Configurações", false)

	btn_resume.pressed.connect(close)
	btn_settings.pressed.connect(func(): _show_view(View.SETTINGS))

	btn_list.add_child(btn_resume)
	btn_list.add_child(btn_settings)

	if world_mode:
		var btn_menu := _make_menu_button("Voltar ao Menu", false)
		btn_menu.pressed.connect(_on_quit_to_menu)
		btn_list.add_child(btn_menu)
	else:
		var btn_forfeit := _make_menu_button("Desistir da Partida", true)
		btn_forfeit.pressed.connect(func():
			emit_signal("forfeit_requested")
			_show_view(View.CONFIRM)
		)
		btn_list.add_child(btn_forfeit)

	var sp3 := Control.new(); sp3.custom_minimum_size = Vector2(0, 20); inner.add_child(sp3)

	# Footer
	var footer_text := "Pressione ESC para retomar" if world_mode else "Pressione ESC para retomar a batalha"
	var footer := _make_label(footer_text, FONT_ITALIC, 13, Color(C_GOLD_DIM, 0.7))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(footer)

	# Corner ornaments
	_add_corner_ornaments(panel, C_GOLD_MID, 0.55, 18)

	return vbox

# ── Settings View ─────────────────────────────────────────────────────────────

func _build_settings_view() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.visible = false

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(440, 0)
	vbox.add_theme_constant_override("separation", 0)

	var crest := _build_crest_control(76)
	crest.custom_minimum_size = Vector2(76, 76)
	var cc := CenterContainer.new()
	cc.add_child(crest)
	vbox.add_child(cc)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(C_GOLD_MID, 0.32))
	vbox.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   38)
	margin.add_theme_constant_override("margin_right",  42)
	margin.add_theme_constant_override("margin_top",    35)
	margin.add_theme_constant_override("margin_bottom", 42)
	panel.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 0)
	margin.add_child(inner)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "← Voltar"
	back_btn.flat = true
	back_btn.add_theme_font_override("font", FONT_REGULAR)
	back_btn.add_theme_font_size_override("font_size", 11)
	back_btn.add_theme_color_override("font_color", C_GOLD_MID)
	back_btn.add_theme_color_override("font_hover_color", C_GOLD)
	back_btn.pressed.connect(func(): _show_view(View.MAIN))
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0, 0, 0, 0)
	back_btn.add_theme_stylebox_override("normal", back_style)
	back_btn.add_theme_stylebox_override("hover",  back_style)
	back_btn.add_theme_stylebox_override("pressed", back_style)
	inner.add_child(back_btn)

	var sp0 := Control.new(); sp0.custom_minimum_size = Vector2(0, 4); inner.add_child(sp0)

	var eyebrow := _make_label("CONFIGURAÇÕES", FONT_REGULAR, 9, C_GOLD_DIM)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(eyebrow)

	var sp1 := Control.new(); sp1.custom_minimum_size = Vector2(0, 6); inner.add_child(sp1)

	var title := _make_label("Áudio", FONT_DECO, 30, C_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(title)

	var sp2 := Control.new(); sp2.custom_minimum_size = Vector2(0, 10); inner.add_child(sp2)
	inner.add_child(_build_divider())
	var sp3 := Control.new(); sp3.custom_minimum_size = Vector2(0, 24); inner.add_child(sp3)

	# Music row
	var music_row := _build_volume_row("MÚSICA", true)
	inner.add_child(music_row)

	var sp4 := Control.new(); sp4.custom_minimum_size = Vector2(0, 22); inner.add_child(sp4)

	# FX row
	var fx_row := _build_volume_row("EFEITOS", false)
	inner.add_child(fx_row)

	var sp5 := Control.new(); sp5.custom_minimum_size = Vector2(0, 20); inner.add_child(sp5)

	var footer := _make_label("Use as setas ← → para ajustes finos", FONT_ITALIC, 13, Color(C_GOLD_DIM, 0.7))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(footer)

	_add_corner_ornaments(panel, C_GOLD_MID, 0.55, 18)
	center.add_child(vbox)
	return center

func _build_volume_row(label_text: String, is_music: bool) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	# Header row
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var lbl := _make_label(label_text, FONT_REGULAR, 11, C_GOLD_MID)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(lbl)

	var val_lbl := _make_label("70%", FONT_REGULAR, 12, C_GOLD)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.custom_minimum_size = Vector2(60, 0)
	header.add_child(val_lbl)

	if is_music:
		_music_value_label = val_lbl
	else:
		_fx_value_label = val_lbl

	# Slider row
	var slider_row := HBoxContainer.new()
	slider_row.add_theme_constant_override("separation", 10)
	vbox.add_child(slider_row)

	var minus_btn := _make_small_btn("−")
	slider_row.add_child(minus_btn)

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 24)

	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color(C_GOLD_DIM, 0.18)
	slider_bg.set_border_width_all(0)
	slider_bg.content_margin_left = 0
	slider_bg.content_margin_right = 0
	slider_bg.content_margin_top = 0
	slider_bg.content_margin_bottom = 0
	slider.add_theme_stylebox_override("slider", slider_bg)

	var grabber_area := StyleBoxFlat.new()
	grabber_area.bg_color = Color(C_GOLD_MID, 0.55)
	slider.add_theme_stylebox_override("grabber_area", grabber_area)
	slider.add_theme_stylebox_override("grabber_area_highlight", grabber_area)

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = C_GOLD
	grabber.set_border_width_all(0)
	grabber.set_corner_radius_all(2)
	grabber.content_margin_left   = 5
	grabber.content_margin_right  = 5
	grabber.content_margin_top    = 8
	grabber.content_margin_bottom = 8
	slider.add_theme_stylebox_override("grabber", grabber)
	slider.add_theme_stylebox_override("grabber_highlight", grabber)

	slider_row.add_child(slider)

	var plus_btn := _make_small_btn("+")
	slider_row.add_child(plus_btn)

	if is_music:
		_music_slider = slider
		slider.value = _music_pct
		slider.value_changed.connect(_on_music_changed)
		minus_btn.pressed.connect(func(): _on_music_changed(max(0, _music_pct - 5)))
		plus_btn.pressed.connect(func():  _on_music_changed(min(100, _music_pct + 5)))
	else:
		_fx_slider = slider
		slider.value = _fx_pct
		slider.value_changed.connect(_on_fx_changed)
		minus_btn.pressed.connect(func(): _on_fx_changed(max(0, _fx_pct - 5)))
		plus_btn.pressed.connect(func():  _on_fx_changed(min(100, _fx_pct + 5)))

	return vbox

func _make_small_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.flat = true
	btn.custom_minimum_size = Vector2(26, 26)
	btn.add_theme_font_override("font", FONT_DECO)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", C_GOLD_MID)
	btn.add_theme_color_override("font_hover_color", C_GOLD)
	var s := StyleBoxFlat.new(); s.bg_color = Color(0, 0, 0, 0)
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover",  s)
	btn.add_theme_stylebox_override("pressed", s)
	return btn

# ── Confirm Modal ─────────────────────────────────────────────────────────────

func _build_confirm_modal() -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.visible = false

	var modal_bg := ColorRect.new()
	modal_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_bg.color = Color(0, 0, 0, 0.55)
	modal_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_bg.gui_input.connect(_on_modal_backdrop_input)
	layer.add_child(modal_bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(center)

	var modal_panel := PanelContainer.new()
	modal_panel.custom_minimum_size = Vector2(380, 0)
	var modal_style := _make_panel_style(C_RED, 0.45)
	modal_panel.add_theme_stylebox_override("panel", modal_style)
	center.add_child(modal_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   28)
	margin.add_theme_constant_override("margin_right",  28)
	margin.add_theme_constant_override("margin_top",    25)
	margin.add_theme_constant_override("margin_bottom", 28)
	modal_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	margin.add_child(vbox)

	# Warning icon (drawn via control)
	var icon_ctrl := _build_warning_icon()
	var icon_center := CenterContainer.new()
	icon_center.add_child(icon_ctrl)
	vbox.add_child(icon_center)

	var sp0 := Control.new(); sp0.custom_minimum_size = Vector2(0, 12); vbox.add_child(sp0)

	var modal_title := _make_label("Desistir da Partida?", FONT_DECO, 22, Color(0.843, 0.55, 0.251))
	modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(modal_title)

	var sp1 := Control.new(); sp1.custom_minimum_size = Vector2(0, 10); vbox.add_child(sp1)

	var body := _make_label("Tem certeza que deseja abandonar a batalha?", FONT_ITALIC, 15, Color(0.72, 0.66, 0.55, 0.85))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body)

	var sp2 := Control.new(); sp2.custom_minimum_size = Vector2(0, 8); vbox.add_child(sp2)

	var penalty := _make_label("— Você perderá pontos —", FONT_REGULAR, 10, Color(C_RED_DIM, 0.9))
	penalty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(penalty)

	var sp3 := Control.new(); sp3.custom_minimum_size = Vector2(0, 20); vbox.add_child(sp3)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 11)
	vbox.add_child(actions)

	var btn_cancel  := _make_modal_button("Cancelar",     false)
	var btn_confirm := _make_modal_button("Sim, Desistir", true)

	btn_cancel.pressed.connect(func(): _show_view(View.MAIN))
	btn_confirm.pressed.connect(_on_confirm_yes)

	actions.add_child(btn_cancel)
	actions.add_child(btn_confirm)

	_add_corner_ornaments(modal_panel, C_RED, 0.55, 14)

	return layer

func _build_warning_icon() -> Control:
	var ctrl := Control.new()
	ctrl.custom_minimum_size = Vector2(44, 44)
	ctrl.draw.connect(func():
		var col_fill   := Color(C_RED, 0.15)
		var col_stroke := C_RED
		# Triangle
		var pts := PackedVector2Array([
			Vector2(22, 4), Vector2(40, 36), Vector2(4, 36)
		])
		ctrl.draw_colored_polygon(pts, col_fill)
		ctrl.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), col_stroke, 1.5)
		# Exclamation
		ctrl.draw_rect(Rect2(20, 16, 4, 12), col_stroke, true)
		ctrl.draw_rect(Rect2(20, 30, 4, 4),  col_stroke, true)
	)
	return ctrl

# ── Helpers ───────────────────────────────────────────────────────────────────

func _build_crest_control(size: int) -> Control:
	var ctrl := Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.draw.connect(func():
		var w := float(size)
		var h := float(size)
		var col := C_GOLD_MID
		# Shield outline
		var pts := PackedVector2Array([
			Vector2(w*0.5, h*0.08),
			Vector2(w*0.92, h*0.22),
			Vector2(w*0.92, h*0.58),
			Vector2(w*0.5,  h*0.94),
			Vector2(w*0.08, h*0.58),
			Vector2(w*0.08, h*0.22),
		])
		ctrl.draw_colored_polygon(pts, Color(col, 0.15))
		ctrl.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5], pts[0]]), col, 1.5)
		# Two vertical pause bars
		var bar_w := w * 0.10
		var bar_h := h * 0.38
		var bar_y := h * 0.31
		ctrl.draw_rect(Rect2(w * 0.35, bar_y, bar_w, bar_h), C_GOLD, true)
		ctrl.draw_rect(Rect2(w * 0.55, bar_y, bar_w, bar_h), C_GOLD, true)
	)
	return ctrl

func _build_divider() -> Control:
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)

	var line_l := ColorRect.new()
	line_l.custom_minimum_size = Vector2(40, 1)
	line_l.color = Color(C_GOLD_DIM, 0.5)
	hbox.add_child(line_l)

	var diamond := Control.new()
	diamond.custom_minimum_size = Vector2(8, 8)
	diamond.draw.connect(func():
		diamond.draw_rect(Rect2(1, 1, 6, 6), C_GOLD, true)
	)
	hbox.add_child(diamond)

	var line_r := ColorRect.new()
	line_r.custom_minimum_size = Vector2(40, 1)
	line_r.color = Color(C_GOLD_DIM, 0.5)
	hbox.add_child(line_r)

	return hbox

func _make_label(text: String, font: Font, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _make_menu_button(text: String, is_danger: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 56)
	btn.add_theme_font_override("font", FONT_REGULAR)
	btn.add_theme_font_size_override("font_size", 13)

	var fg := C_RED if is_danger else C_GOLD
	var border_col := Color(C_RED, 0.5) if is_danger else Color(C_GOLD_MID, 0.45)
	var border_hover := Color(C_RED, 0.8) if is_danger else Color(C_GOLD, 0.75)

	btn.add_theme_color_override("font_color",       fg)
	btn.add_theme_color_override("font_hover_color", fg.lightened(0.15))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.086, 0.094, 0.188, 0.9)
	normal.border_color = border_col
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(0)
	normal.set_content_margin(SIDE_TOP,    17)
	normal.set_content_margin(SIDE_BOTTOM, 17)
	normal.set_content_margin(SIDE_LEFT,   16)
	normal.set_content_margin(SIDE_RIGHT,  16)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.11, 0.12, 0.22, 0.95)
	hover.border_color = border_hover

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.07, 0.07, 0.15, 0.95)

	btn.add_theme_stylebox_override("normal",  normal)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())

	return btn

func _make_modal_button(text: String, is_danger: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_override("font", FONT_REGULAR)
	btn.add_theme_font_size_override("font_size", 12)

	var fg         := Color(C_RED, 0.9) if is_danger else C_GOLD_MID
	var border_col := Color(C_RED, 0.65) if is_danger else Color(C_GOLD_DIM, 0.5)
	var border_hov := Color(C_RED, 0.9)  if is_danger else Color(C_GOLD, 0.7)

	btn.add_theme_color_override("font_color",       fg)
	btn.add_theme_color_override("font_hover_color", fg.lightened(0.1))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.086, 0.086, 0.165, 0.9)
	normal.border_color = border_col
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(0)
	normal.set_content_margin(SIDE_TOP,    14)
	normal.set_content_margin(SIDE_BOTTOM, 14)
	normal.set_content_margin(SIDE_LEFT,   20)
	normal.set_content_margin(SIDE_RIGHT,  20)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = border_hov
	hover.bg_color = Color(0.11, 0.09, 0.18, 0.95)

	btn.add_theme_stylebox_override("normal",  normal)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", normal)
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	return btn

func _make_panel_style(border_color: Color, border_alpha: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = C_PANEL_BG
	s.border_color = Color(border_color, border_alpha)
	s.set_border_width_all(1)
	s.set_corner_radius_all(0)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size   = 18
	s.shadow_offset = Vector2(0, 10)
	return s

func _add_corner_ornaments(panel: Control, col: Color, alpha: float, size: int) -> void:
	for i in 4:
		var c := Control.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var corner_idx := i
		var corner_col := Color(col, alpha)
		var L := float(size)
		var W := 2.0
		c.draw.connect(func():
			match corner_idx:
				0: # top-left
					c.draw_rect(Rect2(0, 0, L, W), corner_col, true)
					c.draw_rect(Rect2(0, 0, W, L), corner_col, true)
				1: # top-right
					c.draw_rect(Rect2(-L + W, 0, L, W), corner_col, true)
					c.draw_rect(Rect2(-W + W, 0, W, L), corner_col, true)
				2: # bottom-right
					c.draw_rect(Rect2(-L + W, -W, L, W), corner_col, true)
					c.draw_rect(Rect2(0, -L + W, W, L),  corner_col, true)
				3: # bottom-left
					c.draw_rect(Rect2(0, -W, L, W), corner_col, true)
					c.draw_rect(Rect2(0, -L + W, W, L), corner_col, true)
		)
		match i:
			0: c.set_anchor_and_offset(SIDE_LEFT,   0, 0); c.set_anchor_and_offset(SIDE_TOP,    0, 0)
			1: c.set_anchor_and_offset(SIDE_RIGHT,  1, 0); c.set_anchor_and_offset(SIDE_TOP,    0, 0)
			2: c.set_anchor_and_offset(SIDE_RIGHT,  1, 0); c.set_anchor_and_offset(SIDE_BOTTOM, 1, 0)
			3: c.set_anchor_and_offset(SIDE_LEFT,   0, 0); c.set_anchor_and_offset(SIDE_BOTTOM, 1, 0)
		c.custom_minimum_size = Vector2(size, size)
		panel.add_child(c)

# ── View Switching ────────────────────────────────────────────────────────────

func _show_view(v: View) -> void:
	_current_view = v
	_main_view.visible     = (v == View.MAIN)
	_settings_view.visible = (v == View.SETTINGS)
	_confirm_modal.visible = (v == View.CONFIRM)
	if v == View.CONFIRM:
		_main_view.visible = true

# ── Volume Handlers ───────────────────────────────────────────────────────────

func _on_music_changed(v: float) -> void:
	_music_pct = int(clamp(v, 0, 100))
	if _music_slider != null:
		_music_slider.set_value_no_signal(_music_pct)
	_sync_slider_labels()
	_apply_bus_volume("Music", _music_pct)
	_save_settings()
	emit_signal("settings_changed", _music_pct, _fx_pct)

func _on_fx_changed(v: float) -> void:
	_fx_pct = int(clamp(v, 0, 100))
	if _fx_slider != null:
		_fx_slider.set_value_no_signal(_fx_pct)
	_sync_slider_labels()
	_apply_bus_volume("SFX", _fx_pct)
	_save_settings()
	emit_signal("settings_changed", _music_pct, _fx_pct)

func _sync_slider_labels() -> void:
	if _music_value_label != null:
		_music_value_label.text = "Mudo" if _music_pct == 0 else "%d%%" % _music_pct
		_music_value_label.add_theme_color_override("font_color",
			Color(C_GOLD_DIM, 0.7) if _music_pct == 0 else C_GOLD)
	if _fx_value_label != null:
		_fx_value_label.text = "Mudo" if _fx_pct == 0 else "%d%%" % _fx_pct
		_fx_value_label.add_theme_color_override("font_color",
			Color(C_GOLD_DIM, 0.7) if _fx_pct == 0 else C_GOLD)

func _apply_bus_volume(bus_name: String, pct: int) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	if pct == 0:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(pct / 100.0))

# ── Audio bus setup ──────────────────────────────────────────────────────────

func _ensure_audio_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

# ── Persistence ───────────────────────────────────────────────────────────────

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		_music_pct = int(cfg.get_value("audio", "music", 70))
		_fx_pct    = int(cfg.get_value("audio", "fx",    85))
	if _music_slider != null:
		_music_slider.set_value_no_signal(_music_pct)
	if _fx_slider != null:
		_fx_slider.set_value_no_signal(_fx_pct)
	_apply_bus_volume("Music", _music_pct)
	_apply_bus_volume("SFX",   _fx_pct)

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", _music_pct)
	cfg.set_value("audio", "fx",    _fx_pct)
	cfg.save(SETTINGS_PATH)

# ── Animations ────────────────────────────────────────────────────────────────

func _animate_in() -> void:
	_backdrop.modulate.a = 0.0
	_pause_card.modulate.a = 0.0
	_pause_card.scale = Vector2(0.92, 0.92)
	var t := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_backdrop,    "modulate:a", 1.0,       0.35)
	t.tween_property(_pause_card,  "modulate:a", 1.0,       0.50).set_delay(0.05)
	t.tween_property(_pause_card,  "scale",      Vector2.ONE, 0.50).set_delay(0.05)

func _animate_out() -> void:
	var t := create_tween().set_parallel(true).set_ease(Tween.EASE_IN)
	t.tween_property(_backdrop,   "modulate:a", 0.0, 0.25)
	t.tween_property(_pause_card, "modulate:a", 0.0, 0.20)

# ── Modal backdrop click ──────────────────────────────────────────────────────

func _on_modal_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_show_view(View.MAIN)

# ── Forfeit confirm ───────────────────────────────────────────────────────────

func _on_confirm_yes() -> void:
	_is_open = false
	visible = false
	get_tree().paused = false
	emit_signal("forfeit_confirmed")

func _on_quit_to_menu() -> void:
	_is_open = false
	visible = false
	get_tree().paused = false
	emit_signal("quit_to_menu_requested")
