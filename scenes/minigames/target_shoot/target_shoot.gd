# scenes/minigames/target_shoot/target_shoot.gd
# Tiro ao alvo: um alvo aparece em posição aleatória dentro da arena e o jogador precisa CLICAR
# nele antes do anel de tempo se esgotar. 3 fases (número de alvos + meta mínima de acertos cada);
# cada fase é mais rápida que a anterior (o alvo some mais cedo). Acertar = "flecha" cai no alvo.
# Errar (clique fora ou o tempo esgota) só consome a tentativa — a fase só falha se os acertos
# ficarem abaixo da meta ao fim dela.
# Config: { targets_per_round: Array[int], hits_needed: Array[int], target_lifetime: float,
#           lifetime_decrease: float, target_radius: float }.
extends Minigame

const AREA := Vector2(440.0, 300.0)
const TARGET_R := 28.0
const HIT_FLASH_TIME := 0.25

# Sinal interno: a tentativa no alvo atual terminou (acerto ou tempo esgotado).
signal _attempt_done(hit: bool)

@onready var _title: Label = $Title
@onready var _status: Label = $Status

var _targets_per_round: Array = [7, 8, 10]
var _hits_needed: Array = [3, 5, 7]
var _lifetime: float = 1.0
var _lifetime_decrease: float = 0.15
var _target_r: float = TARGET_R

var _target_pos: Vector2 = Vector2.ZERO
var _target_active: bool = false
var _target_time_left: float = 0.0
var _target_full_time: float = 1.0
var _hit_flash: float = 0.0   # >0 = tocando a animação de acerto (flecha) na posição do alvo

func start(p_config: Dictionary) -> void:
	_targets_per_round = p_config.get("targets_per_round", [7, 8, 10])
	_hits_needed       = p_config.get("hits_needed", [3, 5, 7])
	_lifetime          = float(p_config.get("target_lifetime", 1.0))
	_lifetime_decrease = float(p_config.get("lifetime_decrease", 0.15))
	_target_r          = float(p_config.get("target_radius", TARGET_R))
	print("[TargetShoot] config=%s" % [p_config])
	_status.text = ""
	set_process(true)
	for r in _targets_per_round.size():
		_title.text = "Fase %d / %d — clique nos alvos!" % [r + 1, _targets_per_round.size()]
		var lifetime_r: float = maxf(0.35, _lifetime - r * _lifetime_decrease)
		var ok: bool = await _play_round(int(_targets_per_round[r]), int(_hits_needed[r]), lifetime_r)
		if not ok:
			_end(false)
			return
		if r < _targets_per_round.size() - 1:
			_status.text = "Fase %d concluída!" % [r + 1]
			await get_tree().create_timer(0.5).timeout
	_end(true)

# Uma fase: dispara p_total alvos em sequência, devolve se atingiu a meta de acertos.
func _play_round(p_total: int, p_needed: int, p_lifetime: float) -> bool:
	var hits := 0
	for i in p_total:
		_status.text = "Acertos: %d / %d necessários" % [hits, p_needed]
		var hit: bool = await _play_target(p_lifetime)
		if hit:
			hits += 1
	return hits >= p_needed

# Um alvo: sorteia posição, espera clique ou estouro do tempo. Devolve se acertou.
func _play_target(p_lifetime: float) -> bool:
	_target_pos = Vector2(randf_range(_target_r, AREA.x - _target_r), randf_range(_target_r, AREA.y - _target_r))
	_target_full_time = p_lifetime
	_target_time_left = p_lifetime
	_target_active = true
	var hit: bool = await _attempt_done
	_hit_flash = HIT_FLASH_TIME
	await get_tree().create_timer(0.18).timeout
	return hit

func _process(delta: float) -> void:
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta)
	if _target_active:
		_target_time_left -= delta
		if _target_time_left <= 0.0:
			_target_active = false
			_attempt_done.emit(false)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not _target_active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local := get_viewport().get_mouse_position() - _area_rect().position
		if local.distance_to(_target_pos) <= _target_r:
			_target_active = false
			_attempt_done.emit(true)

func _area_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(vp * 0.5 - AREA * 0.5, AREA)

func _draw() -> void:
	# Escurecimento de fundo (fica ATRÁS da arena; os Labels são filhos → por cima).
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0, 0, 0, 0.7), true)
	var area := _area_rect()
	var o := area.position
	draw_rect(area, Color(0.08, 0.10, 0.18, 0.95), true)
	draw_rect(area, Color(0.4, 0.6, 1.0, 0.6), false, 2.0)
	if _target_active:
		var t := o + _target_pos
		var frac := clampf(_target_time_left / maxf(_target_full_time, 0.001), 0.0, 1.0)
		draw_circle(t, _target_r, Color(0.9, 0.3, 0.25, 0.25))
		draw_arc(t, _target_r, 0.0, TAU, 32, Color(0.95, 0.4, 0.3, 0.9), 3.0, true)
		draw_arc(t, _target_r * 0.55, -PI * 0.5, -PI * 0.5 + TAU * frac, 24, Color(1, 1, 1, 0.85), 4.0, true)
	if _hit_flash > 0.0:
		var t := o + _target_pos
		var alpha := _hit_flash / HIT_FLASH_TIME
		draw_circle(t, _target_r * (1.6 - alpha * 0.6), Color(1.0, 0.85, 0.3, alpha * 0.8))
		# flecha "descendo" no alvo, encolhendo até o impacto.
		var tail := t + Vector2(0, -_target_r * 2.2 * alpha - 6.0)
		draw_line(tail, t, Color(0.85, 0.7, 0.4, alpha), 4.0)
		draw_line(t, t + Vector2(-7, -10), Color(0.85, 0.7, 0.4, alpha), 4.0)
		draw_line(t, t + Vector2(7, -10), Color(0.85, 0.7, 0.4, alpha), 4.0)
	# mira do mouse (feedback simples de "onde vou clicar").
	var mouse := get_viewport().get_mouse_position()
	if Rect2(Vector2.ZERO, AREA).has_point(mouse - o):
		draw_line(mouse + Vector2(-10, 0), mouse + Vector2(10, 0), Color(1, 1, 1, 0.7), 2.0)
		draw_line(mouse + Vector2(0, -10), mouse + Vector2(0, 10), Color(1, 1, 1, 0.7), 2.0)

func _end(p_success: bool) -> void:
	set_process(false)
	_status.text = "Pontaria de mestre!" if p_success else "Faltou pontaria..."
	await get_tree().create_timer(0.7).timeout
	finished.emit(p_success)
