# Overlay do ritual dirigido. Full-screen, sob demanda. Coreografia (s):
# CHANNEL 0–1.3 (anéis giram, núcleo dourado pulsa) · DRAW 1.3 (oferendas sugadas ao
# centro) · BURST 2.35 (flash dourado) · REVEAL 2.75 (materializa a carta-ALVO escolhida).
# Emite `kept` ao confirmar.
class_name RitualStage
extends Control

signal kept

const CARD_VIEW := preload("res://scenes/ui/card_view/card_view.tscn")
const CARD_SIZE := Vector2(160, 240)

const T_DRAW := 1.3
const T_BURST := 2.35
const T_REVEAL := 2.75

var _target: Dictionary
var _veil: ColorRect
var _core: TextureRect
var _offerings: Array[Control] = []
var _center: Vector2
var _vp: Vector2


func play(target: Dictionary, offerings: Array, radius: float) -> void:
	_target = target
	_vp = get_viewport_rect().size
	position = Vector2.ZERO
	size = _vp
	mouse_filter = Control.MOUSE_FILTER_STOP
	_center = _vp * 0.5

	_veil = ColorRect.new()
	_veil.color = Color(0, 0, 0, 0)
	_veil.position = Vector2.ZERO
	_veil.size = _vp
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	create_tween().tween_property(_veil, "color:a", 0.88, 0.5)

	_spin_rings()
	_grow_core()
	_spawn_offerings(offerings, radius)

	get_tree().create_timer(T_DRAW).timeout.connect(_draw_to_center)
	get_tree().create_timer(T_BURST).timeout.connect(_gold_flash)
	get_tree().create_timer(T_REVEAL).timeout.connect(_show_reveal)


func _spin_rings() -> void:
	for spec in [{ "d": 420.0, "w": 3, "a": 0.8, "dir": 1.0 }, { "d": 320.0, "w": 2, "a": 0.5, "dir": -1.0 }]:
		var ring := _make_ring(float(spec.d), int(spec.w), Color(ForgeTheme.GOLD.r, ForgeTheme.GOLD.g, ForgeTheme.GOLD.b, float(spec.a)))
		add_child(ring)
		var spin := create_tween().set_loops()
		spin.tween_property(ring, "rotation", TAU * float(spec.dir), 6.0)


func _make_ring(d: float, w: int, col: Color) -> Control:
	var ring := Control.new()
	ring.custom_minimum_size = Vector2(d, d)
	ring.size = Vector2(d, d)
	ring.pivot_offset = Vector2(d, d) * 0.5
	ring.position = _center - Vector2(d, d) * 0.5
	var inner := PanelContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_border_width_all(w)
	style.border_color = col
	style.set_corner_radius_all(int(d * 0.5))
	inner.add_theme_stylebox_override("panel", style)
	ring.add_child(inner)
	return ring


func _grow_core() -> void:
	_core = TextureRect.new()
	_core.texture = _radial(Color.WHITE)
	_core.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_core.stretch_mode = TextureRect.STRETCH_SCALE
	_core.custom_minimum_size = Vector2(360, 360)
	_core.size = Vector2(360, 360)
	_core.pivot_offset = Vector2(180, 180)
	_core.position = _center - Vector2(180, 180)
	_core.modulate = Color(ForgeTheme.GOLD_GLOW.r, ForgeTheme.GOLD_GLOW.g, ForgeTheme.GOLD_GLOW.b, 0.0)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_core.material = mat
	add_child(_core)
	var pulse := create_tween().set_loops()
	pulse.tween_property(_core, "modulate:a", 0.6, 0.7).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_core, "modulate:a", 0.25, 0.7).set_trans(Tween.TRANS_SINE)


func _spawn_offerings(offerings: Array, radius: float) -> void:
	var n := offerings.size()
	for i in n:
		var card: Variant = offerings[i]
		if card == null:
			continue
		var cv: Control = CARD_VIEW.instantiate()
		add_child(cv)
		cv.size = CARD_SIZE
		cv.pivot_offset = CARD_SIZE * 0.5
		cv.scale = Vector2(0.5, 0.5)
		var a := TAU * float(i) / float(maxi(1, n)) - PI / 2.0
		var pos := _center + Vector2(cos(a) * radius, sin(a) * radius)
		cv.position = pos - CARD_SIZE * 0.25
		if cv.has_method("bind_dict"):
			cv.bind_dict(card)
		if cv.has_method("set_face_down"):
			cv.set_face_down(false)
		if cv.has_method("set_interactable"):
			cv.set_interactable(false, false)
		_offerings.append(cv)


func _draw_to_center() -> void:
	for cv in _offerings:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(cv, "position", _center - CARD_SIZE * 0.1, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(cv, "scale", Vector2(0.05, 0.05), 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(cv, "modulate:a", 0.0, 1.0)


func _gold_flash() -> void:
	var f := ColorRect.new()
	f.color = Color(ForgeTheme.GOLD_GLOW.r, ForgeTheme.GOLD_GLOW.g, ForgeTheme.GOLD_GLOW.b, 0.0)
	f.position = Vector2.ZERO
	f.size = _vp
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(f)
	var tw := create_tween()
	tw.tween_property(f, "color:a", 0.85, 0.08)
	tw.tween_property(f, "color:a", 0.0, 0.4)
	tw.tween_callback(f.queue_free)


func _show_reveal() -> void:
	create_tween().tween_property(_veil, "color:a", 0.94, 0.4)

	var center := CenterContainer.new()
	center.position = Vector2.ZERO
	center.size = _vp
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var eyebrow := ForgeTheme.make_eyebrow("Ritual completo · Carta materializada", ForgeTheme.GOLD_GLOW, 11)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(eyebrow)

	var wrap := Control.new()
	wrap.custom_minimum_size = CARD_SIZE * 1.4
	wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(wrap)
	var halo := TextureRect.new()
	halo.texture = _radial(Color.WHITE)
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.stretch_mode = TextureRect.STRETCH_SCALE
	halo.custom_minimum_size = CARD_SIZE * 2.0
	halo.size = CARD_SIZE * 2.0
	halo.position = (CARD_SIZE * 1.4 - CARD_SIZE * 2.0) * 0.5
	halo.modulate = Color(ForgeTheme.GOLD_GLOW.r, ForgeTheme.GOLD_GLOW.g, ForgeTheme.GOLD_GLOW.b, 0.5)
	wrap.add_child(halo)

	var cv: Control = CARD_VIEW.instantiate()
	wrap.add_child(cv)
	cv.size = CARD_SIZE * 1.4
	if cv.has_method("bind_dict"):
		cv.bind_dict(_target)
	if cv.has_method("apply_scale"):
		cv.apply_scale(1.4)
	if cv.has_method("set_face_down"):
		cv.set_face_down(false)
	cv.scale = Vector2(0.4, 0.4)
	cv.pivot_offset = (CARD_SIZE * 1.4) * 0.5
	cv.modulate = Color(1, 1, 1, 0)
	var rt := create_tween().set_parallel(true)
	rt.tween_property(cv, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rt.tween_property(cv, "modulate:a", 1.0, 0.35)

	box.add_child(ForgeTheme.make_label(str(_target.get("name", "?")), ForgeTheme.font_display(), 32,
		ForgeTheme.PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER))

	var keep_btn := Button.new()
	keep_btn.text = "✓  Adicionar à Coleção"
	keep_btn.add_theme_font_override("font", ForgeTheme.font_heading())
	keep_btn.add_theme_font_size_override("font_size", 15)
	keep_btn.add_theme_color_override("font_color", ForgeTheme.PARCHMENT)
	keep_btn.add_theme_stylebox_override("normal", ForgeTheme.crimson_button_style())
	keep_btn.add_theme_stylebox_override("hover", ForgeTheme.crimson_button_style(true))
	keep_btn.add_theme_stylebox_override("pressed", ForgeTheme.crimson_button_style(true))
	keep_btn.add_theme_stylebox_override("focus", ForgeTheme.crimson_button_style())
	keep_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	keep_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	keep_btn.pressed.connect(func() -> void:
		kept.emit()
		queue_free())
	box.add_child(keep_btn)


func _radial(tint: Color, size := 128) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(tint.r, tint.g, tint.b, tint.a))
	g.set_color(1, Color(tint.r, tint.g, tint.b, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = size
	tex.height = size
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex
