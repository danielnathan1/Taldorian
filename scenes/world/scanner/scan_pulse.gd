# scenes/world/scanner/scan_pulse.gd
# Efeito de scan PROCEDURAL (sem arte). Dois modos:
#   HOLD     — enquanto o jogador segura o scan: feixe do personagem até o chão + um círculo
#              mágico no piso com uma BARRA RADIAL (estilo relógio) que preenche conforme o
#              progresso (0→1) e muda de cor (azul → verde). É o "mantenha o alvo por X seg".
#   COMPLETE — flash rápido de anel ao concluir o rastreamento.
# Usa CanvasItemMaterial blend ADD (no .tscn) → as cores leem como luz.
extends Node2D

@export var color_start: Color = Color(0.40, 0.80, 1.0)   # progresso 0%
@export var color_full: Color = Color(0.45, 1.0, 0.55)    # progresso 100%
@export var circle_radius: float = 18.0
@export var ground_drop: float = 22.0

const MODE_NONE := 0
const MODE_HOLD := 1
const MODE_COMPLETE := 2

var _mode: int = MODE_NONE
var _offset: Vector2 = Vector2.ZERO
var _progress: float = 0.0
var _spin: float = 0.0          # rotação contínua das runas (cosmético)
var _complete_t: float = 0.0

func _ready() -> void:
	visible = false
	set_process(false)

## Mostra/atualiza o círculo de progresso à frente (chamado a cada frame enquanto segura).
func show_hold(p_offset: Vector2, p_progress: float) -> void:
	_offset = p_offset
	_progress = clampf(p_progress, 0.0, 1.0)
	_mode = MODE_HOLD
	visible = true
	set_process(true)
	queue_redraw()

## Esconde o círculo (soltou o scan). Não interrompe um flash de conclusão em andamento.
func hide_hold() -> void:
	if _mode == MODE_COMPLETE:
		return
	_mode = MODE_NONE
	visible = false
	set_process(false)

## Flash rápido ao concluir o rastreamento.
func flash_complete(p_offset: Vector2) -> void:
	_offset = p_offset
	_complete_t = 0.0
	_mode = MODE_COMPLETE
	visible = true
	set_process(true)

func _process(delta: float) -> void:
	_spin += delta
	if _mode == MODE_COMPLETE:
		_complete_t += delta
		if _complete_t >= 0.4:
			_mode = MODE_NONE
			visible = false
			set_process(false)
	queue_redraw()

func _draw() -> void:
	match _mode:
		MODE_HOLD: _draw_hold()
		MODE_COMPLETE: _draw_complete()

func _draw_hold() -> void:
	var ground := _offset + Vector2(0.0, ground_drop)
	var col := color_start.lerp(color_full, _progress)
	# Feixe do personagem até o chão.
	draw_line(Vector2.ZERO, ground, Color(col.r, col.g, col.b, 0.22), 5.0, true)
	draw_line(Vector2.ZERO, ground, Color(col.r, col.g, col.b, 0.85), 1.5, true)
	# Círculo no chão (achatado = perspectiva).
	draw_set_transform(ground, 0.0, Vector2(1.0, 0.5))
	var r := circle_radius
	# Anel base (fraco).
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(col.r, col.g, col.b, 0.30), 1.5, true)
	# Barra de progresso radial (relógio): do topo, sentido horário.
	var start_ang := -PI / 2.0
	var end_ang := start_ang + _progress * TAU
	if _progress > 0.0:
		draw_arc(Vector2.ZERO, r, start_ang, end_ang, 48, col, 3.0, true)
		# Ponteiro do relógio na ponta do progresso.
		var hand := Vector2(cos(end_ang), sin(end_ang))
		draw_line(Vector2.ZERO, hand * r, col, 1.5, true)
	# Runas girando (cosmético).
	for i in 12:
		var a := _spin + i * (TAU / 12.0)
		var d := Vector2(cos(a), sin(a))
		draw_line(d * (r * 0.78), d * (r * 0.96), Color(col.r, col.g, col.b, 0.28), 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_complete() -> void:
	var ground := _offset + Vector2(0.0, ground_drop)
	var t := _complete_t / 0.4
	draw_set_transform(ground, 0.0, Vector2(1.0, 0.5))
	var r := circle_radius * (1.0 + 0.8 * t)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(color_full.r, color_full.g, color_full.b, (1.0 - t) * 0.9), 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
