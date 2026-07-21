# scenes/ui/boardv2/card_animator.gd
# Anima cartas voando entre posições de tela (deck↔mão, mão↔cemitério/combate).
# Funciona em cima de um CanvasLayer separado — puramente visual, sem tocar no estado do jogo.
class_name CardAnimator
extends Node

const CardViewScene := preload("res://scenes/ui/card_view/card_view.tscn")

const CARD_W   := 112.0
const CARD_H   := 168.0
const ARC_H    := -115.0
const DURATION := 0.44

# Puxar carta (robusto): arco mais alto, pop de escala e rastro de "fantasmas".
const DRAW_DURATION := 0.62
const DRAW_ARC_H    := -190.0

# Descarte: mão → centro do board (apresenta) → cemitério.
const DISCARD_RISE_DUR := 0.42
const DISCARD_HOLD     := 0.20
const DISCARD_FALL_DUR := 0.44

const _COL_DRAW    := Color(0.50, 0.85, 1.00, 0.90)
const _COL_DISCARD := Color(1.00, 0.50, 0.45, 0.90)
const _COL_TODECK  := Color(0.55, 0.75, 1.00, 0.90)

var _layer: CanvasLayer

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)

# Carta face-down (sleeve) voando do deck para a mão — versão robusta: arco alto,
# pop de escala com overshoot, giro suave, rastro de "fantasmas" + faíscas.
func fly_draw(from_pos: Vector2, to_pos: Vector2, sleeve: Texture2D, on_done: Callable = Callable()) -> void:
	var ghost := _make_ghost(sleeve)
	_layer.add_child(ghost)
	ghost.position = from_pos - ghost.pivot_offset
	ghost.scale    = Vector2(0.45, 0.45)
	_burst(from_pos, _COL_DRAW, 8)

	var trail_acc := 0.0
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(ghost):
			return
		var e := 1.0 - pow(1.0 - t, 3.0)
		var p := Vector2(
			lerpf(from_pos.x, to_pos.x, e),
			lerpf(from_pos.y, to_pos.y, e) + DRAW_ARC_H * sin(PI * t)
		)
		ghost.position = p - ghost.pivot_offset
		ghost.rotation = sin(t * PI) * 0.22
		# escala: cresce pequena→grande no auge e assenta com leve overshoot no fim
		var s := lerpf(0.45, 0.9, e) + 0.22 * sin(PI * t)
		if t > 0.82:
			s += 0.10 * sin((t - 0.82) / 0.18 * PI)   # popzinho ao chegar
		ghost.scale = Vector2(s, s)
		# rastro de fantasmas (afterimages) ao longo do caminho
		trail_acc += 1.0
		if trail_acc >= 3.0:
			trail_acc = 0.0
			_spawn_afterimage(sleeve, p, ghost.scale, ghost.rotation, _COL_DRAW)
		if randf() < 0.5:
			_spawn_particle(p, _COL_DRAW)
	, 0.0, 1.0, DRAW_DURATION).set_trans(Tween.TRANS_LINEAR)

	tw.tween_callback(func() -> void:
		_burst(to_pos, _COL_DRAW, 10)
		if is_instance_valid(ghost):
			ghost.queue_free()
		if on_done.is_valid():
			on_done.call()
	)

# Carta face-up voando da mão para o cemitério / zona de combate.
func fly_discard(from_pos: Vector2, to_pos: Vector2, card_tex: Texture2D, on_done: Callable = Callable(),
		card_dict: Dictionary = {}) -> void:
	_fly(from_pos, to_pos, card_tex, _COL_DISCARD, on_done, card_dict)

# Descarte com CORTE: a carta sobe e cresce no centro do board (apresenta), leva um
# talho rápido (streak diagonal + flash) e despenca PARTIDA EM DUAS METADES até o cemitério.
const _SLASH_DEG := -35.0

func fly_discard_to_graveyard(from_pos: Vector2, center_pos: Vector2, grave_pos: Vector2,
		card_tex: Texture2D, on_done: Callable = Callable(), card_dict: Dictionary = {}) -> void:
	var ghost := _spawn_card_node(card_dict, card_tex)
	ghost.position = from_pos - ghost.pivot_offset
	ghost.scale    = Vector2(0.85, 0.85)
	_burst(from_pos, _COL_DISCARD, 5)

	var tw := create_tween()
	# 1) mão → centro (sobe em arco, cresce — "apresenta" a carta)
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(ghost):
			return
		var e := 1.0 - pow(1.0 - t, 3.0)
		var p := from_pos.lerp(center_pos, e) + Vector2(0.0, ARC_H * 0.6 * sin(PI * t))
		ghost.position = p - ghost.pivot_offset
		ghost.rotation = sin(t * PI) * 0.12
		ghost.scale    = Vector2.ONE * lerpf(0.85, 1.3, e)
		if randf() < 0.3:
			_spawn_particle(p, _COL_DISCARD)
	, 0.0, 1.0, DISCARD_RISE_DUR)

	# 2) CORTE no centro — talho + flash, e remove a carta inteira
	tw.tween_callback(func() -> void:
		if is_instance_valid(ghost):
			ghost.queue_free()
		_slash_at(center_pos))

	# 3) breve hold pós-corte
	tw.tween_interval(DISCARD_HOLD)

	# 4) as duas metades despencam ao cemitério
	tw.tween_callback(func() -> void:
		_fall_cut_halves(center_pos, grave_pos, card_tex, on_done, card_dict))

# Talho diagonal rápido + flash branco na área da carta.
func _slash_at(center_pos: Vector2) -> void:
	var streak := ColorRect.new()
	streak.color        = Color(1.0, 0.96, 0.92, 0.95)
	streak.size         = Vector2(12.0, 300.0)
	streak.pivot_offset = streak.size * 0.5
	streak.rotation     = deg_to_rad(_SLASH_DEG)
	streak.position     = center_pos - streak.pivot_offset + Vector2(-110.0, 0.0)
	_layer.add_child(streak)
	var st := create_tween().set_parallel(true)
	st.tween_property(streak, "position:x", streak.position.x + 220.0, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	st.tween_property(streak, "modulate:a", 0.0, 0.18)
	st.chain().tween_callback(streak.queue_free)

	var flash := ColorRect.new()
	flash.color        = Color(1.0, 1.0, 1.0, 0.0)
	flash.size         = Vector2(CARD_W * 1.4, CARD_H * 1.4)
	flash.pivot_offset = flash.size * 0.5
	flash.position     = center_pos - flash.pivot_offset
	_layer.add_child(flash)
	var ft := create_tween()
	ft.tween_property(flash, "color:a", 0.55, 0.04)
	ft.tween_property(flash, "color:a", 0.0,  0.16)
	ft.tween_callback(flash.queue_free)

	_burst(center_pos, _COL_DISCARD, 10)

# Duas metades (cartas inteiras divergindo perpendicular ao corte) caem ao cemitério.
func _fall_cut_halves(center_pos: Vector2, grave_pos: Vector2, card_tex: Texture2D,
		on_done: Callable, card_dict: Dictionary = {}) -> void:
	var perp := Vector2(cos(deg_to_rad(_SLASH_DEG + 90.0)), sin(deg_to_rad(_SLASH_DEG + 90.0)))
	for i in 2:
		var dir := 1.0 if i == 0 else -1.0
		var ghost := _spawn_card_node(card_dict, card_tex)
		var start := center_pos + perp * (16.0 * dir)
		ghost.position = start - ghost.pivot_offset
		ghost.scale    = Vector2(1.3, 1.3)
		ghost.rotation = deg_to_rad(_SLASH_DEG)
		var tw := create_tween()
		tw.tween_method(func(t: float) -> void:
			if not is_instance_valid(ghost):
				return
			var e := t * t
			var p := start.lerp(grave_pos, e) + perp * (16.0 * dir) * (1.0 - e)
			ghost.position   = p - ghost.pivot_offset
			ghost.rotation   = deg_to_rad(_SLASH_DEG) + e * 1.0 * dir
			ghost.scale      = Vector2.ONE * lerpf(1.3, 0.3, e)
			ghost.modulate.a = 1.0 - 0.85 * e
			if randf() < 0.3:
				_spawn_particle(p, _COL_DISCARD)
		, 0.0, 1.0, DISCARD_FALL_DUR)
		var is_last := i == 0
		tw.tween_callback(func() -> void:
			if is_instance_valid(ghost):
				ghost.queue_free()
			if is_last:
				_burst(grave_pos, _COL_DISCARD, 9)
				if on_done.is_valid():
					on_done.call())

# Carta voando de volta para o BARALHO (ex.: colocar no fundo do deck): arco, encolhe,
# gira e some "entrando" no deck.
func fly_card_to_deck(from_pos: Vector2, deck_pos: Vector2, card_tex: Texture2D,
		on_done: Callable = Callable(), card_dict: Dictionary = {}) -> void:
	var ghost := _spawn_card_node(card_dict, card_tex)
	ghost.position = from_pos - ghost.pivot_offset
	ghost.scale    = Vector2(0.9, 0.9)
	_burst(from_pos, _COL_TODECK, 5)

	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(ghost):
			return
		var e := 1.0 - pow(1.0 - t, 3.0)
		var p := from_pos.lerp(deck_pos, e) + Vector2(0.0, ARC_H * 0.5 * sin(PI * t))
		ghost.position   = p - ghost.pivot_offset
		ghost.rotation   = sin(t * PI) * 0.3
		ghost.scale      = Vector2.ONE * lerpf(0.9, 0.32, e)
		ghost.modulate.a = 1.0 - 0.7 * e
		if randf() < 0.3:
			_spawn_particle(p, _COL_TODECK)
	, 0.0, 1.0, DURATION)

	tw.tween_callback(func() -> void:
		_burst(deck_pos, _COL_TODECK, 7)
		if is_instance_valid(ghost):
			ghost.queue_free()
		if on_done.is_valid():
			on_done.call()
	)

# Cria o nó da carta em voo. Se houver card_dict (do catálogo Collection.all_card_dicts),
# renderiza a CardView COMPLETA (moldura + arte + nome + atk/def + símbolo); senão, cai no
# ghost só-arte. O nó já entra em _layer aqui (a CardView precisa estar na árvore antes do
# bind_dict, que toca @onready). Retorna um Control (CardView ou TextureRect).
func _spawn_card_node(card_dict: Dictionary, tex: Texture2D) -> Control:
	if not card_dict.is_empty():
		return _make_card_ghost(card_dict)
	var g := _make_ghost(tex)
	_layer.add_child(g)
	return g

func _make_card_ghost(card_dict: Dictionary) -> Control:
	var cv: CardView = CardViewScene.instantiate()
	cv.custom_minimum_size = Vector2.ZERO
	cv.size         = Vector2(CARD_W, CARD_H)
	cv.pivot_offset = Vector2(CARD_W * 0.5, CARD_H * 0.5)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(cv)                 # antes do bind: bind_dict toca @onready (precisa _ready)
	cv.bind_dict(card_dict)
	cv.set_preview_enabled(false)
	cv.set_interactable(false, false)
	cv.apply_scale(CARD_W / 160.0)       # fontes proporcionais ao tamanho reduzido do voo
	return cv

# Cria o nó-carta (TextureRect) usado nas animações de voo (só-arte / fallback).
func _make_ghost(texture: Texture2D) -> TextureRect:
	var ghost := TextureRect.new()
	ghost.size         = Vector2(CARD_W, CARD_H)
	ghost.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_SCALE
	ghost.pivot_offset = Vector2(CARD_W / 2.0, CARD_H / 2.0)
	ghost.texture      = texture
	return ghost

# Cópia esmaecida da carta deixada no caminho (rastro de movimento).
func _spawn_afterimage(texture: Texture2D, center: Vector2, scale: Vector2, rot: float, tint: Color) -> void:
	var img := _make_ghost(texture)
	img.position = center - img.pivot_offset
	img.scale    = scale
	img.rotation = rot
	img.modulate = Color(tint.r, tint.g, tint.b, 0.45)
	_layer.add_child(img)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(img, "modulate:a", 0.0, 0.28)
	tw.tween_property(img, "scale", scale * 0.85, 0.28)
	tw.chain().tween_callback(img.queue_free)

func _fly(from_pos: Vector2, to_pos: Vector2, texture: Texture2D, pcolor: Color, on_done: Callable,
		card_dict: Dictionary = {}) -> void:
	var ghost := _spawn_card_node(card_dict, texture)
	ghost.position = from_pos - ghost.pivot_offset

	_burst(from_pos, pcolor, 6)

	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(ghost):
			return
		var e := 1.0 - pow(1.0 - t, 3.0)
		var p := Vector2(
			lerpf(from_pos.x, to_pos.x, e),
			lerpf(from_pos.y, to_pos.y, e) + ARC_H * sin(PI * t)
		)
		ghost.position = p - ghost.pivot_offset
		ghost.rotation = sin(t * PI) * 0.14
		var s := 0.82 + 0.22 * sin(t * PI)
		ghost.scale = Vector2(s, s)
		if randf() < 0.28:
			_spawn_particle(p, pcolor)
	, 0.0, 1.0, DURATION)

	tw.tween_callback(func() -> void:
		_burst(to_pos, pcolor, 8)
		if is_instance_valid(ghost):
			ghost.queue_free()
		if on_done.is_valid():
			on_done.call()
	)

func _burst(pos: Vector2, color: Color, count: int) -> void:
	for _i in count:
		_spawn_particle(pos, color)

func _spawn_particle(pos: Vector2, color: Color) -> void:
	var p := ColorRect.new()
	p.size         = Vector2(7.0, 7.0)
	p.pivot_offset = Vector2(3.5, 3.5)
	p.color        = color
	p.position     = pos + Vector2(randf_range(-16.0, 16.0), randf_range(-16.0, 16.0))
	_layer.add_child(p)

	var end_pos := p.position + Vector2(randf_range(-55.0, 55.0), randf_range(-75.0, -8.0))
	var pt := create_tween().set_parallel(true)
	pt.tween_property(p, "position",    end_pos,             0.50).set_ease(Tween.EASE_OUT)
	pt.tween_property(p, "modulate:a",  0.0,                 0.44)
	pt.tween_property(p, "scale",       Vector2(0.15, 0.15), 0.42)
	pt.set_parallel(false)
	pt.tween_callback(p.queue_free)
