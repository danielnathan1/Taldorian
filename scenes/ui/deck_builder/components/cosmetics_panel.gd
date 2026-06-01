extends Control

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")

signal sleeve_changed(sleeve_id: String)
signal playmat_changed(playmat_id: String)

var _selected_sleeve: String  = "default"
var _selected_playmat: String = "default"

var _sleeve_items: Dictionary  = {}  # id -> PanelContainer
var _playmat_items: Dictionary = {}  # id -> PanelContainer


func _ready() -> void:
	_build_ui()


func refresh(deck: DeckData) -> void:
	_selected_sleeve  = deck.sleeve
	_selected_playmat = deck.playmat
	_update_sleeve_visuals()
	_update_playmat_visuals()


# ── UI construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)

	# ── Sleeves ──────────────────────────────────────────────────────────────
	_add_section_label(vbox, "SLEEVE")

	var sleeve_flow := HFlowContainer.new()
	sleeve_flow.add_theme_constant_override("h_separation", 10)
	sleeve_flow.add_theme_constant_override("v_separation", 10)
	vbox.add_child(sleeve_flow)

	for s: Dictionary in CosmeticsStore.get_available_sleeves():
		var id: String   = str(s.get("id", ""))
		var name: String = str(s.get("name", id))
		var path: String = "res://assets/sleve/%s.png" % str(s.get("art_key", id))
		var item := _make_image_item(path, name, 72, 100)
		sleeve_flow.add_child(item)
		_sleeve_items[id] = item
		# captura id por valor para o closure
		var captured_id := id
		item.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton \
			and ev.button_index == MOUSE_BUTTON_LEFT \
			and ev.pressed:
				_on_sleeve_selected(captured_id)
		)

	_add_separator(vbox)

	# ── Playmats ─────────────────────────────────────────────────────────────
	_add_section_label(vbox, "PLAYMAT")

	var playmat_flow := HFlowContainer.new()
	playmat_flow.add_theme_constant_override("h_separation", 10)
	playmat_flow.add_theme_constant_override("v_separation", 10)
	vbox.add_child(playmat_flow)

	for p: Dictionary in CosmeticsStore.get_available_playmats():
		var id: String   = str(p.get("id", ""))
		var name: String = str(p.get("name", id))
		var path: String = "res://assets/playmats/%s.png" % str(p.get("art_key", id))
		var item := _make_image_item(path, name, 192, 108)
		playmat_flow.add_child(item)
		_playmat_items[id] = item
		var captured_id := id
		item.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton \
			and ev.button_index == MOUSE_BUTTON_LEFT \
			and ev.pressed:
				_on_playmat_selected(captured_id)
		)

	_update_sleeve_visuals()
	_update_playmat_visuals()


func _make_image_item(tex_path: String, label_text: String, w: int, h: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(w + 10, h + 26)
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.add_theme_stylebox_override("panel", _style_item_normal())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   4)
	margin.add_theme_constant_override("margin_right",  4)
	margin.add_theme_constant_override("margin_top",    4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 4)
	margin.add_child(vb)

	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(w, h)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	if ResourceLoader.exists(tex_path):
		tex_rect.texture = load(tex_path)
	vb.add_child(tex_rect)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", S.FONT_REG)
	lbl.add_theme_color_override("font_color", S.C_PARCHMENT_D)
	lbl.add_theme_font_size_override("font_size", 10)
	vb.add_child(lbl)

	return panel


func _add_section_label(parent: Control, title: String) -> void:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_override("font", S.FONT_BOLD)
	lbl.add_theme_color_override("font_color", S.C_GOLD)
	lbl.add_theme_font_size_override("font_size", 11)
	parent.add_child(lbl)


func _add_separator(parent: Control) -> void:
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(S.C_GOLD.r, S.C_GOLD.g, S.C_GOLD.b, 0.25))
	parent.add_child(sep)


# ── StyleBoxes ───────────────────────────────────────────────────────────────

func _style_item_normal() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(S.C_BG_SURFACE2.r, S.C_BG_SURFACE2.g, S.C_BG_SURFACE2.b, 0.6)
	s.border_color = Color(S.C_GOLD.r, S.C_GOLD.g, S.C_GOLD.b, 0.15)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	return s


func _style_item_selected() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(S.C_GOLD.r, S.C_GOLD.g, S.C_GOLD.b, 0.12)
	s.border_color = Color(S.C_GOLD.r, S.C_GOLD.g, S.C_GOLD.b, 0.90)
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	return s


# ── Interaction ───────────────────────────────────────────────────────────────

func _on_sleeve_selected(id: String) -> void:
	_selected_sleeve = id
	_update_sleeve_visuals()
	sleeve_changed.emit(id)


func _on_playmat_selected(id: String) -> void:
	_selected_playmat = id
	_update_playmat_visuals()
	playmat_changed.emit(id)


# ── Visuals ───────────────────────────────────────────────────────────────────

func _update_sleeve_visuals() -> void:
	for id: String in _sleeve_items:
		var selected := (id == _selected_sleeve)
		_sleeve_items[id].add_theme_stylebox_override(
			"panel",
			_style_item_selected() if selected else _style_item_normal()
		)
		# Atualiza cor do label (último filho do VBox)
		_set_item_label_color(_sleeve_items[id], selected)


func _update_playmat_visuals() -> void:
	for id: String in _playmat_items:
		var selected := (id == _selected_playmat)
		_playmat_items[id].add_theme_stylebox_override(
			"panel",
			_style_item_selected() if selected else _style_item_normal()
		)
		_set_item_label_color(_playmat_items[id], selected)


func _set_item_label_color(panel: PanelContainer, selected: bool) -> void:
	# estrutura: panel → MarginContainer → VBox → [TextureRect, Label]
	var margin: Node = panel.get_child(0)
	if margin == null:
		return
	var vb: Node = margin.get_child(0)
	if vb == null or vb.get_child_count() < 2:
		return
	var lbl := vb.get_child(1) as Label
	if lbl == null:
		return
	lbl.add_theme_color_override(
		"font_color",
		S.C_GOLD_GLOW if selected else S.C_PARCHMENT_D
	)
