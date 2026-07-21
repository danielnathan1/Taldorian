## scenes/vfx/rosas_negras/rosas_negras.gd
## VFX autocontido da passiva "Rosas Negras" do Darian: 3 rosas negras saem da
## retaguarda voando em ARCO (mesma trajetória Bézier + ondulação dos Mísseis
## Mágicos) até heróis do oponente sorteados no servidor (podem repetir alvo).
## Puramente cosmético — NÃO causa dano nem toca no estado; o throw só marca
## (Hero.black_roses) e o marcador do slot exibe a contagem via sync.
##
## Uso:
##   var fx := RosasNegrasScene.instantiate()
##   fx.roses = [ { "id": 0, "target": "1_2", "side": 1.0, "curve": 70.0, "waves": 1.8 }, ... ]
##   add_child(fx)
##   fx.play(darian_slot_global_pos, { "1_2": { "pos": p }, "1_0": { "pos": p } })
class_name RosasNegras
extends CanvasLayer

# ── Assets ────────────────────────────────────────────────────────────────────
const _TEX_ROSE   := preload("res://scenes/vfx/rosas_negras/black_rose.png")
# Texturas radiais reaproveitadas dos Mísseis Mágicos (tingidas em carmesim).
const _TEX_GLOW   := preload("res://scenes/vfx/magic_missiles/charge_glow.png")
const _TEX_ORB    := preload("res://scenes/vfx/magic_missiles/charge_orb.png")
const _TEX_TRAIL  := preload("res://scenes/vfx/magic_missiles/missile_trail.png")
const _TEX_BURST  := preload("res://scenes/vfx/magic_missiles/impact_burst.png")
const _TEX_FLASH  := preload("res://scenes/vfx/magic_missiles/impact_flash.png")
const _TEX_SPARK  := preload("res://scenes/vfx/magic_missiles/spark_particle.png")

# ── Paleta sombria / carmesim (tokens OKLCH do RosasNegras_GodotPrompt.md) ────
const _C_ROSE   := Color(1.000, 0.910, 0.945)   # modulate da rosa (mantém a arte)
const _C_GLOW   := Color(0.820, 0.180, 0.290)   # halo carmesim atrás da rosa
const _C_TRAIL  := Color(0.720, 0.200, 0.300)   # rastro carmesim
const _C_CRIMSON:= Color(0.780, 0.320, 0.380)   # subtítulo / status / regra
const _C_TITLE  := Color(0.945, 0.820, 0.850)   # nome da habilidade
const _C_SHADOW := Color(0.560, 0.120, 0.180)   # sombra do título
const _C_PETAL  := Color(0.520, 0.110, 0.180)   # pétalas do impacto

# ── Timeline (segundos — espelha o T de Rosas Negras.html) ───────────────────
const T_CHARGE_START : float = 0.0
const T_CHARGE_END   : float = 0.9
const T_BANNER_IN    : float = 0.15
const T_BANNER_OUT   : float = 2.6
const T_LAUNCH_FIRST : float = 0.9
const T_LAUNCH_LAST  : float = 1.5
const T_HOLD_END     : float = 3.6

# Cada rosa: alvo (chave em _targets), lado da curva, força, nº de ondas.
const ROSES_DEFAULT := [
	{ "id": 0, "target": "active", "side":  1.0, "curve": 70.0, "waves": 1.8 },
	{ "id": 1, "target": "active", "side": -1.0, "curve": 95.0, "waves": 2.2 },
	{ "id": 2, "target": "active", "side":  1.0, "curve": 60.0, "waves": 1.6 },
]

## Emitido quando a animação termina. O nó se auto-destrói logo em seguida.
signal finished

# ── Config sobrescrevível ─────────────────────────────────────────────────────
@export var flight_time: float       = 1.15
@export var ability_name: String     = "ROSAS NEGRAS"
@export var ability_subtitle: String = "Magia Sombria"
## Rosas a disparar. Vazio → usa ROSES_DEFAULT.
@export var roses: Array             = []

# ── Estado ───────────────────────────────────────────────────────────────────
var _source: Vector2
var _targets: Dictionary = {}   # { chave -> { "pos": Vector2 } }
var _roses: Array = []

var _charge_layer:  Node2D
var _roses_layer:   Node2D
var _impacts_layer: Node2D

var _status_label: Label = null

func _ready() -> void:
	layer = 50

# ── API pública ───────────────────────────────────────────────────────────────

## source_pos — posição global do slot de Darian (origem das rosas).
## targets    — Dictionary mapeando chave -> { "pos": Vector2 }.
func play(source_pos: Vector2, targets: Dictionary) -> void:
	_source  = source_pos
	_targets = targets
	_roses   = roses if not roses.is_empty() else ROSES_DEFAULT
	_setup_layers()
	_run()

# ── Setup ──────────────────────────────────────────────────────────────────────

func _setup_layers() -> void:
	_charge_layer  = _make_layer(11)
	_roses_layer   = _make_layer(13)
	_impacts_layer = _make_layer(15)

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

	_create_charge_glow()
	_create_charge_petals()
	_create_banner(center)

	# Dispara cada rosa em sequência escalonada (T_LAUNCH_FIRST..T_LAUNCH_LAST).
	var n := _roses.size()
	for i in n:
		var frac: float = 0.0 if n <= 1 else float(i) / float(n - 1)
		var launch_t: float = T_LAUNCH_FIRST + (T_LAUNCH_LAST - T_LAUNCH_FIRST) * frac
		get_tree().create_timer(launch_t, false).timeout.connect(_spawn_rose.bind(i))

	get_tree().create_timer(T_CHARGE_END, false).timeout.connect(func() -> void:
		if is_instance_valid(_status_label):
			_status_label.text = "As rosas cravam nos inimigos"
	)

	get_tree().create_timer(T_HOLD_END, false).timeout.connect(_on_finished)

# ── Glow de carga carmesim na mão de Darian ─────────────────────────────────────

func _create_charge_glow() -> void:
	var glow := Sprite2D.new()
	glow.texture  = _TEX_GLOW
	glow.position = _source
	glow.scale    = Vector2(0.18, 0.18)
	glow.modulate = Color(_C_GLOW.r, _C_GLOW.g, _C_GLOW.b, 0.0)
	_add_mat(glow)
	_charge_layer.add_child(glow)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(glow, "modulate:a", 0.85, T_CHARGE_END) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(glow, "scale", Vector2(1.15, 1.15), T_CHARGE_END) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(glow, "modulate:a", 0.0, 0.40).set_delay(T_CHARGE_END)
	tw.chain().tween_callback(glow.queue_free)

# ── 7 pétalas espiralando para dentro até colapsar na mão ──────────────────────

func _create_charge_petals() -> void:
	for i in 7:
		var petal := Sprite2D.new()
		petal.texture  = _TEX_ORB
		petal.scale    = Vector2(0.40, 0.40)
		petal.modulate = Color(_C_GLOW.r, _C_GLOW.g, _C_GLOW.b, 0.0)
		_add_mat(petal)
		_charge_layer.add_child(petal)

		var phase: float = float(i) * TAU / 7.0
		var tw := create_tween()
		tw.tween_method(
			func(p: float) -> void:
				if not is_instance_valid(petal):
					return
				var ang: float = p * 2.6 * TAU + phase
				var rad: float = (1.0 - p) * 40.0 + 8.0
				petal.position   = _source + Vector2(cos(ang), sin(ang)) * rad
				petal.rotation   = ang
				petal.modulate.a = p,
			0.0, 1.0, T_CHARGE_END
		)
		tw.tween_callback(petal.queue_free)

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
	sub.add_theme_color_override("font_color", _C_CRIMSON)
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
	rule.color    = Color(_C_CRIMSON.r, _C_CRIMSON.g, _C_CRIMSON.b, 0.75)
	rule.size     = Vector2(300.0, 1.0)
	rule.position = Vector2(-150.0, 28.0)
	root.add_child(rule)

	_status_label = Label.new()
	_status_label.text                 = "Colhendo espinhos sombrios"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.position             = Vector2(-200.0, 34.0)
	_status_label.custom_minimum_size  = Vector2(400.0, 18.0)
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(_C_CRIMSON.r, _C_CRIMSON.g, _C_CRIMSON.b, 0.85))
	root.add_child(_status_label)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(root, "modulate:a", 1.0, 0.35).set_delay(T_BANNER_IN)
	tw.tween_property(root, "modulate:a", 0.0, 0.40).set_delay(T_BANNER_OUT - 0.40)
	tw.chain().tween_callback(root.queue_free)

# ═══════════════════════════════════════════════════════════════════════════════
#  TRAJETÓRIA CURVA — idêntica aos Mísseis Mágicos (Bézier cúbica + ondulação).
# ═══════════════════════════════════════════════════════════════════════════════

func _build_path(m: Dictionary) -> Dictionary:
	var p0: Vector2  = _source
	var p3: Vector2  = _target_pos(m.target) + Vector2(0.0, 6.0)
	var dir: Vector2 = (p3 - p0).normalized()
	var nrm := Vector2(-dir.y, dir.x)
	var length: float = p0.distance_to(p3)
	var c1: Vector2 = p0 + dir * length * 0.30 + nrm * (float(m.curve) * float(m.side))
	var c2: Vector2 = p0 + dir * length * 0.72 + nrm * (float(m.curve) * 0.55 * float(m.side))
	# Mantém os controles dentro da viewport → o arco nunca sai da tela.
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

func _rose_pos(p: Dictionary, u: float) -> Vector2:
	var base := _cbez(p, u)
	var tan := _cbez_tangent(p, u).normalized()
	var wn := Vector2(-tan.y, tan.x)
	var fade := sin(u * PI)
	var wob := sin(u * PI * p.waves + p.id) * 14.0 * fade * (1.0 - u * 0.4)
	return base + wn * wob

func _ease_in_out_cubic(t: float) -> float:
	return 4.0 * t * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0

# ── Spawn de uma rosa em voo ────────────────────────────────────────────────────

func _spawn_rose(idx: int) -> void:
	var m: Dictionary = _roses[idx]
	var path := _build_path(m)

	# Container que carrega o halo carmesim (ADD) + a rosa (blend normal).
	var rose := Node2D.new()
	_roses_layer.add_child(rose)

	var halo := Sprite2D.new()
	halo.texture  = _TEX_GLOW
	halo.scale    = Vector2(0.20, 0.20)
	halo.modulate = Color(_C_GLOW.r, _C_GLOW.g, _C_GLOW.b, 0.75)
	_add_mat(halo)
	rose.add_child(halo)

	# A rosa em blend NORMAL — é escura; ADD apagaria o corpo. Só o halo é aditivo.
	var bloom := Sprite2D.new()
	bloom.texture  = _TEX_ROSE
	bloom.scale    = Vector2(0.05, 0.05)
	bloom.modulate = _C_ROSE
	rose.add_child(bloom)

	# Rastro carmesim que sampleia a curva real para trás.
	var trail := Line2D.new()
	trail.width          = 6.0
	trail.joint_mode     = Line2D.LINE_JOINT_ROUND
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode   = Line2D.LINE_CAP_ROUND
	trail.texture        = _TEX_TRAIL
	trail.texture_mode   = Line2D.LINE_TEXTURE_STRETCH
	_add_mat(trail)
	var grad := Gradient.new()
	grad.set_color(0, Color(_C_TRAIL.r, _C_TRAIL.g, _C_TRAIL.b, 0.0))
	grad.set_color(1, Color(_C_TRAIL.r, _C_TRAIL.g, _C_TRAIL.b, 0.60))
	trail.gradient = grad
	_roses_layer.add_child(trail)

	const TRAIL_STEPS := 12
	const TRAIL_SPAN  := 0.15

	var fly := create_tween()
	fly.tween_method(
		func(local: float) -> void:
			if not is_instance_valid(rose):
				return
			var u := _ease_in_out_cubic(local)
			rose.position = _rose_pos(path, u)
			# Rosa aponta com o botão na frente (a arte cresce para -Y).
			bloom.rotation = _cbez_tangent(path, u).angle() + PI * 0.5
			var pts := PackedVector2Array()
			for i in range(TRAIL_STEPS, -1, -1):
				var uu: float = u - (float(i) / float(TRAIL_STEPS)) * TRAIL_SPAN
				if uu < 0.0:
					continue
				pts.append(_rose_pos(path, uu))
			trail.points = pts,
		0.0, 1.0, flight_time
	)
	fly.tween_callback(func() -> void:
		rose.queue_free()
		var tt := create_tween()
		tt.tween_property(trail, "modulate:a", 0.0, 0.18)
		tt.tween_callback(trail.queue_free)
		_on_rose_impact(path.p3)
	)

# ── Impacto (só visual — sem dano/popup) ────────────────────────────────────────

func _on_rose_impact(pos: Vector2) -> void:
	# Anel de choque carmesim.
	var burst := Sprite2D.new()
	burst.texture  = _TEX_BURST
	burst.position = pos
	burst.scale    = Vector2(0.08, 0.08)
	burst.modulate = _C_GLOW
	_add_mat(burst)
	_impacts_layer.add_child(burst)
	var bt := create_tween().set_parallel(true)
	bt.tween_property(burst, "scale", Vector2(1.1, 1.1), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bt.tween_property(burst, "modulate:a", 0.0, 0.5)
	bt.chain().tween_callback(burst.queue_free)

	# Flash breve.
	var flash := Sprite2D.new()
	flash.texture  = _TEX_FLASH
	flash.position = pos
	flash.scale    = Vector2(0.28, 0.28)
	flash.modulate = Color(1.0, 0.85, 0.88, 1.0)
	_add_mat(flash)
	_impacts_layer.add_child(flash)
	var ft := create_tween().set_parallel(true)
	ft.tween_property(flash, "scale", Vector2(0.55, 0.55), 0.2)
	ft.tween_property(flash, "modulate:a", 0.0, 0.2)
	ft.chain().tween_callback(flash.queue_free)

	# Burst de pétalas negras se desprendendo.
	var spark := CPUParticles2D.new()
	spark.position             = pos
	spark.texture              = _TEX_SPARK
	spark.amount               = 8
	spark.lifetime             = 0.55
	spark.one_shot             = true
	spark.explosiveness        = 1.0
	spark.spread               = 180.0
	spark.initial_velocity_min = 50.0
	spark.initial_velocity_max = 130.0
	spark.gravity              = Vector2(0.0, 120.0)
	spark.scale_amount_min     = 0.3
	spark.scale_amount_max     = 0.6
	spark.color                = Color(_C_PETAL.r, _C_PETAL.g, _C_PETAL.b, 0.85)
	spark.emitting             = true
	_impacts_layer.add_child(spark)
	get_tree().create_timer(0.9, false).timeout.connect(spark.queue_free)

# ── Fim ──────────────────────────────────────────────────────────────────────────

func _on_finished() -> void:
	finished.emit()
	queue_free()
