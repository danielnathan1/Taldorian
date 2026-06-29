# Overlay do "cataclismo" da forja aleatória. Full-screen, instanciado sob demanda.
# Coreografia (s): SHAKE 0–1.25 · SCATTER 1.25 · CONVERGE 2.15 (+luz) · FLASH 3.25 ·
# REVEAL 3.65. Emite `kept` quando o jogador confirma "Adicionar à Coleção".
#
# Lição do protótipo: no REVEAL NÃO confiar em blend aditivo sobre a carta (estoura em
# branco) — fundo escuro sólido acima da luz, carta acima dele, halo atrás da carta.
class_name CataclysmStage
extends Control

signal kept

const CARD_VIEW := preload("res://scenes/ui/card_view/card_view.tscn")
const CARD_SIZE := Vector2(160, 240)

const T_SCATTER := 1.25
const T_CONVERGE := 2.15
const T_FLASH := 3.25
const T_REVEAL := 3.65

var _result: Dictionary
var _fx: Control                 # container que treme
var _veil: ColorRect
var _light: TextureRect
var _backs: Array[Control] = []
var _shake_amp_px := 5.0
var _shake_tween: Tween
var _center: Vector2
var _vp: Vector2


func play(result: Dictionary, cards: Array, lightning: bool, shake_amp: String) -> void:
	_result = result
	# Tamanho explícito do viewport — não confiar na propagação de âncora do pai
	# (que pode chegar 0 no frame da criação e jogar tudo pro canto superior esquerdo).
	_vp = get_viewport_rect().size
	position = Vector2.ZERO
	size = _vp
	mouse_filter = Control.MOUSE_FILTER_STOP
	_center = _vp * 0.5
	_shake_amp_px = { "sutil": 2.0, "forte": 5.0, "caotico": 10.0 }.get(shake_amp, 5.0)

	_veil = ColorRect.new()
	_veil.color = Color(0, 0, 0, 0)
	_veil.position = Vector2.ZERO
	_veil.size = _vp
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	create_tween().tween_property(_veil, "color:a", 0.86, 0.6)

	_fx = Control.new()
	_fx.position = Vector2.ZERO
	_fx.size = _vp
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)

	_grow_cracks()
	if lightning:
		_start_bolts()
	_spawn_backs(cards)
	_start_shake()

	get_tree().create_timer(T_SCATTER).timeout.connect(_scatter_out)
	get_tree().create_timer(T_CONVERGE).timeout.connect(func() -> void:
		_converge_in()
		_grow_central_light())
	get_tree().create_timer(T_FLASH).timeout.connect(_screen_flash)
	get_tree().create_timer(T_REVEAL).timeout.connect(func() -> void:
		_stop_shake()
		_show_reveal())


# ── SHAKE ────────────────────────────────────────────────────────────────────
func _start_shake() -> void:
	_shake_tween = create_tween().set_loops()
	for _i in 20:
		var off := Vector2(randf_range(-_shake_amp_px, _shake_amp_px), randf_range(-_shake_amp_px, _shake_amp_px))
		_shake_tween.tween_property(_fx, "position", off, 0.05)
	_shake_tween.tween_property(_fx, "position", Vector2.ZERO, 0.05)


func _stop_shake() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_fx.position = Vector2.ZERO


# ── Rachaduras radiais ────────────────────────────────────────────────────────
func _grow_cracks() -> void:
	for i in 7:
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = Color(0.85, 0.53, 0.24, 0.65)
		line.position = _center
		var ang := deg_to_rad(i * 51.0 + randf_range(-12.0, 12.0))
		var dir := Vector2(cos(ang), sin(ang))
		line.add_point(Vector2.ZERO)
		line.add_point(Vector2.ZERO)
		_fx.add_child(line)
		var len := randf_range(260.0, 520.0)
		var tw := create_tween()
		tw.tween_method(func(t: float) -> void: line.set_point_position(1, dir * t),
			0.0, len, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var fade := create_tween()
		fade.tween_interval(0.9)
		fade.tween_property(line, "modulate:a", 0.0, 0.9)


# ── Raios ─────────────────────────────────────────────────────────────────────
func _start_bolts() -> void:
	for i in 5:
		var t := get_tree().create_timer(randf_range(0.1, 1.1))
		t.timeout.connect(_spawn_bolt)


func _spawn_bolt() -> void:
	var bolt := Line2D.new()
	bolt.width = 2.5
	bolt.default_color = Color(0.7, 0.85, 1.0, 0.9)
	var x := randf_range(_center.x - 420.0, _center.x + 420.0)
	var y := 0.0
	bolt.add_point(Vector2(x, y))
	for _s in 5:
		x += randf_range(-40.0, 40.0)
		y += randf_range(60.0, 110.0)
		bolt.add_point(Vector2(x, y))
	_fx.add_child(bolt)
	var tw := create_tween()
	tw.tween_property(bolt, "modulate:a", 0.0, 0.25)
	tw.tween_callback(bolt.queue_free)
	_screen_flash(Color(0.6, 0.75, 1.0), 0.18)


# ── Cartas: scatter → converge ───────────────────────────────────────────────
func _spawn_backs(cards: Array) -> void:
	for card in cards:
		var cv: Control = CARD_VIEW.instantiate()
		_fx.add_child(cv)
		cv.size = CARD_SIZE
		cv.pivot_offset = CARD_SIZE * 0.5
		cv.position = _center - CARD_SIZE * 0.5
		if cv.has_method("bind_dict"):
			cv.bind_dict(card)
		if cv.has_method("set_face_down"):
			cv.set_face_down(true)
		if cv.has_method("set_interactable"):
			cv.set_interactable(false, false)
		_backs.append(cv)


func _scatter_out() -> void:
	var n := _backs.size()
	for i in n:
		var cv := _backs[i]
		var ang := TAU * float(i) / float(maxi(1, n)) + randf_range(-0.2, 0.2)
		var dist := randf_range(280.0, 420.0)
		var target := _center + Vector2(cos(ang) * dist, sin(ang) * dist * 0.78) - CARD_SIZE * 0.5
		var tw := create_tween().set_parallel(true)
		tw.tween_property(cv, "position", target, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(cv, "rotation", randf_range(-2.0, 2.0), 0.85)


func _converge_in() -> void:
	for cv in _backs:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(cv, "position", _center - CARD_SIZE * 0.5, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(cv, "scale", Vector2(0.05, 0.05), 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(cv, "modulate:a", 0.0, 1.0)


# ── Luz central ───────────────────────────────────────────────────────────────
func _grow_central_light() -> void:
	var tier: Dictionary = _result.tier
	_light = TextureRect.new()
	_light.texture = _radial(Color.WHITE)
	_light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_light.stretch_mode = TextureRect.STRETCH_SCALE
	_light.custom_minimum_size = Vector2(600, 600)
	_light.size = Vector2(600, 600)
	_light.pivot_offset = Vector2(300, 300)
	_light.position = _center - Vector2(300, 300)
	_light.modulate = Color(tier.glow.r, tier.glow.g, tier.glow.b, 0.0)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_light.material = mat
	_fx.add_child(_light)
	_light.scale = Vector2(0.1, 0.1)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_light, "scale", Vector2(1.6, 1.6), 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_light, "modulate:a", 1.0, 0.9)
	# Cromático: roda o hue do modulate (aproxima a luz arco-íris da Mística).
	if bool(tier.get("chromatic", false)):
		var spin := create_tween().set_loops()
		spin.tween_method(_set_light_hue, 0.0, 1.0, 2.0)


func _set_light_hue(h: float) -> void:
	if is_instance_valid(_light):
		var c := Color.from_hsv(h, 0.6, 1.0)
		_light.modulate = Color(c.r, c.g, c.b, _light.modulate.a)


func _screen_flash(col := Color.WHITE, peak := 0.9) -> void:
	var f := ColorRect.new()
	f.color = Color(col.r, col.g, col.b, 0.0)
	f.position = Vector2.ZERO
	f.size = _vp
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(f)
	var tw := create_tween()
	tw.tween_property(f, "color:a", peak, 0.06)
	tw.tween_property(f, "color:a", 0.0, 0.35)
	tw.tween_callback(f.queue_free)


# ── REVEAL ────────────────────────────────────────────────────────────────────
func _show_reveal() -> void:
	var tier: Dictionary = _result.tier
	var card: Dictionary = _result.card

	# Esconde luz/cartas; fundo escuro sólido garante a carta legível.
	if is_instance_valid(_light):
		create_tween().tween_property(_light, "modulate:a", 0.25, 0.5)
	for cv in _backs:
		cv.visible = false
	create_tween().tween_property(_veil, "color:a", 0.94, 0.4)

	var center := CenterContainer.new()
	center.position = Vector2.ZERO
	center.size = _vp
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var center_box := VBoxContainer.new()
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.add_theme_constant_override("separation", 14)
	center.add_child(center_box)

	var eyebrow := ForgeTheme.make_eyebrow("Forja %s · Luz %s" % [str(tier.name), str(tier.light)],
		Color(tier.glow), 11)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_box.add_child(eyebrow)

	# Carta com halo atrás (não-aditivo sobre a carta).
	var card_wrap := Control.new()
	card_wrap.custom_minimum_size = CARD_SIZE * 1.4
	card_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center_box.add_child(card_wrap)
	var halo := TextureRect.new()
	halo.texture = _radial(Color.WHITE)
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.stretch_mode = TextureRect.STRETCH_SCALE
	halo.custom_minimum_size = CARD_SIZE * 2.0
	halo.size = CARD_SIZE * 2.0
	halo.position = (CARD_SIZE * 1.4 - CARD_SIZE * 2.0) * 0.5
	halo.modulate = Color(tier.glow.r, tier.glow.g, tier.glow.b, 0.55)
	card_wrap.add_child(halo)

	var cv: Control = CARD_VIEW.instantiate()
	card_wrap.add_child(cv)
	cv.size = CARD_SIZE * 1.4
	cv.position = (CARD_SIZE * 1.4 - CARD_SIZE * 1.4) * 0.5
	if cv.has_method("bind_dict"):
		cv.bind_dict(card)
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

	var title := ForgeTheme.make_label(str(card.get("name", "?")), ForgeTheme.font_display(), 32,
		Color(tier.glow) if bool(tier.get("chromatic", false)) else ForgeTheme.PARCHMENT,
		HORIZONTAL_ALIGNMENT_CENTER)
	center_box.add_child(title)

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
	center_box.add_child(keep_btn)


# ── Util ──────────────────────────────────────────────────────────────────────
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
