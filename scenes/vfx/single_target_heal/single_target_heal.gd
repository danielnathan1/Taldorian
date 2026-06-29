## scenes/vfx/single_target_heal/single_target_heal.gd
## VFX autocontido para curas de alvo único originadas por cartas.
## Uso:
##   var fx := SingleTargetHealScene.instantiate()
##   add_child(fx)
##   fx.play(target_global_pos, card_size, null, start_hp, end_hp)
class_name SingleTargetHeal
extends CanvasLayer

# ── Assets ─────────────────────────────────────────────────────────────────────
const _TEX_ORB    := preload("res://scenes/vfx/single_target_heal/heal_orb.png")
const _TEX_PART   := preload("res://scenes/vfx/single_target_heal/heal_particle.png")
const _TEX_TRAIL  := preload("res://scenes/vfx/single_target_heal/trail_dot.png")
const _TEX_GLOW   := preload("res://scenes/vfx/single_target_heal/origin_glow.png")
const _TEX_FLASH  := preload("res://scenes/vfx/single_target_heal/impact_flash.png")
const _TEX_WAVE   := preload("res://scenes/vfx/single_target_heal/burst_wave.png")
const _TEX_CROSS  := preload("res://scenes/vfx/single_target_heal/heal_cross.png")
const _TEX_CORNER := preload("res://scenes/vfx/single_target_heal/target_corner.png")

# ── Palette ────────────────────────────────────────────────────────────────────
const _C_CORE   := Color("#f4ffe8")
const _C_BRIGHT := Color("#bcf6a6")
const _C_MID    := Color("#7adfa1")

# ── Origem: centro do viewport (calculado dinamicamente em _run) ──────────────
var _origin := Vector2.ZERO

# ── Timeline (segundos — espelha Single Target Heal.html) ─────────────────────
const T_GATHER_START  := 0.00
const T_GATHER_END    := 0.75
const T_BANNER_IN     := 0.15
const T_BANNER_OUT    := 3.60
const T_TARGET_LOCK   := 0.30
const T_TARGET_UNLOCK := 3.60
const T_LAUNCH        := 0.75
const T_IMPACT        := 1.50
const T_HP_FILL_START := 1.50
const T_HP_FILL_END   := 2.10
const T_POP_START     := 1.55
const T_POP_END       := 2.80
const T_HOLD_END      := 4.20

const _NUM_GATHER    := 14
const _NUM_BURST     := 42
const _NUM_TRAIL     := 28   # amostras de trail (2× para suavidade)
const _NUM_SHOCKWAVE := 2

## Emitido quando a animação termina. O nó se auto-destrói logo em seguida.
signal finished

@export var heal_color: Color        = Color("#7adfa1")

var _target_pos:       Vector2
var _target_card_size: Vector2 = Vector2(70.0, 98.0)
var _hp_node:          Range   = null
var _start_hp:         int     = 0
var _end_hp:           int     = 0
var _heal_amount:      int     = 0

var _rng := RandomNumberGenerator.new()

# Camadas organizacionais (Node2D filhos do CanvasLayer)
var _gather_layer: Node2D
var _trail_layer:  Node2D
var _target_layer: Node2D
var _burst_layer:  Node2D
var _float_layer:  Node2D
var _popup_layer:  Node2D

# Nós animados
var _origin_glow:  Sprite2D
var _orb:          Sprite2D
var _target_ring:  Sprite2D
var _corner_nodes: Array[Sprite2D] = []
var _board_dimmer: ColorRect
var _screen_flash: ColorRect
var _impact_flash: Sprite2D

func _ready() -> void:
	layer = 50

# ── API pública ────────────────────────────────────────────────────────────────

## Inicia a animação de cura single-target.
## target_pos      — posição global do centro da carta-alvo
## target_card_size— tamanho da carta (70×98 bench, 90×126 herói ativo)
## hp_node         — Range opcional para animar a barra de HP
## start_hp        — HP antes da cura (em pontos)
## end_hp          — HP após a cura (em pontos)
func play(
	target_pos: Vector2,
	target_card_size: Vector2 = Vector2(70.0, 98.0),
	hp_node: Range = null,
	start_hp: int = 0,
	end_hp: int = 0
) -> void:
	_target_pos       = target_pos
	_target_card_size = target_card_size
	_hp_node          = hp_node
	_start_hp         = start_hp
	_end_hp           = end_hp
	_heal_amount      = end_hp - start_hp
	_rng.seed         = 7
	_setup_layers()
	_run()

# ── Criação de camadas ─────────────────────────────────────────────────────────

func _setup_layers() -> void:
	_gather_layer = _make_layer(6)
	_trail_layer  = _make_layer(8)
	_target_layer = _make_layer(7)
	_burst_layer  = _make_layer(10)
	_float_layer  = _make_layer(11)
	_popup_layer  = _make_layer(12)

func _make_layer(z: int) -> Node2D:
	var n := Node2D.new()
	n.z_index = z
	add_child(n)
	return n

func _add_mat(node: CanvasItem) -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	node.material = mat

# ── Orquestração principal ─────────────────────────────────────────────────────

func _run() -> void:
	var vp_rect := get_viewport().get_visible_rect()
	var vp_size := vp_rect.size
	_origin      = vp_rect.get_center()

	# Board dimmer — escurece o fundo durante o target lock
	_board_dimmer = ColorRect.new()
	_board_dimmer.color        = Color(0.0, 0.0, 0.0, 0.30)
	_board_dimmer.size         = vp_size
	_board_dimmer.z_index      = 3
	_board_dimmer.modulate.a   = 0.0
	_board_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board_dimmer)

	# Screen flash — flash breve ao impactar (alpha inicial 0 via color.a, modulate fica em 1)
	_screen_flash = ColorRect.new()
	_screen_flash.color        = Color(0.855, 0.992, 0.871, 0.0)
	_screen_flash.size         = vp_size
	_screen_flash.z_index      = 20
	_screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen_flash)

	# Origin glow — cresce no centro durante o gather
	_origin_glow          = Sprite2D.new()
	_origin_glow.texture  = _TEX_GLOW
	_origin_glow.position = _origin
	_origin_glow.scale    = Vector2(0.12, 0.12)
	_origin_glow.modulate = Color(heal_color.r, heal_color.g, heal_color.b, 0.0)
	_add_mat(_origin_glow)
	_gather_layer.add_child(_origin_glow)

	# Orb — partícula principal que voa até o alvo
	_orb          = Sprite2D.new()
	_orb.texture  = _TEX_ORB
	_orb.position = _origin
	_orb.scale    = Vector2(0.05, 0.05)
	_orb.modulate = Color(_C_CORE.r, _C_CORE.g, _C_CORE.b, 0.0)
	_add_mat(_orb)
	_trail_layer.add_child(_orb)

	# Target ring — anel ao redor da carta-alvo escalado ao tamanho dela
	var ring_w := _target_card_size.x + 10.0
	var ring_h := _target_card_size.y + 10.0
	_target_ring          = Sprite2D.new()
	_target_ring.texture  = load("res://scenes/vfx/single_target_heal/target_ring.png")
	_target_ring.position = _target_pos
	_target_ring.scale    = Vector2(ring_w / 80.0, ring_h / 108.0)
	_target_ring.modulate = Color(heal_color.r, heal_color.g, heal_color.b, 0.0)
	_target_layer.add_child(_target_ring)

	# Cantos em L nos quatro cantos do target ring
	var half := Vector2(ring_w * 0.5, ring_h * 0.5)
	var corner_data := [
		[_target_pos + Vector2(-half.x, -half.y), 0.0         ],
		[_target_pos + Vector2( half.x, -half.y), PI * 0.5    ],
		[_target_pos + Vector2( half.x,  half.y), PI          ],
		[_target_pos + Vector2(-half.x,  half.y), -PI * 0.5   ],
	]
	_corner_nodes.clear()
	for cd in corner_data:
		var sp          := Sprite2D.new()
		sp.texture       = _TEX_CORNER
		sp.position      = cd[0]
		sp.rotation      = cd[1]
		sp.scale         = Vector2(0.8, 0.8)
		sp.modulate      = Color(heal_color.r, heal_color.g, heal_color.b, 0.0)
		_target_layer.add_child(sp)
		_corner_nodes.append(sp)

	# Impact flash — flash radial no ponto de impacto
	_impact_flash          = Sprite2D.new()
	_impact_flash.texture  = _TEX_FLASH
	_impact_flash.position = _target_pos
	_impact_flash.scale    = Vector2(0.4, 0.4)
	_impact_flash.modulate = Color(_C_CORE.r, _C_CORE.g, _C_CORE.b, 0.0)
	_add_mat(_impact_flash)
	_burst_layer.add_child(_impact_flash)

	# Anima em paralelo
	var t := create_tween().set_parallel(true)
	_animate_origin_glow(t)
	_animate_gather_particles()
	_animate_target_lock(t)
	_animate_board_dim(t)

	get_tree().create_timer(T_LAUNCH,        false).timeout.connect(_launch_orb)
	get_tree().create_timer(T_IMPACT,        false).timeout.connect(_trigger_impact)

	if _hp_node != null:
		_animate_hp_fill()

	_spawn_heal_popup()
	get_tree().create_timer(T_IMPACT, false).timeout.connect(_spawn_floating_crosses)
	get_tree().create_timer(T_HOLD_END, false).timeout.connect(_on_finished)

# ── Origin glow ────────────────────────────────────────────────────────────────

func _animate_origin_glow(t: Tween) -> void:
	t.tween_property(_origin_glow, "scale", Vector2(0.40, 0.40), T_GATHER_END) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_origin_glow, "modulate:a", 0.9, T_GATHER_END) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Pulse breve ao fim do gather
	t.tween_property(_origin_glow, "scale", Vector2(0.50, 0.50), 0.15).set_delay(T_GATHER_END)
	# Desaparece ao lançar o orbe
	t.tween_property(_origin_glow, "modulate:a", 0.0, 0.25).set_delay(T_LAUNCH)

# ── Gather: 14 partículas espiralam para dentro do centro ─────────────────────

func _animate_gather_particles() -> void:
	for i in _NUM_GATHER:
		var start_angle := float(i) / _NUM_GATHER * TAU + _rng.randf() * 0.6
		var start_rad   := 70.0 + _rng.randf() * 90.0
		var delay       := _rng.randf() * 0.25
		var size        := 1.2 + _rng.randf() * 1.8
		var dur         := maxf((T_GATHER_END - T_GATHER_START) - delay, 0.1)

		var p          := Sprite2D.new()
		p.texture       = _TEX_PART
		p.scale         = Vector2(size * 0.08, size * 0.08)
		p.modulate      = Color(heal_color.r, heal_color.g, heal_color.b, 0.95)
		_add_mat(p)
		_gather_layer.add_child(p)

		var tw := create_tween()
		if delay > 0.0:
			tw.tween_interval(delay)
		tw.tween_method(
			func(u: float) -> void:
				if not is_instance_valid(p):
					return
				var eased: float = u * u * u
				var rad: float   = start_rad * (1.0 - eased)
				var ang: float   = start_angle + eased * TAU * 2.5
				p.position  = _origin + Vector2(cos(ang) * rad, sin(ang) * rad)
				p.modulate.a = (1.0 - u) * 0.95,
			0.0, 1.0, dur
		)
		tw.tween_callback(p.queue_free)

# ── Target lock ────────────────────────────────────────────────────────────────

func _animate_target_lock(t: Tween) -> void:
	t.tween_property(_target_ring, "modulate:a", 1.0, 0.35).set_delay(T_TARGET_LOCK)
	for c in _corner_nodes:
		t.tween_property(c, "modulate:a", 1.0, 0.35).set_delay(T_TARGET_LOCK)
	t.tween_property(_target_ring, "modulate:a", 0.0, 0.45).set_delay(T_TARGET_UNLOCK - 0.45)
	for c in _corner_nodes:
		t.tween_property(c, "modulate:a", 0.0, 0.45).set_delay(T_TARGET_UNLOCK - 0.45)

func _animate_board_dim(t: Tween) -> void:
	t.tween_property(_board_dimmer, "modulate:a", 1.0, 0.40).set_delay(T_TARGET_LOCK)
	t.tween_property(_board_dimmer, "modulate:a", 0.0, 0.50).set_delay(T_TARGET_UNLOCK - 0.50)

# ── Bezier quadrática ──────────────────────────────────────────────────────────

func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2

# ── Launch do orbe (T_LAUNCH → T_IMPACT) ──────────────────────────────────────

func _launch_orb() -> void:
	var ctrl := Vector2(
		(_target_pos.x + _origin.x) * 0.5 - 40.0,
		min(_origin.y, _target_pos.y) - 80.0
	)
	var dur := T_IMPACT - T_LAUNCH

	_orb.modulate = Color(_C_CORE.r, _C_CORE.g, _C_CORE.b, 1.0)

	var tw := create_tween()
	tw.tween_method(
		func(u: float) -> void:
			if not is_instance_valid(_orb):
				return
			var eased: float = u * u * u * 0.55 + u * 0.45
			_orb.position = _bezier(_origin, ctrl, _target_pos, eased)
			var s: float = 0.30 + eased * 0.15
			_orb.scale = Vector2(s, s),
		0.0, 1.0, dur
	)

	_spawn_trail(ctrl, dur)

# ── Trail ──────────────────────────────────────────────────────────────────────

func _spawn_trail(ctrl: Vector2, flight_dur: float) -> void:
	var interval := flight_dur / float(_NUM_TRAIL)
	for i in _NUM_TRAIL:
		var delay := float(i) * interval
		get_tree().create_timer(delay, false).timeout.connect(func() -> void:
			var u: float     = clamp(delay / flight_dur, 0.0, 0.999)
			var eased: float = u * u * u * 0.55 + u * 0.45
			var pos: Vector2 = _bezier(_origin, ctrl, _target_pos, eased)

			var dot         := Sprite2D.new()
			dot.texture      = _TEX_TRAIL
			dot.position     = pos
			dot.scale        = Vector2(0.5, 0.5)
			dot.modulate     = Color(heal_color.r, heal_color.g, heal_color.b, 0.85)
			_add_mat(dot)
			_trail_layer.add_child(dot)

			var tw := create_tween().set_parallel(true)
			tw.tween_property(dot, "modulate:a", 0.0, 0.30)
			tw.tween_property(dot, "scale",      Vector2(0.15, 0.15), 0.30)
			tw.chain().tween_callback(dot.queue_free)
		)

# ── Impact (T_IMPACT) ──────────────────────────────────────────────────────────

func _trigger_impact() -> void:
	if is_instance_valid(_orb):
		_orb.modulate.a = 0.0

	# Screen flash curto
	var ft := create_tween()
	ft.tween_property(_screen_flash, "color:a", 0.30, 0.05)
	ft.tween_property(_screen_flash, "color:a", 0.0,  0.35)

	# Flash radial no alvo
	_impact_flash.modulate.a = 0.95
	var rf := create_tween().set_parallel(true)
	rf.tween_property(_impact_flash, "scale",      Vector2(1.1, 1.1), 0.45) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	rf.tween_property(_impact_flash, "modulate:a", 0.0,               0.45)

	# Ondas de choque
	for i in _NUM_SHOCKWAVE:
		get_tree().create_timer(float(i) * 0.12, false).timeout.connect(_spawn_shockwave)

	# Burst radial de partículas
	_spawn_burst_particles()

func _spawn_shockwave() -> void:
	var wave         := Sprite2D.new()
	wave.texture      = _TEX_WAVE
	wave.position     = _target_pos
	wave.scale        = Vector2(0.125, 0.125)
	wave.modulate     = Color(heal_color.r, heal_color.g, heal_color.b, 0.95)
	_add_mat(wave)
	_burst_layer.add_child(wave)

	# Raio final ~126px → scale = (126 * 2) / 256 ≈ 0.984
	var target_scale := (126.0 * 2.0) / 256.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(wave, "scale",      Vector2(target_scale, target_scale), 0.60) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(wave, "modulate:a", 0.0, 0.60)
	tw.chain().tween_callback(wave.queue_free)

func _spawn_burst_particles() -> void:
	for i in _NUM_BURST:
		var angle := float(i) / _NUM_BURST * TAU + _rng.randf() * 0.4
		var speed := 60.0 + _rng.randf() * 110.0
		var life  := 0.55 + _rng.randf() * 0.45
		var sz    := 0.5  + _rng.randf() * 0.9

		var p         := Sprite2D.new()
		p.texture      = _TEX_PART
		p.position     = _target_pos
		p.scale        = Vector2(sz * 0.09, sz * 0.09)
		p.modulate     = Color(_C_CORE.r, _C_CORE.g, _C_CORE.b, 1.0)
		_add_mat(p)
		_burst_layer.add_child(p)

		var vel := Vector2(cos(angle), sin(angle)) * speed
		var tw  := create_tween()
		tw.tween_method(
			func(u: float) -> void:
				if not is_instance_valid(p):
					return
				p.position   = _target_pos + vel * u * life + Vector2(0.0, 35.0 * u * u * life)
				p.modulate.a = clamp(1.0 - u * 1.2, 0.0, 1.0),
			0.0, 1.0, life
		)
		tw.tween_callback(p.queue_free)

# ── HP fill (easeOutCubic) ─────────────────────────────────────────────────────

func _animate_hp_fill() -> void:
	if _hp_node == null:
		return
	var tw := create_tween()
	tw.tween_interval(T_HP_FILL_START)
	tw.tween_property(_hp_node, "value", float(_end_hp), T_HP_FILL_END - T_HP_FILL_START) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ── Popup "+N / VIDA" ──────────────────────────────────────────────────────────

func _spawn_heal_popup() -> void:
	if _heal_amount <= 0:
		return
	get_tree().create_timer(T_POP_START, false).timeout.connect(func() -> void:
		var container          := VBoxContainer.new()
		container.alignment     = BoxContainer.ALIGNMENT_CENTER
		container.position      = _target_pos + Vector2(-30.0, -90.0)
		container.modulate.a    = 0.0
		container.scale         = Vector2(0.5, 0.5)
		_popup_layer.add_child(container)

		var amount_lbl := Label.new()
		amount_lbl.text = "+%d" % _heal_amount
		amount_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amount_lbl.add_theme_font_size_override("font_size", 38)
		amount_lbl.add_theme_color_override("font_color", _C_CORE)
		amount_lbl.add_theme_color_override("font_shadow_color", Color(0.051, 0.125, 0.078))
		amount_lbl.add_theme_constant_override("shadow_offset_x",    0)
		amount_lbl.add_theme_constant_override("shadow_offset_y",    2)
		amount_lbl.add_theme_constant_override("shadow_outline_size", 12)
		container.add_child(amount_lbl)

		var vida_lbl := Label.new()
		vida_lbl.text = "VIDA"
		vida_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vida_lbl.add_theme_font_size_override("font_size", 12)
		vida_lbl.add_theme_color_override("font_color", _C_BRIGHT)
		container.add_child(vida_lbl)

		var dur := T_POP_END - T_POP_START
		var tw  := create_tween().set_parallel(true)
		tw.tween_property(container, "modulate:a", 1.0, 0.15)
		tw.tween_property(container, "scale", Vector2(1.2, 1.2), 0.30) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(container, "scale", Vector2(1.0, 1.0), 0.20) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(container, "position:y", container.position.y - 56.0, dur) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(container, "modulate:a", 0.0, dur * 0.30).set_delay(dur * 0.70)
		tw.chain().tween_callback(container.queue_free)
	)

# ── 4 cruzes flutuantes ao redor do alvo ──────────────────────────────────────

func _spawn_floating_crosses() -> void:
	for i in 4:
		var phase_offset := float(i) * TAU * 0.25
		var cr           := Sprite2D.new()
		cr.texture        = _TEX_CROSS
		cr.scale          = Vector2(0.5, 0.5)
		cr.modulate       = Color(heal_color.r, heal_color.g, heal_color.b, 0.0)
		_add_mat(cr)
		_float_layer.add_child(cr)

		var dur := 1.5
		var tw  := create_tween()
		tw.tween_method(
			func(u: float) -> void:
				if not is_instance_valid(cr):
					return
				var drift: float = u * 28.0 * 1.5
				cr.position   = _target_pos + Vector2(
					cos(u * 1.8 + phase_offset) * 24.0,
					-8.0 - drift + sin(u * 1.8 + phase_offset) * 5.0
				)
				cr.modulate.a = clamp(1.0 - u, 0.0, 1.0) * 0.85
				var sc: float = 0.5 + min(u * 2.5, 1.0) * 0.6
				cr.scale      = Vector2(sc, sc),
			0.0, 1.0, dur
		)
		tw.tween_callback(cr.queue_free)

# ── Fim ────────────────────────────────────────────────────────────────────────

func _on_finished() -> void:
	finished.emit()
	queue_free()
