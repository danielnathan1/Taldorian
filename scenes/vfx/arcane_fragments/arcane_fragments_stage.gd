## scenes/vfx/arcane_fragments/arcane_fragments_stage.gd
##
## Node2D que toca a timeline dos "Fragmentos Arcanos" em COORDENADAS GLOBAIS DE
## TELA (como o magic_missiles), leve sobre o board ao vivo — sem escurecer a
## tela, sem banner grande, sem runa cinemática. Cada frame é derivado de um
## único tempo `t`; todo o visual é desenhado via _draw() com blend ADITIVO —
## nenhuma textura PNG externa.
##
## Origem = posição do token do Fragmento. Destino = onde o clímax acontece
## (deck para o efeito 1; centro da combat zone para 2 e 3). Os fragmentos
## NASCEM no token e o estouro/luz acontece no destino.
##
## Escalada de intensidade (idêntica à referência):
##   1 = pedra única → detona · 2 = duas pedras → colisão + luz contida
##   · 3 = três pedras → órbita acelerando → fusão (raios + pilar de luz).
class_name ArcaneFragmentsStage
extends Node2D

# ── Timeline (segundos) ──────────────────────────────────────────────────────
# ── Efeito 1 — Impacto ──
const E1_REL    := 0.30   # pedra deixa o token
const E1_IMPACT := 1.25   # detonação no destino
const E1_END    := 2.55

# ── Efeito 2 — Colisão ──
const E2_REL    := 0.30
const E2_IMPACT := 1.25
const E2_END    := 2.95

# ── Efeito 3 — Fusão ──
const E3_ARRIVE  := 1.05   # fragmentos chegam ao anel orbital (no destino)
const E3_MERGE   := 2.05   # fusão / clímax
const E3_ORBIT_R := 64.0   # raio do anel (espaço de tela)
const E3_END     := 3.30

# ── Curvatura dos arcos (fração da distância origem→destino) ─────────────────
const E1_BOW := -0.34
const E2_BOW := 0.42      # duas pedras com bows opostos → "lente" que colide no destino

# ── Paleta arcana (idêntica ao HTML) ─────────────────────────────────────────
const C_CORE    := Color(0.99, 0.96, 1.00)   # núcleo branco-quente  #FCF5FF
const C_BRIGHT  := Color(0.85, 0.66, 1.00)   # violeta brilhante     #D9A8FF
const C_MID     := Color("#b07ef0")          # violeta médio
const C_DEEP    := Color("#7c5ae0")          # violeta profundo
const C_CRYSTAL := Color("#3a1e5c")          # corpo do cristal
const C_NAME    := Color("#eddafa")          # luz quente

# ── Faíscas/estilhaços pré-semeados (determinísticos) ────────────────────────
var _sparks: Array = []

# ── Estado ───────────────────────────────────────────────────────────────────
var _vfx: ArcaneFragments = null
var _effect := 1
var _origin := Vector2.ZERO
var _dest := Vector2.ZERO
var _end := E1_END
var _t := 0.0
var _done := false
var _scene := {}


# setup() é chamado ANTES de entrar na árvore.
func setup(p_vfx: ArcaneFragments, p_effect: int, p_origin: Vector2, p_dest: Vector2) -> void:
	_vfx = p_vfx
	_effect = clampi(p_effect, 1, 3)
	_origin = p_origin
	_dest = p_dest
	_end = [0.0, E1_END, E2_END, E3_END][_effect]
	_seed_sparks()


func _ready() -> void:
	# Blend aditivo em todo o desenho (glows somam → look arcano).
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_scene = _derive(0.0)
	queue_redraw()


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_scene = _derive(_t)
	queue_redraw()
	if _t >= _end + 0.4:
		_done = true
		_vfx._emit_finished()


# ════════════════════════════════════════════════════════════════════════════
#  Matemática
# ════════════════════════════════════════════════════════════════════════════
func _clamp01(v: float) -> float: return clampf(v, 0.0, 1.0)
func _ease_in_quad(t: float) -> float: return t * t
func _ease_in_cubic(t: float) -> float: return t * t * t
func _ease_out_cubic(t: float) -> float: return 1.0 - pow(1.0 - t, 3.0)


# Arco quadrático p0→p1; arc = deslocamento perpendicular (bow).
func _travel(p0: Vector2, p1: Vector2, u: float, arc := 0.0) -> Vector2:
	var mid := (p0 + p1) * 0.5
	var dir := (p1 - p0).normalized()
	var nrm := Vector2(-dir.y, dir.x)
	var c := mid + nrm * arc
	var v := 1.0 - u
	return v * v * p0 + 2.0 * v * u * c + u * u * p1


# Bow proporcional à distância origem→destino.
func _bow(p0: Vector2, p1: Vector2, frac: float) -> float:
	return p0.distance_to(p1) * frac


func _trail_of(pos_fn: Callable, time: float, n: int = 6, step: float = 0.028) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		pts.append(pos_fn.call(time - float(i) * step))
	return pts


# Posição orbital de um fragmento do Efeito 3 — nasce no token, abre até o anel
# (em volta do destino) e então gira acelerando enquanto colapsa ao destino.
func _e3_frag_pos(i: int, tt: float) -> Vector2:
	var base_ang := -PI / 2.0 + float(i) * (TAU / 3.0)
	if tt < E3_ARRIVE:
		var u := _ease_out_cubic(_clamp01((tt - 0.25) / (E3_ARRIVE - 0.25)))
		var target := _dest + Vector2(cos(base_ang), sin(base_ang)) * E3_ORBIT_R
		var arc := _bow(_origin, target, 0.16) * (1.0 if i == 0 else -1.0)
		return _travel(_origin, target, u, arc)
	var lt := _clamp01((tt - E3_ARRIVE) / (E3_MERGE - E3_ARRIVE))
	var spin := (lt + lt * lt * 1.8) * TAU * 2.4          # rotação acelerando
	var rad := lerpf(E3_ORBIT_R, 4.0, _ease_in_cubic(lt))  # raio encolhe a ~0
	var ang := base_ang + spin
	return _dest + Vector2(cos(ang), sin(ang)) * rad


func _seed_sparks() -> void:
	for i in 28:
		var a := (float(i) / 28.0) * TAU + fmod(float(i) * 1.7, 1.0) * 0.5
		var speed := 0.6 + fmod(float(i) * 0.37, 1.0) * 0.8
		var size := 0.6 + fmod(float(i) * 0.53, 1.0) * 1.3
		_sparks.append({"a": a, "speed": speed, "size": size})


# ════════════════════════════════════════════════════════════════════════════
#  Derivação da cena
# ════════════════════════════════════════════════════════════════════════════
func _derive(t: float) -> Dictionary:
	match _effect:
		2: return _derive_e2(t)
		3: return _derive_e3(t)
		_: return _derive_e1(t)


func _blank() -> Dictionary:
	return {
		"fragments": [], "bursts": [], "debris": [], "orbs": [], "rays": [],
		"pillar": 0.0, "dest_glow": 0.0, "origin_glow": 0.0,
	}


# ── Efeito 1 — pedra única → detona no destino ───────────────────────────────
func _derive_e1(t: float) -> Dictionary:
	var s := _blank()
	var flight := E1_IMPACT - E1_REL
	var fly_u := _clamp01((t - E1_REL) / flight)
	var arc := _bow(_origin, _dest, E1_BOW)
	s["origin_glow"] = _clamp01((E1_REL + 0.15 - t) / (E1_REL + 0.15))

	var dest_glow := 0.0
	if t >= E1_REL and t < E1_IMPACT:
		var eu := _ease_in_quad(fly_u)
		var p := _travel(_origin, _dest, eu, arc)
		var trail := _trail_of(
			func(tt: float) -> Vector2:
				return _travel(_origin, _dest, _ease_in_quad(_clamp01((tt - E1_REL) / flight)), arc),
			t)
		s["fragments"].append({
			"x": p.x, "y": p.y, "rot": t * 320.0,
			"scale": 0.85 + eu * 0.5, "glow": 0.5 + eu * 0.7, "trail": trail,
		})
		dest_glow = eu * 0.7

	var since := t - E1_IMPACT
	if since >= 0.0:
		var life := since / 1.3
		if life < 1.0:
			s["bursts"].append({"x": _dest.x, "y": _dest.y, "life": life, "intensity": 1.0})
			s["bursts"].append({"x": _dest.x, "y": _dest.y, "life": _clamp01(since / 0.7), "intensity": 0.55})
			s["debris"].append({"x": _dest.x, "y": _dest.y, "life": life, "spread": 200.0, "count": 22})
			dest_glow = maxf(dest_glow, (1.0 - life) * 0.9)

	s["dest_glow"] = dest_glow
	return s


# ── Efeito 2 — duas pedras nascem no token → colidem no destino → luz contida ─
func _derive_e2(t: float) -> Dictionary:
	var s := _blank()
	var flight := E2_IMPACT - E2_REL
	var fly_u := _clamp01((t - E2_REL) / flight)
	var arc := _bow(_origin, _dest, E2_BOW)
	# Ambas saem do token; bows OPOSTOS → separam no caminho e se chocam no destino.
	var pos_a := func(tt: float) -> Vector2:
		return _travel(_origin, _dest, _ease_in_quad(_clamp01((tt - E2_REL) / flight)), arc)
	var pos_b := func(tt: float) -> Vector2:
		return _travel(_origin, _dest, _ease_in_quad(_clamp01((tt - E2_REL) / flight)), -arc)
	s["origin_glow"] = _clamp01((E2_REL + 0.15 - t) / (E2_REL + 0.15))

	var dest_glow := 0.0
	if t >= E2_REL and t < E2_IMPACT:
		var eu := _ease_in_quad(fly_u)
		var pa: Vector2 = pos_a.call(t)
		var pb: Vector2 = pos_b.call(t)
		s["fragments"].append({
			"x": pa.x, "y": pa.y, "rot": t * 260.0,
			"scale": 0.8 + eu * 0.4, "glow": 0.45 + eu * 0.5, "trail": _trail_of(pos_a, t),
		})
		s["fragments"].append({
			"x": pb.x, "y": pb.y, "rot": -t * 260.0,
			"scale": 0.8 + eu * 0.4, "glow": 0.45 + eu * 0.5, "trail": _trail_of(pos_b, t),
		})
		dest_glow = eu * 0.35

	var since := t - E2_IMPACT
	if since >= 0.0:
		var bl := _clamp01(since / 0.5)
		if bl < 1.0:
			s["bursts"].append({"x": _dest.x, "y": _dest.y, "life": bl, "intensity": 0.42})
			s["debris"].append({"x": _dest.x, "y": _dest.y, "life": bl, "spread": 80.0, "count": 12})
		# Luz pequena sustentada (a "centelha contida") — o ponto do efeito 2.
		var orb_fade := _clamp01(since / 0.45) * _clamp01((E2_END - t) / 0.6)
		var pulse := 0.78 + 0.22 * sin(since * 5.5)
		s["orbs"].append({
			"x": _dest.x, "y": _dest.y,
			"r": 13.0 * pulse, "glow": orb_fade, "halo": 30.0 + 6.0 * sin(since * 4.0),
		})
		dest_glow = orb_fade * 0.5

	s["dest_glow"] = dest_glow
	return s


# ── Efeito 3 — três pedras → órbita → fusão (raios + pilar) no destino ───────
func _derive_e3(t: float) -> Dictionary:
	var s := _blank()
	s["origin_glow"] = _clamp01((0.6 - t) / 0.6)

	var dest_glow := 0.0
	if t < E3_MERGE:
		var lt := _clamp01((t - E3_ARRIVE) / (E3_MERGE - E3_ARRIVE))
		for i in 3:
			var p := _e3_frag_pos(i, t)
			s["fragments"].append({
				"x": p.x, "y": p.y, "rot": t * 300.0 + float(i) * 120.0,
				"scale": 0.85 + lt * 0.55, "glow": 0.5 + lt * 0.6,
				"trail": _trail_of(func(tt: float) -> Vector2: return _e3_frag_pos(i, tt), t, 7, 0.024),
			})
		dest_glow = 0.1 if t < E3_ARRIVE else 0.1 + lt * lt * 0.85

	var since := t - E3_MERGE
	if since >= 0.0:
		var life := since / 1.7
		if life < 1.0:
			s["bursts"].append({"x": _dest.x, "y": _dest.y, "life": life, "intensity": 1.35})
			s["bursts"].append({"x": _dest.x, "y": _dest.y, "life": _clamp01(since / 1.0), "intensity": 0.8})
			s["bursts"].append({"x": _dest.x, "y": _dest.y, "life": _clamp01(since / 0.6), "intensity": 0.5})
			s["debris"].append({"x": _dest.x, "y": _dest.y, "life": life, "spread": 300.0, "count": 28})
			s["rays"].append({"x": _dest.x, "y": _dest.y, "life": _clamp01(since / 1.2), "angle": since * 90.0, "intensity": 1.0})
			s["pillar"] = _clamp01(since / 0.3) * _clamp01((1.5 - since) / 1.0)
			dest_glow = maxf(0.4, (1.0 - life) * 1.0)

	s["dest_glow"] = dest_glow
	return s


# ════════════════════════════════════════════════════════════════════════════
#  Desenho
# ════════════════════════════════════════════════════════════════════════════
func _draw() -> void:
	if _scene.is_empty():
		return
	_draw_dest_rune(_scene["dest_glow"])
	if _scene["origin_glow"] > 0.01:
		_draw_origin_glow(_scene["origin_glow"])
	for ry in _scene["rays"]:
		_draw_rays(ry)
	for b in _scene["bursts"]:
		_draw_burst(b)
	for d in _scene["debris"]:
		_draw_debris(d)
	for o in _scene["orbs"]:
		_draw_orb(o)
	for f in _scene["fragments"]:
		_draw_fragment(f)
	if _scene["pillar"] > 0.001:
		_draw_pillar(_scene["pillar"])


func _a(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, clampf(alpha, 0.0, 1.0))


# Runa pequena + glow que cresce no destino conforme as pedras convergem.
func _draw_dest_rune(glow: float) -> void:
	if glow <= 0.01:
		return
	var c := _dest
	var op := 0.16 + glow * 0.6
	var r := 26.0 + glow * 10.0
	draw_arc(c, r, 0.0, TAU, 40, _a(C_MID, op), 0.8, true)
	for i in 4:
		var a := float(i) * PI / 2.0
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * (r - 2.0), c + d * (r + 5.0), _a(C_BRIGHT, op), 0.9)
	if glow > 0.02:
		draw_circle(c, glow * 22.0, _a(C_CORE, glow * 0.4))


func _draw_origin_glow(g: float) -> void:
	draw_circle(_origin, 24.0 * g, _a(C_DEEP, 0.20 * g))
	draw_circle(_origin, 12.0 * g, _a(C_BRIGHT, 0.45 * g))
	draw_circle(_origin, 5.0 * g, _a(C_CORE, 0.85 * g))


func _draw_fragment(f: Dictionary) -> void:
	var pos := Vector2(f["x"], f["y"])
	var scl: float = f["scale"]
	var glow: float = f["glow"]
	var trail: PackedVector2Array = f["trail"]
	if trail.size() > 1:
		draw_polyline(trail, _a(C_BRIGHT, 0.4), 5.0 * scl, true)
		draw_polyline(trail, _a(C_NAME, 0.6), 1.6 * scl, true)
	# Glow radial aproximado por círculos concêntricos.
	draw_circle(pos, 20.0 * glow * scl, _a(C_BRIGHT, 0.28 * glow))
	draw_circle(pos, 11.0 * glow * scl, _a(C_NAME, 0.4 * glow))
	# Corpo do cristal (espaço local rotacionado/escalado).
	draw_set_transform(pos, deg_to_rad(f["rot"]), Vector2(scl, scl))
	var body := PackedVector2Array([Vector2(0, -13), Vector2(7, -2), Vector2(0, 13), Vector2(-7, -2)])
	draw_colored_polygon(body, _a(C_CRYSTAL, 0.95))
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, _a(C_BRIGHT, 0.95), 1.0, true)
	var facet := PackedVector2Array([Vector2(0, -13), Vector2(7, -2), Vector2(0, 2), Vector2(-7, -2)])
	draw_colored_polygon(facet, _a(C_MID, 0.85))
	draw_line(Vector2(0, -13), Vector2(0, 13), _a(C_CORE, 0.8), 0.7)
	draw_circle(Vector2(0, -1), 2.0, C_CORE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_burst(b: Dictionary) -> void:
	var life: float = b["life"]
	if life >= 1.0:
		return
	var intensity: float = b["intensity"]
	var ctr := Vector2(b["x"], b["y"])
	var op := 1.0 - life
	var rad := 10.0 + life * 120.0 * intensity
	draw_arc(ctr, rad, 0.0, TAU, 48, _a(C_BRIGHT, op * 0.9), 2.2 * intensity, true)
	draw_arc(ctr, rad * 0.62, 0.0, TAU, 40, _a(C_CORE, op * 0.7), 1.1 * intensity, true)
	if life < 0.4:
		draw_circle(ctr, 34.0 * intensity * (1.0 - life / 0.4), _a(C_CORE, (1.0 - life / 0.4) * 0.95))
	if life < 0.6:
		draw_circle(ctr, 20.0 * intensity * (1.0 - life / 0.6), _a(C_BRIGHT, (1.0 - life / 0.6) * 0.55))


func _draw_debris(d: Dictionary) -> void:
	var life: float = d["life"]
	if life >= 1.0:
		return
	var ctr := Vector2(d["x"], d["y"])
	var spread: float = d["spread"]
	var count: int = d["count"]
	var e := _ease_out_cubic(life)
	var op := 1.0 - life
	for i in mini(count, _sparks.size()):
		var sp: Dictionary = _sparks[i]
		var dist: float = e * spread * sp["speed"]
		var pp := ctr + Vector2(cos(sp["a"]), sin(sp["a"])) * dist
		draw_line(ctr + (pp - ctr) * 0.7, pp, _a(C_NAME, op * 0.5), sp["size"] * 0.8)
		draw_circle(pp, sp["size"] * (0.5 + op * 0.7), _a(C_CORE, op * 0.85))


func _draw_rays(r: Dictionary) -> void:
	var life: float = r["life"]
	if life >= 1.0:
		return
	var ctr := Vector2(r["x"], r["y"])
	var intensity: float = r["intensity"]
	var op := (1.0 - life) * 0.85
	var base := deg_to_rad(r["angle"])
	var length := 50.0 + _ease_out_cubic(life) * 240.0 * intensity
	for i in 12:
		var a := base + (float(i) / 12.0) * TAU
		var odd := (i % 2) == 1
		var l := length * (0.6 if odd else 1.0)
		var d := Vector2(cos(a), sin(a))
		draw_line(ctr, ctr + d * l, _a(C_CORE, op * (0.4 if odd else 0.8)), 1.2 if odd else 2.4)


func _draw_orb(o: Dictionary) -> void:
	var glow: float = o["glow"]
	if glow <= 0.01:
		return
	var ctr := Vector2(o["x"], o["y"])
	var rad: float = o["r"]
	draw_circle(ctr, o["halo"], _a(C_DEEP, 0.18 * glow))
	draw_circle(ctr, rad * 1.7, _a(C_BRIGHT, 0.4 * glow))
	draw_circle(ctr, rad, _a(C_NAME, 0.85 * glow))
	draw_circle(ctr, rad * 0.5, _a(C_CORE, glow))


# Pilar de luz LOCALIZADO no destino (não cobre a tela inteira).
func _draw_pillar(op: float) -> void:
	var cx := _dest.x
	var halfw := 42.0
	var half_h := 170.0
	var top := _dest.y - half_h
	var height := half_h * 2.0
	var strips := 20
	for i in strips:
		var fx := float(i) / float(strips - 1)
		var dx: float = absf(fx - 0.5) * 2.0      # 0 no centro → 1 nas bordas
		var a := pow(maxf(0.0, 1.0 - dx), 1.4)
		var col := C_CORE.lerp(C_BRIGHT, dx)
		var sx := cx - halfw + fx * (halfw * 2.0)
		var w := (halfw * 2.0) / float(strips) + 1.0
		draw_rect(Rect2(sx, top, w, height), _a(col, a * op * 0.8))
