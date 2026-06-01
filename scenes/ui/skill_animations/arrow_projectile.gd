# scenes/ui/skill_animations/arrow_projectile.gd
# Animação reutilizável: flecha voando de um ponto a outro na tela.
# Uso:
#   var arrow := ArrowProjectileScene.instantiate()
#   $UI.add_child(arrow)
#   arrow.animation_finished.connect(on_done)
#   arrow.play(from_global_pos, to_global_pos)
class_name ArrowProjectile
extends Node2D

signal animation_finished

const DURATION    := 0.70
const COLOR_HEAD  := Color(0.45, 0.92, 0.28)        # verde ranger
const COLOR_SHAFT := Color(0.75, 0.62, 0.30)        # madeira
const COLOR_FLASH := Color(0.55, 1.00, 0.30, 0.90)  # impacto

func play(from: Vector2, to: Vector2) -> void:
	var dir   := (to - from).normalized()
	var angle := dir.angle()

	# ── Haste (Line2D que cresce da origem até a ponta) ──
	var shaft := Line2D.new()
	shaft.width = 2.5
	shaft.default_color = COLOR_SHAFT
	shaft.add_point(from)
	shaft.add_point(from)   # ponta começa na origem; vai sendo atualizada
	add_child(shaft)

	# ── Pena (triângulo na cauda) ──
	var feather := Polygon2D.new()
	feather.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(-14, -5), Vector2(-9, 0), Vector2(-14, 5)
	])
	feather.color    = COLOR_HEAD.darkened(0.25)
	feather.rotation = angle
	feather.position = from
	add_child(feather)

	# ── Ponta da flecha (triângulo) ──
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([
		Vector2(12, 0), Vector2(-5, -5), Vector2(-5, 5)
	])
	head.color    = COLOR_HEAD
	head.rotation = angle
	head.position = from
	add_child(head)

	# ── Animação ──
	var tw := create_tween().set_parallel(true)

	# Haste cresce: ponto 1 vai de `from` até `to`
	tw.tween_method(
		func(v: Vector2) -> void: shaft.set_point_position(1, v),
		from, to, DURATION
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	# Pena segue a cauda (fica ~14 px atrás da ponta)
	tw.tween_property(feather, "position", to - dir * 14.0, DURATION)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	# Ponta vai da origem ao alvo
	tw.tween_property(head, "position", to, DURATION)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	# Após todas as tweens, dispara impacto
	tw.chain().tween_callback(func() -> void: _on_impact(to))

func _on_impact(pos: Vector2) -> void:
	visible = false
	_play_impact_flash(pos)

func _play_impact_flash(pos: Vector2) -> void:
	# Círculo que expande e some
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a), sin(a)) * 10.0)

	var flash := Polygon2D.new()
	flash.polygon  = pts
	flash.color    = COLOR_FLASH
	flash.position = pos
	get_parent().add_child(flash)

	# Raios de impacto (linhas curtas em 4 direções)
	for angle_deg in [0, 90, 180, 270]:
		var ray := Line2D.new()
		var dir := Vector2.from_angle(deg_to_rad(angle_deg))
		ray.add_point(pos + dir * 8.0)
		ray.add_point(pos + dir * 22.0)
		ray.width         = 2.0
		ray.default_color = COLOR_FLASH
		get_parent().add_child(ray)
		var tw_ray := create_tween()
		tw_ray.tween_property(ray, "modulate:a", 0.0, 0.25)
		tw_ray.tween_callback(ray.queue_free)

	var tw := create_tween()
	tw.tween_property(flash, "scale", Vector2(2.8, 2.8), 0.22).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(flash, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func() -> void:
		flash.queue_free()
		animation_finished.emit()
		queue_free()
	)
