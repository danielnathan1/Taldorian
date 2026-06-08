## scenes/vfx/assassin_attack/assassin_attack.gd
## VFX fullscreen one-shot, generico e reutilizavel: o mundo se parte ao meio por
## um corte de luz azul. Usado atualmente pela passiva de Hakai ("Golpe das Sombras"),
## mas projetado para servir qualquer heroi do arquetipo "assassino".
##
## - Cobre a tela inteira (1280x720) sobre um CanvasLayer (layer = 80).
## - Toca a sequencia completa (~3.55s), se restaura sozinho e emite `finished`,
##   fazendo `queue_free()`. Nao se vincula a nenhuma carta nem segue posicao.
## - Sem banner de texto: e puramente o efeito visual.
##
## Uso:
##   var fx := AssassinAttackScene.instantiate()
##   add_child(fx)
##   fx.finished.connect(callback)
##   fx.play()
##
## Reutilizavel via @export (cor / metades reais via SubViewport).
class_name AssassinAttack
extends CanvasLayer

# ── Assets ───────────────────────────────────────────────────────────────────
const _BASE := "res://scenes/vfx/assassin_attack/"
const _TEX_FOG    := preload("res://scenes/vfx/assassin_attack/fog_blob.png")
const _TEX_CHARGE := preload("res://scenes/vfx/assassin_attack/charge_dot.png")
const _TEX_CORE   := preload("res://scenes/vfx/assassin_attack/slice_core.png")
const _TEX_BLOOM  := preload("res://scenes/vfx/assassin_attack/slice_bloom.png")
const _TEX_GLINT  := preload("res://scenes/vfx/assassin_attack/glint.png")
const _TEX_SPARK  := preload("res://scenes/vfx/assassin_attack/spark.png")
const _SHADER     := preload("res://scenes/vfx/assassin_attack/darken_vignette.gdshader")

# ── Timeline (segundos — espelha EXATAMENTE o const T do prototipo HTML) ───────
const T_DARK_IN    : float = 0.0
const T_DARK_FULL  : float = 0.75
const T_FOG_IN     : float = 0.15
const T_FOG_FULL   : float = 1.00
const T_CHARGE_AT  : float = 0.70
const T_SLICE_AT   : float = 1.55
const T_SLICE_DUR  : float = 0.26
const T_FLASH_AT   : float = 1.55
const T_FLASH_DUR  : float = 0.40
const T_SEP_FROM   : float = 1.60
const T_SEP_DUR    : float = 0.45
const T_WIND_FROM  : float = 2.45
const T_WIND_DUR   : float = 1.05
const T_END        : float = 3.55

const STAGE   := Vector2(1280.0, 720.0)
const MID_Y   : float = 360.0
const MAX_SEP : float = 13.0   # overshoot logo apos o corte
const REST_SEP: float = 7.0    # separacao em repouso
const NUM_FOG : int   = 7

# Paleta-mestre (ver tabela do prompt)
const COL_CORE   := Color("eaf4ff")  # nucleo branco-azulado
const COL_BRIGHT := Color("5aa0ff")  # azul brilhante (bloom/glints/caps)
const COL_FOG    := Color(0.55, 0.62, 0.95)
const COL_VOID   := Color("04050a")

## Emitido ao terminar (antes do queue_free).
signal finished

# ── Configuracao reutilizavel ─────────────────────────────────────────────────
@export var slice_color: Color       = COL_BRIGHT
## Textura de um SubViewport do board para mostrar as duas metades reais
## deslizando (Opcao A). Se null, usa apenas a fenda + costura (Opcao B).
@export var board_texture: Texture2D = null
@export var use_split_halves: bool   = false

var _rng := RandomNumberGenerator.new()
var _fog: Array[Sprite2D] = []
var _running: bool = false

# Nós construídos proceduralmente
var _darken: ColorRect
var _fog_layer: Node2D
var _gap_void: ColorRect
var _charge: Sprite2D
var _core: NinePatchRect
var _bloom: NinePatchRect
var _cap_left: Sprite2D
var _cap_right: Sprite2D
var _glints: CPUParticles2D
var _sparks: CPUParticles2D
var _flash: ColorRect
var _top_half: TextureRect
var _bottom_half: TextureRect

func _ready() -> void:
	layer = 80

# ── API pública ────────────────────────────────────────────────────────────────
func play() -> void:
	_rng.seed = 71  # mesma semente do HTML → névoa consistente
	_build()
	_running = true
	_run_sequence()

# ── Construção dos nós ──────────────────────────────────────────────────────────
func _build() -> void:
	# Metades reais do board (Opção A) — só quando há textura
	if use_split_halves and board_texture != null:
		_top_half = _make_board_half(Rect2(0.0, 0.0, STAGE.x, MID_Y))
		_bottom_half = _make_board_half(Rect2(0.0, MID_Y, STAGE.x, MID_Y))
		add_child(_top_half)
		add_child(_bottom_half)

	# 1. Escurecimento + vinheta (shader)
	_darken = ColorRect.new()
	_darken.set_anchors_preset(Control.PRESET_FULL_RECT)
	_darken.size = STAGE
	_darken.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dmat := ShaderMaterial.new()
	dmat.shader = _SHADER
	dmat.set_shader_parameter("amount", 0.0)
	_darken.material = dmat
	add_child(_darken)

	# 2. Camada de névoa
	_fog_layer = Node2D.new()
	add_child(_fog_layer)
	_spawn_fog()

	# 3. Vão preto entre as metades
	_gap_void = ColorRect.new()
	_gap_void.color = COL_VOID
	_gap_void.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gap_void.modulate.a = 0.0
	add_child(_gap_void)

	# 4. Lâmina (halo largo + linha fina), pontas e ponto de carga — blend ADD
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_bloom = NinePatchRect.new()
	_bloom.texture = _TEX_BLOOM
	_bloom.patch_margin_left = 8
	_bloom.patch_margin_right = 8
	_bloom.modulate = slice_color
	_bloom.modulate.a = 0.0
	_bloom.material = add_mat
	_bloom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bloom)

	_core = NinePatchRect.new()
	_core.texture = _TEX_CORE
	_core.patch_margin_left = 8
	_core.patch_margin_right = 8
	_core.modulate = COL_CORE
	_core.modulate.a = 0.0
	_core.material = add_mat
	_core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_core)

	_cap_left = _make_cap(add_mat)
	_cap_right = _make_cap(add_mat)
	add_child(_cap_left)
	add_child(_cap_right)

	_charge = Sprite2D.new()
	_charge.texture = _TEX_CHARGE
	_charge.position = STAGE / 2.0
	_charge.modulate = COL_CORE
	_charge.modulate.a = 0.0
	_charge.material = add_mat
	add_child(_charge)

	# 5. Partículas da costura
	_glints = _make_glints()
	_glints.position = Vector2(STAGE.x / 2.0, MID_Y)
	add_child(_glints)

	_sparks = _make_sparks()
	_sparks.position = Vector2(STAGE.x / 2.0, MID_Y)
	add_child(_sparks)

	# 6. Flash de tela
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.size = STAGE
	_flash.color = slice_color
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	_flash.material = add_mat
	add_child(_flash)

func _make_board_half(region: Rect2) -> TextureRect:
	# Recorta a metade correspondente da textura do viewport via AtlasTexture
	# (forma correta de "clip" no Godot 4 — TextureRect não tem region_enabled).
	var atlas := AtlasTexture.new()
	atlas.atlas = board_texture
	atlas.region = region
	var tr := TextureRect.new()
	tr.texture = atlas
	tr.position = region.position
	tr.size = region.size
	tr.stretch_mode = TextureRect.STRETCH_KEEP
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

func _make_cap(add_mat: CanvasItemMaterial) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _TEX_CHARGE
	s.modulate = COL_BRIGHT
	s.modulate.a = 0.0
	s.scale = Vector2(0.6, 0.6)
	s.material = add_mat
	return s

## Glints contínuos correndo pela costura (CPUParticles2D — padrão do projeto).
func _make_glints() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _TEX_GLINT
	p.amount = 18
	p.lifetime = 2.2
	p.one_shot = false
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(640.0, 3.0)
	p.direction = Vector2(1.0, 0.0)
	p.spread = 180.0  # metade corre para cada lado da costura
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 190.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.6
	p.color = COL_BRIGHT
	var cmat := CanvasItemMaterial.new()
	cmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = cmat
	return p

## Faíscas one-shot disparadas no momento do corte.
func _make_sparks() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _TEX_SPARK
	p.amount = 22
	p.lifetime = 0.5
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(410.0, 2.0)
	p.direction = Vector2(0.0, -1.0)
	p.spread = 80.0  # espalha p/ cima e p/ baixo da costura
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 200.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.2
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 1.0))
	sc.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = sc
	p.color = COL_BRIGHT
	var cmat := CanvasItemMaterial.new()
	cmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = cmat
	return p

# ── Sequência completa one-shot ─────────────────────────────────────────────────
func _run_sequence() -> void:
	var t := create_tween().set_parallel(true)

	# 1. Escurecimento (0 → 0.75)
	t.tween_method(_set_darken, 0.0, 1.0, T_DARK_FULL - T_DARK_IN).set_delay(T_DARK_IN)

	# 2. Névoa: fade-in coletivo (0.15 → 1.0); o drift roda no _process
	for f in _fog:
		t.tween_property(f, "modulate:a", float(f.get_meta("max_op")), T_FOG_FULL - T_FOG_IN) \
			.set_delay(T_FOG_IN)

	# 3. Carga: ponto cresce e brilha (0.70 → 1.55)
	t.tween_property(_charge, "modulate:a", 1.0, T_SLICE_AT - T_CHARGE_AT) \
		.set_delay(T_CHARGE_AT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_charge, "scale", Vector2(2.2, 2.2), T_SLICE_AT - T_CHARGE_AT) \
		.set_delay(T_CHARGE_AT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 4. Corte
	get_tree().create_timer(T_SLICE_AT, false).timeout.connect(_trigger_cut)
	# 6. Dissipação
	get_tree().create_timer(T_WIND_FROM, false).timeout.connect(_trigger_dissipate)
	# Fim
	get_tree().create_timer(T_END, false).timeout.connect(_on_finished)

func _set_darken(v: float) -> void:
	if is_instance_valid(_darken):
		(_darken.material as ShaderMaterial).set_shader_parameter("amount", v)

# ── Disparo do corte ─────────────────────────────────────────────────────────────
func _trigger_cut() -> void:
	if not _running:
		return
	_charge.modulate.a = 0.0

	_core.modulate.a = 1.0
	_bloom.modulate.a = 1.0
	_cap_left.modulate.a = 1.0
	_cap_right.modulate.a = 1.0

	# Lâmina expande do centro até as bordas (half-width 0 → 640)
	var grow := create_tween()
	grow.tween_method(_set_slice_width, 0.0, 1.0, T_SLICE_DUR) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	# Flash de tela (1.55 → 1.95)
	var ft := create_tween()
	ft.tween_property(_flash, "modulate:a", 0.85, 0.04)
	ft.tween_property(_flash, "modulate:a", 0.0, T_FLASH_DUR - 0.04) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Faíscas (one-shot) + glints contínuos
	_sparks.restart()
	_sparks.emitting = true
	_glints.emitting = true

	# Esconde as pontas quando a lâmina chega ao fim
	get_tree().create_timer(T_SLICE_DUR, false).timeout.connect(func() -> void:
		var hide := create_tween().set_parallel(true)
		hide.tween_property(_cap_left, "modulate:a", 0.0, 0.12)
		hide.tween_property(_cap_right, "modulate:a", 0.0, 0.12)
	)

	# 5. Separação das metades (1.60 → 2.45)
	if use_split_halves and board_texture != null:
		var sep := create_tween()
		sep.tween_method(_set_separation, 0.0, MAX_SEP, 0.18) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		sep.chain().tween_method(_set_separation, MAX_SEP, REST_SEP, T_SEP_DUR - 0.18) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		# Opção B: só cresce a fenda preta
		var gap := create_tween()
		gap.tween_method(_set_gap_only, 0.0, REST_SEP, T_SEP_DUR) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

# largura da lâmina: frac 0→1 mapeia half-width 0→640
func _set_slice_width(frac: float) -> void:
	var half := frac * (STAGE.x / 2.0)
	var w := half * 2.0
	var left := STAGE.x / 2.0 - half
	_core.position = Vector2(left, MID_Y - 4.0)
	_core.size = Vector2(w, 8.0)
	_bloom.position = Vector2(left, MID_Y - 32.0)
	_bloom.size = Vector2(w, 64.0)
	_cap_left.position = Vector2(left, MID_Y)
	_cap_right.position = Vector2(left + w, MID_Y)

# separa as metades verticalmente + abre o vão preto
func _set_separation(sep: float) -> void:
	if is_instance_valid(_top_half):
		_top_half.position.y = -sep
	if is_instance_valid(_bottom_half):
		_bottom_half.position.y = MID_Y + sep
	_set_gap_only(sep)

func _set_gap_only(sep: float) -> void:
	_gap_void.modulate.a = 1.0 if sep > 0.2 else 0.0
	_gap_void.position = Vector2(0.0, MID_Y - sep)
	_gap_void.size = Vector2(STAGE.x, sep * 2.0)
	# a costura acompanha o centro do vão
	_core.position.y = MID_Y - 4.0
	_bloom.position.y = MID_Y - 32.0

# ── Dissipação (2.45 → 3.55): tudo faz fade-out em paralelo ───────────────────
func _trigger_dissipate() -> void:
	if not _running:
		return
	_glints.emitting = false
	_sparks.emitting = false

	var d := create_tween().set_parallel(true)
	d.tween_method(_set_darken, 1.0, 0.0, T_WIND_DUR)
	for f in _fog:
		d.tween_property(f, "modulate:a", 0.0, T_WIND_DUR)
	d.tween_property(_core, "modulate:a", 0.0, T_WIND_DUR)
	d.tween_property(_bloom, "modulate:a", 0.0, T_WIND_DUR)
	d.tween_property(_gap_void, "modulate:a", 0.0, T_WIND_DUR)
	# metades voltam a se juntar
	if use_split_halves and board_texture != null:
		d.tween_property(_top_half, "position:y", 0.0, T_WIND_DUR) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		d.tween_property(_bottom_half, "position:y", MID_Y, T_WIND_DUR) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

# ── Névoa: spawn de 7 blobs + drift contínuo ─────────────────────────────────
func _spawn_fog() -> void:
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in NUM_FOG:
		var s := Sprite2D.new()
		s.texture = _TEX_FOG
		s.material = add_mat
		var bx := _rng.randf() * STAGE.x
		var by := 120.0 + _rng.randf() * (STAGE.y - 240.0)
		var sc := 0.7 + _rng.randf() * 0.8
		s.position = Vector2(bx, by)
		s.scale = Vector2(sc, sc * 0.55)
		s.modulate = COL_FOG
		s.modulate.a = 0.0
		s.set_meta("base", Vector2(bx, by))
		s.set_meta("drift", Vector2(30.0 + _rng.randf() * 70.0, 14.0 + _rng.randf() * 26.0))
		s.set_meta("speed", 0.04 + _rng.randf() * 0.06)
		s.set_meta("phase", _rng.randf() * TAU)
		s.set_meta("max_op", 0.10 + _rng.randf() * 0.12)
		_fog_layer.add_child(s)
		_fog.append(s)

func _process(_dt: float) -> void:
	if not _running:
		return
	var t := Time.get_ticks_msec() / 1000.0
	for f in _fog:
		if not is_instance_valid(f):
			continue
		var base: Vector2 = f.get_meta("base")
		var drift: Vector2 = f.get_meta("drift")
		var speed: float = f.get_meta("speed")
		var phase: float = f.get_meta("phase")
		f.position = base + Vector2(
			sin(t * speed * 6.0 + phase) * drift.x,
			cos(t * speed * 4.4 + phase * 1.3) * drift.y
		)

func _on_finished() -> void:
	_running = false
	finished.emit()
	queue_free()
