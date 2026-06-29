## scenes/vfx/empower_beam/empower_beam.gd
## VFX autocontido para CARTAS SIMPLES de buff (apenas ATK/DEF, sem efeitos).
## Um feixe em arco sai da carta recém-jogada e floresce sobre o herói ativo
## de quem a jogou, fazendo popar chips +ATK / +DEF. É tingido pela cor do
## elemento da carta (ver SYMBOL_COLOR). Puramente cosmético / não-bloqueante.
##
## Adaptado do protótipo docs/default_animation/Empower Beam.html — no protótipo
## o feixe ia de um conjurador a um aliado distinto; aqui é um self-buff
## (carta → herói ativo), então a origem é a carta jogada e o alvo é o herói.
##
## Uso (ver board.gd._play_empower_beam_vfx):
##   var fx := EmpowerBeamScene.instantiate()
##   add_child(fx)
##   fx.play(source_global, target_global, "azul", atk_gain, def_gain, card_size)
class_name EmpowerBeam
extends CanvasLayer

## Emitido quando a animação termina. O nó se auto-destrói logo em seguida.
signal finished

# ── Paletas por cor (aprox. dos oklch do protótipo, convertidos p/ sRGB) ───────
const PALETTES := {
	"vermelho": { "bright": Color(0.95, 0.35, 0.26), "core": Color(1.00, 0.86, 0.80) },
	"amarelo":  { "bright": Color(0.98, 0.80, 0.28), "core": Color(1.00, 0.97, 0.84) },
	"azul":     { "bright": Color(0.36, 0.55, 0.98), "core": Color(0.84, 0.90, 1.00) },
	"branco":   { "bright": Color(0.93, 0.94, 0.97), "core": Color(0.99, 0.99, 1.00) },
	"marrom":   { "bright": Color(0.70, 0.52, 0.30), "core": Color(0.90, 0.82, 0.68) },
}

# Elemento da carta → cor do feixe (ids em GameSymbols).
const SYMBOL_COLOR := {
	GameSymbols.FOGO:  "vermelho",
	GameSymbols.AGUA:  "azul",
	GameSymbols.TERRA: "marrom",
	GameSymbols.RAIO:  "amarelo",
	GameSymbols.AR:    "branco",
}

# ── Timeline (segundos) — comprimida em relação ao protótipo (3.3s → ~2.3s),
#    pois é feedback de carta jogada toda rodada, não um showcase de habilidade.
const T_BEAM_START   := 0.05
const T_BEAM_CONNECT := 0.55
const T_BUFF_POP     := 0.72
const T_FADE_START   := 1.35
const T_FADE_END     := 1.85
const T_HOLD_END     := 2.30
const BOW            := 64.0   # altura do arco da bézier quadrática

const _MOTE_N    := 7
const _BEAM_STEPS := 48

# Banner central — desligado por padrão (carta simples toca isto toda rodada;
# um banner "FORTALECER" gigante a cada jogada seria ruído). Ligável p/ showcase.
@export var show_banner: bool       = false
@export var ability_name: String     = "FORTALECER"
@export var ability_subtitle: String = "Reforço"

var _src: Vector2
var _tgt: Vector2
var _pc: Vector2
var _theme: Dictionary
var _atk: int = 0
var _def: int = 0
var _card_size: Vector2 = Vector2(90.0, 126.0)

var _glow_tex: GradientTexture2D
var _beam_layer:  Node2D
var _bloom_layer: Node2D
var _line_glow: Line2D
var _line_mid:  Line2D
var _line_core: Line2D
var _source_node: Sprite2D
var _head:        Sprite2D
var _motes: Array[Sprite2D] = []
var _screen_flash: ColorRect
var _target_glow:  Sprite2D

var _draw_len: float       = 0.0
var _beam_intensity: float = 1.0   # multiplica o alpha dos motes (fade no fim)
var _time: float           = 0.0
var _beam_running: bool     = false

func _ready() -> void:
	layer = 50
	_glow_tex = _make_radial_tex()

# ── API pública ────────────────────────────────────────────────────────────────

## Mapeia os símbolos de uma carta para a chave de cor do feixe (1º elemento
## reconhecido vence). Default: "azul".
static func color_key_for_symbols(symbols: Array) -> String:
	for s in symbols:
		if SYMBOL_COLOR.has(s):
			return SYMBOL_COLOR[s]
	return "azul"

## source_pos / target_pos — posições GLOBAIS (centro da carta jogada e do
## herói ativo). color_key — chave em PALETTES. atk_gain/def_gain — valores
## da carta. target_card_size — tamanho da carta-alvo (chips flanqueiam ela).
func play(
	source_pos: Vector2,
	target_pos: Vector2,
	color_key: String,
	atk_gain: int,
	def_gain: int,
	target_card_size: Vector2 = Vector2(90.0, 126.0)
) -> void:
	_src   = source_pos
	_tgt   = target_pos
	_atk   = atk_gain
	_def   = def_gain
	_card_size = target_card_size
	_theme = _make_theme(color_key)

	# Ponto de controle: perpendicular à reta origem→alvo, arqueando p/ cima.
	var mid := (_src + _tgt) * 0.5
	var dir := _tgt - _src
	var perp := Vector2(0.0, -1.0)
	if dir.length() > 0.001:
		perp = Vector2(-dir.y, dir.x).normalized()
	if perp.y > 0.0:
		perp = -perp
	_pc = mid + perp * BOW

	_build_nodes()
	_run()

# ── Helpers de criação ───────────────────────────────────────────────────────

func _make_theme(key: String) -> Dictionary:
	var p: Dictionary = PALETTES.get(key, PALETTES["azul"])
	var b: Color = p["bright"]
	return {
		"core":   p["core"],
		"bright": b,
		"mid":    Color(b.r, b.g, b.b, 0.90),
		"glow":   Color(b.r, b.g, b.b, 0.50),
		"soft":   Color(b.r, b.g, b.b, 0.22),
		"faint":  Color(b.r, b.g, b.b, 0.10),
	}

## Glow radial branco (centro → transparente). Tingido por modulate em uso.
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

func _make_line(width: float, color: Color, parent: Node) -> Line2D:
	var ln := Line2D.new()
	ln.width        = width
	ln.default_color = color
	ln.joint_mode   = Line2D.LINE_JOINT_ROUND
	ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ln.end_cap_mode = Line2D.LINE_CAP_ROUND
	ln.antialiased  = true
	_add_mat(ln)
	parent.add_child(ln)
	return ln

func _build_nodes() -> void:
	var vp_size := get_viewport().get_visible_rect().size

	# Screen flash (breve, no instante da conexão)
	_screen_flash = ColorRect.new()
	_screen_flash.color = Color(_theme["core"].r, _theme["core"].g, _theme["core"].b, 0.0)
	_screen_flash.size  = vp_size
	_screen_flash.z_index = 20
	_screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen_flash)

	# Glow sustentado sob a carta-alvo (estado reforçado)
	_target_glow = _glow_sprite(maxf(_card_size.x, _card_size.y) * 0.9, _theme["glow"], self)
	_target_glow.position   = _tgt
	_target_glow.z_index    = 1
	_target_glow.modulate.a = 0.0

	# Camadas do feixe e da luz
	_beam_layer = Node2D.new()
	_beam_layer.z_index = 6
	add_child(_beam_layer)
	_bloom_layer = Node2D.new()
	_bloom_layer.z_index = 8
	add_child(_bloom_layer)

	# 3 linhas do feixe (halo macio → núcleo quase branco)
	_line_glow = _make_line(16.0, _theme["soft"],  _beam_layer)
	_line_mid  = _make_line(6.5,  _theme["mid"],   _beam_layer)
	_line_core = _make_line(2.6,  _theme["core"],  _beam_layer)

	# Nó luminoso na origem + cabeça da ponta
	_source_node = _glow_sprite(12.0, _theme["bright"], _beam_layer)
	_source_node.position = _src
	_head = _glow_sprite(11.0, _theme["bright"], _beam_layer)
	_head.position = _src
	_head.visible  = false

	# Pool de motes que fluem pela curva
	for i in _MOTE_N:
		var m := _glow_sprite(3.0, _theme["core"], _beam_layer)
		m.visible = false
		_motes.append(m)

# ── Orquestração ─────────────────────────────────────────────────────────────

func _run() -> void:
	if show_banner:
		_create_banner()

	_beam_running = true

	# Crescimento do feixe (estende em arco até o alvo)
	var grow := create_tween()
	grow.tween_interval(T_BEAM_START)
	grow.tween_method(_update_beam, 0.0, 1.0, T_BEAM_CONNECT - T_BEAM_START) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	grow.tween_callback(_on_connect)

	get_tree().create_timer(T_FADE_START, false).timeout.connect(_fade_beam)
	get_tree().create_timer(T_HOLD_END,   false).timeout.connect(_on_finished)

func _qbez(t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * _src + 2.0 * u * t * _pc + t * t * _tgt

func _update_beam(progress: float) -> void:
	_draw_len = progress
	var pts := PackedVector2Array()
	for i in range(_BEAM_STEPS + 1):
		var u := float(i) / _BEAM_STEPS
		if u > _draw_len:
			break
		pts.append(_qbez(u))
	pts.append(_qbez(_draw_len))
	_line_glow.points = pts
	_line_mid.points  = pts
	_line_core.points = pts
	_head.position = _qbez(_draw_len)
	_head.visible  = _draw_len < 0.999

func _process(delta: float) -> void:
	if not _beam_running:
		return
	_time += delta
	for i in _MOTE_N:
		var m := _motes[i]
		var u: float = fmod(_time * 0.85 + float(i) / float(_MOTE_N), 1.0)
		if _draw_len <= 0.01 or u > _draw_len:
			m.visible = false
			continue
		var fade := sin(u * PI)
		m.visible   = true
		m.position  = _qbez(u)
		m.modulate.a = (0.5 + fade * 0.5) * _beam_intensity
		var sc: float = (1.6 + fade * 1.6) * 2.0 / float(_glow_tex.width)
		m.scale = Vector2(sc, sc)

# ── Conexão: luz floresce sobre o herói ──────────────────────────────────────

func _on_connect() -> void:
	_head.visible = false

	# Flash de tela curto
	var sf := create_tween()
	sf.tween_property(_screen_flash, "color:a", 0.32, 0.04)
	sf.tween_property(_screen_flash, "color:a", 0.0,  0.30)

	_bloom_burst()

	# Glow sustentado na carta (segue reforçado, resíduo até o fim)
	var tg := create_tween()
	tg.tween_property(_target_glow, "modulate:a", 0.8, 0.20)
	tg.tween_property(_target_glow, "modulate:a", 0.45, T_FADE_START - T_BEAM_CONNECT) \
		.set_delay(0.1)
	tg.tween_property(_target_glow, "modulate:a", 0.0, T_HOLD_END - T_FADE_START)

	_spawn_rising()

	# Chips +ATK / +DEF
	get_tree().create_timer(T_BUFF_POP - T_BEAM_CONNECT, false).timeout.connect(_pop_buffs)

func _bloom_burst() -> void:
	# Halo sustentado
	var halo := _glow_sprite(54.0, _theme["bright"], _bloom_layer)
	halo.position   = _tgt
	halo.modulate.a = 0.0
	var ht := create_tween()
	ht.tween_property(halo, "modulate:a", 0.7, 0.20)
	ht.tween_property(halo, "modulate:a", 0.0, T_HOLD_END - T_BEAM_CONNECT - 0.2)

	# Flash central
	var flash := _glow_sprite(70.0, _theme["core"], _bloom_layer)
	flash.position   = _tgt
	flash.scale      *= 0.4
	flash.modulate.a = 0.9
	var ft := create_tween().set_parallel(true)
	ft.tween_property(flash, "scale",      flash.scale / 0.4, 0.5) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	ft.tween_property(flash, "modulate:a", 0.0, 0.5)
	ft.chain().tween_callback(flash.queue_free)

	# Anel expansivo
	var ring := _make_line(2.4, _theme["bright"], _bloom_layer)
	ring.position = _tgt
	ring.points   = _circle_points(40.0)
	ring.closed   = true
	ring.scale    = Vector2.ONE * 0.1
	var rt := create_tween().set_parallel(true)
	rt.tween_property(ring, "scale",      Vector2.ONE * 1.2, 0.6) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rt.tween_property(ring, "modulate:a", 0.0, 0.6)
	rt.chain().tween_callback(ring.queue_free)

	# 12 raios ascendentes em leque
	for i in 12:
		var a := float(i) / 12.0 * TAU - PI * 0.5
		var d := Vector2(cos(a), sin(a))
		var ray := _make_line(1.6, _theme["bright"], _bloom_layer)
		ray.position = _tgt
		ray.points   = PackedVector2Array([d * 14.0, d * 30.0])
		ray.scale    = Vector2.ONE * 0.6
		var yt := create_tween().set_parallel(true)
		yt.tween_property(ray, "scale",      Vector2.ONE * 1.7, 0.5) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		yt.tween_property(ray, "modulate:a", 0.0, 0.5)
		yt.chain().tween_callback(ray.queue_free)

func _circle_points(radius: float, segs: int = 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segs + 1):
		var a := float(i) / float(segs) * TAU
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts

## Motes subindo do herói reforçado durante o hold.
func _spawn_rising() -> void:
	var n := 9
	for i in n:
		var dot := _glow_sprite(2.2, _theme["bright"], _bloom_layer)
		var base_x := _tgt.x + (_card_size.x * 0.5) * (randf() * 2.0 - 1.0) * 0.8
		dot.position   = Vector2(base_x, _tgt.y + _card_size.y * 0.4)
		dot.modulate.a = 0.0
		var dur := 0.9 + randf() * 0.5
		var delay := float(i) * 0.07
		var rise := _card_size.y * 0.9 + randf() * 20.0
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(dot, "modulate:a", 0.85, 0.15)
		tw.parallel().tween_property(dot, "position:y", dot.position.y - rise, dur) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(dot, "modulate:a", 0.0, 0.3)
		tw.tween_callback(dot.queue_free)

# ── Chips +ATK / +DEF flanqueando o herói ────────────────────────────────────

func _pop_buffs() -> void:
	if _atk > 0:
		_spawn_chip("+%d" % _atk, "ATK", true)
	if _def > 0:
		_spawn_chip("+%d" % _def, "DEF", false)

func _spawn_chip(num_text: String, tag: String, to_left: bool) -> void:
	var panel := PanelContainer.new()
	panel.z_index = 12
	var sb := StyleBoxFlat.new()
	sb.bg_color     = Color(0.10, 0.07, 0.12, 0.78)
	sb.border_color = _theme["bright"]
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left   = 8.0
	sb.content_margin_right  = 10.0
	sb.content_margin_top    = 3.0
	sb.content_margin_bottom = 3.0
	panel.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	panel.add_child(hb)

	var num_lbl := Label.new()
	num_lbl.text = num_text
	num_lbl.add_theme_font_size_override("font_size", 22)
	num_lbl.add_theme_color_override("font_color", _theme["core"])
	num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(num_lbl)

	var tag_lbl := Label.new()
	tag_lbl.text = tag
	tag_lbl.add_theme_font_size_override("font_size", 11)
	tag_lbl.add_theme_color_override("font_color", _theme["bright"])
	tag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(tag_lbl)

	add_child(panel)

	# Posiciona após o layout calcular o tamanho do chip.
	var gap := _card_size.x * 0.5 + 6.0
	var anchor := _tgt + Vector2(0.0, -6.0)
	await get_tree().process_frame
	if not is_instance_valid(panel):
		return
	var sz := panel.size
	if to_left:
		panel.position = anchor + Vector2(-gap - sz.x, -sz.y * 0.5)
	else:
		panel.position = anchor + Vector2(gap, -sz.y * 0.5)
	panel.pivot_offset = sz * 0.5

	panel.scale      = Vector2(0.4, 0.4)
	panel.modulate.a = 0.0
	var start_y := panel.position.y
	var pt := create_tween().set_parallel(true)
	pt.tween_property(panel, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pt.tween_property(panel, "modulate:a", 1.0, 0.2)
	pt.tween_property(panel, "position:y", start_y - 26.0, T_HOLD_END - T_BUFF_POP) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pt.chain().tween_property(panel, "modulate:a", 0.0, 0.3)
	pt.chain().tween_callback(panel.queue_free)

# ── Fade do feixe e fim ──────────────────────────────────────────────────────

func _fade_beam() -> void:
	var dur := T_FADE_END - T_FADE_START
	var ft := create_tween().set_parallel(true)
	for ln in [_line_glow, _line_mid, _line_core, _source_node]:
		if is_instance_valid(ln):
			ft.tween_property(ln, "modulate:a", 0.0, dur)
	ft.tween_method(func(v: float) -> void: _beam_intensity = v, 1.0, 0.0, dur)

func _create_banner() -> void:
	var vp := get_viewport().get_visible_rect().size
	var root := Control.new()
	root.position   = Vector2(vp.x * 0.5, vp.y * 0.5 - 60.0)
	root.modulate.a = 0.0
	root.z_index    = 15
	add_child(root)

	var sub := Label.new()
	sub.text = ability_subtitle
	sub.position = Vector2(-200.0, -40.0)
	sub.custom_minimum_size = Vector2(400.0, 18.0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", _theme["bright"])
	root.add_child(sub)

	var title := Label.new()
	title.text = ability_name
	title.position = Vector2(-200.0, -18.0)
	title.custom_minimum_size = Vector2(400.0, 44.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", _theme["core"])
	title.add_theme_color_override("font_shadow_color", _theme["glow"])
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.add_theme_constant_override("shadow_outline_size", 4)
	root.add_child(title)

	var t := create_tween()
	t.tween_property(root, "modulate:a", 1.0, 0.3).set_delay(0.1)
	t.tween_property(root, "modulate:a", 0.0, 0.4).set_delay(T_HOLD_END - 0.6)
	t.tween_callback(root.queue_free)

func _on_finished() -> void:
	_beam_running = false
	finished.emit()
	queue_free()
