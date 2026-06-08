## scenes/vfx/combat_resolution/combat_resolution_stage.gd
##
## Node2D que toca a timeline da Resolução de Combate em espaço de design
## 1280×720, escalado para cobrir o viewport.
##
## As cartas-duelistas são HeroSlot REAIS (o mesmo card do board, com HP, ataque,
## defesa, classe, passiva e skill) — instanciadas, bindadas e animadas
## (posição + escala). Os golpes/popups/flash são desenhados por cima via _draw.
##
## Porta fielmente "docs/combat_resolution/Combat Resolution.html": cada frame é
## derivado de um único tempo `t`. O board real fica por trás, escurecido.
class_name CombatResolutionStage
extends Node2D

const HeroSlotScene := preload("res://scenes/ui/hero_slot/hero_slot.tscn")

# ── Geometria (espelha o HTML — não inventar) ────────────────────────────────
const STAGE_W := 1280.0
const STAGE_H := 720.0
const H1_HOME := Vector2(720, 540)   # jogador (embaixo)
const H2_HOME := Vector2(720, 200)   # oponente (em cima)
const H1_DUEL := Vector2(472, 360)   # aliado encara à esquerda
const H2_DUEL := Vector2(808, 360)   # inimigo à direita
const HOME_W := 90.0
const HOME_H := 126.0
const DUEL_W := 164.0
const DUEL_H := 230.0
# Tamanho base do HeroSlot (escala via node.scale a partir daqui)
const CARD_W := 160.0
const CARD_H := 240.0

# ── Timeline (segundos — espelha const T do HTML) ────────────────────────────
const T_ENTRANCE_END := 1.15
const T_A1_START := 1.55
const T_A1_END   := 3.35
const T_A2_START := 3.70
const T_A2_END   := 5.50
const T_HOLD_END := 6.20
const ATTACK_DUR := 1.80
const POPUP_DUR  := 1.30

# ── Paletas por arquétipo, indexadas por AtkType (LAMINA/MACHADO/MAGIA) ───────
const PAL := [
	{ "core": Color("#eef3fb"), "bright": Color("#a9cdf0"), "mid": Color("#7fb4e6"), "glow": Color("#97c2ec"), "dust": Color("#6f9ece") },  # LAMINA
	{ "core": Color("#ffedb8"), "bright": Color("#ffba6e"), "mid": Color("#e8703a"), "glow": Color("#f5904a"), "dust": Color("#6b5334") },  # MACHADO
	{ "core": Color("#f3e6fb"), "bright": Color("#c79af0"), "mid": Color("#a463e0"), "glow": Color("#b97fe6"), "dust": Color("#9a6cc4") },  # MAGIA
]
const POPUP_COLOR := Color("#e8503a")
const GOLD := Color("#cba24f")

# ── Partículas pré-semeadas (determinísticas — espelham o HTML) ───────────────
var _axe_shards: Array = []
var _axe_dust:   Array = []
var _magic_sparks: Array = []

# ── Fontes ───────────────────────────────────────────────────────────────────
var _font_black: Font = preload("res://assets/fonts/CinzelDecorative-Black.ttf")
var _font_reg:   Font = preload("res://assets/fonts/CinzelDecorative-Regular.ttf")

# ── Estado ───────────────────────────────────────────────────────────────────
var _vfx: CombatResolution = null
var _cfg: CombatResolution.Config = null
var _t := 0.0
var _base_offset := Vector2.ZERO
var _scale := 1.0
var _scene := {}
var _impacted := { "ally": false, "enemy": false }
var _done := false

# Cartas-duelistas (HeroSlot reais) + dim por trás
var _dim_rect: ColorRect = null
var _ally_slot: HeroSlot = null
var _enemy_slot: HeroSlot = null

# Tipos de golpe resolvidos + HP capturado pré-golpe
var _type1 := 0
var _type2 := 0
var _ally_hp_before := 0
var _enemy_hp_before := 0
var _ally_max := 1
var _enemy_max := 1


# setup() é chamado ANTES de o stage entrar na árvore: cria o dim e os HeroSlot
# como filhos do _vfx (CanvasLayer) em espaço de TELA, para que o stage (FX),
# adicionado depois, desenhe POR CIMA das cartas.
func setup(p_vfx: CombatResolution, p_cfg: CombatResolution.Config) -> void:
	_vfx = p_vfx
	_cfg = p_cfg
	_seed_particles()
	_compute_metrics()
	_type1 = _resolve_type(_cfg.ally_hero, _cfg.atk1_type)
	_type2 = _resolve_type(_cfg.enemy_hero, _cfg.atk2_type)
	_ally_hp_before  = _cfg.ally_hero.current_hp  if _cfg.ally_hero  else 0
	_enemy_hp_before = _cfg.enemy_hero.current_hp if _cfg.enemy_hero else 0
	_ally_max  = maxi(1, _cfg.ally_hero.max_hp)  if _cfg.ally_hero  else 1
	_enemy_max = maxi(1, _cfg.enemy_hero.max_hp) if _cfg.enemy_hero else 1
	_build_nodes()


func _ready() -> void:
	# Transform do palco de FX: design 1280×720 → tela (escalado/centrado).
	scale = Vector2(_scale, _scale)
	position = _base_offset
	_scene = _derive_scene(0.0)
	_apply_scene_to_nodes()
	queue_redraw()


# Fator de escala design→tela (cobre o viewport, centrado).
func _compute_metrics() -> void:
	var vp := _vfx.get_viewport().get_visible_rect().size
	_scale = maxf(vp.x / STAGE_W, vp.y / STAGE_H)
	_base_offset = (vp - Vector2(STAGE_W, STAGE_H) * _scale) * 0.5


# Dim (full-screen) + dois HeroSlot reais — todos filhos do _vfx, em espaço de
# tela e tamanho NATIVO (sem upscale por transform → texto nítido).
func _build_nodes() -> void:
	var vp := _vfx.get_viewport().get_visible_rect().size
	_dim_rect = ColorRect.new()
	_dim_rect.color = Color(0.02, 0.02, 0.05, 0.0)
	_dim_rect.size = vp
	_dim_rect.position = Vector2.ZERO
	_dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vfx.add_child(_dim_rect)

	_ally_slot  = _make_slot(_cfg.ally_hero, _cfg.ally_atk, _cfg.ally_def)
	_enemy_slot = _make_slot(_cfg.enemy_hero, _cfg.enemy_atk, _cfg.enemy_def)


func _make_slot(hero: Hero, atk: int, dfs: int) -> HeroSlot:
	var slot: HeroSlot = HeroSlotScene.instantiate()
	# Tamanho de tela final (DUEL) — fontes nítidas via apply_scale, não transform.
	var base := Vector2(CARD_W, CARD_H) * _scale
	slot.custom_minimum_size = base
	slot.size = base
	slot.pivot_offset = base * 0.5
	_vfx.add_child(slot)
	if hero != null:
		slot.bind(hero)
		slot.set_face_down(false)   # no combate ambos estão revelados
		slot.apply_scale(_scale)    # fontes/offsets no tamanho de tela (nitidez)
		if atk >= 0:
			slot.set_modified_attack(atk)
		if dfs >= 0:
			slot.set_modified_defense(dfs)
	_ignore_mouse(slot)
	return slot


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_ignore_mouse(c)


func _resolve_type(hero: Hero, override_type: int) -> int:
	if override_type >= 0:
		return override_type
	if hero == null:
		return CombatResolution.AtkType.LAMINA
	match hero.hero_class:
		Hero.HeroClass.BARBARIAN:
			return CombatResolution.AtkType.MACHADO
		Hero.HeroClass.CLERIC, Hero.HeroClass.RANGER:
			return CombatResolution.AtkType.MAGIA
		_:
			return CombatResolution.AtkType.LAMINA


func _seed_particles() -> void:
	for i in 13:
		var a := (float(i) / 13.0) * TAU + (0.12 if (i % 2) == 1 else -0.12)
		_axe_shards.append({ "a": a, "len": 40.0 + (i % 4) * 16.0, "w": 1.4 + (i % 3) * 0.7 })
	for i in 9:
		_axe_dust.append({ "a": (float(i) / 9.0) * TAU, "dist": 30.0 + (i % 3) * 22.0, "r": 4.0 + (i % 4) * 2.5 })
	for i in 12:
		var a2 := (float(i) / 12.0) * TAU + (0.2 if (i % 2) == 1 else -0.1)
		_magic_sparks.append({ "a": a2, "len": 50.0 + (i % 5) * 18.0, "size": 2.0 + (i % 3) })


# ── Loop ──────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _done:
		return
	_t = minf(_t + delta, T_HOLD_END)
	_check_impacts()
	_scene = _derive_scene(_t)
	# Screen shake aplicado ao palco inteiro (espelha #shake-inner)
	position = _base_offset + _scene["shake_off"] * _scale
	_apply_scene_to_nodes()
	queue_redraw()
	if _t >= T_HOLD_END:
		_done = true
		_vfx._emit_finished()


# Aplica posição/escala/HP nas cartas-duelistas reais e o alpha do dim.
func _apply_scene_to_nodes() -> void:
	if _scene.is_empty():
		return
	_dim_rect.color.a = _scene["dim"] * 0.6
	_apply_card(_ally_slot, _scene["h1"], _ally_max)
	_apply_card(_enemy_slot, _scene["h2"], _enemy_max)


func _apply_card(slot: HeroSlot, h: Dictionary, max_hp: int) -> void:
	if slot == null:
		return
	# node.scale só faz DOWNSCALE na entrada (1.0 = nativo no duelo → nítido).
	var s: float = h["w"] / DUEL_W
	slot.scale = Vector2(s, s)
	# Posição em espaço de TELA (design → tela), com o mesmo shake dos FX.
	var shake: Vector2 = _scene["shake_off"]
	var center_screen: Vector2 = _base_offset + Vector2(h["x"], h["y"]) * _scale + shake * _scale
	slot.position = center_screen - slot.pivot_offset
	var hp_now: float = maxf(0.0, h["hp_now"])
	slot.hp_bar.value = hp_now
	slot.hp_label.text = "%d/%d" % [roundi(hp_now), max_hp]


func _check_impacts() -> void:
	var imp1_abs := T_A1_START + _impact_local(_type1) * ATTACK_DUR
	var imp2_abs := T_A2_START + _impact_local(_type2) * ATTACK_DUR
	if not _impacted["enemy"] and _t >= imp1_abs:
		_impacted["enemy"] = true
		_vfx._emit_impact("enemy", _cfg.dmg1)
	if not _impacted["ally"] and _t >= imp2_abs:
		_impacted["ally"] = true
		_vfx._emit_impact("ally", _cfg.dmg2)


func _impact_local(type: int) -> float:
	if type == CombatResolution.AtkType.MAGIA: return 0.60
	if type == CombatResolution.AtkType.MACHADO: return 0.54
	return 0.50


# ── Easings (espelham o HTML) ─────────────────────────────────────────────────
func _c01(v: float) -> float: return clampf(v, 0.0, 1.0)
func _eoc(t: float) -> float: return 1.0 - pow(1.0 - t, 3.0)        # easeOutCubic
func _eoq(t: float) -> float: return 1.0 - pow(1.0 - t, 4.0)        # easeOutQuart
func _eiq(t: float) -> float: return t * t                          # easeInQuad
func _eob(t: float) -> float:                                       # easeOutBack
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)


# ════════════════════════════════════════════════════════════════════════════
#  Contribuição de um ataque (espelha attackFX)
# ════════════════════════════════════════════════════════════════════════════
func _attack_fx(t: float, start: float, type: int, dmg: int, dir: float,
		attacker: Dictionary, target: Dictionary) -> Dictionary:
	var res := {
		"lungeX": 0.0, "extraY": 0.0, "charge": 0.0, "type": type,
		"recoilX": 0.0, "shakeX": 0.0, "shakeY": 0.0, "hitFlash": 0.0, "hpLost": 0.0,
		"fx": [], "flash": 0.0, "screenShake": 0.0, "popup": null,
	}
	var d := ATTACK_DUR
	var u := (t - start) / d
	var impact_abs := start + _impact_local(type) * d

	# Queda de HP + popup (independentes da janela de movimento — persistem depois)
	if t >= impact_abs:
		res["hpLost"] = float(dmg) * _eoc(_c01((t - impact_abs) / 0.35))
	var p_age := t - impact_abs
	if p_age >= 0.0 and p_age < POPUP_DUR:
		var pp := p_age / POPUP_DUR
		var op := pp / 0.12 if pp < 0.12 else ((1.0 - pp) / 0.32 if pp > 0.68 else 1.0)
		res["popup"] = {
			"value": dmg,
			"x": target["x"],
			"y": target["y"] - target["h"] / 2.0 - 16.0 - _eoc(pp) * 50.0,
			"opacity": _c01(op),
			"scale": 0.7 + _eob(_c01(pp / 0.3)) * 0.3,
		}

	if u < 0.0 or u > 1.0:
		return res

	var hand_x: float = attacker["x"] + dir * (attacker["w"] * 0.30)
	var hand_y: float = attacker["y"] - attacker["h"] * 0.16
	var tcx: float = target["x"]
	var tcy: float = target["y"]

	if type == CombatResolution.AtkType.LAMINA:
		var lunge := 0.0
		var charge := 0.0
		if u < 0.30:
			var w := u / 0.30
			charge = _eoc(w) * 0.55
			lunge = -8.0 * w
		elif u < 0.50:
			var w := (u - 0.30) / 0.20
			charge = 0.55 + 0.45 * w
			lunge = lerpf(-8.0, 60.0, _eiq(w))
		else:
			var w := (u - 0.50) / 0.50
			charge = 0.5 * _c01(1.0 - w * 2.0)
			lunge = 60.0 * (1.0 - _eoc(w))
		res["lungeX"] = lunge * dir
		res["charge"] = charge
		if u >= 0.42 and u <= 0.74:
			res["fx"].append({ "kind": "slash", "type": type, "p": (u - 0.42) / 0.32, "x": tcx, "y": tcy, "w": target["w"], "h": target["h"] })
		var imp := u - 0.50
		if imp >= 0.0 and imp < 0.26:
			var w := imp / 0.26
			res["hitFlash"] = (1.0 - w)
			res["recoilX"] = dir * 24.0 * (1.0 - _eoc(w))
			res["shakeX"] = sin(t * 95.0) * (1.0 - w) * 3.0
			res["flash"] = (1.0 - w) * 0.14

	elif type == CombatResolution.AtkType.MACHADO:
		var lunge := 0.0
		var extra_y := 0.0
		var charge := 0.0
		if u < 0.38:
			var w := u / 0.38
			charge = _eiq(w)
			lunge = -16.0 * _eoc(w)
			extra_y = -12.0 * _eoc(w)
		elif u < 0.54:
			var w := (u - 0.38) / 0.16
			charge = 1.0
			lunge = lerpf(-16.0, 88.0, _eiq(w))
			extra_y = lerpf(-12.0, 8.0, _eiq(w))
		else:
			var w := (u - 0.54) / 0.46
			charge = 0.4 * _c01(1.0 - w * 2.0)
			lunge = 88.0 * (1.0 - _eoc(w))
			extra_y = 8.0 * (1.0 - _eoc(w))
		res["lungeX"] = lunge * dir
		res["extraY"] = extra_y
		res["charge"] = charge
		var imp := u - 0.54
		if imp >= 0.0 and imp < 0.46:
			res["fx"].append({ "kind": "axe", "type": type, "p": imp / 0.46, "x": tcx, "y": tcy })
		if imp >= 0.0 and imp < 0.5:
			var w := _c01(imp / 0.5)
			res["hitFlash"] = (1.0 - _c01(imp / 0.28))
			res["recoilX"] = dir * 46.0 * (1.0 - _eoc(w))
			var sa := (1.0 - _c01(imp / 0.34)) * 7.0
			res["shakeX"] = sin(t * 130.0) * sa
			res["shakeY"] = cos(t * 110.0) * sa * 0.7
			res["screenShake"] = (1.0 - _c01(imp / 0.32)) * 11.0
			res["flash"] = (1.0 - _c01(imp / 0.24)) * 0.22

	else: # MAGIA
		var lunge := 0.0
		var charge := 0.0
		if u < 0.34:
			var w := u / 0.34
			charge = _eoc(w)
			lunge = -7.0 * w
		else:
			var w := (u - 0.34) / 0.66
			lunge = -7.0 * (1.0 - _eoc(_c01(w * 2.0)))
			charge = 0.0
		res["lungeX"] = lunge * dir
		res["charge"] = charge
		if u < 0.40:
			res["fx"].append({ "kind": "orb", "type": type, "p": u / 0.40, "x": hand_x, "y": hand_y })
		if u >= 0.34 and u < 0.62:
			var w := (u - 0.34) / 0.28
			var px := lerpf(hand_x, tcx, _eiq(w))
			var py := lerpf(hand_y, tcy, w) - sin(w * PI) * 26.0
			res["fx"].append({ "kind": "proj", "type": type, "p": w, "x": px, "y": py, "dir": dir })
		var imp := u - 0.60
		if imp >= 0.0 and imp < 0.45:
			res["fx"].append({ "kind": "burst", "type": type, "p": imp / 0.45, "x": tcx, "y": tcy })
		if imp >= 0.0 and imp < 0.5:
			var w := _c01(imp / 0.5)
			res["hitFlash"] = (1.0 - _c01(imp / 0.26))
			res["recoilX"] = dir * 30.0 * (1.0 - _eoc(w))
			res["shakeX"] = sin(t * 100.0) * (1.0 - w) * 4.0
			res["flash"] = (1.0 - _c01(imp / 0.3)) * 0.20

	return res


# ════════════════════════════════════════════════════════════════════════════
#  Derivação da cena (espelha deriveScene)
# ════════════════════════════════════════════════════════════════════════════
func _derive_scene(t: float) -> Dictionary:
	var e_p := _c01(t / T_ENTRANCE_END)
	var e_pos := _eoc(e_p)
	var e_size := _eob(_c01(e_p * 1.05))
	var rise := -sin(e_p * PI) * 20.0

	var h1base := {
		"x": lerpf(H1_HOME.x, H1_DUEL.x, e_pos),
		"y": lerpf(H1_HOME.y, H1_DUEL.y, e_pos) + rise,
		"w": lerpf(HOME_W, DUEL_W, e_size),
		"h": lerpf(HOME_H, DUEL_H, e_size),
	}
	var h2base := {
		"x": lerpf(H2_HOME.x, H2_DUEL.x, e_pos),
		"y": lerpf(H2_HOME.y, H2_DUEL.y, e_pos) + rise,
		"w": lerpf(HOME_W, DUEL_W, e_size),
		"h": lerpf(HOME_H, DUEL_H, e_size),
	}

	var settled := _c01((t - T_ENTRANCE_END) / 0.5)
	var bob := sin(t * 1.6) * 2.4 * settled
	h1base["y"] += bob
	h2base["y"] += bob * -1.0

	var a1 := _attack_fx(t, T_A1_START, _type1, _cfg.dmg1, 1.0, h1base, h2base)
	var a2 := _attack_fx(t, T_A2_START, _type2, _cfg.dmg2, -1.0, h2base, h1base)

	var h1 := {
		"x": h1base["x"] + a1["lungeX"] + a2["recoilX"] + a2["shakeX"],
		"y": h1base["y"] + a1["extraY"] + a2["shakeY"],
		"w": h1base["w"], "h": h1base["h"],
		"charge": a1["charge"], "chargeType": _type1,
		"hitFlash": a2["hitFlash"],
		"hp_now": float(_ally_hp_before) - a2["hpLost"],
	}
	var h2 := {
		"x": h2base["x"] + a2["lungeX"] + a1["recoilX"] + a1["shakeX"],
		"y": h2base["y"] + a2["extraY"] + a1["shakeY"],
		"w": h2base["w"], "h": h2base["h"],
		"charge": a2["charge"], "chargeType": _type2,
		"hitFlash": a1["hitFlash"],
		"hp_now": float(_enemy_hp_before) - a1["hpLost"],
	}

	var fx: Array = []
	fx.append_array(a1["fx"])
	fx.append_array(a2["fx"])
	var popups: Array = []
	if a1["popup"] != null: popups.append(a1["popup"])
	if a2["popup"] != null: popups.append(a2["popup"])

	var flash: float = maxf(a1["flash"], a2["flash"])
	var flash_type: int = _type1 if a1["flash"] >= a2["flash"] else _type2
	var screen_shake: float = maxf(a1["screenShake"], a2["screenShake"])
	var dim := e_pos

	var banner_op := 0.0
	if t >= 0.1 and t < 1.5:
		banner_op = minf(_c01((t - 0.1) / 0.4), _c01((1.5 - t) / 0.4))

	var caption := ""
	if t < T_A1_START: caption = "Heróis ativos avançam"
	elif t < T_A1_END: caption = "Aliado ataca"
	elif t < T_A2_START: caption = ""
	elif t < T_A2_END: caption = "Inimigo revida"
	else: caption = "Combate resolvido"

	var shake_off := Vector2.ZERO
	if screen_shake > 0.1:
		shake_off = Vector2(sin(t * 92.0) * screen_shake, cos(t * 77.0) * screen_shake * 0.6)

	return {
		"h1": h1, "h2": h2, "fx": fx, "popups": popups,
		"flash": flash, "flash_type": flash_type, "dim": dim,
		"banner_op": banner_op, "caption": caption, "shake_off": shake_off,
	}


# ════════════════════════════════════════════════════════════════════════════
#  Desenho — só o que fica POR CIMA das cartas (glow atrás, FX/popups na frente)
# ════════════════════════════════════════════════════════════════════════════
func _draw() -> void:
	if _scene.is_empty():
		return
	# Glow de carga (atrás das cartas — desenhado primeiro, mas as cartas são
	# nós show_behind_parent, então este _draw já fica na frente delas; mantemos
	# o glow sutil e aditivo para ler como brilho ao redor da carta).
	_draw_glow(_scene["h1"])
	_draw_glow(_scene["h2"])
	# Flash vermelho de hit sobre cada carta
	_draw_hitflash(_scene["h1"])
	_draw_hitflash(_scene["h2"])
	# FX dos golpes
	for item in _scene["fx"]:
		_draw_fx(item)
	# Flash de impacto (tela)
	if _scene["flash"] > 0.001:
		var fc: Color = PAL[_scene["flash_type"]]["core"]
		fc.a = _scene["flash"]
		draw_rect(Rect2(0, 0, STAGE_W, STAGE_H), fc)
	# Popups de dano
	for p in _scene["popups"]:
		_draw_popup(p)
	# Banner + caption
	if _scene["banner_op"] > 0.01:
		_draw_banner(_scene["banner_op"])
	if _scene["caption"] != "":
		_draw_caption(_scene["caption"])


func _draw_glow(h: Dictionary) -> void:
	var charge: float = h["charge"]
	if charge <= 0.05:
		return
	var pal: Dictionary = PAL[h["chargeType"]]
	var ctr := Vector2(h["x"], h["y"])
	var gr: float = h["w"] * (1.3 + charge * 0.7) * 0.5
	for i in 3:
		var rr := gr * (1.0 - i * 0.28)
		var gc: Color = pal["glow"] if i == 0 else pal["mid"]
		gc.a = charge * 0.20 * (1.0 - i * 0.2)
		draw_circle(ctr, rr, gc)


func _draw_hitflash(h: Dictionary) -> void:
	var hit: float = h["hitFlash"]
	if hit <= 0.01:
		return
	var s: float = h["w"] / DUEL_W
	var vw := CARD_W * s
	var vh := CARD_H * s
	var rect := Rect2(h["x"] - vw / 2.0, h["y"] - vh / 2.0, vw, vh)
	draw_rect(rect, Color(0.95, 0.20, 0.16, hit * 0.5))


# ── FX dos golpes ─────────────────────────────────────────────────────────────
func _draw_fx(item: Dictionary) -> void:
	var pal: Dictionary = PAL[item["type"]]
	match item["kind"]:
		"slash": _draw_slash(item, pal)
		"axe":   _draw_axe(item, pal)
		"orb":   _draw_orb(item, pal)
		"proj":  _draw_proj(item, pal)
		"burst": _draw_burst(item, pal)


func _draw_slash(it: Dictionary, pal: Dictionary) -> void:
	var p: float = it["p"]
	var x: float = it["x"]
	var y: float = it["y"]
	var w: float = it["w"]
	var h: float = it["h"]
	var over_op := p / 0.14 if p < 0.14 else (maxf(0.0, (1.0 - p) / 0.4) if p > 0.6 else 1.0)
	var d1 := _c01(p / 0.5)
	var d2 := _c01((p - 0.22) / 0.5)
	var hw := w * 0.62
	var hh := h * 0.52
	_draw_bezier_stroke(Vector2(x - hw, y - hh), Vector2(x, y - hh * 0.2), Vector2(x + hw, y + hh), d1, pal, over_op)
	_draw_bezier_stroke(Vector2(x + hw, y - hh), Vector2(x, y - hh * 0.2), Vector2(x - hw, y + hh), d2, pal, over_op)


# Desenha a fração `frac` (0..1) de uma bezier quadrática (glow + core).
func _draw_bezier_stroke(p0: Vector2, p1: Vector2, p2: Vector2, frac: float, pal: Dictionary, op: float) -> void:
	if frac <= 0.0 or op <= 0.0:
		return
	var steps := 20
	var last := int(round(frac * steps))
	if last < 1:
		return
	var pts := PackedVector2Array()
	for i in last + 1:
		var u := float(i) / float(steps)
		var iu := 1.0 - u
		pts.append(iu * iu * p0 + 2.0 * iu * u * p1 + u * u * p2)
	var glow: Color = pal["glow"]
	glow.a = 0.45 * op
	var core: Color = pal["core"]
	core.a = op
	draw_polyline(pts, glow, 10.0)
	draw_polyline(pts, core, 3.0)


func _draw_axe(it: Dictionary, pal: Dictionary) -> void:
	var p: float = it["p"]
	var ctr := Vector2(it["x"], it["y"])
	# Anéis de choque
	for off in [0.0, 0.16]:
		var u := _c01((p - off) / 0.7)
		if u <= 0.0 or u >= 1.0:
			continue
		var rr := 16.0 + _eoq(u) * 150.0
		var op := (1.0 - u) * 0.9
		var lw := 3.0 + (1.0 - u) * 4.0
		var gc: Color = pal["glow"]
		gc.a = op * 0.5
		var bc: Color = pal["bright"]
		bc.a = op
		draw_arc(ctr, rr, 0, TAU, 48, gc, lw + 4.0)
		draw_arc(ctr, rr, 0, TAU, 48, bc, lw)
	# Estilhaços radiais
	var mc: Color = pal["mid"]
	mc.a = (1.0 - p) * 0.95
	for s in _axe_shards:
		var r0: float = 22.0 + _eoc(p) * s["len"]
		var r1: float = r0 + 16.0 + (1.0 - p) * 8.0
		var a: float = s["a"]
		var dirv := Vector2(cos(a), sin(a))
		draw_line(ctr + dirv * r0, ctr + dirv * r1, mc, s["w"])
	# Estrela de impacto
	var star_op := (1.0 - _c01(p / 0.4))
	if star_op > 0.0:
		var sc: Color = pal["core"]
		sc.a = star_op
		for i in 4:
			var a := (float(i) / 4.0) * PI + 0.4
			var dirv := Vector2(cos(a), sin(a)) * 30.0
			draw_line(ctr - dirv, ctr + dirv, sc, 2.5)
	# Poeira
	for dst in _axe_dust:
		var dist: float = dst["dist"] * _eoc(p)
		var dc: Color = pal["dust"]
		dc.a = (1.0 - p) * 0.5
		draw_circle(ctr + Vector2(cos(dst["a"]) * dist, sin(dst["a"]) * dist + p * 20.0), dst["r"] * (0.5 + p), dc)


func _draw_orb(it: Dictionary, pal: Dictionary) -> void:
	var p: float = it["p"]
	var ctr := Vector2(it["x"], it["y"])
	var r := 2.0 + p * 9.0
	var op := 1.0 if p < 0.8 else (1.0 - p) / 0.2
	var gc: Color = pal["glow"]
	gc.a = 0.3 * op
	var bc: Color = pal["bright"]
	bc.a = op
	var cc: Color = pal["core"]
	cc.a = op
	draw_circle(ctr, r * 1.9, gc)
	draw_circle(ctr, r, bc)
	draw_circle(ctr, r * 0.5, cc)
	for i in 5:
		var a := (float(i) / 5.0) * TAU + p * 4.0
		var rr := 24.0 * (1.0 - p)
		var sc: Color = pal["bright"]
		sc.a = p * op
		draw_circle(ctr + Vector2(cos(a), sin(a)) * rr, 1.7, sc)


func _draw_proj(it: Dictionary, pal: Dictionary) -> void:
	var ctr := Vector2(it["x"], it["y"])
	var dir: float = it.get("dir", 1.0)
	for i in range(1, 5):
		var tc: Color = pal["mid"]
		tc.a = 0.5 - i * 0.1
		draw_circle(ctr - Vector2(dir * i * 11.0, 0.0), 9.0 - i * 1.7, tc)
	var gc: Color = pal["glow"]
	gc.a = 0.35
	draw_circle(ctr, 17.0, gc)
	draw_circle(ctr, 8.5, pal["bright"])
	draw_circle(ctr, 4.0, pal["core"])


func _draw_burst(it: Dictionary, pal: Dictionary) -> void:
	var u: float = it["p"]
	var ctr := Vector2(it["x"], it["y"])
	var r := 10.0 + _eoq(u) * 120.0
	var op := 1.0 - u
	var gc: Color = pal["glow"]
	gc.a = op * 0.5
	var bc: Color = pal["bright"]
	bc.a = op * 0.9
	var cc: Color = pal["core"]
	cc.a = op * 0.7
	draw_arc(ctr, r, 0, TAU, 48, gc, 4.0 + (1.0 - u) * 4.0)
	draw_arc(ctr, r, 0, TAU, 48, bc, 2.0 + (1.0 - u) * 3.0)
	draw_arc(ctr, r * 0.55, 0, TAU, 40, cc, 1.5)
	for s in _magic_sparks:
		var rr: float = 16.0 + _eoc(u) * s["len"]
		var spc: Color = pal["core"]
		spc.a = op
		draw_circle(ctr + Vector2(cos(s["a"]) * rr, sin(s["a"]) * rr), s["size"] * (1.0 - u), spc)
	var hc: Color = pal["glow"]
	hc.a = op * 0.4
	draw_circle(ctr, (1.0 - u) * 28.0, hc)


# ── Popup de dano ─────────────────────────────────────────────────────────────
func _draw_popup(p: Dictionary) -> void:
	var op: float = p["opacity"]
	if op <= 0.01:
		return
	var fs := int(round(40.0 * float(p["scale"])))
	var txt := "-%d" % p["value"]
	var w := float(_font_black.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var pos := Vector2(p["x"] - w / 2.0, p["y"] + fs * 0.35)
	draw_string(_font_black, pos + Vector2(0, 2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.10, 0.04, 0.04, op * 0.8))
	var c := POPUP_COLOR
	c.a = op
	draw_string(_font_black, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)


# ── Banner de título ──────────────────────────────────────────────────────────
func _draw_banner(op: float) -> void:
	var cy := STAGE_H * 0.41
	var sub_c := GOLD
	sub_c.a = op * 0.85
	draw_string(_font_reg, Vector2(0, cy), "FIM DA RODADA",
		HORIZONTAL_ALIGNMENT_CENTER, STAGE_W, 14, sub_c)
	var name_c := Color("#e8e0c0")
	name_c.a = op
	draw_string(_font_black, Vector2(0, cy + 44), "RESOLUÇÃO DE COMBATE",
		HORIZONTAL_ALIGNMENT_CENTER, STAGE_W, 42, name_c)
	var rule_c := GOLD
	rule_c.a = op * 0.8
	draw_line(Vector2(STAGE_W / 2.0 - 160, cy + 58), Vector2(STAGE_W / 2.0 + 160, cy + 58), rule_c, 1.0)


func _draw_caption(text: String) -> void:
	var c := GOLD
	c.a = 0.9
	draw_string(_font_reg, Vector2(0, 34), text.to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER, STAGE_W, 13, c)
