## scenes/vfx/stealth_smoke/stealth_smoke.gd
## VFX autocontido de FURTIVIDADE: uma "bombinha" sai da origem (cartas de combate),
## arremessa em arco até o herói ativo e "explode" numa nuvem de fumaça arroxeada —
## o herói ficou furtivo. Cosmético / não-bloqueante.
## Uso:
##   var fx := StealthSmokeScene.instantiate()
##   add_child(fx)
##   fx.play(source_global_pos, target_global_pos)
##
## Sem assets externos: a partícula soft é gerada por código (cacheada estaticamente),
## então uma carta/efeito novo que reusa a chave "stealth" ganha o VFX de graça.
class_name StealthSmoke
extends CanvasLayer

# ── Palette — fumaça em ardósia/roxo (tema furtividade) ─────────────────────────
const _C_SMOKE_DARK := Color("#241f2e")
const _C_SMOKE_MID  := Color("#463f57")
const _C_SMOKE_LITE := Color("#7a6f93")
const _C_SPARK      := Color("#c9b6ff")
const _C_FLASH      := Color("#e8ddff")

# ── Timeline (segundos) ─────────────────────────────────────────────────────────
const T_IMPACT     := 0.42   # voo da bombinha → impacto
const T_PUFF_LIFE  := 2.40   # vida-base de uma baforada (dissipa devagar)
const T_HOLD_END   := 0.90   # folga após a fumaça antes de auto-destruir

const _NUM_PUFFS := 44   # baforadas que dispersam pra fora
const _NUM_CORE  := 8    # baforadas grandes e lentas que formam o núcleo denso
const _NUM_TRAIL := 14

## Emitido quando a animação termina. O nó se auto-destrói logo em seguida.
signal finished

var _source_pos: Vector2
var _target_pos: Vector2
var _rng := RandomNumberGenerator.new()

# Textura soft (disco com falloff radial) compartilhada — gerada uma única vez.
static var _soft_tex: Texture2D = null

# Camadas organizacionais
var _trail_layer: Node2D
var _bomb_layer:  Node2D
var _flash_layer: Node2D
var _smoke_layer: Node2D

var _bomb: Sprite2D

func _ready() -> void:
	layer = 50

# ── API pública ────────────────────────────────────────────────────────────────

## Inicia a animação.
## source_pos — posição global de onde a bombinha parte (cartas de combate do dono)
## target_pos — posição global do herói ativo (centro do slot)
func play(source_pos: Vector2, target_pos: Vector2) -> void:
	_source_pos = source_pos
	_target_pos = target_pos
	_rng.randomize()
	_ensure_tex()
	_setup_layers()
	_run()

# ── Textura procedural (disco soft branco — tingido via modulate) ──────────────

static func _ensure_tex() -> void:
	if _soft_tex != null:
		return
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	var r := float(size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / r
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a   # falloff suave
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_soft_tex = ImageTexture.create_from_image(img)

# ── Camadas / materiais ────────────────────────────────────────────────────────

func _setup_layers() -> void:
	_trail_layer = _make_layer(6)
	_smoke_layer = _make_layer(7)
	_bomb_layer  = _make_layer(9)
	_flash_layer = _make_layer(12)

func _make_layer(z: int) -> Node2D:
	var n := Node2D.new()
	n.z_index = z
	add_child(n)
	return n

func _add_mat(node: CanvasItem) -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	node.material = mat

# ── Bézier quadrática ──────────────────────────────────────────────────────────

func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2

# ── Orquestração ────────────────────────────────────────────────────────────────

func _run() -> void:
	# Ponto de controle do arco (acima da reta origem→alvo).
	var ctrl := Vector2(
		(_source_pos.x + _target_pos.x) * 0.5,
		min(_source_pos.y, _target_pos.y) - 70.0
	)

	# A bombinha: esfera escura.
	_bomb          = Sprite2D.new()
	_bomb.texture  = _soft_tex
	_bomb.position = _source_pos
	_bomb.scale    = Vector2(0.34, 0.34)
	_bomb.modulate = _C_SMOKE_DARK
	_bomb_layer.add_child(_bomb)

	# Brilho de pavio (aditivo) preso à bomba.
	var fuse         := Sprite2D.new()
	fuse.texture      = _soft_tex
	fuse.scale        = Vector2(0.75, 0.75)
	fuse.modulate     = Color(_C_SPARK.r, _C_SPARK.g, _C_SPARK.b, 0.9)
	_add_mat(fuse)
	_bomb.add_child(fuse)

	# Voo em arco com tumbling.
	var tw := create_tween()
	tw.tween_method(
		func(u: float) -> void:
			if not is_instance_valid(_bomb):
				return
			_bomb.position = _bezier(_source_pos, ctrl, _target_pos, u)
			_bomb.rotation = u * TAU * 1.5,
		0.0, 1.0, T_IMPACT
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	_spawn_trail(ctrl)
	get_tree().create_timer(T_IMPACT, false).timeout.connect(_explode)
	get_tree().create_timer(T_IMPACT + T_PUFF_LIFE + T_HOLD_END, false) \
		.timeout.connect(_on_finished)

# ── Rastro de fumacinha ao longo do voo ────────────────────────────────────────

func _spawn_trail(ctrl: Vector2) -> void:
	var interval := T_IMPACT / float(_NUM_TRAIL)
	for i in _NUM_TRAIL:
		var delay := float(i) * interval
		get_tree().create_timer(delay, false).timeout.connect(func() -> void:
			var u: float     = clamp(delay / T_IMPACT, 0.0, 0.999)
			var pos: Vector2 = _bezier(_source_pos, ctrl, _target_pos, u)

			var dot         := Sprite2D.new()
			dot.texture      = _soft_tex
			dot.position     = pos
			dot.scale        = Vector2(0.16, 0.16)
			dot.modulate     = Color(_C_SMOKE_MID.r, _C_SMOKE_MID.g, _C_SMOKE_MID.b, 0.5)
			_trail_layer.add_child(dot)

			var tw := create_tween().set_parallel(true)
			tw.tween_property(dot, "modulate:a", 0.0, 0.40)
			tw.tween_property(dot, "scale",      Vector2(0.30, 0.30), 0.40)
			tw.chain().tween_callback(dot.queue_free)
		)

# ── Explosão de fumaça no alvo ─────────────────────────────────────────────────

func _explode() -> void:
	if is_instance_valid(_bomb):
		_bomb.queue_free()

	# Flash curto aditivo no ponto de impacto.
	var flash         := Sprite2D.new()
	flash.texture      = _soft_tex
	flash.position     = _target_pos
	flash.scale        = Vector2(0.50, 0.50)
	flash.modulate     = Color(_C_FLASH.r, _C_FLASH.g, _C_FLASH.b, 0.95)
	_add_mat(flash)
	_flash_layer.add_child(flash)
	var ft := create_tween().set_parallel(true)
	ft.tween_property(flash, "scale", Vector2(2.6, 2.6), 0.30) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	ft.tween_property(flash, "modulate:a", 0.0, 0.35)
	ft.chain().tween_callback(flash.queue_free)

	# Núcleo denso (grande, lento) primeiro, depois as baforadas dispersas por cima.
	for i in _NUM_CORE:
		_spawn_core_puff()
	for i in _NUM_PUFFS:
		_spawn_puff()

## Uma baforada: nasce no alvo, dispersa pra fora + sobe, cresce e some.
## Blend normal (fumaça opaca, não aditiva) para realmente "encobrir" o herói.
func _spawn_puff() -> void:
	var ang     := _rng.randf() * TAU
	var dist    := 30.0 + _rng.randf() * 120.0
	var rise    := 40.0 + _rng.randf() * 70.0
	var life    := T_PUFF_LIFE * (0.75 + _rng.randf() * 0.45)
	var start_s := 0.30 + _rng.randf() * 0.25
	var end_s   := 1.4  + _rng.randf() * 1.2
	var palette := [_C_SMOKE_DARK, _C_SMOKE_MID, _C_SMOKE_LITE]
	var col: Color = palette[_rng.randi() % palette.size()]
	var peak_a  := 0.65 + _rng.randf() * 0.25
	_emit_puff(ang, dist, rise, life, start_s, end_s, col, peak_a, 14.0)

## Baforada de NÚCLEO: grande, lenta, pouco deslocamento — adensa o centro e persiste,
## encobrindo o herói por mais tempo antes de dissipar.
func _spawn_core_puff() -> void:
	var ang     := _rng.randf() * TAU
	var dist    := _rng.randf() * 40.0
	var rise    := 20.0 + _rng.randf() * 35.0
	var life    := T_PUFF_LIFE * (1.0 + _rng.randf() * 0.3)
	var start_s := 0.6 + _rng.randf() * 0.3
	var end_s   := 2.4 + _rng.randf() * 1.0
	var palette := [_C_SMOKE_DARK, _C_SMOKE_MID]
	var col: Color = palette[_rng.randi() % palette.size()]
	var peak_a  := 0.80 + _rng.randf() * 0.18
	_emit_puff(ang, dist, rise, life, start_s, end_s, col, peak_a, 10.0)

## Cria e anima uma única baforada (compartilhado por puff/core).
func _emit_puff(ang: float, dist: float, rise: float, life: float,
		start_s: float, end_s: float, col: Color, peak_a: float, jitter: float) -> void:
	var p          := Sprite2D.new()
	p.texture       = _soft_tex
	p.position      = _target_pos + Vector2(cos(ang), sin(ang)) * (_rng.randf() * jitter)
	p.scale         = Vector2(start_s, start_s)
	p.rotation      = _rng.randf() * TAU
	p.modulate      = Color(col.r, col.g, col.b, 0.0)
	_smoke_layer.add_child(p)

	var dir := Vector2(cos(ang), sin(ang)) * dist

	# Movimento + crescimento (paralelo).
	var mt := create_tween().set_parallel(true)
	mt.tween_method(
		func(u: float) -> void:
			if not is_instance_valid(p):
				return
			p.position = _target_pos + dir * u + Vector2(0.0, -rise * u),
		0.0, 1.0, life
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	mt.tween_property(p, "scale", Vector2(end_s, end_s), life) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Alpha: aparece rápido, segura, e dissipa bem devagar.
	var at := create_tween()
	at.tween_property(p, "modulate:a", peak_a, life * 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	at.tween_property(p, "modulate:a", 0.0, life * 0.86) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	at.tween_callback(p.queue_free)

# ── Fim ─────────────────────────────────────────────────────────────────────────

func _on_finished() -> void:
	finished.emit()
	queue_free()
