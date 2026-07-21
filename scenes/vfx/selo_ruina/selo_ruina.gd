## scenes/vfx/selo_ruina/selo_ruina.gd
## VFX autocontido da passiva "Selo da Ruína" da Lilith: uma névoa negra/violeta sai do
## slot da Lilith voando em ARCO (mesma trajetória Bézier + ondulação dos Mísseis/Rosas)
## até o herói-alvo, e ao chegar se dissipa num baforada que "assenta" no card. A partir
## daí a emanação contínua é responsabilidade do próprio HeroSlot (Hero.sealed_ruin).
## Puramente cosmético — NÃO causa dano nem toca no estado.
##
## Uso:
##   var fx := SeloRuinaScene.instantiate()
##   add_child(fx)
##   fx.play(lilith_slot_global_pos, target_slot_global_pos)
class_name SeloRuina
extends CanvasLayer

# ── Assets (reaproveitados dos Mísseis Mágicos, tingidos em violeta sombrio) ────
const _TEX_GLOW  := preload("res://scenes/vfx/magic_missiles/charge_glow.png")
const _TEX_ORB   := preload("res://scenes/vfx/magic_missiles/charge_orb.png")
const _TEX_SMOKE := preload("res://scenes/vfx/magic_missiles/spark_particle.png")
const _TEX_TRAIL := preload("res://scenes/vfx/magic_missiles/missile_trail.png")
const _TEX_BURST := preload("res://scenes/vfx/magic_missiles/impact_burst.png")

# ── Paleta: névoa da Ruína (violeta sombrio / abissal) ─────────────────────────
const _C_GLOW := Color(0.42, 0.16, 0.55)   # halo violeta (aditivo)
const _C_CORE := Color(0.12, 0.05, 0.18)   # núcleo escuro da névoa (normal)
const _C_MIST := Color(0.30, 0.12, 0.42)   # partículas de fumaça

## Emitido quando a animação termina. O nó se auto-destrói logo em seguida.
signal finished

@export var flight_time: float = 2.5

# Serpenteado da névoa: nº de meias-ondas e amplitude (px) do "S" ao longo do percurso.
const _SNAKE_WAVES := 3.4
const _SNAKE_AMP   := 46.0

var _source: Vector2
var _target: Vector2
var _mist_layer:   Node2D
var _impact_layer: Node2D

func _ready() -> void:
	layer = 50

# ── API pública ────────────────────────────────────────────────────────────────

## source_pos — posição global do slot da Lilith (origem da névoa).
## target_pos — posição global do slot do herói selado (destino).
func play(source_pos: Vector2, target_pos: Vector2) -> void:
	_source = source_pos
	_target = target_pos
	_mist_layer   = _make_layer(13)
	_impact_layer = _make_layer(15)
	_spawn_mist()
	get_tree().create_timer(flight_time + 0.9, false).timeout.connect(_on_finished)

func _make_layer(z: int) -> Node2D:
	var n := Node2D.new()
	n.z_index = z
	add_child(n)
	return n

func _add_mat(node: CanvasItem) -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	node.material = mat

# ── Trajetória curva (Bézier cúbica + ondulação — igual Rosas/Mísseis) ──────────

func _build_path() -> Dictionary:
	var p0: Vector2  = _source
	var p3: Vector2  = _target + Vector2(0.0, 6.0)
	var dir: Vector2 = (p3 - p0).normalized()
	var nrm := Vector2(-dir.y, dir.x)
	var length: float = p0.distance_to(p3)
	var c1: Vector2 = p0 + dir * length * 0.30 + nrm * 80.0
	var c2: Vector2 = p0 + dir * length * 0.72 + nrm * 44.0
	var bounds := get_viewport().get_visible_rect().grow(-24.0)
	c1 = _clamp_to_rect(c1, bounds)
	c2 = _clamp_to_rect(c2, bounds)
	return { "p0": p0, "c1": c1, "c2": c2, "p3": p3 }

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

func _mist_pos(p: Dictionary, u: float) -> Vector2:
	var base := _cbez(p, u)
	var tan := _cbez_tangent(p, u).normalized()
	var wn := Vector2(-tan.y, tan.x)
	# fade = sin(u·π): zero nas pontas (sai da Lilith, chega no alvo), máx no meio → o
	# "S" da serpente incha no percurso sem descolar dos dois cantos.
	var fade := sin(u * PI)
	var wob := sin(u * PI * _SNAKE_WAVES) * _SNAKE_AMP * fade
	return base + wn * wob

func _ease_in_out_cubic(t: float) -> float:
	return 4.0 * t * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0

# ── Névoa em voo ────────────────────────────────────────────────────────────────

func _spawn_mist() -> void:
	var path := _build_path()

	var mist := Node2D.new()
	_mist_layer.add_child(mist)

	# Halo violeta aditivo (dá o brilho abissal).
	var halo := Sprite2D.new()
	halo.texture  = _TEX_GLOW
	halo.scale    = Vector2(0.55, 0.55)
	halo.modulate = Color(_C_GLOW.r, _C_GLOW.g, _C_GLOW.b, 0.85)
	_add_mat(halo)
	mist.add_child(halo)

	# Núcleo escuro (blend normal — a névoa é sombria; ADD apagaria o corpo).
	var core := Sprite2D.new()
	core.texture  = _TEX_ORB
	core.scale    = Vector2(0.40, 0.40)
	core.modulate = Color(_C_CORE.r, _C_CORE.g, _C_CORE.b, 0.9)
	mist.add_child(core)

	# Fumaça arrastada — parece uma trilha de névoa.
	var smoke := CPUParticles2D.new()
	smoke.texture              = _TEX_SMOKE
	smoke.amount               = 26
	smoke.lifetime             = 0.8
	smoke.local_coords         = false
	smoke.spread               = 40.0
	smoke.direction            = Vector2(0.0, -1.0)
	smoke.gravity              = Vector2(0.0, -20.0)
	smoke.initial_velocity_min = 10.0
	smoke.initial_velocity_max = 40.0
	smoke.scale_amount_min     = 0.25
	smoke.scale_amount_max     = 0.55
	smoke.color                = Color(_C_MIST.r, _C_MIST.g, _C_MIST.b, 0.55)
	smoke.emitting             = true
	mist.add_child(smoke)

	# Rastro Line2D que sampleia o próprio "S" da serpente — o corpo de sombra que
	# serpenteia atrás da cabeça (mesma técnica das Rosas/Mísseis).
	var trail := Line2D.new()
	trail.width          = 9.0
	trail.joint_mode     = Line2D.LINE_JOINT_ROUND
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode   = Line2D.LINE_CAP_ROUND
	trail.texture        = _TEX_TRAIL
	trail.texture_mode   = Line2D.LINE_TEXTURE_STRETCH
	_add_mat(trail)
	var grad := Gradient.new()
	grad.set_color(0, Color(_C_GLOW.r, _C_GLOW.g, _C_GLOW.b, 0.0))
	grad.set_color(1, Color(_C_GLOW.r, _C_GLOW.g, _C_GLOW.b, 0.55))
	trail.gradient = grad
	_mist_layer.add_child(trail)

	var trail_steps := 18
	var trail_span  := 0.28

	var fly := create_tween()
	fly.tween_method(
		func(local: float) -> void:
			if not is_instance_valid(mist):
				return
			var u := _ease_in_out_cubic(local)
			mist.position = _mist_pos(path, u)
			if is_instance_valid(trail):
				var pts := PackedVector2Array()
				for i in range(trail_steps, -1, -1):
					var uu: float = u - (float(i) / float(trail_steps)) * trail_span
					if uu < 0.0:
						continue
					pts.append(_mist_pos(path, uu))
				trail.points = pts,
		0.0, 1.0, flight_time
	)
	fly.tween_callback(func() -> void:
		if is_instance_valid(smoke):
			smoke.emitting = false
		mist.queue_free()
		if is_instance_valid(trail):
			var tt := create_tween()
			tt.tween_property(trail, "modulate:a", 0.0, 0.25)
			tt.tween_callback(trail.queue_free)
		_on_impact(path.p3)
	)

# ── Impacto: baforada que "assenta" no card ─────────────────────────────────────

func _on_impact(pos: Vector2) -> void:
	# Anel violeta que expande e some (o selo se fecha).
	var ring := Sprite2D.new()
	ring.texture  = _TEX_BURST
	ring.position = pos
	ring.scale    = Vector2(0.10, 0.10)
	ring.modulate = _C_GLOW
	_add_mat(ring)
	_impact_layer.add_child(ring)
	var rt := create_tween().set_parallel(true)
	rt.tween_property(ring, "scale", Vector2(0.85, 0.85), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rt.tween_property(ring, "modulate:a", 0.0, 0.45)
	rt.chain().tween_callback(ring.queue_free)

	# Baforada de fumaça que sobe e se dissipa sobre o herói.
	var puff := CPUParticles2D.new()
	puff.position             = pos
	puff.texture              = _TEX_SMOKE
	puff.amount               = 14
	puff.lifetime             = 0.8
	puff.one_shot             = true
	puff.explosiveness        = 0.85
	puff.spread               = 180.0
	puff.direction            = Vector2(0.0, -1.0)
	puff.gravity              = Vector2(0.0, -40.0)
	puff.initial_velocity_min = 20.0
	puff.initial_velocity_max = 70.0
	puff.scale_amount_min     = 0.3
	puff.scale_amount_max     = 0.7
	puff.color                = Color(_C_MIST.r, _C_MIST.g, _C_MIST.b, 0.7)
	puff.emitting             = true
	_impact_layer.add_child(puff)
	get_tree().create_timer(1.0, false).timeout.connect(puff.queue_free)

# ── Fim ──────────────────────────────────────────────────────────────────────────

func _on_finished() -> void:
	finished.emit()
	queue_free()
