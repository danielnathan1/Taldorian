# scenes/minigames/mana_orb/mana_orb.gd
# "Pesca" temática: a esfera de mana foge pela área; o jogador controla um círculo com o MOUSE
# e precisa manter a esfera dentro dele. Uma barra de captura ENCHE enquanto a esfera está dentro
# e DRENA quando escapa. Encheu (1.0) = capturou (vitória); zerou (0.0) = fugiu (derrota).
# Config (dificuldade): { orb_speed, dir_change, dash_chance, zone_radius, fill_rate, drain_rate,
# start_progress }. Mais raro = mais rápido / mais erra a direção / dá dashes.
extends Minigame

const AREA := Vector2(440.0, 300.0)   # tamanho da arena de jogo
const ORB_R := 12.0

@onready var _title: Label = $Title
@onready var _status: Label = $Status

var _orb: Vector2 = AREA * 0.5
var _vel: Vector2 = Vector2.ZERO
var _dir_timer: float = 0.0
var _progress: float = 0.4
var _playing: bool = false

# dificuldade (vem da config)
var _orb_speed: float = 120.0
var _dir_change: float = 1.2
var _dash_chance: float = 0.0
var _zone_r: float = 55.0
var _fill: float = 0.55
var _drain: float = 0.45

func start(p_config: Dictionary) -> void:
	_orb_speed   = float(p_config.get("orb_speed", 120.0))
	_dir_change  = float(p_config.get("dir_change", 1.2))
	_dash_chance = float(p_config.get("dash_chance", 0.0))
	_zone_r      = float(p_config.get("zone_radius", 55.0))
	_fill        = float(p_config.get("fill_rate", 0.55))
	_drain       = float(p_config.get("drain_rate", 0.45))
	_progress    = float(p_config.get("start_progress", 0.4))
	print("[ManaOrb] config=%s  (zona=%d, vel=%d)" % [p_config, int(_zone_r), int(_orb_speed)])
	_orb = AREA * 0.5
	_vel = Vector2.from_angle(randf() * TAU) * _orb_speed
	_title.text = "Mantenha a esfera dentro do círculo!"
	_status.text = ""
	_playing = true
	set_process(true)

func _process(delta: float) -> void:
	if not _playing:
		return
	_update_orb(delta)
	var inside := _orb.distance_to(_zone_local()) <= _zone_r
	_progress = clampf(_progress + (_fill if inside else -_drain) * delta, 0.0, 1.0)
	if _progress >= 1.0:
		_end(true)
	elif _progress <= 0.0:
		_end(false)
	queue_redraw()

func _update_orb(delta: float) -> void:
	_dir_timer -= delta
	if _dir_timer <= 0.0:
		_dir_timer = randf_range(_dir_change * 0.5, _dir_change * 1.5)
		var speed := _orb_speed * (2.4 if randf() < _dash_chance else 1.0)   # dash ocasional
		_vel = Vector2.from_angle(randf() * TAU) * speed
	_orb += _vel * delta
	if _orb.x < 0.0:
		_orb.x = 0.0; _vel.x = absf(_vel.x)
	elif _orb.x > AREA.x:
		_orb.x = AREA.x; _vel.x = -absf(_vel.x)
	if _orb.y < 0.0:
		_orb.y = 0.0; _vel.y = absf(_vel.y)
	elif _orb.y > AREA.y:
		_orb.y = AREA.y; _vel.y = -absf(_vel.y)

# Arena centrada no viewport; orbe e zona vivem em coords locais (0..AREA).
func _area_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(vp * 0.5 - AREA * 0.5, AREA)

func _zone_local() -> Vector2:
	var area := _area_rect()
	return (get_viewport().get_mouse_position() - area.position).clamp(Vector2.ZERO, AREA)

func _draw() -> void:
	# Escurecimento de fundo (desenhado aqui pra ficar ATRÁS da arena; os Labels são filhos → por cima).
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0, 0, 0, 0.7), true)
	var area := _area_rect()
	var o := area.position
	draw_rect(area, Color(0.08, 0.10, 0.18, 0.95), true)
	draw_rect(area, Color(0.4, 0.6, 1.0, 0.6), false, 2.0)
	# Zona do jogador (verde quando a esfera está dentro).
	var zone := _zone_local()
	var inside := _orb.distance_to(zone) <= _zone_r
	var zcol := Color(0.45, 1.0, 0.6) if inside else Color(0.55, 0.75, 1.0)
	draw_circle(o + zone, _zone_r, Color(zcol.r, zcol.g, zcol.b, 0.12))
	draw_arc(o + zone, _zone_r, 0.0, TAU, 48, Color(zcol.r, zcol.g, zcol.b, 0.85), 2.5, true)
	# Esfera de mana.
	var oc := o + _orb
	draw_circle(oc, ORB_R, Color(0.7, 0.5, 1.0))
	draw_arc(oc, ORB_R + 3.0, 0.0, TAU, 24, Color(0.9, 0.75, 1.0, 0.8), 2.0, true)
	# Barra de captura.
	var bar := Rect2(o.x, o.y + AREA.y + 16.0, AREA.x, 18.0)
	draw_rect(bar, Color(0, 0, 0, 0.5), true)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _progress, bar.size.y)), Color(0.4, 0.9, 0.5), true)
	draw_rect(bar, Color(1, 1, 1, 0.3), false, 1.0)

func _end(p_success: bool) -> void:
	_playing = false
	set_process(false)
	_status.text = "Capturada!" if p_success else "A esfera escapou..."
	await get_tree().create_timer(0.7).timeout
	finished.emit(p_success)
