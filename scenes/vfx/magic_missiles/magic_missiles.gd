## scenes/vfx/magic_missiles/magic_missiles.gd
## VFX autocontido para habilidades de "projétil mágico perseguidor".
## Usado pelos Mísseis Mágicos da Arquimaga, mas reutilizável por qualquer
## habilidade de homing bolt — basta trocar textura/cor/nº de feixes ou passar
## um array de mísseis customizado.
##
## Uso:
##   var fx := MagicMissilesScene.instantiate()
##   add_child(fx)
##   fx.finished.connect(callback)
##   fx.play(staff_tip_global_pos, {
##       "active": { "pos": p, "hp_node": bar },
##       "h1":     { "pos": p, "hp_node": bar },
##       "h2":     { "pos": p, "hp_node": bar },
##   })
class_name MagicMissiles
extends CanvasLayer

# ── Assets (locais à pasta do vfx, como nos demais efeitos) ───────────────────
const _TEX_HEAD   := preload("res://scenes/vfx/magic_missiles/missile_head.png")
const _TEX_TRAIL  := preload("res://scenes/vfx/magic_missiles/missile_trail.png")
const _TEX_ORB    := preload("res://scenes/vfx/magic_missiles/charge_orb.png")
const _TEX_GLOW   := preload("res://scenes/vfx/magic_missiles/charge_glow.png")
const _TEX_BURST  := preload("res://scenes/vfx/magic_missiles/impact_burst.png")
const _TEX_FLASH  := preload("res://scenes/vfx/magic_missiles/impact_flash.png")
const _TEX_SPARK  := preload("res://scenes/vfx/magic_missiles/spark_particle.png")
const _TEX_AURA   := preload("res://scenes/vfx/magic_missiles/target_aura.png")
const _TEX_CORNER := preload("res://scenes/vfx/magic_missiles/target_corner.png")

# ── Paleta arcana ────────────────────────────────────────────────────────────
const _C_BOLT   := Color(0.78, 0.45, 1.00)   # violeta arcano (corpo do feixe)
const _C_VIOLET := Color(0.741, 0.494, 0.941) # #bd7ef0 (subtítulo / status / regra)
const _C_TITLE  := Color(0.929, 0.855, 0.980) # #eddafa (nome da habilidade)
const _C_SHADOW := Color(0.659, 0.361, 0.878) # #a85ce0 (sombra do título)
const _C_DAMAGE := Color(0.933, 0.784, 1.000) # #eec8ff (popup de dano)

# ── Timeline (segundos — espelha o objeto T de Magic Missiles.html) ──────────
const T_CHARGE_START : float = 0.0
const T_CHARGE_END   : float = 1.0    # orbes reunidos, caster libera
const T_BANNER_IN    : float = 0.15
const T_BANNER_OUT   : float = 2.5
const T_TARGET_IN    : float = 0.55
const T_TARGET_OUT   : float = 3.4
const T_LAUNCH_FIRST : float = 1.0
const T_LAUNCH_LAST  : float = 1.55   # último feixe deixa a mão
const T_HOLD_END     : float = 3.9    # duração total da cena

# Cada míssil: alvo (chave em _targets), lado da curva, força da curva,
# nº de ondas senoidais e dano. Espelha o array MISSILES do HTML.
const MISSILES := [
	{ "id": 0, "target": "active", "side":  1.0, "curve": 200.0, "waves": 2.0, "dmg": 4 },
	{ "id": 1, "target": "active", "side": -1.0, "curve": 230.0, "waves": 2.4, "dmg": 4 },
	{ "id": 2, "target": "h1",     "side": -1.0, "curve": 180.0, "waves": 1.8, "dmg": 3 },
	{ "id": 3, "target": "h2",     "side":  1.0, "curve": 250.0, "waves": 2.2, "dmg": 3 },
	{ "id": 4, "target": "active", "side":  1.0, "curve": 150.0, "waves": 2.6, "dmg": 4 },
]

## Emitido quando a animação termina. O nó se auto-destrói logo em seguida.
signal finished

# ── Configuração sobrescrevível por outras habilidades de homing bolt ─────────
@export var head_texture: Texture2D  = _TEX_HEAD
@export var trail_texture: Texture2D = _TEX_TRAIL
@export var flight_time: float       = 0.95
@export var ability_name: String     = "MÍSSEIS MÁGICOS"
@export var ability_subtitle: String = "Magia Arcana"
@export var bolt_color: Color        = _C_BOLT
## Mísseis a disparar. Vazio → usa MISSILES (configuração canônica da Arquimaga).
@export var missiles: Array          = []

# ── Estado ───────────────────────────────────────────────────────────────────
var _source: Vector2
var _targets: Dictionary = {}   # { chave -> { "pos": Vector2, "hp_node": Range } }
var _missiles: Array = []
var _rng := RandomNumberGenerator.new()

# Camadas organizacionais (Node2D filhos do CanvasLayer)
var _charge_layer:  Node2D
var _missiles_layer: Node2D
var _impacts_layer: Node2D
var _popups_layer:  Node2D

var _status_label: Label = null

func _ready() -> void:
	layer = 50

# ── API pública ───────────────────────────────────────────────────────────────

## Inicia a animação completa.
## source_pos — posição global da ponta do cajado (origem dos feixes).
## targets    — Dictionary mapeando chave -> { "pos": Vector2, "hp_node": Range }.
##              A chave "active" é o alvo principal (zona de marcação).
func play(source_pos: Vector2, targets: Dictionary) -> void:
	_source   = source_pos
	_targets  = targets
	_missiles = missiles if not missiles.is_empty() else MISSILES
	_rng.seed = 7   # mesma semente do HTML → comportamento consistente

	_setup_layers()
	_run()

# ── Setup ──────────────────────────────────────────────────────────────────────

func _setup_layers() -> void:
	_charge_layer   = _make_layer(11)
	_missiles_layer = _make_layer(13)
	_impacts_layer  = _make_layer(15)
	_popups_layer   = _make_layer(18)

func _make_layer(z: int) -> Node2D:
	var n := Node2D.new()
	n.z_index = z
	add_child(n)
	return n

func _add_mat(node: CanvasItem) -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	node.material = mat

# Resolve a posição de um alvo, com fallback para "active" e depois para a origem.
func _target_pos(key: String) -> Vector2:
	if _targets.has(key):
		return _targets[key].get("pos", _source)
	if _targets.has("active"):
		return _targets["active"].get("pos", _source)
	return _source

# ── Orquestração principal ──────────────────────────────────────────────────────

func _run() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var center  := vp_size * 0.5

	_create_screen_flash(vp_size)
	_create_charge_glow()
	_create_charge_orbs()
	_create_banner(center)
	_create_target_zone()

	# Dispara cada míssil em sequência escalonada (T_LAUNCH_FIRST..T_LAUNCH_LAST)
	var n := _missiles.size()
	for i in n:
		var frac: float = 0.0 if n <= 1 else float(i) / float(n - 1)
		var launch_t: float = T_LAUNCH_FIRST + (T_LAUNCH_LAST - T_LAUNCH_FIRST) * frac
		get_tree().create_timer(launch_t, false).timeout.connect(_spawn_missile.bind(i))

	# Troca de status ao liberar os feixes
	get_tree().create_timer(T_CHARGE_END, false).timeout.connect(func() -> void:
		if is_instance_valid(_status_label):
			_status_label.text = "Os feixes perseguem o alvo"
	)

	get_tree().create_timer(T_HOLD_END, false).timeout.connect(_on_finished)

# ── Flash de tela breve na liberação ────────────────────────────────────────────

func _create_screen_flash(vp_size: Vector2) -> void:
	var flash := ColorRect.new()
	flash.color        = Color(0.953, 0.867, 1.000, 0.0)  # #f3ddff
	flash.size         = vp_size
	flash.z_index      = 20
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)

	var tw := create_tween()
	tw.tween_interval(T_CHARGE_END - 0.05)
	tw.tween_property(flash, "color:a", 0.32, 0.05)
	tw.tween_property(flash, "color:a", 0.0,  0.30)
	tw.tween_callback(flash.queue_free)

# ── Glow de carga ao redor do cajado ───────────────────────────────────────────

func _create_charge_glow() -> void:
	var glow := Sprite2D.new()
	glow.texture  = _TEX_GLOW
	glow.position = _source
	glow.scale    = Vector2(0.20, 0.20)
	glow.modulate = Color(bolt_color.r, bolt_color.g, bolt_color.b, 0.0)
	_add_mat(glow)
	_charge_layer.add_child(glow)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(glow, "modulate:a", 0.85, T_CHARGE_END) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(glow, "scale", Vector2(1.40, 1.40), T_CHARGE_END) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(glow, "modulate:a", 0.0, 0.40).set_delay(T_CHARGE_END)
	tw.chain().tween_callback(glow.queue_free)

# ── 8 orbes que espiralam para dentro até colapsar na ponta do cajado ──────────

func _create_charge_orbs() -> void:
	for i in 8:
		var orb := Sprite2D.new()
		orb.texture  = _TEX_ORB
		orb.scale    = Vector2(0.45, 0.45)
		orb.modulate = Color(bolt_color.r, bolt_color.g, bolt_color.b, 0.0)
		_add_mat(orb)
		_charge_layer.add_child(orb)

		var phase: float = float(i) * TAU / 8.0
		var tw := create_tween()
		tw.tween_method(
			func(p: float) -> void:
				if not is_instance_valid(orb):
					return
				var ang: float = p * 3.0 * TAU + phase
				var rad: float = (1.0 - p) * 42.0 + 8.0
				orb.position   = _source + Vector2(cos(ang), sin(ang)) * rad
				orb.modulate.a = p,
			0.0, 1.0, T_CHARGE_END
		)
		tw.tween_callback(orb.queue_free)

# ── Banner central ──────────────────────────────────────────────────────────────

func _create_banner(center: Vector2) -> void:
	var root := Node2D.new()
	root.position   = center - Vector2(0.0, 24.0)
	root.modulate.a = 0.0
	root.z_index    = 16
	add_child(root)

	var sub := Label.new()
	sub.text                 = ability_subtitle
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position             = Vector2(-200.0, -64.0)
	sub.custom_minimum_size  = Vector2(400.0, 20.0)
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", _C_VIOLET)
	root.add_child(sub)

	var title := Label.new()
	title.text                 = ability_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position             = Vector2(-200.0, -36.0)
	title.custom_minimum_size  = Vector2(400.0, 56.0)
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", _C_TITLE)
	title.add_theme_color_override("font_shadow_color", Color(_C_SHADOW.r, _C_SHADOW.g, _C_SHADOW.b, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.add_theme_constant_override("shadow_outline_size", 4)
	root.add_child(title)

	var rule := ColorRect.new()
	rule.color    = Color(_C_VIOLET.r, _C_VIOLET.g, _C_VIOLET.b, 0.75)
	rule.size     = Vector2(300.0, 1.0)
	rule.position = Vector2(-150.0, 28.0)
	root.add_child(rule)

	_status_label = Label.new()
	_status_label.text                 = "Concentrando energia arcana"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.position             = Vector2(-200.0, 34.0)
	_status_label.custom_minimum_size  = Vector2(400.0, 18.0)
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(_C_VIOLET.r, _C_VIOLET.g, _C_VIOLET.b, 0.85))
	root.add_child(_status_label)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(root, "modulate:a", 1.0, 0.35).set_delay(T_BANNER_IN)
	tw.tween_property(root, "modulate:a", 0.0, 0.40).set_delay(T_BANNER_OUT - 0.40)
	tw.chain().tween_callback(root.queue_free)

# ── Zona de marcação do alvo ativo (haze radial + cantos em L) ──────────────────

func _create_target_zone() -> void:
	if not _targets.has("active"):
		return
	var c: Vector2 = _targets["active"].get("pos", _source)

	var aura := Sprite2D.new()
	aura.texture  = _TEX_AURA
	aura.position = c
	aura.scale    = Vector2(0.85, 0.85)
	aura.modulate = Color(bolt_color.r, bolt_color.g, bolt_color.b, 0.0)
	_add_mat(aura)
	add_child(aura)

	var corner_defs := [
		[c + Vector2(-52.0, -70.0), 0.0],
		[c + Vector2( 52.0, -70.0), PI * 0.5],
		[c + Vector2( 52.0,  70.0), PI],
		[c + Vector2(-52.0,  70.0), -PI * 0.5],
	]
	var corners: Array[Sprite2D] = []
	for cd in corner_defs:
		var sp := Sprite2D.new()
		sp.texture  = _TEX_CORNER
		sp.position = cd[0]
		sp.rotation = cd[1]
		sp.scale    = Vector2(0.6, 0.6)
		sp.modulate = Color(bolt_color.r, bolt_color.g, bolt_color.b, 0.0)
		add_child(sp)
		corners.append(sp)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(aura, "modulate:a", 1.0, 0.40).set_delay(T_TARGET_IN)
	for sp in corners:
		tw.tween_property(sp, "modulate:a", 1.0, 0.40).set_delay(T_TARGET_IN)
	tw.tween_property(aura, "modulate:a", 0.0, 0.50).set_delay(T_TARGET_OUT - 0.50)
	for sp in corners:
		tw.tween_property(sp, "modulate:a", 0.0, 0.50).set_delay(T_TARGET_OUT - 0.50)
	tw.chain().tween_callback(func() -> void:
		aura.queue_free()
		for sp in corners:
			sp.queue_free()
	)

# ═══════════════════════════════════════════════════════════════════════════════
#  TRAJETÓRIA CURVA — coração do efeito. Espelha cbez/missilePos do HTML.
# ═══════════════════════════════════════════════════════════════════════════════

func _build_path(m: Dictionary) -> Dictionary:
	var p0: Vector2  = _source
	var p3: Vector2  = _target_pos(m.target) + Vector2(0.0, 6.0)
	var dir: Vector2 = (p3 - p0).normalized()
	var nrm := Vector2(-dir.y, dir.x)              # perpendicular
	var length: float = p0.distance_to(p3)
	# Os DOIS controles empurrados para o mesmo lado → um arco em "C" claro;
	# o segundo volta um pouco ao centro para o feixe cravar reto no alvo.
	var c1: Vector2 = p0 + dir * length * 0.30 + nrm * (m.curve * m.side)
	var c2: Vector2 = p0 + dir * length * 0.72 + nrm * (m.curve * 0.55 * m.side)
	# Uma Bézier cúbica fica contida no fecho convexo dos seus 4 pontos. Como p0/p3
	# são posições de heróis (sempre no board), manter c1/c2 dentro da viewport
	# garante que o feixe nunca saia da tela — mesmo em tiros diagonais longos onde
	# o caster não está no centro como na referência HTML.
	var bounds := get_viewport().get_visible_rect().grow(-24.0)
	c1 = _clamp_to_rect(c1, bounds)
	c2 = _clamp_to_rect(c2, bounds)
	return { "p0": p0, "c1": c1, "c2": c2, "p3": p3, "waves": float(m.waves), "id": int(m.id) }

func _clamp_to_rect(p: Vector2, r: Rect2) -> Vector2:
	return Vector2(
		clampf(p.x, r.position.x, r.position.x + r.size.x),
		clampf(p.y, r.position.y, r.position.y + r.size.y)
	)

func _cbez(p: Dictionary, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * u * p.p0 + 3.0 * u * u * t * p.c1 + 3.0 * u * t * t * p.c2 + t * t * t * p.p3

func _cbez_tangent(p: Dictionary, t: float) -> Vector2:
	var u := 1.0 - t
	return 3.0 * u * u * (p.c1 - p.p0) + 6.0 * u * t * (p.c2 - p.c1) + 3.0 * t * t * (p.p3 - p.c2)

# Posição final = bézier + ondulação senoidal que some perto dos extremos.
func _missile_pos(p: Dictionary, u: float) -> Vector2:
	var base := _cbez(p, u)
	var tan := _cbez_tangent(p, u).normalized()
	var wn := Vector2(-tan.y, tan.x)               # normal à tangente
	var fade := sin(u * PI)                         # 0 nos extremos, 1 no meio
	var wob := sin(u * PI * p.waves + p.id) * 16.0 * fade * (1.0 - u * 0.4)
	return base + wn * wob

func _ease_in_out_cubic(t: float) -> float:
	return 4.0 * t * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0

# ── Spawn de um míssil em voo ───────────────────────────────────────────────────

func _spawn_missile(idx: int) -> void:
	var m: Dictionary = _missiles[idx]
	var path := _build_path(m)

	# Cabeça brilhante tipo cometa
	var head := Sprite2D.new()
	head.texture  = head_texture
	head.scale    = Vector2(0.18, 0.18)
	head.modulate = bolt_color.lightened(0.3)
	_add_mat(head)
	_missiles_layer.add_child(head)

	# Rastro: Line2D que sampleia a curva REAL para trás (não uma reta)
	var trail := Line2D.new()
	trail.width          = 7.0
	trail.joint_mode     = Line2D.LINE_JOINT_ROUND
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode   = Line2D.LINE_CAP_ROUND
	trail.texture        = trail_texture
	trail.texture_mode   = Line2D.LINE_TEXTURE_STRETCH
	_add_mat(trail)
	var grad := Gradient.new()
	grad.set_color(0, Color(bolt_color.r, bolt_color.g, bolt_color.b, 0.0))   # cauda transparente
	grad.set_color(1, Color(0.92, 0.78, 1.00, 0.80))                          # cabeça brilhante
	trail.gradient = grad
	_missiles_layer.add_child(trail)

	const TRAIL_STEPS := 14
	const TRAIL_SPAN  := 0.16

	var fly := create_tween()
	fly.tween_method(
		func(local: float) -> void:
			if not is_instance_valid(head):
				return
			var u := _ease_in_out_cubic(local)     # acelera e depois "homing"
			head.position = _missile_pos(path, u)
			head.rotation = _cbez_tangent(path, u).angle()
			# reconstrói o rastro amostrando a curva para trás
			var pts := PackedVector2Array()
			for i in range(TRAIL_STEPS, -1, -1):
				var uu: float = u - (float(i) / float(TRAIL_STEPS)) * TRAIL_SPAN
				if uu < 0.0:
					continue
				pts.append(_missile_pos(path, uu))
			trail.points = pts,
		0.0, 1.0, flight_time
	)
	fly.tween_callback(func() -> void:
		head.queue_free()
		var tt := create_tween()
		tt.tween_property(trail, "modulate:a", 0.0, 0.18)
		tt.tween_callback(trail.queue_free)
		_on_missile_impact(path.p3, m.target, int(m.dmg))
	)

# ── Impacto ──────────────────────────────────────────────────────────────────────

func _on_missile_impact(pos: Vector2, target_key: String, dmg: int) -> void:
	# Burst arcano expansivo
	var burst := Sprite2D.new()
	burst.texture  = _TEX_BURST
	burst.position = pos
	burst.scale    = Vector2(0.1, 0.1)
	_add_mat(burst)
	_impacts_layer.add_child(burst)
	var bt := create_tween().set_parallel(true)
	bt.tween_property(burst, "scale", Vector2(1.4, 1.4), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bt.tween_property(burst, "modulate:a", 0.0, 0.55)
	bt.chain().tween_callback(burst.queue_free)

	# Flash central
	var flash := Sprite2D.new()
	flash.texture  = _TEX_FLASH
	flash.position = pos
	flash.scale    = Vector2(0.35, 0.35)
	_add_mat(flash)
	_impacts_layer.add_child(flash)
	var ft := create_tween().set_parallel(true)
	ft.tween_property(flash, "scale", Vector2(0.7, 0.7), 0.22)
	ft.tween_property(flash, "modulate:a", 0.0, 0.22)
	ft.chain().tween_callback(flash.queue_free)

	# 8 faíscas radiais
	var spark := CPUParticles2D.new()
	spark.position             = pos
	spark.texture              = _TEX_SPARK
	spark.amount               = 8
	spark.lifetime             = 0.5
	spark.one_shot             = true
	spark.explosiveness        = 1.0
	spark.spread               = 180.0
	spark.initial_velocity_min = 60.0
	spark.initial_velocity_max = 140.0
	spark.scale_amount_min     = 0.3
	spark.scale_amount_max     = 0.6
	spark.color                = Color(0.9, 0.75, 1.0, 0.8)
	_add_mat(spark)
	spark.emitting = true
	_impacts_layer.add_child(spark)
	get_tree().create_timer(0.9, false).timeout.connect(spark.queue_free)

	# Dano: barra de HP + popup
	if _targets.has(target_key):
		_apply_damage(_targets[target_key], dmg)

func _apply_damage(target: Dictionary, dmg: int) -> void:
	var pos: Vector2 = target.get("pos", _source)

	var hp_node = target.get("hp_node", null)
	if hp_node != null and is_instance_valid(hp_node) and hp_node is Range:
		var bar := hp_node as Range
		var end_val: float = maxf(0.0, bar.value - float(dmg))
		var ht := create_tween()
		ht.tween_property(bar, "value", end_val, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var lbl := Label.new()
	lbl.text = "−%d" % dmg
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", _C_DAMAGE)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.position = pos - Vector2(18.0, 18.0)
	_popups_layer.add_child(lbl)

	var pt := create_tween().set_parallel(true)
	pt.tween_property(lbl, "position:y", lbl.position.y - 42.0, 0.85)
	pt.tween_property(lbl, "modulate:a", 0.0, 0.85).set_delay(0.15)
	pt.chain().tween_callback(lbl.queue_free)

# ── Fim ──────────────────────────────────────────────────────────────────────────

func _on_finished() -> void:
	finished.emit()
	queue_free()
