## scenes/vfx/arrow_rain/arrow_rain.gd
## VFX autocontido da habilidade "Chuva de Flechas" de Ieldor.
## Uso:
##   var fx := ArrowRainScene.instantiate()
##   add_child(fx)
##   fx.finished.connect(callback)
##   fx.play(source_global_pos, target_global_rect)
class_name ArrowRain
extends CanvasLayer

# ── Assets ───────────────────────────────────────────────────────────────────
const _BASE := "res://scenes/ui/skill_animations/rain_of_arrows/vfx/arrow_rain/"
const _TEX_FLIGHT := preload("res://scenes/ui/skill_animations/rain_of_arrows/vfx/arrow_rain/arrow_flight.png")
const _TEX_STUCK  := preload("res://scenes/ui/skill_animations/rain_of_arrows/vfx/arrow_rain/arrow_stuck.png")
const _TEX_RING   := preload("res://scenes/ui/skill_animations/rain_of_arrows/vfx/arrow_rain/impact_ring.png")
const _TEX_FLASH  := preload("res://scenes/ui/skill_animations/rain_of_arrows/vfx/arrow_rain/impact_flash.png")
const _TEX_DUST   := preload("res://scenes/ui/skill_animations/rain_of_arrows/vfx/arrow_rain/dust_particle.png")
const _TEX_GLOW   := preload("res://scenes/ui/skill_animations/rain_of_arrows/vfx/arrow_rain/charge_glow.png")
const _TEX_CORNER := preload("res://scenes/ui/skill_animations/rain_of_arrows/vfx/arrow_rain/target_corner.png")
const _TEX_SCAN   := preload("res://scenes/ui/skill_animations/rain_of_arrows/vfx/arrow_rain/scan_line.png")
const _TEX_AURA   := preload("res://scenes/ui/skill_animations/rain_of_arrows/vfx/arrow_rain/target_aura.png")

# ── Timeline (em segundos — espelhado do HTML de referência) ─────────────────
const T_CHARGE_END   : float = 1.1
const T_BANNER_IN    : float = 0.2
const T_BANNER_OUT   : float = 2.6
const T_TARGET_IN    : float = 0.55
const T_TARGET_OUT   : float = 3.6
const T_VOLLEY_START : float = 1.1
const T_VOLLEY_END   : float = 2.1
const T_ARROW_FLIGHT : float = 1.2
const T_HOLD_END     : float = 4.6
const NUM_ARROWS     : int   = 22

## Emitido quando toda a animação encerra. O nó se auto-destrói logo em seguida.
signal finished

@export var ability_name: String     = "CHUVA DE FLECHAS"
@export var ability_subtitle: String = "Habilidade Definitiva"

var _source: Vector2
var _target_rect: Rect2
var _rng := RandomNumberGenerator.new()

# Camadas organizacionais
var _arrows_layer:  Node2D
var _impacts_layer: Node2D
var _popups_layer:  Node2D

# Label de status no banner (trocada em T_CHARGE_END)
var _status_label: Label = null

func _ready() -> void:
	layer = 50

# ── API pública ───────────────────────────────────────────────────────────────

## Inicia a animação completa.
## source_pos   — posição global do herói que dispara (centro da carta).
## target_rect  — Rect2 global da área inimiga onde as flechas caem.
## opponent_heroes — Array[Dictionary{pos:Vector2}] opcional (não utilizado ainda).
func play(source_pos: Vector2, target_rect: Rect2, opponent_heroes: Array = []) -> void:
	_source      = source_pos
	_target_rect = target_rect
	_rng.seed    = 7  # mesma semente do HTML → trajetórias consistentes

	# Pré-computa as 22 trajetórias antes de qualquer outra chamada ao rng
	var trajectories: Array = _precompute_trajectories()

	_arrows_layer  = Node2D.new()
	_impacts_layer = Node2D.new()
	_popups_layer  = Node2D.new()
	add_child(_arrows_layer)
	add_child(_impacts_layer)
	add_child(_popups_layer)

	_animate(trajectories)

# ── Pré-computa trajetórias bezier (ordem de rng idêntica ao HTML) ────────────

func _precompute_trajectories() -> Array:
	var list: Array = []
	for i in NUM_ARROWS:
		var launch_t: float = T_VOLLEY_START \
			+ (T_VOLLEY_END - T_VOLLEY_START) * float(i) / float(NUM_ARROWS - 1)
		var tx: float = _target_rect.position.x + _rng.randf() * _target_rect.size.x
		var ty: float = _target_rect.position.y + 30.0 + _rng.randf() * (_target_rect.size.y - 40.0)
		var mid_x: float  = (_source.x + tx) / 2.0
		var peak_y: float = min(_source.y, ty) - 220.0 - _rng.randf() * 110.0
		var ctrl_x: float = mid_x + (_rng.randf() - 0.5) * 80.0
		# p0 tem um leve wobble (igual ao HTML)
		var p0 := Vector2(
			_source.x + (_rng.randf() - 0.5) * 4.0,
			_source.y - 40.0 + (_rng.randf() - 0.5) * 6.0
		)
		list.append({
			"launch_t": launch_t,
			"p0": p0,
			"p1": Vector2(ctrl_x, peak_y),
			"p2": Vector2(tx, ty),
		})
	return list

# ── Orquestração principal ────────────────────────────────────────────────────

func _animate(trajectories: Array) -> void:
	var vp_size  := get_viewport().get_visible_rect().size
	var center   := vp_size * 0.5

	_create_charge_glow()
	_create_banner(center)
	_create_target_zone()
	_create_screen_flash(vp_size)

	for data in trajectories:
		var t: float = data["launch_t"]
		get_tree().create_timer(t).timeout.connect(_spawn_arrow.bind(data))

	get_tree().create_timer(T_HOLD_END).timeout.connect(_on_finished)

# ── Glow de carga ao redor da carta do herói ──────────────────────────────────

func _create_charge_glow() -> void:
	var glow := Sprite2D.new()
	glow.texture  = _TEX_GLOW
	glow.position = _source
	glow.modulate = Color(1.0, 0.92, 0.55, 0.0)
	glow.scale    = Vector2(0.12, 0.12)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material  = mat
	add_child(glow)

	var tw := create_tween().set_parallel(true)
	# 0 → T_CHARGE_END: cresce e acende
	tw.tween_property(glow, "modulate:a", 0.85, T_CHARGE_END) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(glow, "scale", Vector2(0.38, 0.38), T_CHARGE_END) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Desaparece logo após disparar
	tw.tween_property(glow, "modulate:a", 0.0, 0.4).set_delay(T_CHARGE_END)
	tw.chain().tween_callback(glow.queue_free)

# ── Banner central ────────────────────────────────────────────────────────────

func _create_banner(center: Vector2) -> void:
	var root := Node2D.new()
	root.position  = center - Vector2(0.0, 22.0)
	root.modulate.a = 0.0
	add_child(root)

	# "Habilidade Definitiva"
	var sub := Label.new()
	sub.text = ability_subtitle
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.85, 0.76, 0.42))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position             = Vector2(-200.0, -72.0)
	sub.custom_minimum_size  = Vector2(400.0, 20.0)
	root.add_child(sub)

	# "CHUVA DE FLECHAS"
	var title := Label.new()
	title.text = ability_name
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.98, 0.90, 0.63))
	title.add_theme_color_override("font_shadow_color", Color(0.88, 0.72, 0.35, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.add_theme_constant_override("shadow_outline_size", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position             = Vector2(-200.0, -44.0)
	title.custom_minimum_size  = Vector2(400.0, 52.0)
	root.add_child(title)

	# Linha dourada decorativa
	var rule := ColorRect.new()
	rule.color    = Color(0.85, 0.76, 0.42, 0.70)
	rule.size     = Vector2(280.0, 1.0)
	rule.position = Vector2(-140.0, 13.0)
	root.add_child(rule)

	# Status: muda de "Preparando o disparo" para "Volley em alvo" em T_CHARGE_END
	_status_label = Label.new()
	_status_label.text = "Preparando o disparo"
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.85, 0.76, 0.42, 0.85))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.position             = Vector2(-200.0, 20.0)
	_status_label.custom_minimum_size  = Vector2(400.0, 18.0)
	root.add_child(_status_label)

	# Anima fade-in / fade-out do banner inteiro
	var tw := create_tween().set_parallel(true)
	tw.tween_property(root, "modulate:a", 1.0, 0.35).set_delay(T_BANNER_IN)
	tw.tween_property(root, "modulate:a", 0.0, 0.40).set_delay(T_BANNER_OUT - 0.4)
	tw.chain().tween_callback(root.queue_free)

	get_tree().create_timer(T_CHARGE_END).timeout.connect(func() -> void:
		if is_instance_valid(_status_label):
			_status_label.text = "Volley em alvo"
	)

# ── Zona alvo (aura + cantos + scan) ─────────────────────────────────────────

func _create_target_zone() -> void:
	var center := _target_rect.get_center()

	# Aura radial vermelha de fundo
	var aura := Sprite2D.new()
	aura.texture  = _TEX_AURA
	aura.position = center
	aura.scale    = Vector2(_target_rect.size.x / 512.0, _target_rect.size.y / 256.0)
	aura.modulate = Color(1.0, 0.45, 0.35, 0.0)
	add_child(aura)

	# 4 cantos em "L" com rotação
	var corner_defs := [
		{ "pos": _target_rect.position,                                                                    "rot": 0.0           },
		{ "pos": Vector2(_target_rect.position.x + _target_rect.size.x, _target_rect.position.y),          "rot": PI * 0.5      },
		{ "pos": _target_rect.position + _target_rect.size,                                                "rot": PI            },
		{ "pos": Vector2(_target_rect.position.x, _target_rect.position.y + _target_rect.size.y),          "rot": -PI * 0.5     },
	]
	var corner_nodes: Array[Sprite2D] = []
	for cd in corner_defs:
		var sp := Sprite2D.new()
		sp.texture  = _TEX_CORNER
		sp.position = cd["pos"]
		sp.rotation = cd["rot"]
		sp.scale    = Vector2(0.16, 0.16)
		sp.modulate = Color(1.0, 0.45, 0.35, 0.0)
		add_child(sp)
		corner_nodes.append(sp)

	# Linha de scan que varre de cima a baixo
	var scan := Sprite2D.new()
	scan.texture  = _TEX_SCAN
	scan.position = Vector2(center.x, _target_rect.position.y)
	scan.scale    = Vector2(_target_rect.size.x / 1024.0, 1.0)
	scan.modulate = Color(1.0, 0.50, 0.40, 0.0)
	add_child(scan)

	# Fade-in de todos os elementos da zona
	var tw := create_tween().set_parallel(true)
	tw.tween_property(aura, "modulate:a", 1.0, 0.40).set_delay(T_TARGET_IN)
	tw.tween_property(scan, "modulate:a", 1.0, 0.30).set_delay(T_TARGET_IN)
	for sp in corner_nodes:
		tw.tween_property(sp, "modulate:a", 1.0, 0.40).set_delay(T_TARGET_IN)

	# Scan varre top → bottom durante o volley
	var scan_start := T_CHARGE_END - 0.2
	var scan_dur   := (T_VOLLEY_END + 0.2) - scan_start
	tw.tween_property(scan, "position:y",
		_target_rect.position.y + _target_rect.size.y, scan_dur) \
		.set_delay(scan_start) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	# Fade-out
	tw.tween_property(aura, "modulate:a", 0.0, 0.50).set_delay(T_TARGET_OUT - 0.5)
	tw.tween_property(scan, "modulate:a", 0.0, 0.50).set_delay(T_TARGET_OUT - 0.5)
	for sp in corner_nodes:
		tw.tween_property(sp, "modulate:a", 0.0, 0.50).set_delay(T_TARGET_OUT - 0.5)

	tw.chain().tween_callback(func() -> void:
		aura.queue_free()
		scan.queue_free()
		for sp in corner_nodes:
			sp.queue_free()
	)

# ── Flash breve de tela ao soltar o volley ────────────────────────────────────

func _create_screen_flash(vp_size: Vector2) -> void:
	var flash := ColorRect.new()
	flash.color        = Color(0.95, 0.97, 0.85, 0.0)
	flash.size         = vp_size
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)

	var tw := create_tween()
	tw.tween_interval(T_CHARGE_END - 0.05)
	tw.tween_property(flash, "color:a", 0.35, 0.05)
	tw.tween_property(flash, "color:a", 0.0,  0.25)
	tw.tween_callback(flash.queue_free)

# ── Spawn de uma flecha em voo ────────────────────────────────────────────────

func _spawn_arrow(data: Dictionary) -> void:
	var p0: Vector2 = data["p0"]
	var p1: Vector2 = data["p1"]
	var p2: Vector2 = data["p2"]

	var arrow := Sprite2D.new()
	arrow.texture  = _TEX_FLIGHT
	arrow.position = p0
	arrow.scale    = Vector2(0.30, 0.30)
	arrow.z_index  = 10
	_arrows_layer.add_child(arrow)

	var on_tick := func(u: float) -> void:
		if not is_instance_valid(arrow):
			return
		# Leve aceleração no final (efeito de gravidade) — idêntico ao HTML
		var eu: float = u * u * 0.45 + u * 0.55
		var pos  := _bezier(p0, p1, p2, eu)
		var tang := _bezier_tangent(p0, p1, p2, eu)
		arrow.position = pos
		arrow.rotation = tang.angle()

	var tw := create_tween()
	tw.tween_method(on_tick, 0.0, 1.0, T_ARROW_FLIGHT).set_trans(Tween.TRANS_LINEAR)

	tw.tween_callback(func() -> void:
		if is_instance_valid(arrow):
			arrow.queue_free()
		var land_tang := _bezier_tangent(p0, p1, p2, 1.0)
		_on_arrow_landed(p2, land_tang.angle())
	)

# ── Impacto ao pousar ─────────────────────────────────────────────────────────

func _on_arrow_landed(pos: Vector2, angle: float) -> void:
	# Material aditivo compartilhado entre anel e flash
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	# 1. Flecha cravada com wobble
	var stuck := Sprite2D.new()
	stuck.texture  = _TEX_STUCK
	stuck.position = pos
	stuck.rotation = angle
	stuck.scale    = Vector2(0.35, 0.35)
	stuck.z_index  = 9
	_arrows_layer.add_child(stuck)

	var wob := create_tween()
	wob.tween_property(stuck, "rotation", angle + 0.07, 0.05)
	wob.tween_property(stuck, "rotation", angle - 0.04, 0.06)
	wob.tween_property(stuck, "rotation", angle,        0.08)

	# Fade-out perto do fim da cena
	get_tree().create_timer(maxf(0.0, T_HOLD_END - 0.65)).timeout.connect(func() -> void:
		if is_instance_valid(stuck):
			var ft := create_tween()
			ft.tween_property(stuck, "modulate:a", 0.0, 0.55)
			ft.tween_callback(stuck.queue_free)
	)

	# 2. Onda de choque expansiva
	var ring := Sprite2D.new()
	ring.texture  = _TEX_RING
	ring.position = pos
	ring.scale    = Vector2(0.08, 0.08)
	ring.z_index  = 8
	ring.material = mat
	_impacts_layer.add_child(ring)

	var rt := create_tween().set_parallel(true)
	rt.tween_property(ring, "scale",      Vector2(1.1, 1.1), 0.70) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rt.tween_property(ring, "modulate:a", 0.0,              0.70)
	rt.chain().tween_callback(ring.queue_free)

	# 3. Flash central
	var fl := Sprite2D.new()
	fl.texture  = _TEX_FLASH
	fl.position = pos
	fl.scale    = Vector2(0.28, 0.28)
	fl.z_index  = 11
	fl.material = mat.duplicate() as CanvasItemMaterial
	_impacts_layer.add_child(fl)

	var flt := create_tween().set_parallel(true)
	flt.tween_property(fl, "scale",      Vector2(0.62, 0.62), 0.22)
	flt.tween_property(fl, "modulate:a", 0.0,                 0.22)
	flt.chain().tween_callback(fl.queue_free)

	# 4. Partículas de poeira
	var dust := CPUParticles2D.new()
	dust.position             = pos
	dust.texture              = _TEX_DUST
	dust.amount               = 6
	dust.lifetime             = 0.60
	dust.one_shot             = true
	dust.explosiveness        = 0.95
	dust.spread               = 180.0
	dust.direction            = Vector2(0.0, -1.0)
	dust.gravity              = Vector2(0.0, 80.0)
	dust.initial_velocity_min = 40.0
	dust.initial_velocity_max = 90.0
	dust.scale_amount_min     = 0.30
	dust.scale_amount_max     = 0.60
	dust.color                = Color(0.85, 0.70, 0.50, 0.70)
	dust.emitting             = true
	_impacts_layer.add_child(dust)
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if is_instance_valid(dust):
			dust.queue_free()
	)

# ── Bezier quadrático (espelhado do HTML) ─────────────────────────────────────

func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2

func _bezier_tangent(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return 2.0 * u * (p1 - p0) + 2.0 * t * (p2 - p1)

# ─────────────────────────────────────────────────────────────────────────────

func _on_finished() -> void:
	finished.emit()
	queue_free()
