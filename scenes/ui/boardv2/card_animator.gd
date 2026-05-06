# scenes/ui/boardv2/card_animator.gd
# Anima cartas voando entre posições de tela (deck↔mão, mão↔cemitério/combate).
# Funciona em cima de um CanvasLayer separado — puramente visual, sem tocar no estado do jogo.
class_name CardAnimator
extends Node

const CARD_W   := 112.0
const CARD_H   := 168.0
const ARC_H    := -115.0
const DURATION := 0.44

const _COL_DRAW    := Color(0.50, 0.85, 1.00, 0.90)
const _COL_DISCARD := Color(1.00, 0.50, 0.45, 0.90)

var _layer: CanvasLayer

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)

# Carta face-down (sleeve) voando do deck para a mão.
func fly_draw(from_pos: Vector2, to_pos: Vector2, sleeve: Texture2D) -> void:
	_fly(from_pos, to_pos, sleeve, _COL_DRAW)

# Carta face-up voando da mão para o cemitério / zona de combate.
func fly_discard(from_pos: Vector2, to_pos: Vector2, card_tex: Texture2D) -> void:
	_fly(from_pos, to_pos, card_tex, _COL_DISCARD)

func _fly(from_pos: Vector2, to_pos: Vector2, texture: Texture2D, pcolor: Color) -> void:
	var ghost := TextureRect.new()
	ghost.size         = Vector2(CARD_W, CARD_H)
	ghost.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_SCALE
	ghost.pivot_offset = Vector2(CARD_W / 2.0, CARD_H / 2.0)
	ghost.texture      = texture
	_layer.add_child(ghost)
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
