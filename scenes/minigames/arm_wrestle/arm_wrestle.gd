# scenes/minigames/arm_wrestle/arm_wrestle.gd
# Queda de braço: cada CLIQUE aumenta a força do jogador (até um teto) e essa força decai sozinha
# quando ele para de clicar. A força da oponente é uma resistência CONSTANTE — é aí que mora a
# dificuldade. O braço (posição 0..1) desliza pra diferença das forças a cada frame.
# 0.0 = oponente vence; 1.0 = jogador vence.
# Fica PARADO (sem decay/puxão do oponente) até o primeiro clique — dá tempo de ler o aviso
# antes do relógio começar a correr.
# Config (dificuldade): { opponent_power, click_power, power_decay, max_power, start_pos }.
extends Minigame

const BAR_SIZE := Vector2(420.0, 40.0)
const INTRO_TEXT := "Clique o máximo de vezes que conseguir!"

@onready var _title: Label = $Title
@onready var _status: Label = $Status

var _pos: float = 0.5
var _player_power: float = 0.0
var _playing: bool = false
var _started: bool = false   # vira true no 1º clique — só aí o oponente começa a puxar

# dificuldade (vem da config)
var _opponent_power: float = 0.55
var _click_power: float = 0.14
var _power_decay: float = 0.5
var _max_power: float = 1.0

func start(p_config: Dictionary) -> void:
	_opponent_power = float(p_config.get("opponent_power", 0.55))
	_click_power    = float(p_config.get("click_power", 0.14))
	_power_decay    = float(p_config.get("power_decay", 0.5))
	_max_power      = float(p_config.get("max_power", 1.0))
	_pos            = float(p_config.get("start_pos", 0.5))
	print("[ArmWrestle] config=%s" % [p_config])
	_player_power = 0.0
	_started = false
	_title.text = INTRO_TEXT
	_status.text = ""
	_playing = true
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if not _playing or not _started:
		return
	_player_power = maxf(0.0, _player_power - _power_decay * delta)
	_pos = clampf(_pos + (_player_power - _opponent_power) * delta, 0.0, 1.0)
	if _pos >= 1.0:
		_end(true)
	elif _pos <= 0.0:
		_end(false)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not _playing:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _started:
			_started = true
			_title.text = "Não pare de clicar!"
		_player_power = minf(_max_power, _player_power + _click_power)
		queue_redraw()

func _bar_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(vp * 0.5 - BAR_SIZE * 0.5, BAR_SIZE)

func _draw() -> void:
	# Escurecimento de fundo (fica ATRÁS da arena; os Labels são filhos → por cima).
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0, 0, 0, 0.7), true)
	var bar := _bar_rect()
	# Trilha da disputa: vermelho (oponente, esquerda) preenchido por verde (jogador) até _pos.
	draw_rect(bar, Color(0.55, 0.18, 0.18, 0.95), true)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _pos, bar.size.y)), Color(0.25, 0.7, 0.35, 0.95), true)
	draw_rect(bar, Color(1, 1, 1, 0.35), false, 2.0)
	# Marcador central (empate).
	var mid_x := bar.position.x + bar.size.x * 0.5
	draw_line(Vector2(mid_x, bar.position.y - 8.0), Vector2(mid_x, bar.position.y + bar.size.y + 8.0), Color(1, 1, 1, 0.5), 2.0)
	# Cursor do braço.
	var cursor := Vector2(bar.position.x + bar.size.x * _pos, bar.position.y + bar.size.y * 0.5)
	draw_circle(cursor, bar.size.y * 0.6, Color(1.0, 0.9, 0.6))
	draw_arc(cursor, bar.size.y * 0.6, 0.0, TAU, 32, Color(0.4, 0.3, 0.1, 0.9), 2.0, true)
	# Medidor de força do jogador (abaixo da barra) — feedback do ramp-up/decaimento do clique.
	var gauge := Rect2(bar.position.x, bar.position.y + bar.size.y + 24.0, bar.size.x, 14.0)
	draw_rect(gauge, Color(0, 0, 0, 0.5), true)
	var gauge_fill := gauge.size.x * (_player_power / maxf(_max_power, 0.001))
	draw_rect(Rect2(gauge.position, Vector2(gauge_fill, gauge.size.y)), Color(1.0, 0.75, 0.3), true)
	draw_rect(gauge, Color(1, 1, 1, 0.3), false, 1.0)

func _end(p_success: bool) -> void:
	_playing = false
	set_process(false)
	_status.text = "Você venceu a queda de braço!" if p_success else "Sua força não foi suficiente..."
	await get_tree().create_timer(0.7).timeout
	finished.emit(p_success)
