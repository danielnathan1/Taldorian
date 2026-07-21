## scenes/vfx/abyss_curse/abyss_curse.gd
## VFX autocontido da especial "Maldição do Abismo" da Lilith. Encena, em fases:
##   1) um VÓRTICE abissal se forma no centro enquanto vários símbolos de Trevas surgem da
##      Lilith e ESPIRALAM (com rastro) até ele;
##   2) IMPACTO em camadas — flash + anéis de choque + explosão de fumaça e estilhaços;
##   3) uma NÉVOA densa (com rastro) escorre do centro até o deck do oponente → `mist_arrived`
##      (o board dispara os banimentos 1 a 1 a partir daí);
##   4) a névoa assenta no deck e some → `finished`.
## Um leve escurecimento (vinheta) acompanha o conjuro. Puramente cosmético.
##
## Uso:
##   var fx := AbyssCurseScene.instantiate(); add_child(fx)
##   fx.mist_arrived.connect(...); fx.play(caster_pos, center_pos, deck_pos)
class_name AbyssCurse
extends CanvasLayer

# ── Assets (símbolo de Trevas + radiais reaproveitados, tingidos em violeta) ────
const _TEX_DARK  := preload("res://assets/icons/elements/dark.png")
const _TEX_GLOW  := preload("res://scenes/vfx/magic_missiles/charge_glow.png")
const _TEX_ORB   := preload("res://scenes/vfx/magic_missiles/charge_orb.png")
const _TEX_BURST := preload("res://scenes/vfx/magic_missiles/impact_burst.png")
const _TEX_FLASH := preload("res://scenes/vfx/magic_missiles/impact_flash.png")
const _TEX_TRAIL := preload("res://scenes/vfx/magic_missiles/missile_trail.png")
const _TEX_SMOKE := preload("res://scenes/vfx/magic_missiles/spark_particle.png")

# ── Paleta abissal (violeta sombrio) ───────────────────────────────────────────
const _C_GLOW := Color(0.42, 0.16, 0.55)
const _C_DARK := Color(0.62, 0.30, 0.82)   # tint dos símbolos (mantém visível)
const _C_MIST := Color(0.30, 0.12, 0.42)
const _C_CORE := Color(0.10, 0.04, 0.16)
const _C_VOID := Color(0.06, 0.02, 0.10)   # vinheta / vórtice

# ── Timeline (segundos) — animação de ~3s até a névoa chegar ────────────────────
const T_CONVERGE := 1.8    # símbolos espiralam da Lilith até o vórtice central
const T_MIST     := 1.2    # névoa viaja do centro até o deck
const N_SYMBOLS  := 10

## Emitido quando a névoa chega ao deck do oponente — o board dispara os banimentos aqui.
signal mist_arrived
## Emitido quando toda a animação termina. O nó se auto-destrói em seguida.
signal finished

var _caster: Vector2
var _center: Vector2
var _deck: Vector2
var _vignette:     ColorRect
var _vortex_layer: Node2D
var _sym_layer:    Node2D
var _impact_layer: Node2D
var _mist_layer:   Node2D
var _vortex_root:  Node2D

func _ready() -> void:
	layer = 50

# ── API pública ────────────────────────────────────────────────────────────────

func play(caster_pos: Vector2, center_pos: Vector2, deck_pos: Vector2) -> void:
	_caster = caster_pos
	_center = center_pos
	_deck   = deck_pos
	_build_vignette()
	_vortex_layer = _make_layer(11)
	_sym_layer    = _make_layer(12)
	_mist_layer   = _make_layer(13)
	_impact_layer = _make_layer(14)
	_run()

func _make_layer(z: int) -> Node2D:
	var n := Node2D.new()
	n.z_index = z
	add_child(n)
	return n

func _add_mat(node: CanvasItem) -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	node.material = mat

func _ease_out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)

# ── Vinheta: leve escurecimento da tela durante o conjuro ────────────────────────

func _build_vignette() -> void:
	_vignette = ColorRect.new()
	_vignette.color = Color(_C_VOID.r, _C_VOID.g, _C_VOID.b, 0.0)
	_vignette.size  = get_viewport().get_visible_rect().size
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.z_index = -1
	add_child(_vignette)
	var tw := create_tween()
	tw.tween_property(_vignette, "color:a", 0.34, T_CONVERGE * 0.8).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.2)
	tw.tween_property(_vignette, "color:a", 0.0, T_MIST + 0.5).set_ease(Tween.EASE_OUT)

# ── Orquestração ─────────────────────────────────────────────────────────────────

func _run() -> void:
	_create_vortex()
	for i in N_SYMBOLS:
		_spawn_symbol(i)
	# Ao fim da convergência: impacto no centro, depois a névoa viaja ao deck.
	get_tree().create_timer(T_CONVERGE, false).timeout.connect(_on_converged)

# Vórtice que se forma no centro e cresce/gira conforme os símbolos chegam.
func _create_vortex() -> void:
	_vortex_root = Node2D.new()
	_vortex_root.position = _center
	_vortex_layer.add_child(_vortex_root)

	var halo := Sprite2D.new()
	halo.texture  = _TEX_GLOW
	halo.scale    = Vector2(0.1, 0.1)
	halo.modulate = Color(_C_GLOW.r, _C_GLOW.g, _C_GLOW.b, 0.0)
	_add_mat(halo)
	_vortex_root.add_child(halo)

	var core := Sprite2D.new()
	core.texture  = _TEX_ORB
	core.scale    = Vector2(0.05, 0.05)
	core.modulate = Color(_C_CORE.r, _C_CORE.g, _C_CORE.b, 0.0)
	_vortex_root.add_child(core)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(halo, "scale", Vector2(1.0, 1.0), T_CONVERGE).set_ease(Tween.EASE_IN)
	tw.tween_property(halo, "modulate:a", 0.8, T_CONVERGE).set_ease(Tween.EASE_IN)
	tw.tween_property(core, "scale", Vector2(0.55, 0.55), T_CONVERGE).set_ease(Tween.EASE_IN)
	tw.tween_property(core, "modulate:a", 0.95, T_CONVERGE).set_ease(Tween.EASE_IN)
	# Giro contínuo do vórtice.
	var spin := create_tween().set_loops()
	spin.tween_property(_vortex_root, "rotation", TAU, 2.4).from(0.0)

func _symbol_pos(phase: float, t: float) -> Vector2:
	var e := _ease_out_cubic(t)
	var ang: float = phase + t * TAU * 1.9              # ~1.9 voltas orbitando
	var rad: float = (1.0 - e) * 92.0                   # espiral fechando no centro
	var base := _caster.lerp(_center, e)
	return base + Vector2(cos(ang), sin(ang)) * rad

func _spawn_symbol(idx: int) -> void:
	var phase: float = float(idx) * TAU / float(N_SYMBOLS)

	var sym := Node2D.new()
	_sym_layer.add_child(sym)

	# Halo violeta aditivo atrás do símbolo.
	var halo := Sprite2D.new()
	halo.texture  = _TEX_GLOW
	halo.scale    = Vector2(0.32, 0.32)
	halo.modulate = Color(_C_GLOW.r, _C_GLOW.g, _C_GLOW.b, 0.0)
	_add_mat(halo)
	sym.add_child(halo)

	# O símbolo de Trevas (blend normal — é escuro).
	var glyph := Sprite2D.new()
	glyph.texture  = _TEX_DARK
	glyph.modulate = Color(_C_DARK.r, _C_DARK.g, _C_DARK.b, 0.0)
	var base_scale := 30.0 / maxf(1.0, float(_TEX_DARK.get_width()))
	glyph.scale = Vector2(base_scale, base_scale)
	sym.add_child(glyph)

	# Rastro violeta que sampleia a espiral atrás do símbolo.
	var trail := Line2D.new()
	trail.width        = 5.0
	trail.joint_mode   = Line2D.LINE_JOINT_ROUND
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode   = Line2D.LINE_CAP_ROUND
	trail.texture      = _TEX_TRAIL
	trail.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	_add_mat(trail)
	var grad := Gradient.new()
	grad.set_color(0, Color(_C_GLOW.r, _C_GLOW.g, _C_GLOW.b, 0.0))
	grad.set_color(1, Color(_C_GLOW.r, _C_GLOW.g, _C_GLOW.b, 0.5))
	trail.gradient = grad
	_sym_layer.add_child(trail)

	var steps := 12
	var span  := 0.16

	var tw := create_tween()
	tw.tween_method(
		func(t: float) -> void:
			if not is_instance_valid(sym):
				return
			sym.position = _symbol_pos(phase, t)
			var ang: float = phase + t * TAU * 1.9
			glyph.rotation = ang
			var a: float = clampf(sin(t * PI) * 0.95 + 0.1, 0.0, 1.0)
			glyph.modulate.a = a
			halo.modulate.a  = a * 0.85
			if is_instance_valid(trail):
				var pts := PackedVector2Array()
				for i in range(steps, -1, -1):
					var tt: float = t - (float(i) / float(steps)) * span
					if tt < 0.0:
						continue
					pts.append(_symbol_pos(phase, tt))
				trail.points = pts
				trail.modulate.a = a,
		0.0, 1.0, T_CONVERGE
	)
	tw.tween_callback(func() -> void:
		sym.queue_free()
		if is_instance_valid(trail):
			var tt := create_tween()
			tt.tween_property(trail, "modulate:a", 0.0, 0.2)
			tt.tween_callback(trail.queue_free)
	)

# ── Impacto em camadas no centro ─────────────────────────────────────────────────

func _on_converged() -> void:
	# Colapso do vórtice (flare + some).
	if is_instance_valid(_vortex_root):
		var vt := create_tween().set_parallel(true)
		vt.tween_property(_vortex_root, "scale", Vector2(1.6, 1.6), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		vt.tween_property(_vortex_root, "modulate:a", 0.0, 0.5)
		vt.chain().tween_callback(_vortex_root.queue_free)

	# Flash central intenso.
	var flash := Sprite2D.new()
	flash.texture  = _TEX_FLASH
	flash.position = _center
	flash.scale    = Vector2(0.35, 0.35)
	flash.modulate = Color(0.88, 0.72, 1.0, 1.0)
	_add_mat(flash)
	_impact_layer.add_child(flash)
	var ft := create_tween().set_parallel(true)
	ft.tween_property(flash, "scale", Vector2(0.9, 0.9), 0.28)
	ft.tween_property(flash, "modulate:a", 0.0, 0.28)
	ft.chain().tween_callback(flash.queue_free)

	# Anéis de choque abissais em cascata.
	for k in 3:
		var delay := float(k) * 0.12
		get_tree().create_timer(delay, false).timeout.connect(_spawn_shock_ring)

	# Explosão de fumaça densa.
	var burst := CPUParticles2D.new()
	burst.position             = _center
	burst.texture              = _TEX_SMOKE
	burst.amount               = 26
	burst.lifetime             = 0.9
	burst.one_shot             = true
	burst.explosiveness        = 0.9
	burst.spread               = 180.0
	burst.initial_velocity_min = 50.0
	burst.initial_velocity_max = 150.0
	burst.scale_amount_min     = 0.35
	burst.scale_amount_max     = 0.85
	burst.color                = Color(_C_MIST.r, _C_MIST.g, _C_MIST.b, 0.85)
	burst.emitting             = true
	_impact_layer.add_child(burst)
	get_tree().create_timer(1.2, false).timeout.connect(burst.queue_free)

	# Após um respiro dramático, a névoa parte rumo ao deck.
	get_tree().create_timer(0.3, false).timeout.connect(_spawn_mist_to_deck)

func _spawn_shock_ring() -> void:
	var ring := Sprite2D.new()
	ring.texture  = _TEX_BURST
	ring.position = _center
	ring.scale    = Vector2(0.10, 0.10)
	ring.modulate = _C_GLOW
	_add_mat(ring)
	_impact_layer.add_child(ring)
	var rt := create_tween().set_parallel(true)
	rt.tween_property(ring, "scale", Vector2(1.25, 1.25), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rt.tween_property(ring, "modulate:a", 0.0, 0.6)
	rt.chain().tween_callback(ring.queue_free)

# ── Névoa do centro até o deck do oponente ───────────────────────────────────────

func _spawn_mist_to_deck() -> void:
	var mist := Node2D.new()
	mist.position = _center
	_mist_layer.add_child(mist)

	var halo := Sprite2D.new()
	halo.texture  = _TEX_GLOW
	halo.scale    = Vector2(0.7, 0.7)
	halo.modulate = Color(_C_GLOW.r, _C_GLOW.g, _C_GLOW.b, 0.85)
	_add_mat(halo)
	mist.add_child(halo)

	var core := Sprite2D.new()
	core.texture  = _TEX_ORB
	core.scale    = Vector2(0.35, 0.35)
	core.modulate = Color(_C_CORE.r, _C_CORE.g, _C_CORE.b, 0.9)
	mist.add_child(core)

	var smoke := CPUParticles2D.new()
	smoke.texture              = _TEX_SMOKE
	smoke.amount               = 34
	smoke.lifetime             = 0.9
	smoke.local_coords         = false
	smoke.spread               = 55.0
	smoke.direction            = Vector2(0.0, -1.0)
	smoke.gravity              = Vector2(0.0, -16.0)
	smoke.initial_velocity_min = 14.0
	smoke.initial_velocity_max = 48.0
	smoke.scale_amount_min     = 0.35
	smoke.scale_amount_max     = 0.7
	smoke.color                = Color(_C_MIST.r, _C_MIST.g, _C_MIST.b, 0.6)
	smoke.emitting             = true
	mist.add_child(smoke)

	# Rastro da névoa (centro → deck).
	var trail := Line2D.new()
	trail.width        = 12.0
	trail.joint_mode   = Line2D.LINE_JOINT_ROUND
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode   = Line2D.LINE_CAP_ROUND
	trail.texture      = _TEX_TRAIL
	trail.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	_add_mat(trail)
	var grad := Gradient.new()
	grad.set_color(0, Color(_C_MIST.r, _C_MIST.g, _C_MIST.b, 0.0))
	grad.set_color(1, Color(_C_GLOW.r, _C_GLOW.g, _C_GLOW.b, 0.5))
	trail.gradient = grad
	_mist_layer.add_child(trail)

	var fly := create_tween()
	fly.tween_method(
		func(t: float) -> void:
			var e := _ease_out_cubic(t)
			var pos := _center.lerp(_deck, e)
			if is_instance_valid(mist):
				mist.position = pos
			if is_instance_valid(trail):
				trail.points = PackedVector2Array([_center, _center.lerp(pos, 0.5), pos]),
		0.0, 1.0, T_MIST
	)
	fly.tween_callback(func() -> void:
		if is_instance_valid(smoke):
			smoke.emitting = false
		if is_instance_valid(mist):
			mist.queue_free()
		if is_instance_valid(trail):
			var tt := create_tween()
			tt.tween_property(trail, "modulate:a", 0.0, 0.3)
			tt.tween_callback(trail.queue_free)
		mist_arrived.emit()      # o board começa a banir as cartas 1 a 1
		_deck_puff()
		get_tree().create_timer(0.7, false).timeout.connect(_on_finished)
	)

func _deck_puff() -> void:
	var puff := CPUParticles2D.new()
	puff.position             = _deck
	puff.texture              = _TEX_SMOKE
	puff.amount               = 16
	puff.lifetime             = 1.0
	puff.one_shot             = true
	puff.explosiveness        = 0.85
	puff.spread               = 180.0
	puff.direction            = Vector2(0.0, -1.0)
	puff.gravity              = Vector2(0.0, -28.0)
	puff.initial_velocity_min = 22.0
	puff.initial_velocity_max = 70.0
	puff.scale_amount_min     = 0.3
	puff.scale_amount_max     = 0.7
	puff.color                = Color(_C_MIST.r, _C_MIST.g, _C_MIST.b, 0.7)
	puff.emitting             = true
	_mist_layer.add_child(puff)
	get_tree().create_timer(1.2, false).timeout.connect(puff.queue_free)

func _on_finished() -> void:
	finished.emit()
	queue_free()
