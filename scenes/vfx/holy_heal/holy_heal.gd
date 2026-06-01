## scenes/vfx/holy_heal/holy_heal.gd
## VFX autocontido da habilidade passiva "Crescimento Natural" de Irena.
## Uso:
##   var fx := HolyHealScene.instantiate()
##   add_child(fx)
##   fx.finished.connect(callback)
##   fx.play(source_global_pos, ally_zone_rect, ally_positions)
class_name HolyHeal
extends CanvasLayer

# ── Assets ───────────────────────────────────────────────────────────────────
const _TEX_PARTICLE := preload("res://scenes/vfx/holy_heal/heal_particle.png")
const _TEX_WAVE     := preload("res://scenes/vfx/holy_heal/heal_wave.png")
const _TEX_PULSE    := preload("res://scenes/vfx/holy_heal/ally_pulse.png")
const _TEX_FLASH    := preload("res://scenes/vfx/holy_heal/landing_flash.png")
const _TEX_CROSS    := preload("res://scenes/vfx/holy_heal/heal_cross.png")
const _TEX_GLOW     := preload("res://scenes/vfx/holy_heal/charge_glow.png")
const _TEX_AURA     := preload("res://scenes/vfx/holy_heal/ally_aura.png")
const _TEX_CORNER   := preload("res://scenes/vfx/holy_heal/ally_corner.png")
const _TEX_BEAM     := preload("res://scenes/vfx/holy_heal/light_beam.png")

# ── Timeline (em segundos — espelhado do Holy Heal.html) ─────────────────────
const T_CHARGE_END     : float = 1.1
const T_BANNER_IN      : float = 0.2
const T_BANNER_OUT     : float = 3.0
const T_ZONE_IN        : float = 0.55
const T_ZONE_OUT       : float = 4.0
const T_WAVE_START     : float = 1.1
const T_PARTICLE_START : float = 1.15
const T_PARTICLE_END   : float = 3.0
const T_PARTICLE_FLIGHT: float = 0.9
const T_HOLD_END       : float = 5.2
const NUM_PARTICLES    : int   = 60
const NUM_WAVES        : int   = 3
const WAVE_INTERVAL    : float = 0.35
const WAVE_DURATION    : float = 1.4
const WAVE_MAX_RADIUS  : float = 520.0

## Emitido quando toda a animação encerra. O nó se auto-destrói logo em seguida.
signal finished

@export var ability_name: String     = "BÊNÇÃO DOS ANCESTRAIS"
@export var ability_subtitle: String = "Habilidade Definitiva"

var _source: Vector2
var _ally_zone: Rect2
var _allies: Array = []   # Array[Dictionary{pos: Vector2}]
var _rng := RandomNumberGenerator.new()

# Camadas organizacionais
var _waves_layer:     Node2D
var _particles_layer: Node2D
var _impacts_layer:   Node2D
var _popups_layer:    Node2D

# Label de status no banner (trocada em T_CHARGE_END)
var _status_label: Label = null

# Rastreia se cada aliado já recebeu pulso + popup (dispara só uma vez por aliado)
var _ally_pulse_done: Array[bool] = []

func _ready() -> void:
	layer = 50

# ── API pública ───────────────────────────────────────────────────────────────

## Inicia a animação completa.
## source_pos — posição global de Irena (centro da carta ativa).
## ally_zone  — Rect2 global da área dos aliados.
## allies     — Array[Dictionary{pos: Vector2}] — posições dos aliados a curar.
func play(source_pos: Vector2, ally_zone: Rect2, allies: Array = []) -> void:
	_source    = source_pos
	_ally_zone = ally_zone
	_allies    = allies if not allies.is_empty() else [{ "pos": source_pos }]
	_ally_pulse_done.resize(_allies.size())
	_ally_pulse_done.fill(false)
	_rng.seed  = 13  # mesma semente do HTML → trajetórias consistentes

	var trajectories: Array = _precompute_trajectories()

	_waves_layer     = Node2D.new()
	_particles_layer = Node2D.new()
	_impacts_layer   = Node2D.new()
	_popups_layer    = Node2D.new()
	add_child(_waves_layer)
	add_child(_particles_layer)
	add_child(_impacts_layer)
	add_child(_popups_layer)

	_animate(trajectories)

# ── Pré-computa trajetórias bezier (ordem de rng idêntica ao HTML) ────────────

func _precompute_trajectories() -> Array:
	var list: Array = []
	for i in NUM_PARTICLES:
		var launch_t: float = T_PARTICLE_START \
			+ (T_PARTICLE_END - T_PARTICLE_START) * float(i) / float(NUM_PARTICLES - 1)
		var ally_idx: int    = i % _allies.size()
		var ally_pos: Vector2 = _allies[ally_idx].get("pos", _source)
		# ponto alvo espalhado ao redor do centro da carta do aliado
		var tx: float = ally_pos.x + (_rng.randf() - 0.5) * 50.0
		var ty: float = ally_pos.y + (_rng.randf() - 0.5) * 80.0
		# origem ligeiramente deslocada do topo do healer
		var sx: float = _source.x + (_rng.randf() - 0.5) * 40.0
		var sy: float = _source.y - 30.0 + (_rng.randf() - 0.5) * 20.0
		# arco para cima — ponto de controle acima do meio
		var mid_x: float  = (sx + tx) / 2.0
		var peak_y: float = min(sy, ty) - 80.0 - _rng.randf() * 90.0
		var ctrl_x: float = mid_x + (_rng.randf() - 0.5) * 60.0
		var wobble: float = (_rng.randf() - 0.5) * 1.5
		list.append({
			"launch_t": launch_t,
			"ally_idx": ally_idx,
			"p0": Vector2(sx, sy),
			"p1": Vector2(ctrl_x, peak_y),
			"p2": Vector2(tx, ty),
			"wobble": wobble,
			"seed_id": i,
		})
	return list

# ── Orquestração principal ────────────────────────────────────────────────────

func _animate(trajectories: Array) -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var center  := vp_size * 0.5

	_create_charge_glow()
	_create_light_beam()
	_create_banner(center)
	_create_ally_zone()
	_create_screen_flash(vp_size)

	# Ondas concêntricas a partir da Irena
	for i in NUM_WAVES:
		var wave_start: float = T_WAVE_START + i * WAVE_INTERVAL
		get_tree().create_timer(wave_start).timeout.connect(_spawn_wave)

	# Partículas de cura distribuídas entre os aliados
	for data in trajectories:
		get_tree().create_timer(data["launch_t"]).timeout.connect(_spawn_particle.bind(data))

	get_tree().create_timer(T_HOLD_END).timeout.connect(_on_finished)

# ── Glow de carga ao redor da carta da Irena ─────────────────────────────────

func _create_charge_glow() -> void:
	var glow := Sprite2D.new()
	glow.texture  = _TEX_GLOW
	glow.position = _source
	glow.modulate = Color(0.50, 1.00, 0.55, 0.0)
	glow.scale    = Vector2(0.12, 0.12)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material  = mat
	add_child(glow)

	var tw := create_tween().set_parallel(true)
	# Cresce e acende até T_CHARGE_END
	tw.tween_property(glow, "modulate:a", 0.90, T_CHARGE_END) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(glow, "scale", Vector2(0.42, 0.42), T_CHARGE_END) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Pulsa enquanto canaliza (sobe/desce suave)
	tw.tween_property(glow, "scale", Vector2(0.50, 0.50), 0.35) \
		.set_delay(T_CHARGE_END).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(glow, "scale", Vector2(0.40, 0.40), 0.35) \
		.set_delay(T_CHARGE_END + 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Fade-out após emissão das partículas
	tw.tween_property(glow, "modulate:a", 0.0, 0.50).set_delay(T_PARTICLE_END)
	tw.chain().tween_callback(glow.queue_free)

# ── Feixe de luz vertical (canalização) ──────────────────────────────────────

func _create_light_beam() -> void:
	var beam := Sprite2D.new()
	beam.texture  = _TEX_BEAM
	beam.position = _source - Vector2(0.0, 80.0)
	beam.scale    = Vector2(1.0, 0.4)
	beam.modulate = Color(0.55, 1.00, 0.65, 0.0)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	beam.material  = mat
	add_child(beam)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(beam, "modulate:a", 0.80, 0.30).set_delay(T_CHARGE_END)
	tw.tween_property(beam, "scale:y",    1.0,  0.50).set_delay(T_CHARGE_END) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(beam, "modulate:a", 0.0,  0.40).set_delay(T_PARTICLE_END)
	tw.chain().tween_callback(beam.queue_free)

# ── Banner central ────────────────────────────────────────────────────────────

func _create_banner(center: Vector2) -> void:
	var root := Node2D.new()
	root.position   = center - Vector2(0.0, 22.0)
	root.modulate.a = 0.0
	add_child(root)

	var sub := Label.new()
	sub.text = ability_subtitle
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.78, 0.95, 0.78))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position             = Vector2(-200.0, -72.0)
	sub.custom_minimum_size  = Vector2(400.0, 20.0)
	root.add_child(sub)

	var title := Label.new()
	title.text = ability_name
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color",        Color(0.91, 0.98, 0.88))
	title.add_theme_color_override("font_shadow_color", Color(0.48, 0.87, 0.63, 0.85))
	title.add_theme_constant_override("shadow_offset_x",  0)
	title.add_theme_constant_override("shadow_offset_y",  3)
	title.add_theme_constant_override("shadow_outline_size", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position             = Vector2(-200.0, -44.0)
	title.custom_minimum_size  = Vector2(400.0, 52.0)
	root.add_child(title)

	var rule := ColorRect.new()
	rule.color    = Color(0.48, 0.87, 0.63, 0.70)
	rule.size     = Vector2(280.0, 1.0)
	rule.position = Vector2(-140.0, 13.0)
	root.add_child(rule)

	_status_label = Label.new()
	_status_label.text = "Canalizando energia"
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.78, 0.95, 0.78, 0.85))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.position             = Vector2(-200.0, 20.0)
	_status_label.custom_minimum_size  = Vector2(400.0, 18.0)
	root.add_child(_status_label)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(root, "modulate:a", 1.0, 0.35).set_delay(T_BANNER_IN)
	tw.tween_property(root, "modulate:a", 0.0, 0.45).set_delay(T_BANNER_OUT - 0.45)
	tw.chain().tween_callback(root.queue_free)

	get_tree().create_timer(T_CHARGE_END).timeout.connect(func() -> void:
		if is_instance_valid(_status_label):
			_status_label.text = "Cura em onda"
	)

# ── Zona aliada (aura radial + cantos em L) ───────────────────────────────────

func _create_ally_zone() -> void:
	var center := _ally_zone.get_center()

	var aura := Sprite2D.new()
	aura.texture  = _TEX_AURA
	aura.position = center
	aura.scale    = Vector2(_ally_zone.size.x / 512.0, _ally_zone.size.y / 256.0)
	aura.modulate = Color(0.55, 1.00, 0.65, 0.0)
	add_child(aura)

	var corner_defs := [
		{ "pos": _ally_zone.position,                                                               "rot": 0.0       },
		{ "pos": Vector2(_ally_zone.position.x + _ally_zone.size.x, _ally_zone.position.y),        "rot": PI * 0.5  },
		{ "pos": _ally_zone.position + _ally_zone.size,                                             "rot": PI        },
		{ "pos": Vector2(_ally_zone.position.x, _ally_zone.position.y + _ally_zone.size.y),        "rot": -PI * 0.5 },
	]
	var corner_nodes: Array[Sprite2D] = []
	for cd in corner_defs:
		var sp := Sprite2D.new()
		sp.texture  = _TEX_CORNER
		sp.position = cd["pos"]
		sp.rotation = cd["rot"]
		sp.scale    = Vector2(0.16, 0.16)
		sp.modulate = Color(0.55, 1.00, 0.65, 0.0)
		add_child(sp)
		corner_nodes.append(sp)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(aura, "modulate:a", 1.0, 0.50).set_delay(T_ZONE_IN)
	for sp in corner_nodes:
		tw.tween_property(sp, "modulate:a", 1.0, 0.50).set_delay(T_ZONE_IN)
	tw.tween_property(aura, "modulate:a", 0.0, 0.55).set_delay(T_ZONE_OUT - 0.55)
	for sp in corner_nodes:
		tw.tween_property(sp, "modulate:a", 0.0, 0.55).set_delay(T_ZONE_OUT - 0.55)
	tw.chain().tween_callback(func() -> void:
		aura.queue_free()
		for sp in corner_nodes:
			sp.queue_free()
	)

# ── Flash verde suave de tela ao liberar a cura ───────────────────────────────

func _create_screen_flash(vp_size: Vector2) -> void:
	var flash := ColorRect.new()
	flash.color        = Color(0.85, 0.98, 0.87, 0.0)
	flash.size         = vp_size
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)

	var tw := create_tween()
	tw.tween_interval(T_CHARGE_END - 0.05)
	tw.tween_property(flash, "color:a", 0.30, 0.05)
	tw.tween_property(flash, "color:a", 0.0,  0.35)
	tw.tween_callback(flash.queue_free)

# ── Onda concêntrica verde expandindo a partir da Irena ───────────────────────

func _spawn_wave() -> void:
	var wave := Sprite2D.new()
	wave.texture  = _TEX_WAVE
	wave.position = _source - Vector2(0.0, 8.0)
	# Textura 256×256 → raio efetivo = 128px por unidade de escala
	# Escala inicial para raio ≈ 30px = 0.23
	wave.scale    = Vector2(0.23, 0.23)
	wave.modulate = Color(0.55, 1.00, 0.70, 0.75)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	wave.material  = mat
	_waves_layer.add_child(wave)

	# target_scale: raio 520px → scale = (520 * 2) / 256 ≈ 4.06
	var target_scale: float = (WAVE_MAX_RADIUS * 2.0) / 256.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(wave, "scale",      Vector2(target_scale, target_scale), WAVE_DURATION) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(wave, "modulate:a", 0.0,                                WAVE_DURATION) \
		.set_trans(Tween.TRANS_LINEAR)
	tw.chain().tween_callback(wave.queue_free)

# ── Spawn de uma partícula de cura em voo ─────────────────────────────────────

func _spawn_particle(data: Dictionary) -> void:
	var p0: Vector2   = data["p0"]
	var p1: Vector2   = data["p1"]
	var p2: Vector2   = data["p2"]
	var ally_idx: int = data["ally_idx"]
	var wobble: float = data["wobble"]
	var seed_id: int  = data["seed_id"]

	var p := Sprite2D.new()
	p.texture  = _TEX_PARTICLE
	p.scale    = Vector2(0.35, 0.35)
	p.z_index  = 10
	p.modulate = Color(0.75, 1.00, 0.80, 0.0)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material     = mat
	_particles_layer.add_child(p)

	var on_tick := func(u: float) -> void:
		if not is_instance_valid(p):
			return
		var pos := _bezier(p0, p1, p2, u)
		pos.x += sin(u * 8.0 + seed_id) * wobble * (1.0 - u)
		p.position = pos
		var op: float = 1.0
		if u < 0.1:
			op = u / 0.1
		elif u > 0.85:
			op = (1.0 - u) / 0.15
		p.modulate.a = op

	var tw := create_tween()
	tw.tween_method(on_tick, 0.0, 1.0, T_PARTICLE_FLIGHT) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		p.queue_free()
		_on_particle_landed(ally_idx, p2)
	)

# ── Impacto da partícula no aliado ────────────────────────────────────────────

func _on_particle_landed(ally_idx: int, pos: Vector2) -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	# Flash brilhante no ponto de impacto
	var flash := Sprite2D.new()
	flash.texture  = _TEX_FLASH
	flash.position = pos
	flash.scale    = Vector2(0.30, 0.30)
	flash.z_index  = 11
	flash.material = mat
	_impacts_layer.add_child(flash)

	var ft := create_tween().set_parallel(true)
	ft.tween_property(flash, "scale",      Vector2(0.85, 0.85), 0.25)
	ft.tween_property(flash, "modulate:a", 0.0,                 0.25)
	ft.chain().tween_callback(flash.queue_free)

	# Pulso + crosses + popup apenas na primeira partícula por aliado
	if ally_idx >= 0 and ally_idx < _ally_pulse_done.size() \
			and not _ally_pulse_done[ally_idx]:
		_ally_pulse_done[ally_idx] = true
		var ally_pos: Vector2 = _allies[ally_idx].get("pos", pos)
		_spawn_ally_pulse(ally_pos, mat.duplicate() as CanvasItemMaterial)
		_spawn_floating_crosses(ally_pos)
		_spawn_heal_popup(ally_pos)

# ── Pulso de anel ao redor do aliado curado ───────────────────────────────────

func _spawn_ally_pulse(at: Vector2, mat: CanvasItemMaterial) -> void:
	var pulse := Sprite2D.new()
	pulse.texture  = _TEX_PULSE
	pulse.position = at
	pulse.scale    = Vector2(0.17, 0.17)
	pulse.modulate = Color(0.65, 1.00, 0.75, 1.0)
	pulse.z_index  = 6
	pulse.material = mat
	_impacts_layer.add_child(pulse)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(pulse, "scale",      Vector2(0.55, 0.55), 1.0) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(pulse, "modulate:a", 0.0,                 1.0) \
		.set_trans(Tween.TRANS_LINEAR)
	tw.chain().tween_callback(pulse.queue_free)

# ── 3 cruzes flutuantes que sobem ao redor do aliado ─────────────────────────

func _spawn_floating_crosses(at: Vector2) -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	for i in 3:
		var cr := Sprite2D.new()
		cr.texture  = _TEX_CROSS
		cr.position = at + Vector2(cos(float(i) * TAU / 3.0) * 22.0, -12.0)
		cr.scale    = Vector2(0.50, 0.50)
		cr.z_index  = 12
		cr.material = mat.duplicate() as CanvasItemMaterial
		cr.modulate = Color(0.75, 1.00, 0.80, 1.0)
		_impacts_layer.add_child(cr)

		var phase: float    = float(i) * TAU / 3.0
		var base_pos: Vector2 = at

		var on_drift := func(u: float) -> void:
			if not is_instance_valid(cr):
				return
			cr.position = base_pos + Vector2(
				cos(u * 4.0 + phase) * 22.0,
				-12.0 - u * 36.0 + sin(u * 6.0 + phase) * 6.0
			)

		var tw := create_tween().set_parallel(true)
		tw.tween_method(on_drift, 0.0, 1.0, 1.4)
		tw.tween_property(cr, "scale",      Vector2(1.10, 1.10), 0.30)
		tw.tween_property(cr, "scale",      Vector2(0.85, 0.85), 1.10).set_delay(0.30)
		tw.tween_property(cr, "modulate:a", 0.0,                 0.60).set_delay(0.80)
		tw.chain().tween_callback(cr.queue_free)

# ── Popup "+1" subindo acima do aliado ────────────────────────────────────────

func _spawn_heal_popup(at: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = "+1"
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color",        Color(0.86, 1.00, 0.86))
	lbl.add_theme_color_override("font_shadow_color", Color(0.18, 0.55, 0.30, 0.80))
	lbl.add_theme_constant_override("shadow_offset_x",   0)
	lbl.add_theme_constant_override("shadow_offset_y",   2)
	lbl.add_theme_constant_override("shadow_outline_size", 4)
	lbl.position = at + Vector2(-14.0, -30.0)
	_popups_layer.add_child(lbl)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 44.0, 1.2)
	tw.tween_property(lbl, "modulate:a", 0.0,                   0.85).set_delay(0.25)
	tw.chain().tween_callback(lbl.queue_free)

# ── Bezier quadrático (espelhado do HTML) ─────────────────────────────────────

func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2

# ─────────────────────────────────────────────────────────────────────────────

func _on_finished() -> void:
	finished.emit()
	queue_free()
