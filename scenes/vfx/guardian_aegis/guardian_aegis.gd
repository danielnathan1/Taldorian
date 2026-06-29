## scenes/vfx/guardian_aegis/guardian_aegis.gd
## VFX persistente da passiva "Muro de Aço" da Valkar (Guardião) — e reutilizável
## para outros efeitos de "prevenir/proteger aliados".
##
## Adaptado de docs/Guardian Animation/Guardian Aegis.html. No protótipo o card do
## Guardião subia e batia no chão; aqui o card ativo é um HeroSlot real vinculado
## ao estado (não pode ser animado), então cravamos um ESCUDO-fantasma a partir da
## base da Valkar (impacto: flash + onda de choque + rachaduras + poeira) e os
## DOMOS protetores se formam sobre os aliados de retaguarda visíveis, persistindo
## com shimmer enquanto a Valkar for a ativa.
##
## Ciclo de vida controlado externamente (igual ao BattleFury):
##   var fx := GuardianAegisScene.instantiate()
##   add_child(fx)
##   fx.activate(guardian_slot, [ally_slot_a, ally_slot_b, ...], mirror)
##   ...
##   fx.deactivate()   → fade-out e queue_free automático
##
## Sinais:
##   activated    → domos persistentes entraram (no impacto)
##   deactivated  → após o fade-out (antes do queue_free)
class_name GuardianAegis
extends CanvasLayer

signal activated
signal deactivated

# ── Paleta (aço-azul; aprox. dos oklch ~215-222 do protótipo) ─────────────────
const C_CORE   := Color(0.88, 0.95, 1.00)   # núcleo quase branco
const C_BRIGHT := Color(0.48, 0.72, 0.96)   # rim/brilho
const C_MID    := Color(0.30, 0.55, 0.85)
const C_GOLD   := Color(0.95, 0.80, 0.42)   # boss do escudo

# ── Timeline (segundos) — espelha o T do protótipo, levemente comprimida ──────
const T_CHARGE_END := 0.55
const T_RISE_PEAK  := 1.00
const T_IMPACT     := 1.22
const T_DOME_START := 1.30
const T_DOME_STAGGER := 0.11
const T_DOME_FORM  := 0.50
const T_BANNER_IN  := 0.20
const T_BANNER_OUT := 3.10
const T_BANNER_END := 3.60

const IMPACT_OFFSET := 56.0   # base do card ativo (de onde o escudo crava)
const RISE_OFFSET   := 70.0   # altura que o escudo sobe antes de cravar

@export var show_banner: bool        = true
@export var ability_name: String     = "MURO DE AÇO"
@export var ability_subtitle: String = "Passiva — Guardião"

enum State { IDLE, ACTIVATING, ACTIVE, DEACTIVATING, DEAD }
var _state: State = State.IDLE

var _source_slot: Control = null
var _target_slots: Array[Control] = []
var _dir: float = 1.0          # +1 jogador (embaixo) · -1 oponente (em cima)
var _rng := RandomNumberGenerator.new()

var _glow_tex: GradientTexture2D
var _ring_tex: ImageTexture

var _guardian_root: Node2D = null   # segue o slot da Valkar
var _guardian_glow: Sprite2D = null
var _domes: Array[Dictionary] = []  # { root, slot, breathe, rim, fade_nodes }
var _status_label: Label = null
var _banner_root: Control = null

var _activation_timers: Array[SceneTreeTimer] = []

func _ready() -> void:
	layer = 50
	_glow_tex = _make_radial_tex()
	_ring_tex = _make_ring_tex(256)

# ── API pública ────────────────────────────────────────────────────────────────

## source_slot — origem do "slam" (cosmético; NÃO ganha domo automaticamente).
## target_slots — quem recebe o domo/escudo (passe explicitamente; pode incluir o
##   próprio source, como na carta Fluxo Reativo onde o herói ativo também é protegido).
## auto_dismiss_after — se > 0, a Égide some sozinha após N segundos (uso one-shot de
##   carta); 0 = persistente até deactivate() (passiva da Valkar).
func activate(source_slot: Control, target_slots: Array, mirror: bool = false, auto_dismiss_after: float = 0.0) -> void:
	if _state != State.IDLE:
		return
	_source_slot = source_slot
	_target_slots.clear()
	for s in target_slots:
		if s is Control:
			_target_slots.append(s)
	_dir   = -1.0 if mirror else 1.0
	_rng.seed = 99
	_state = State.ACTIVATING
	_run_activation()
	if auto_dismiss_after > 0.0:
		get_tree().create_timer(auto_dismiss_after, false).timeout.connect(deactivate)

func deactivate() -> void:
	if _state in [State.DEACTIVATING, State.DEAD, State.IDLE]:
		return
	_state = State.DEACTIVATING
	_run_deactivation()

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _process(_dt: float) -> void:
	# Raiz do guardião segue o slot ativo da Valkar
	if is_instance_valid(_guardian_root) and is_instance_valid(_source_slot):
		_guardian_root.position = _slot_center(_source_slot)
	# Cada domo segue seu slot e some se o slot ficar invisível
	for d in _domes:
		var root := d["root"] as Node2D
		var slot := d["slot"] as Control
		if not is_instance_valid(root):
			continue
		if is_instance_valid(slot):
			root.position = _slot_center(slot)
			root.visible  = slot.visible
		else:
			root.visible = false

func _slot_center(slot: Control) -> Vector2:
	return slot.get_global_transform() * (slot.size * 0.5)

## Deslocamento vertical "rumo à borda do dono" (espelhado para o oponente).
func _v(dy: float) -> Vector2:
	return Vector2(0.0, dy * _dir)

# ── Timers rastreados (cancelados se deactivate vier antes) ───────────────────

func _timer(delay: float, cb: Callable) -> void:
	var t := get_tree().create_timer(delay, false)
	_activation_timers.append(t)
	t.timeout.connect(func() -> void:
		_activation_timers.erase(t)
		if _state != State.DEACTIVATING and _state != State.DEAD:
			cb.call()
	)

# ── Sequência de ativação ─────────────────────────────────────────────────────

func _run_activation() -> void:
	_guardian_root = Node2D.new()
	_guardian_root.position = _slot_center(_source_slot) if is_instance_valid(_source_slot) else get_viewport().get_visible_rect().get_center()
	add_child(_guardian_root)

	_create_guardian_glow()
	_create_shield_slammer()
	if show_banner:
		_create_banner()

	_timer(T_IMPACT, _on_impact)

	# Formação escalonada dos domos
	for i in _target_slots.size():
		_timer(T_DOME_START + float(i) * T_DOME_STAGGER, func() -> void:
			_form_dome(_target_slots[i]))

# Glow de carga atrás do guardião (cresce na carga, lampeja no impacto, fica residual)
func _create_guardian_glow() -> void:
	var glow := _glow_sprite(70.0, C_BRIGHT, _guardian_root)
	glow.position   = Vector2.ZERO
	glow.modulate.a = 0.0
	glow.z_index    = -1
	_guardian_glow  = glow

	var tw := create_tween().set_parallel(true)
	tw.tween_property(glow, "modulate:a", 0.55, T_CHARGE_END) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(glow, "scale", glow.scale * 1.6, T_RISE_PEAK) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

# Escudo-fantasma que sobe e crava na base do guardião
func _create_shield_slammer() -> void:
	var shield := Node2D.new()
	shield.position   = Vector2.ZERO
	shield.modulate.a = 0.0
	shield.z_index    = 4
	_guardian_root.add_child(shield)
	_build_shield_visual(shield, 2.4)

	var rise_pos := _v(-RISE_OFFSET)
	var slam_pos := _v(IMPACT_OFFSET)

	var tw := create_tween()
	# Surge e sobe
	tw.tween_property(shield, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(shield, "position", rise_pos, T_RISE_PEAK) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(shield, "scale", Vector2(1.15, 1.15), T_RISE_PEAK) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	# Crava (rápido)
	tw.tween_property(shield, "position", slam_pos, T_IMPACT - T_RISE_PEAK) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# Dispersa após o impacto
	tw.tween_property(shield, "scale", Vector2(1.4, 0.9), 0.12)
	tw.parallel().tween_property(shield, "modulate:a", 0.0, 0.4)
	tw.tween_callback(shield.queue_free)

# ── Impacto ───────────────────────────────────────────────────────────────────

func _on_impact() -> void:
	var impact_local := _v(IMPACT_OFFSET)

	# Flash de tela curto
	_spawn_screen_flash()

	# Flare do glow do guardião
	if is_instance_valid(_guardian_glow):
		var gt := create_tween()
		gt.tween_property(_guardian_glow, "modulate:a", 1.0, 0.04)
		gt.tween_property(_guardian_glow, "modulate:a", 0.25, 0.6)

	# Brilho no "chão" (elipse achatada)
	var ground := _glow_sprite(120.0, C_BRIGHT, _guardian_root)
	ground.position = impact_local
	ground.scale.y  *= 0.42
	ground.modulate.a = 0.0
	var grt := create_tween()
	grt.tween_property(ground, "modulate:a", 0.7, 0.08)
	grt.tween_property(ground, "modulate:a", 0.0, 0.7)
	grt.tween_callback(ground.queue_free)

	# Ondas de choque (elipses achatadas varrendo para fora)
	for i in 3:
		_timer(float(i) * 0.09, func() -> void: _spawn_shockwave(impact_local))

	# Rachaduras no chão + poeira
	_spawn_cracks(impact_local)
	_spawn_dust(impact_local)

	# Estado persistente entra
	_state = State.ACTIVE
	activated.emit()

func _spawn_screen_flash() -> void:
	var vp := get_viewport().get_visible_rect().size
	var flash := ColorRect.new()
	flash.color        = Color(C_CORE.r, C_CORE.g, C_CORE.b, 0.0)
	flash.size         = vp
	flash.z_index      = 30
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.30, 0.05)
	tw.tween_property(flash, "color:a", 0.0,  0.32)
	tw.tween_callback(flash.queue_free)

func _spawn_shockwave(local_pos: Vector2) -> void:
	var wave := Sprite2D.new()
	wave.texture  = _ring_tex
	wave.position = local_pos
	wave.modulate = Color(C_BRIGHT.r, C_BRIGHT.g, C_BRIGHT.b, 0.85)
	wave.scale    = Vector2(0.12, 0.12 * 0.42)
	_add_mat(wave)
	_guardian_root.add_child(wave)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(wave, "scale", Vector2(3.6, 3.6 * 0.42), 0.85) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(wave, "modulate:a", 0.0, 0.85)
	tw.chain().tween_callback(wave.queue_free)

func _spawn_cracks(local_pos: Vector2) -> void:
	var n := 9
	for i in n:
		var base_a := float(i) / n * TAU + _rng.randf_range(-0.3, 0.3)
		var length := 90.0 + _rng.randf() * 110.0
		var pts := PackedVector2Array([Vector2.ZERO])
		var p := Vector2.ZERO
		var steps := 4
		for s in steps:
			var jitter := _rng.randf_range(-0.5, 0.5)
			var seg := length / steps
			p += Vector2(cos(base_a + jitter) * seg, sin(base_a + jitter) * seg * 0.42 * _dir)
			pts.append(p)
		var crack := Line2D.new()
		crack.points       = pts
		crack.position     = local_pos
		crack.width        = 1.8
		crack.default_color = Color(C_CORE.r, C_CORE.g, C_CORE.b, 0.55)
		crack.joint_mode   = Line2D.LINE_JOINT_ROUND
		crack.begin_cap_mode = Line2D.LINE_CAP_ROUND
		crack.end_cap_mode = Line2D.LINE_CAP_ROUND
		crack.z_index      = -1
		_guardian_root.add_child(crack)
		var tw := create_tween()
		tw.tween_property(crack, "modulate:a", 0.0, 1.1).set_delay(0.4)
		tw.tween_callback(crack.queue_free)

func _spawn_dust(local_pos: Vector2) -> void:
	for i in 22:
		var ang := -PI * 0.5 * _dir + _rng.randf_range(-0.9, 0.9)
		var speed := 120.0 + _rng.randf() * 220.0
		var vel := Vector2(cos(ang) * speed, sin(ang) * speed)
		var life := 0.5 + _rng.randf() * 0.5
		var sz := 1.4 + _rng.randf() * 3.0

		var d := _glow_sprite(sz * 1.6, Color(0.82, 0.88, 0.96, 1.0), _guardian_root)
		d.position = local_pos
		var grav := 360.0 * _dir
		var tw := create_tween()
		tw.tween_method(
			func(u: float) -> void:
				if not is_instance_valid(d):
					return
				d.position = local_pos + vel * u + Vector2(0.0, grav * u * u)
				d.modulate.a = clampf(1.0 - u / 1.0, 0.0, 1.0) * 0.75,
			0.0, life, life
		)
		tw.tween_callback(d.queue_free)

# ── Domos protetores ──────────────────────────────────────────────────────────

func _form_dome(slot: Control) -> void:
	if not is_instance_valid(slot):
		return
	var dome_w := slot.size.x + 46.0
	var dome_h := slot.size.y + 40.0

	var root := Node2D.new()
	root.position = _slot_center(slot)
	root.z_index  = 8
	root.scale    = Vector2.ZERO
	root.modulate.a = 0.0
	add_child(root)

	var fade_nodes: Array[CanvasItem] = []

	# Corpo de vidro (glow radial achatado em elipse)
	var glass := _glow_sprite(dome_w * 0.5, Color(C_MID.r, C_MID.g, C_MID.b, 0.28), root)
	glass.scale.y *= (dome_h / dome_w)
	fade_nodes.append(glass)

	# Linhas de latitude/longitude (elipses finas)
	for spec in [Vector2(0.55, 1.0), Vector2(1.0, 0.42), Vector2(1.0, 0.74)]:
		var ln := _ellipse_line(dome_w * 0.5 * spec.x, dome_h * 0.5 * spec.y,
			Color(C_BRIGHT.r, C_BRIGHT.g, C_BRIGHT.b, 0.30), 0.7)
		root.add_child(ln)
		fade_nodes.append(ln)

	# Rim externo
	var rim := _ellipse_line(dome_w * 0.5, dome_h * 0.5,
		Color(C_BRIGHT.r, C_BRIGHT.g, C_BRIGHT.b, 0.85), 1.6)
	root.add_child(rim)
	fade_nodes.append(rim)

	# Realce especular (canto superior esquerdo)
	var spec_hl := _glow_sprite(dome_w * 0.18, Color(C_CORE.r, C_CORE.g, C_CORE.b, 0.32), root)
	spec_hl.position = Vector2(-dome_w * 0.22, -dome_h * 0.30 * _dir)
	fade_nodes.append(spec_hl)

	# Emblema de escudo central
	var emblem := Node2D.new()
	emblem.z_index = 1
	root.add_child(emblem)
	_build_shield_visual(emblem, 0.85)
	fade_nodes.append(emblem)

	# Pop-in com overshoot
	var pin := create_tween().set_parallel(true)
	pin.tween_property(root, "scale", Vector2.ONE, T_DOME_FORM) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pin.tween_property(root, "modulate:a", 1.0, 0.18)

	# Anel de "encaixe" (snap) que lampeja ao formar
	var snap := _ellipse_line(dome_w * 0.5, dome_h * 0.5,
		Color(C_CORE.r, C_CORE.g, C_CORE.b, 0.9), 2.0)
	root.add_child(snap)
	var st := create_tween().set_parallel(true)
	st.tween_property(snap, "scale", Vector2(1.5, 1.5), 0.4) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	st.tween_property(snap, "modulate:a", 0.0, 0.4)
	st.chain().tween_callback(snap.queue_free)

	# Respiração contínua (shimmer) — guardada para matar no deactivate
	var breathe := create_tween().set_loops()
	breathe.tween_property(root, "scale", Vector2(1.03, 1.03), 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breathe.tween_property(root, "scale", Vector2(0.98, 0.98), 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_domes.append({
		"root": root, "slot": slot, "breathe": breathe,
		"fade_nodes": fade_nodes,
	})

	_spawn_ward_popup(slot)

func _spawn_ward_popup(slot: Control) -> void:
	var lbl := Label.new()
	lbl.text = "◈ Protegido"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", C_CORE)
	lbl.add_theme_color_override("font_shadow_color", Color(C_MID.r, C_MID.g, C_MID.b, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.add_theme_constant_override("shadow_outline_size", 4)
	lbl.z_index = 12
	add_child(lbl)
	await get_tree().process_frame
	if not is_instance_valid(lbl):
		return
	var center := _slot_center(slot)
	var start := center + _v(-(slot.size.y * 0.5 + 18.0)) - Vector2(lbl.size.x * 0.5, lbl.size.y * 0.5)
	lbl.position   = start
	lbl.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.2)
	tw.tween_property(lbl, "position:y", start.y + (-34.0 * _dir), 1.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(lbl, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(lbl.queue_free)

# ── Banner ────────────────────────────────────────────────────────────────────

func _create_banner() -> void:
	var vp := get_viewport().get_visible_rect().size
	_banner_root = Control.new()
	_banner_root.position   = Vector2(vp.x * 0.5, vp.y * 0.5 - 22.0)
	_banner_root.modulate.a = 0.0
	_banner_root.z_index    = 20
	add_child(_banner_root)

	var sub := Label.new()
	sub.text = ability_subtitle
	sub.position = Vector2(-200.0, -52.0)
	sub.custom_minimum_size = Vector2(400.0, 18.0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", C_BRIGHT)
	_banner_root.add_child(sub)

	var title := Label.new()
	title.text = ability_name
	title.position = Vector2(-200.0, -30.0)
	title.custom_minimum_size = Vector2(400.0, 44.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", C_CORE)
	title.add_theme_color_override("font_shadow_color", Color(C_BRIGHT.r, C_BRIGHT.g, C_BRIGHT.b, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.add_theme_constant_override("shadow_outline_size", 6)
	_banner_root.add_child(title)

	var rule := ColorRect.new()
	rule.color    = Color(C_BRIGHT.r, C_BRIGHT.g, C_BRIGHT.b, 0.65)
	rule.size     = Vector2(280.0, 1.0)
	rule.position = Vector2(-140.0, 16.0)
	_banner_root.add_child(rule)

	_status_label = Label.new()
	_status_label.text = "Invocando a guarda"
	_status_label.position = Vector2(-200.0, 22.0)
	_status_label.custom_minimum_size = Vector2(400.0, 16.0)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(C_BRIGHT.r, C_BRIGHT.g, C_BRIGHT.b, 0.85))
	_banner_root.add_child(_status_label)

	_timer(T_IMPACT, func() -> void:
		if is_instance_valid(_status_label):
			_status_label.text = "Aliados protegidos")

	var tw := create_tween()
	tw.tween_property(_banner_root, "modulate:a", 1.0, 0.35).set_delay(T_BANNER_IN)
	tw.tween_property(_banner_root, "modulate:a", 0.0, 0.45).set_delay(T_BANNER_OUT - T_BANNER_IN - 0.45)
	tw.tween_callback(func() -> void:
		if is_instance_valid(_banner_root):
			_banner_root.queue_free())

# ── Desativação ───────────────────────────────────────────────────────────────

func _run_deactivation() -> void:
	_activation_timers.clear()

	var tw := create_tween().set_parallel(true)
	var had_visible := false

	if is_instance_valid(_guardian_glow):
		tw.tween_property(_guardian_glow, "modulate:a", 0.0, 0.5)
		had_visible = true

	for d in _domes:
		var breathe := d.get("breathe") as Tween
		if breathe and breathe.is_valid():
			breathe.kill()
		var root := d["root"] as Node2D
		if is_instance_valid(root):
			tw.tween_property(root, "modulate:a", 0.0, 0.45) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			had_visible = true

	if not had_visible:
		tw.tween_interval(0.01)

	tw.chain().tween_callback(func() -> void:
		_state = State.DEAD
		deactivated.emit()
		queue_free())

# ── Helpers de desenho ────────────────────────────────────────────────────────

func _add_mat(node: CanvasItem) -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	node.material = mat

func _glow_sprite(radius: float, color: Color, parent: Node) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture  = _glow_tex
	sp.scale    = Vector2.ONE * (radius * 2.0 / float(_glow_tex.width))
	sp.modulate = color
	_add_mat(sp)
	parent.add_child(sp)
	return sp

func _ellipse_points(rx: float, ry: float, segs: int = 44) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segs + 1):
		var a := float(i) / float(segs) * TAU
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _ellipse_line(rx: float, ry: float, color: Color, width: float) -> Line2D:
	var ln := Line2D.new()
	ln.points        = _ellipse_points(rx, ry)
	ln.closed        = true
	ln.width         = width
	ln.default_color = color
	ln.joint_mode    = Line2D.LINE_JOINT_ROUND
	ln.antialiased   = true
	_add_mat(ln)
	return ln

## Constrói o desenho de um escudo (fill + contorno + boss) sobre `parent`.
func _build_shield_visual(parent: Node2D, scale: float) -> void:
	var wsh := 19.0 * scale
	var top := -24.0 * scale
	var mid := 6.0 * scale
	var bot := 26.0 * scale
	var shape := PackedVector2Array([
		Vector2(-wsh, top), Vector2(wsh, top),
		Vector2(wsh * 0.86, mid), Vector2(0.0, bot),
		Vector2(-wsh * 0.86, mid),
	])

	var fill := Polygon2D.new()
	fill.polygon = shape
	fill.color   = Color(C_MID.r, C_MID.g, C_MID.b, 0.22)
	parent.add_child(fill)

	var outline := Line2D.new()
	outline.points        = shape
	outline.closed        = true
	outline.width         = 1.5 * scale
	outline.default_color = Color(C_BRIGHT.r, C_BRIGHT.g, C_BRIGHT.b, 0.95)
	outline.joint_mode    = Line2D.LINE_JOINT_ROUND
	outline.antialiased   = true
	parent.add_child(outline)

	var cross_v := Line2D.new()
	cross_v.points        = PackedVector2Array([Vector2(0.0, top), Vector2(0.0, bot)])
	cross_v.width         = 1.0 * scale
	cross_v.default_color = Color(C_CORE.r, C_CORE.g, C_CORE.b, 0.7)
	parent.add_child(cross_v)

	var cross_h := Line2D.new()
	cross_h.points        = PackedVector2Array([Vector2(-wsh * 0.9, mid - 13.0 * scale), Vector2(wsh * 0.9, mid - 13.0 * scale)])
	cross_h.width         = 1.0 * scale
	cross_h.default_color = Color(C_CORE.r, C_CORE.g, C_CORE.b, 0.7)
	parent.add_child(cross_h)

	var boss := _glow_sprite(5.0 * scale, C_GOLD, parent)
	boss.position = Vector2(0.0, mid - 13.0 * scale)

# ── Texturas procedurais ──────────────────────────────────────────────────────

## Glow radial branco (centro → transparente). Tingido por modulate.
func _make_radial_tex(size: int = 128) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors  = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient  = grad
	tex.width     = size
	tex.height    = size
	tex.fill      = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to   = Vector2(1.0, 0.5)
	return tex

## Anel branco (tingido por modulate) — ondas de choque.
func _make_ring_tex(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var h := size * 0.5
	var r := h * 0.9
	var thick := 4.0
	for y in size:
		for x in size:
			var dx := float(x) - h
			var dy := float(y) - h
			var d := sqrt(dx * dx + dy * dy)
			var dist := absf(d - r)
			if dist < thick + 1.5:
				var t := clampf(1.0 - dist / (thick + 1.5), 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, t * 0.9))
	return ImageTexture.create_from_image(img)
