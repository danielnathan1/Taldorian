## scenes/vfx/battle_fury/battle_fury.gd
## VFX persistente da habilidade ativa "Impacto Sísmico" de Poppy (reutilizável para qualquer buff de ataque).
##
## Ciclo de vida controlado externamente:
##   var fx := BattleFuryScene.instantiate()
##   add_child(fx)
##   fx.activate(card_node)              → carga 1.05s → estouro → AURA PERMANENTE
##   fx.deactivate()                     → fade-out 0.6s → queue_free() automático
##
## Sinais:
##   activated                 → disparado quando a aura permanente entra (≈ 1.05s)
##   deactivated               → disparado depois do fade-out (antes de queue_free)
##   atk_value_changed(int)    → tick do pump de ATQ (conecte ao badge da carta)
class_name BattleFury
extends CanvasLayer

# ── Configuração exportável (reutilizável por outros buffs) ───────────────────
@export var ability_name: String       = "IMPACTO SÍSMICO"
@export var ability_subtitle: String   = "Habilidade Ativa"
@export var atk_base: int              = 0
@export var atk_buffed: int            = 3
@export var aura_color: Color          = Color("#e87a3a")
@export var fade_in_duration: float    = 0.45
@export var deactivate_duration: float = 0.6

# ── Timeline (espelhado exatamente do Battle Fury.html) ───────────────────────
const T_CHARGE_START  := 0.0
const T_CHARGE_END    := 1.05
const T_BANNER_IN     := 0.2
const T_BANNER_OUT    := 3.2
const T_RUNE_IN       := 0.8
const T_BURST_AT      := 1.05
const T_ATK_PUMP_FROM := 1.05
const T_ATK_PUMP_TO   := 2.0
const T_ATK_POP_FROM  := 1.1

const NUM_SHARDS      := 14
const NUM_BURST_WAVES := 2
const NUM_EMBERS      := 28
const NUM_SPARKS      := 16

# ── Sinais ────────────────────────────────────────────────────────────────────
signal activated
signal deactivated
signal atk_value_changed(new_atk: int)

# ── Estado ────────────────────────────────────────────────────────────────────
enum State { IDLE, ACTIVATING, ACTIVE, DEACTIVATING, DEAD }
var _state: State = State.IDLE

var _card_node: CanvasItem = null
var _card_size: Vector2 = Vector2(90.0, 126.0)
var _rng := RandomNumberGenerator.new()

# Raiz que segue a carta frame-a-frame (todas as auras são filhas dela)
var _fx_root: Node2D = null

# Refs para controlar o fade-out
var _aura_nodes:    Array[Node]       = []
var _embers:        CPUParticles2D    = null
var _sparks:        CPUParticles2D    = null
var _breathe_tween: Tween             = null
var _spin_tween:    Tween             = null
# Timers da sequência de ativação (cancelados se deactivate() for chamado antes do fim)
var _activation_timers: Array[SceneTreeTimer] = []

# Status label do banner (texto trocado em T_BURST_AT)
var _status_label: Label = null

# ── API PÚBLICA ───────────────────────────────────────────────────────────────

## Ativa o buff ao redor de `card`. A cena segue a posição global da carta a cada frame.
## card_size: tamanho visual da carta em píxeis (default 90×126).
func activate(card: CanvasItem, card_size: Vector2 = Vector2(90.0, 126.0)) -> void:
	assert(_state == State.IDLE, "BattleFury: já foi ativada")
	_card_node = card
	_card_size = card_size
	_rng.seed  = 42
	_state     = State.ACTIVATING
	layer      = 50
	_build_root()
	_run_activation()

## Remove o buff. A cena faz fade-out e se auto-destrói.
## Aceita deactivate durante ACTIVATING (ex: combate resolve antes da carga terminar)
## e ignora silenciosamente se já está desativando ou morto.
func deactivate() -> void:
	if _state == State.DEACTIVATING or _state == State.DEAD or _state == State.IDLE:
		return
	_state = State.DEACTIVATING
	_run_deactivation()

func get_buffed_atk() -> int:
	return atk_buffed

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 50

func _process(_dt: float) -> void:
	# _fx_root segue o centro da carta continuamente
	if _fx_root and is_instance_valid(_fx_root) \
			and _card_node and is_instance_valid(_card_node):
		_fx_root.position = _get_card_center()

# ── Helpers de posição ────────────────────────────────────────────────────────

## Retorna o centro visual do nó-carta em coordenadas de tela.
## Usa get_global_transform().xform() para respeitar transforms dos pais,
## incluindo o scale=(-1,-1) aplicado no half_board do oponente.
func _get_card_center() -> Vector2:
	if _card_node is Control:
		var ctrl := _card_node as Control
		return ctrl.get_global_transform() * (ctrl.size * 0.5)
	return _card_node.get_global_transform().origin

# ── Construção do nó raiz ─────────────────────────────────────────────────────

func _build_root() -> void:
	_fx_root = Node2D.new()
	if _card_node and is_instance_valid(_card_node):
		_fx_root.position = _get_card_center()
	add_child(_fx_root)

# ── Helpers de timer rastreado ────────────────────────────────────────────────

## Cria um SceneTreeTimer e o registra para cancelamento caso deactivate() seja
## chamado antes do timeout. Use no lugar de get_tree().create_timer() durante a ativação.
func _timer(delay: float, cb: Callable) -> void:
	var t := get_tree().create_timer(delay, false)
	_activation_timers.append(t)
	t.timeout.connect(func() -> void:
		_activation_timers.erase(t)
		if _state != State.DEACTIVATING and _state != State.DEAD:
			cb.call()
	)

# ── Sequência de ativação ─────────────────────────────────────────────────────

func _run_activation() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var center  := vp_size * 0.5

	_create_screen_flash(vp_size)
	_create_charge_glow()
	_create_light_beam()
	_create_rune_circle()
	_create_banner(center)
	_create_aura_rings()
	_create_particle_systems()

	# Estouro
	_timer(T_BURST_AT, _trigger_burst)
	# Aura permanente
	_timer(T_CHARGE_END, _enable_persistent_aura)
	# Texto do banner
	_timer(T_BURST_AT, func() -> void:
		if is_instance_valid(_status_label):
			_status_label.text = "Ataque ampliado"
	)
	# Pump ATQ e popup
	_schedule_atk_pump()
	_timer(T_ATK_POP_FROM, _spawn_atk_popup)

# ── Flash de tela ─────────────────────────────────────────────────────────────

func _create_screen_flash(vp_size: Vector2) -> void:
	var flash := ColorRect.new()
	flash.color        = Color(0.97, 0.85, 0.63, 0.0)
	flash.size         = vp_size
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ColorRect é Control — adicionar diretamente ao CanvasLayer (não ao _fx_root)
	add_child(flash)

	var tw := create_tween()
	tw.tween_interval(T_BURST_AT - 0.05)
	tw.tween_property(flash, "color:a", 0.32, 0.05)
	tw.tween_property(flash, "color:a", 0.0,  0.35)
	tw.tween_callback(flash.queue_free)

# ── Charge glow ───────────────────────────────────────────────────────────────

func _create_charge_glow() -> void:
	var glow := Sprite2D.new()
	glow.texture  = _make_radial_glow(256, Color("#fff0c8"), Color("#e87a3a"), Color("#9a4a25"))
	glow.position = Vector2.ZERO   # relativo ao _fx_root
	glow.scale    = Vector2(0.2, 0.2)
	glow.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material  = mat
	glow.z_index   = 6
	_fx_root.add_child(glow)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(glow, "modulate:a", 0.9, T_CHARGE_END) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(glow, "scale", Vector2(1.8, 1.8), T_CHARGE_END) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Breathing loop entra após o estouro
	_timer(T_CHARGE_END, func() -> void:
		if not is_instance_valid(glow):
			return
		_breathe_tween = create_tween().set_loops()
		_breathe_tween.tween_property(glow, "scale", Vector2(2.0, 2.0), 1.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_breathe_tween.tween_property(glow, "scale", Vector2(1.65, 1.65), 1.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	)
	_aura_nodes.append(glow)

# ── Light beam ────────────────────────────────────────────────────────────────

func _create_light_beam() -> void:
	var beam := Sprite2D.new()
	beam.texture  = _make_beam_tex(16, 128, Color("#ffd17a"))
	beam.position = Vector2(0.0, -_card_size.y * 0.5 - 20.0)
	beam.scale    = Vector2(1.0, 0.4)
	beam.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	beam.material  = mat
	beam.z_index   = -1
	_fx_root.add_child(beam)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(beam, "modulate:a", 0.8, 0.4).set_delay(T_CHARGE_END)
	tw.tween_property(beam, "scale:y",    1.0, 0.5).set_delay(T_CHARGE_END) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_aura_nodes.append(beam)

# ── Rune circle ───────────────────────────────────────────────────────────────

func _create_rune_circle() -> void:
	var rune := Sprite2D.new()
	rune.texture  = _make_rune_tex(256, 128, Color("#e87a3a"))
	rune.position = Vector2(0.0, _card_size.y * 0.5 + 10.0)
	rune.scale    = Vector2(0.4, 0.4)
	rune.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	rune.material  = mat
	rune.z_index   = -2
	_fx_root.add_child(rune)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(rune, "modulate:a", 1.0, 0.55).set_delay(T_RUNE_IN)
	tw.tween_property(rune, "scale",      Vector2(1.0, 1.0), 0.55).set_delay(T_RUNE_IN) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Rotação contínua após aparecer
	_timer(T_RUNE_IN, func() -> void:
		if not is_instance_valid(rune):
			return
		_spin_tween = create_tween().set_loops()
		_spin_tween.tween_property(rune, "rotation_degrees", 360.0, 20.0) \
			.as_relative().set_trans(Tween.TRANS_LINEAR)
	)
	_aura_nodes.append(rune)

# ── Aura rings + highlight + corners ─────────────────────────────────────────

func _create_aura_rings() -> void:
	var w := _card_size.x
	var h := _card_size.y

	# Anel externo — outline suave laranja-escuro
	var outer := _make_rect_ring_sprite(
		int(w + 38.0), int(h + 38.0), 4, Color("#e87a3a"), 0.75
	)
	outer.position = Vector2.ZERO
	outer.modulate.a = 0.0
	outer.z_index    = 6
	_fx_root.add_child(outer)

	# Anel interno — linha fina brilhante
	var inner := _make_rect_ring_sprite(
		int(w + 18.0), int(h + 18.0), 2, Color("#ffd17a"), 0.9
	)
	inner.position = Vector2.ZERO
	inner.modulate.a = 0.0
	inner.z_index    = 6
	_fx_root.add_child(inner)

	# Highlight exato da carta
	var hl := _make_rect_ring_sprite(
		int(w + 6.0), int(h + 6.0), 1, Color("#ffd17a"), 1.0
	)
	hl.position = Vector2.ZERO
	hl.modulate.a = 0.0
	hl.z_index    = 7
	_fx_root.add_child(hl)

	# Cantos em L nos quatro cantos da aura externa
	var ow := w + 38.0
	var oh := h + 38.0
	var corner_offsets := [
		Vector2(-ow * 0.5, -oh * 0.5),
		Vector2( ow * 0.5, -oh * 0.5),
		Vector2( ow * 0.5,  oh * 0.5),
		Vector2(-ow * 0.5,  oh * 0.5),
	]
	var corner_rots := [0.0, PI * 0.5, PI, -PI * 0.5]
	var corners: Array[Node] = []
	for i in 4:
		var sp := Sprite2D.new()
		sp.texture   = _make_corner_tex(24, Color("#ffd17a"))
		sp.position  = corner_offsets[i]
		sp.rotation  = corner_rots[i]
		sp.modulate  = Color(1.0, 1.0, 1.0, 0.0)
		sp.z_index   = 6
		_fx_root.add_child(sp)
		corners.append(sp)

	# Guardar refs para _enable_persistent_aura e _run_deactivation
	_fx_root.set_meta("ring_outer",  outer)
	_fx_root.set_meta("ring_inner",  inner)
	_fx_root.set_meta("highlight",   hl)
	_fx_root.set_meta("corners",     corners)

	_aura_nodes.append(outer)
	_aura_nodes.append(inner)
	_aura_nodes.append(hl)
	for c in corners:
		_aura_nodes.append(c)

# ── Sistemas de partículas ────────────────────────────────────────────────────

func _create_particle_systems() -> void:
	# EMBERS — brasas subindo da base da carta
	var emb := CPUParticles2D.new()
	emb.position               = Vector2(0.0, _card_size.y * 0.5 - 4.0)
	emb.amount                 = NUM_EMBERS
	emb.lifetime               = 1.8
	emb.one_shot               = false
	emb.explosiveness          = 0.0
	emb.randomness             = 0.8
	emb.emission_shape         = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emb.emission_rect_extents  = Vector2(_card_size.x * 0.5, 3.0)
	emb.direction              = Vector2(0.0, -1.0)
	emb.spread                 = 14.0
	emb.gravity                = Vector2(0.0, -30.0)
	emb.initial_velocity_min   = 42.0
	emb.initial_velocity_max   = 88.0
	emb.angular_velocity_min   = -60.0
	emb.angular_velocity_max   = 60.0
	emb.scale_amount_min       = 0.4
	emb.scale_amount_max       = 1.2
	emb.color                  = Color("#ffd17a")
	emb.texture                = _make_ember_tex(24)
	emb.emitting               = false
	emb.z_index                = 10
	_fx_root.add_child(emb)
	_embers = emb

	# SPARKS — faíscas piscando nas bordas
	var spk := CPUParticles2D.new()
	spk.position               = Vector2.ZERO
	spk.amount                 = NUM_SPARKS
	spk.lifetime               = 0.45
	spk.one_shot               = false
	spk.explosiveness          = 0.0
	spk.randomness             = 1.0
	spk.emission_shape         = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	spk.emission_rect_extents  = Vector2(_card_size.x * 0.5 + 10.0, _card_size.y * 0.5 + 10.0)
	spk.direction              = Vector2(0.0, 0.0)
	spk.spread                 = 180.0
	spk.gravity                = Vector2.ZERO
	spk.initial_velocity_min   = 0.0
	spk.initial_velocity_max   = 5.0
	spk.scale_amount_min       = 0.6
	spk.scale_amount_max       = 1.5
	spk.color                  = Color(1.0, 0.90, 0.55)
	spk.texture                = _make_spark_tex(16)
	spk.emitting               = false
	spk.z_index                = 10
	_fx_root.add_child(spk)
	_sparks = spk

# ── Banner central ────────────────────────────────────────────────────────────

func _create_banner(center: Vector2) -> void:
	var font_bold    = load("res://assets/fonts/CinzelDecorative-Bold.ttf")
	var font_regular = load("res://assets/fonts/Cinzel_Decorative/CinzelDecorative-Regular.ttf")

	var root := Node2D.new()
	root.position   = center - Vector2(0.0, 22.0)
	root.modulate.a = 0.0
	root.z_index    = 20
	# Banner fica direto no CanvasLayer (posição de tela, não relativo à carta)
	add_child(root)

	# Subtítulo
	var sub := Label.new()
	sub.text = ability_subtitle
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.94, 0.82, 0.47))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position             = Vector2(-200.0, -72.0)
	sub.custom_minimum_size  = Vector2(400.0, 20.0)
	if font_regular:
		sub.add_theme_font_override("font", font_regular)
	root.add_child(sub)

	# Título
	var title := Label.new()
	title.text = ability_name
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color",         Color(1.00, 0.89, 0.70))
	title.add_theme_color_override("font_shadow_color",  Color(0.91, 0.48, 0.23, 0.85))
	title.add_theme_constant_override("shadow_offset_x",   0)
	title.add_theme_constant_override("shadow_offset_y",   2)
	title.add_theme_constant_override("shadow_outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position             = Vector2(-200.0, -44.0)
	title.custom_minimum_size  = Vector2(400.0, 52.0)
	if font_bold:
		title.add_theme_font_override("font", font_bold)
	root.add_child(title)

	# Linha decorativa laranja
	var rule := ColorRect.new()
	rule.color    = Color(0.91, 0.48, 0.23, 0.70)
	rule.size     = Vector2(280.0, 1.0)
	rule.position = Vector2(-140.0, 13.0)
	root.add_child(rule)

	# Status (muda em T_BURST_AT)
	_status_label = Label.new()
	_status_label.text = "Canalizando fúria"
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.94, 0.82, 0.47, 0.85))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.position             = Vector2(-200.0, 20.0)
	_status_label.custom_minimum_size  = Vector2(400.0, 18.0)
	if font_regular:
		_status_label.add_theme_font_override("font", font_regular)
	root.add_child(_status_label)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(root, "modulate:a", 1.0, 0.35).set_delay(T_BANNER_IN)
	tw.tween_property(root, "modulate:a", 0.0, 0.45).set_delay(T_BANNER_OUT - 0.45)
	tw.chain().tween_callback(root.queue_free)

# ── Estouro (T_BURST_AT) ──────────────────────────────────────────────────────

func _trigger_burst() -> void:
	for i in NUM_BURST_WAVES:
		_timer(float(i) * 0.18, _spawn_burst_wave)
	_spawn_burst_shards()

func _spawn_burst_wave() -> void:
	var wave := Sprite2D.new()
	wave.texture  = _make_ring_tex(256, Color("#e87a3a"))
	wave.position = Vector2.ZERO
	wave.scale    = Vector2(0.12, 0.12)
	wave.z_index  = 7
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	wave.material  = mat
	_fx_root.add_child(wave)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(wave, "scale",      Vector2(2.5, 2.5), 0.55) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(wave, "modulate:a", 0.0,              0.55)
	tw.chain().tween_callback(wave.queue_free)

func _spawn_burst_shards() -> void:
	for i in NUM_SHARDS:
		var angle: float = (float(i) / NUM_SHARDS) * TAU \
			+ _rng.randf_range(-0.1, 0.1)
		var r0:     float = 22.0
		var travel: float = 50.0 + _rng.randf_range(0.0, 32.0)

		var start_pos := Vector2(cos(angle) * r0,         sin(angle) * r0)
		var end_pos   := Vector2(cos(angle) * (r0 + travel), sin(angle) * (r0 + travel))

		var line := ColorRect.new()
		line.color    = Color("#ffd17a")
		line.size     = Vector2(1.5, 18.0)
		line.pivot_offset = Vector2(0.75, 9.0)
		line.rotation = angle + PI * 0.5
		line.position = start_pos - Vector2(0.75, 9.0).rotated(angle + PI * 0.5)
		line.z_index  = 7
		_fx_root.add_child(line)

		var final_pos := end_pos - Vector2(0.75, 9.0).rotated(angle + PI * 0.5)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(line, "position",   final_pos, 0.55) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(line, "modulate:a", 0.0,       0.55)
		tw.chain().tween_callback(line.queue_free)

# ── Aura permanente entra ─────────────────────────────────────────────────────

func _enable_persistent_aura() -> void:
	var outer   = _fx_root.get_meta("ring_outer") as Sprite2D
	var inner   = _fx_root.get_meta("ring_inner") as Sprite2D
	var hl      = _fx_root.get_meta("highlight")  as Sprite2D
	var corners = _fx_root.get_meta("corners")    as Array

	var tw := create_tween().set_parallel(true)
	tw.tween_property(outer, "modulate:a", 0.9, fade_in_duration)
	tw.tween_property(inner, "modulate:a", 1.0, fade_in_duration)
	tw.tween_property(hl,    "modulate:a", 1.0, fade_in_duration)
	for c in corners:
		if is_instance_valid(c):
			tw.tween_property(c, "modulate:a", 1.0, fade_in_duration)

	# Anéis respiram em loop (outer)
	_breathe_tween = create_tween().set_loops()
	_breathe_tween.tween_property(outer, "scale", Vector2(1.04, 1.04), 1.425) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breathe_tween.tween_property(outer, "scale", Vector2(0.96, 0.96), 1.425) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if _embers:
		_embers.emitting = true
	if _sparks:
		_sparks.emitting = true

	_state = State.ACTIVE
	activated.emit()

# ── Pump do número de ATQ ─────────────────────────────────────────────────────

func _schedule_atk_pump() -> void:
	if atk_base == atk_buffed:
		return
	var dur := T_ATK_PUMP_TO - T_ATK_PUMP_FROM
	_timer(T_ATK_PUMP_FROM, func() -> void:
		var pump := create_tween()
		pump.tween_method(
			func(v: float) -> void: atk_value_changed.emit(int(round(v))),
			float(atk_base), float(atk_buffed), dur
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)

# ── Popup "+N ATQ" ────────────────────────────────────────────────────────────

func _spawn_atk_popup() -> void:
	var diff := atk_buffed - atk_base
	if diff <= 0:
		return
	var font_bold = load("res://assets/fonts/CinzelDecorative-Bold.ttf")

	var lbl := Label.new()
	lbl.text = "+%d ATQ" % diff
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color",        Color(1.00, 0.82, 0.48))
	lbl.add_theme_color_override("font_shadow_color", Color(0.55, 0.20, 0.05, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x",    0)
	lbl.add_theme_constant_override("shadow_offset_y",    2)
	lbl.add_theme_constant_override("shadow_outline_size", 8)
	if font_bold:
		lbl.add_theme_font_override("font", font_bold)

	# Posição em coordenadas de tela — acima e à direita do centro da carta
	if _card_node and is_instance_valid(_card_node):
		lbl.position = _get_card_center() + Vector2(50.0, -70.0)
	else:
		lbl.position = Vector2(760.0, 470.0)
	add_child(lbl)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 35.0, 1.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.85).set_delay(0.55)
	tw.chain().tween_callback(lbl.queue_free)

# ── Desativação ───────────────────────────────────────────────────────────────

func _run_deactivation() -> void:
	# Invalida timers de ativação pendentes para que não disparem após o queue_free
	_activation_timers.clear()

	if _embers and is_instance_valid(_embers):
		_embers.emitting = false
	if _sparks and is_instance_valid(_sparks):
		_sparks.emitting = false
	if _breathe_tween:
		_breathe_tween.kill()
		_breathe_tween = null
	if _spin_tween:
		_spin_tween.kill()
		_spin_tween = null

	# Se não há nós visíveis ainda (deactivate() durante a carga), apenas limpa
	var tw := create_tween().set_parallel(true)
	var had_visible := false
	for n in _aura_nodes:
		if is_instance_valid(n) and (n as CanvasItem).modulate.a > 0.0:
			tw.tween_property(n, "modulate:a", 0.0, deactivate_duration) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			had_visible = true
	# Fade o glow de carga mesmo que ainda esteja animando (pode estar parcialmente visível)
	if not had_visible:
		tw.tween_interval(0.01)  # garante que o tween tenha pelo menos um step

	atk_value_changed.emit(atk_base)

	tw.chain().tween_callback(func() -> void:
		_state = State.DEAD
		deactivated.emit()
		queue_free()
	)

# ═════════════════════════════════════════════════════════════════════════════
# GERAÇÃO PROCEDURAL DE TEXTURAS
# Todas as texturas são criadas via Image API — sem arquivos externos necessários.
# ═════════════════════════════════════════════════════════════════════════════

## Glow radial: núcleo branco → laranja → vermelho profundo
func _make_radial_glow(size: int, col_core: Color, col_mid: Color, col_outer: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var hsize := size * 0.5
	for y in size:
		for x in size:
			var dx := (float(x) - hsize) / hsize
			var dy := (float(y) - hsize) / hsize
			var d  := sqrt(dx * dx + dy * dy)
			var t  := clampf(1.0 - d, 0.0, 1.0)
			var c: Color
			if t > 0.6:
				c = col_core.lerp(col_mid, 1.0 - (t - 0.6) / 0.4)
			else:
				c = col_mid.lerp(col_outer, 1.0 - t / 0.6)
			c.a = pow(t, 1.3)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

## Feixe vertical com gradiente alpha (cima brilhante → baixo transparente)
func _make_beam_tex(w: int, h: int, col: Color) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var ty: float = float(y) / float(h - 1)          # 0 = cima, 1 = baixo
		var a_y: float = pow(1.0 - ty, 1.5) * 0.85
		for x in w:
			var tx: float = abs(float(x) / float(w - 1) - 0.5) * 2.0
			var a_x: float = clampf(1.0 - tx * tx * 3.0, 0.0, 1.0)
			var px := col
			px.a   = a_y * a_x
			img.set_pixel(x, y, px)
	return ImageTexture.create_from_image(img)

## Círculo rúnico achatado (3 elipses + ticks radiais)
func _make_rune_tex(w: int, h: int, col: Color) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var cx := w * 0.5
	var cy := h * 0.5

	# Três anéis elípticos
	var rings := [
		{ "rx": w * 0.47, "ry": h * 0.40, "thick": 1.2, "a": 0.45 },
		{ "rx": w * 0.35, "ry": h * 0.30, "thick": 1.5, "a": 0.65 },
		{ "rx": w * 0.22, "ry": h * 0.19, "thick": 1.2, "a": 0.90 },
	]
	for ring in rings:
		var rx: float    = ring["rx"]
		var ry: float    = ring["ry"]
		var thick: float = ring["thick"]
		var alpha: float = ring["a"]
		for y in h:
			for x in w:
				var ex: float = (float(x) - cx) / rx
				var ey: float = (float(y) - cy) / ry
				var dist_norm := sqrt(ex * ex + ey * ey)
				var dist_px   := absf(dist_norm - 1.0) * minf(rx, ry)
				if dist_px < thick + 1.5:
					var t := clampf(1.0 - dist_px / (thick + 1.5), 0.0, 1.0)
					var prev := img.get_pixel(x, y)
					var nc := col
					nc.a   = maxf(prev.a, t * alpha)
					img.set_pixel(x, y, nc)

	# Ticks radiais (8 marcas)
	for i in 8:
		var angle := (float(i) / 8.0) * TAU
		for step in 14:
			var r := 0.76 + float(step) / 14.0 * 0.18
			var px := int(cx + cos(angle) * w * 0.47 * r)
			var py := int(cy + sin(angle) * h * 0.40 * r)
			if px >= 0 and px < w and py >= 0 and py < h:
				img.set_pixel(px, py, Color(col.r, col.g, col.b, 0.85))
	return ImageTexture.create_from_image(img)

## Anel circular — para as ondas de estouro
func _make_ring_tex(size: int, col: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var hsize := size * 0.5
	var r     := hsize * 0.90
	var thick := 4.0
	for y in size:
		for x in size:
			var dx := float(x) - hsize
			var dy := float(y) - hsize
			var d  := sqrt(dx * dx + dy * dy)
			var dist := absf(d - r)
			if dist < thick + 1.5:
				var t := clampf(1.0 - dist / (thick + 1.5), 0.0, 1.0)
				var c := col
				c.a   = t * 0.90
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

## Retângulo outline (para aura rings) — retorna Sprite2D com textura centrada
func _make_rect_ring_sprite(w: int, h: int, border: int, col: Color, alpha: float) -> Sprite2D:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	for x in w:
		for b in range(0, border + 2):
			# Borda superior
			var ta := clampf(float(b) / float(border + 1), 0.0, 1.0)
			var sa := ta * alpha
			if b < h:
				var prev := img.get_pixel(x, b)
				if sa > prev.a:
					img.set_pixel(x, b, Color(col.r, col.g, col.b, sa))
			# Borda inferior
			var yb := h - 1 - b
			if yb >= 0 and yb < h:
				var prev := img.get_pixel(x, yb)
				if sa > prev.a:
					img.set_pixel(x, yb, Color(col.r, col.g, col.b, sa))

	for y in h:
		for b in range(0, border + 2):
			var ta := clampf(float(b) / float(border + 1), 0.0, 1.0)
			var sa := ta * alpha
			# Borda esquerda
			if b < w:
				var prev := img.get_pixel(b, y)
				if sa > prev.a:
					img.set_pixel(b, y, Color(col.r, col.g, col.b, sa))
			# Borda direita
			var xr := w - 1 - b
			if xr >= 0 and xr < w:
				var prev := img.get_pixel(xr, y)
				if sa > prev.a:
					img.set_pixel(xr, y, Color(col.r, col.g, col.b, sa))

	var tex := ImageTexture.create_from_image(img)
	var sp  := Sprite2D.new()
	sp.texture          = tex
	sp.centered         = true
	return sp

## Canto em "L" — dois traços finos perpendiculares
func _make_corner_tex(size: int, col: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var len := int(size * 0.55)
	# Traço horizontal
	for x in len:
		img.set_pixel(x, 0, Color(col.r, col.g, col.b, 0.95))
		if size > 1:
			img.set_pixel(x, 1, Color(col.r, col.g, col.b, 0.50))
	# Traço vertical
	for y in len:
		img.set_pixel(0, y, Color(col.r, col.g, col.b, 0.95))
		if size > 1:
			img.set_pixel(1, y, Color(col.r, col.g, col.b, 0.50))
	return ImageTexture.create_from_image(img)

## Brasa com halo radial
func _make_ember_tex(size: int) -> ImageTexture:
	var img  := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := size * 0.5
	for y in size:
		for x in size:
			var dx := float(x) - half
			var dy := float(y) - half
			var d  := sqrt(dx * dx + dy * dy) / half
			var a: float
			if d < 0.22:
				a = 1.0
			elif d < 0.55:
				a = 1.0 - (d - 0.22) / 0.33
			else:
				a = 0.0
			img.set_pixel(x, y, Color(1.0, 0.85, 0.50, a))
	return ImageTexture.create_from_image(img)

## Faísca — ponto brilhante pequeno
func _make_spark_tex(size: int) -> ImageTexture:
	var img  := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := size * 0.5
	for y in size:
		for x in size:
			var dx := float(x) - half
			var dy := float(y) - half
			var d  := sqrt(dx * dx + dy * dy) / half
			var a  := clampf(1.0 - d * d * 1.8, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 0.92, 0.70, a))
	return ImageTexture.create_from_image(img)
