## scenes/vfx/floracao_mortal/floracao_mortal.gd
## VFX da ESPECIAL do Darian (Jardim de Espinhos): detona as Rosas Negras cravadas.
## Rosas negras varrem o campo da ESQUERDA para a DIREITA; conforme a varredura cruza
## o X de cada herói marcado, a rosa daquele herói acende e DETONA com respingo de
## SANGUE (procedural) + popup de dano. Puramente cosmético — dano/estado vêm do sync.
##
## Uso:
##   var fx := FloracaoMortalScene.instantiate()
##   add_child(fx)
##   fx.play([ { "pos": Vector2, "dmg": int }, ... ])   # já ordenado por pos.x
class_name FloracaoMortal
extends CanvasLayer

# ── Assets reaproveitados (rosas + texturas radiais dos Mísseis) ──────────────
const _TEX_ROSE  := preload("res://scenes/vfx/rosas_negras/black_rose.png")
const _TEX_GLOW  := preload("res://scenes/vfx/magic_missiles/charge_glow.png")
const _TEX_BURST := preload("res://scenes/vfx/magic_missiles/impact_burst.png")
const _TEX_FLASH := preload("res://scenes/vfx/magic_missiles/impact_flash.png")
const _TEX_DROP  := preload("res://scenes/vfx/magic_missiles/spark_particle.png")

# ── Paleta sombria / sangue ───────────────────────────────────────────────────
const _C_ROSE   := Color(1.000, 0.910, 0.945)   # modulate da rosa (mantém a arte)
const _C_GLOW   := Color(0.820, 0.180, 0.290)   # halo/ignição carmesim
const _C_BLOOD  := Color(0.560, 0.030, 0.055)   # sangue escuro (gotas)
const _C_BLOOD2 := Color(0.760, 0.080, 0.110)   # sangue mais vivo (splat)
const _C_CRIMSON:= Color(0.780, 0.320, 0.380)   # subtítulo / status / regra
const _C_TITLE  := Color(0.945, 0.820, 0.850)   # nome da habilidade
const _C_SHADOW := Color(0.560, 0.120, 0.180)   # sombra do título
const _C_DMG    := Color(0.960, 0.760, 0.780)   # popup de dano

# ── Timeline ──────────────────────────────────────────────────────────────────
const T_BANNER_IN   := 0.15
const T_SWEEP_START := 0.30
const T_SWEEP_END   := 1.70
const EXPLODE_DELAY := 0.40
const HOLD_TAIL     := 1.20   # tempo após a última explosão antes de sumir

@export var ability_name: String     = "JARDIM DE ESPINHOS"
@export var ability_subtitle: String = "Habilidade Especial"

var _targets: Array = []            # [{ pos, dmg }]
var _plan: Array = []               # [{ idx, ignite_at, explode_at }]
var _sweep_x0: float = 0.0
var _sweep_x1: float = 1280.0
var _band_y0: float = 90.0
var _band_y1: float = 300.0

var _roses_layer:      Node2D
var _explosions_layer: Node2D
var _popups_layer:     Node2D
var _screen_flash:     ColorRect
var _status_label:     Label

func _ready() -> void:
	layer = 80

func play(targets: Array) -> void:
	_targets = targets
	if _targets.is_empty():
		queue_free()
		return
	_compute_bounds()
	_build_plan()
	_setup_layers()
	_run()

# ── Setup ──────────────────────────────────────────────────────────────────────

func _compute_bounds() -> void:
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for tg in _targets:
		var p: Vector2 = tg.pos
		min_x = minf(min_x, p.x); max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y); max_y = maxf(max_y, p.y)
	# A varredura começa/termina fora da coluna dos alvos, para as rosas entrarem e
	# saírem de tela cruzando toda a fileira marcada.
	_sweep_x0 = min_x - 240.0
	_sweep_x1 = max_x + 240.0
	_band_y0  = min_y - 34.0
	_band_y1  = max_y + 34.0

func _build_plan() -> void:
	_plan.clear()
	var span: float = maxf(1.0, _sweep_x1 - _sweep_x0)
	var sweep_dur: float = T_SWEEP_END - T_SWEEP_START
	for i in _targets.size():
		var hx: float = _targets[i].pos.x
		var frac: float = clampf((hx - _sweep_x0) / span, 0.0, 1.0)
		var ignite_at: float = T_SWEEP_START + frac * sweep_dur
		var explode_at: float = ignite_at + EXPLODE_DELAY + i * 0.06
		_plan.append({ "idx": i, "ignite_at": ignite_at, "explode_at": explode_at })

func _setup_layers() -> void:
	_screen_flash = ColorRect.new()
	_screen_flash.color        = Color(_C_BLOOD2.r, _C_BLOOD2.g, _C_BLOOD2.b, 0.0)
	_screen_flash.size         = get_viewport().get_visible_rect().size
	_screen_flash.z_index      = 5
	_screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen_flash)

	_roses_layer      = _make_layer(11)
	_explosions_layer = _make_layer(14)
	_popups_layer     = _make_layer(18)

func _make_layer(z: int) -> Node2D:
	var n := Node2D.new()
	n.z_index = z
	add_child(n)
	return n

func _add_mat(node: CanvasItem) -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	node.material = mat

# ── Orquestração ────────────────────────────────────────────────────────────────

func _run() -> void:
	var center := get_viewport().get_visible_rect().size * 0.5
	_create_banner(center)
	_spawn_sweeping_roses()

	for entry in _plan:
		get_tree().create_timer(entry.ignite_at, false).timeout.connect(_ignite.bind(int(entry.idx), float(entry.explode_at)))

	var last_explode: float = 0.0
	for entry in _plan:
		last_explode = maxf(last_explode, float(entry.explode_at))

	get_tree().create_timer(T_SWEEP_END, false).timeout.connect(func() -> void:
		if is_instance_valid(_status_label):
			_status_label.text = "O sangue sombrio se derrama..."
	)
	get_tree().create_timer(last_explode + HOLD_TAIL, false).timeout.connect(_on_finished)

# ── Rosas varrendo o campo (esquerda → direita) ─────────────────────────────────

func _spawn_sweeping_roses() -> void:
	var count := 13
	var sweep_dur: float = T_SWEEP_END - T_SWEEP_START
	for i in count:
		var frac_y: float = 0.0 if count <= 1 else float(i) / float(count - 1)
		var y: float = lerpf(_band_y0, _band_y1, frac_y)
		# Escalona a saída de cada rosa um pouco, para não voarem em bloco.
		var start_delay: float = T_SWEEP_START + (float(i) / float(count)) * 0.12
		get_tree().create_timer(start_delay, false).timeout.connect(_spawn_one_rose.bind(y, i, sweep_dur))

func _spawn_one_rose(y: float, id: int, dur: float) -> void:
	var rose := Node2D.new()
	rose.position = Vector2(_sweep_x0, y)
	_roses_layer.add_child(rose)

	var halo := Sprite2D.new()
	halo.texture  = _TEX_GLOW
	halo.scale    = Vector2(0.22, 0.22)
	halo.modulate = Color(_C_GLOW.r, _C_GLOW.g, _C_GLOW.b, 0.65)
	_add_mat(halo)
	rose.add_child(halo)

	var bloom := Sprite2D.new()
	bloom.texture  = _TEX_ROSE
	bloom.scale    = Vector2(0.055, 0.055)
	bloom.modulate = _C_ROSE
	bloom.rotation = PI * 0.5   # botão da rosa apontando para a direita (sentido do voo)
	rose.add_child(bloom)

	var amp: float = 16.0 + float(id % 3) * 6.0
	var phase: float = float(id) * 1.3
	var fly := create_tween()
	fly.tween_method(
		func(p: float) -> void:
			if not is_instance_valid(rose):
				return
			rose.position.x = lerpf(_sweep_x0, _sweep_x1, p)
			rose.position.y = y + sin(p * PI * 2.2 + phase) * amp
			bloom.rotation = PI * 0.5 + sin(p * PI * 3.0 + phase) * 0.25,
		0.0, 1.0, dur
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fly.tween_callback(rose.queue_free)

# ── Banner ──────────────────────────────────────────────────────────────────────

func _create_banner(center: Vector2) -> void:
	var root := Node2D.new()
	root.position   = center - Vector2(0.0, 24.0)
	root.modulate.a = 0.0
	root.z_index    = 16
	add_child(root)

	var sub := Label.new()
	sub.text                 = ability_subtitle
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position             = Vector2(-220.0, -64.0)
	sub.custom_minimum_size  = Vector2(440.0, 20.0)
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", _C_CRIMSON)
	root.add_child(sub)

	var title := Label.new()
	title.text                 = ability_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position             = Vector2(-260.0, -36.0)
	title.custom_minimum_size  = Vector2(520.0, 56.0)
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", _C_TITLE)
	title.add_theme_color_override("font_shadow_color", Color(_C_SHADOW.r, _C_SHADOW.g, _C_SHADOW.b, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.add_theme_constant_override("shadow_outline_size", 4)
	root.add_child(title)

	var rule := ColorRect.new()
	rule.color    = Color(_C_CRIMSON.r, _C_CRIMSON.g, _C_CRIMSON.b, 0.75)
	rule.size     = Vector2(320.0, 1.0)
	rule.position = Vector2(-160.0, 28.0)
	root.add_child(rule)

	_status_label = Label.new()
	_status_label.text                 = "Os espinhos varrem o campo..."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.position             = Vector2(-220.0, 34.0)
	_status_label.custom_minimum_size  = Vector2(440.0, 18.0)
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(_C_CRIMSON.r, _C_CRIMSON.g, _C_CRIMSON.b, 0.85))
	root.add_child(_status_label)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(root, "modulate:a", 1.0, 0.35).set_delay(T_BANNER_IN)
	# Sai um pouco depois da última explosão.
	var out_delay: float = maxf(1.0, T_SWEEP_END)
	tw.tween_property(root, "modulate:a", 0.0, 0.5).set_delay(out_delay + 1.6)
	tw.chain().tween_callback(root.queue_free)

# ── Ignição (rosa acende no herói) → Explosão ───────────────────────────────────

func _ignite(idx: int, explode_at: float) -> void:
	var pos: Vector2 = _targets[idx].pos
	# Brilho carmesim crescente sobre o herói até a detonação.
	var glow := Sprite2D.new()
	glow.texture  = _TEX_GLOW
	glow.position = pos
	glow.scale    = Vector2(0.10, 0.10)
	glow.modulate = Color(_C_GLOW.r, _C_GLOW.g, _C_GLOW.b, 0.0)
	_add_mat(glow)
	_explosions_layer.add_child(glow)

	var dur: float = maxf(0.05, explode_at - _plan[idx].ignite_at)
	var gt := create_tween().set_parallel(true)
	gt.tween_property(glow, "modulate:a", 0.85, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	gt.tween_property(glow, "scale", Vector2(0.5, 0.5), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	get_tree().create_timer(dur, false).timeout.connect(func() -> void:
		if is_instance_valid(glow):
			glow.queue_free()
		_explode(idx)
	)

func _explode(idx: int) -> void:
	var tg: Dictionary = _targets[idx]
	var pos: Vector2 = tg.pos
	_spawn_blood(pos)
	_spawn_damage_popup(pos, int(tg.get("dmg", 0)))

	var ft := create_tween()
	ft.tween_property(_screen_flash, "color:a", 0.22, 0.05)
	ft.tween_property(_screen_flash, "color:a", 0.0, 0.28)

# ── Respingo de sangue (procedural) ─────────────────────────────────────────────

func _spawn_blood(pos: Vector2) -> void:
	# Clarão/splat vermelho expandindo (ADD para o brilho do impacto).
	var ring := Sprite2D.new()
	ring.texture  = _TEX_BURST
	ring.position = pos
	ring.scale    = Vector2(0.08, 0.08)
	ring.modulate = _C_BLOOD2
	_add_mat(ring)
	_explosions_layer.add_child(ring)
	var rt := create_tween().set_parallel(true)
	rt.tween_property(ring, "scale", Vector2(1.05, 1.05), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rt.tween_property(ring, "modulate:a", 0.0, 0.5)
	rt.chain().tween_callback(ring.queue_free)

	var flash := Sprite2D.new()
	flash.texture  = _TEX_FLASH
	flash.position = pos
	flash.scale    = Vector2(0.26, 0.26)
	flash.modulate = Color(1.0, 0.5, 0.55, 1.0)
	_add_mat(flash)
	_explosions_layer.add_child(flash)
	var flt := create_tween().set_parallel(true)
	flt.tween_property(flash, "scale", Vector2(0.5, 0.5), 0.18)
	flt.tween_property(flash, "modulate:a", 0.0, 0.18)
	flt.chain().tween_callback(flash.queue_free)

	# Gotas de sangue — blend NORMAL (escuras) e com gravidade para caírem em arco.
	var spray := CPUParticles2D.new()
	spray.position             = pos
	spray.texture              = _TEX_DROP
	spray.amount               = 16
	spray.lifetime             = 0.7
	spray.one_shot             = true
	spray.explosiveness        = 1.0
	spray.spread               = 150.0
	spray.direction            = Vector2(0, -1)     # jorra para cima e cai
	spray.gravity              = Vector2(0.0, 620.0)
	spray.initial_velocity_min = 90.0
	spray.initial_velocity_max = 260.0
	spray.scale_amount_min     = 0.25
	spray.scale_amount_max     = 0.7
	spray.color                = Color(_C_BLOOD.r, _C_BLOOD.g, _C_BLOOD.b, 0.95)
	spray.emitting             = true
	_explosions_layer.add_child(spray)
	get_tree().create_timer(1.1, false).timeout.connect(spray.queue_free)

	# Névoa fina de sangue mais vivo, poucas partículas grandes e lentas.
	var mist := CPUParticles2D.new()
	mist.position             = pos
	mist.texture              = _TEX_DROP
	mist.amount               = 8
	mist.lifetime             = 0.5
	mist.one_shot             = true
	mist.explosiveness        = 1.0
	mist.spread               = 180.0
	mist.gravity              = Vector2(0.0, 180.0)
	mist.initial_velocity_min = 20.0
	mist.initial_velocity_max = 80.0
	mist.scale_amount_min     = 0.5
	mist.scale_amount_max     = 1.1
	mist.color                = Color(_C_BLOOD2.r, _C_BLOOD2.g, _C_BLOOD2.b, 0.55)
	mist.emitting             = true
	_explosions_layer.add_child(mist)
	get_tree().create_timer(0.9, false).timeout.connect(mist.queue_free)

func _spawn_damage_popup(pos: Vector2, dmg: int) -> void:
	if dmg <= 0:
		return
	var lbl := Label.new()
	lbl.text = "−%d" % dmg
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", _C_DMG)
	lbl.add_theme_color_override("font_shadow_color", Color(0.2, 0.0, 0.02, 0.7))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.position = pos - Vector2(18.0, 20.0)
	_popups_layer.add_child(lbl)
	var pt := create_tween().set_parallel(true)
	pt.tween_property(lbl, "position:y", lbl.position.y - 44.0, 0.9)
	pt.tween_property(lbl, "modulate:a", 0.0, 0.9).set_delay(0.2)
	pt.chain().tween_callback(lbl.queue_free)

func _on_finished() -> void:
	queue_free()
