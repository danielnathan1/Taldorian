# scenes/world/scanner/scanner.gd
# Scanner "Olho Arcano" — componente que se anexa ao player. Mecânica HOLD: o jogador SEGURA
# Espaço e precisa manter um alvo do grupo 'scannable' dentro da área por `scan_duration`
# segundos; o pulso mostra o progresso (relógio). Completou → scan_completed(target).
# Se o alvo já foi rastreado (meta "scanned") → scan_blocked(target) (sem carregar).
# Soltar Espaço ou o alvo sair da área → reseta o progresso.
extends Node2D

signal scan_completed(target: Node)
signal scan_blocked(target: Node)

const SCAN_GROUP := "scannable"

@export var reach: float = 38.0            # distância à frente onde o centro da área fica
@export var radius: float = 26.0           # raio da área de detecção
@export var scan_duration: float = 3.0     # segundos mantendo o alvo na área para rastrear

@onready var _pulse: Node2D = $Pulse

var _facing_source: Node                   # fornece get_facing() -> Vector2i (o player)
var _enabled: bool = false
var _charge: float = 0.0
var _consumed: bool = false                # travado após completar, até soltar Espaço
var _blocked_announced: bool = false       # debounce do aviso "já rastreou" por hold

# Liga o scanner e define quem dá a direção (o player). Chamar ao liberar o controle.
func enable(p_facing_source: Node) -> void:
	_facing_source = p_facing_source
	_enabled = true

func disable() -> void:
	_enabled = false
	_reset()

func _process(delta: float) -> void:
	if not _enabled:
		return
	if not Input.is_key_pressed(KEY_SPACE):
		_reset()
		return
	if _consumed:
		return   # segurou após completar; espera soltar para liberar novo scan
	var offset := Vector2(_facing()) * reach
	var target := _best_target(global_position + offset)
	if target == null:
		# Segurando, sem alvo: círculo vazio (sem progresso).
		_charge = 0.0
		_blocked_announced = false
		_pulse.show_hold(offset, 0.0)
		return
	if _is_scanned(target):
		# Já rastreado: avisa uma vez, não carrega.
		_charge = 0.0
		_pulse.show_hold(offset, 0.0)
		if not _blocked_announced:
			_blocked_announced = true
			scan_blocked.emit(target)
		return
	# Alvo novo válido → carrega enquanto mantido na área.
	_blocked_announced = false
	_charge += delta
	var t := clampf(_charge / scan_duration, 0.0, 1.0)
	_pulse.show_hold(offset, t)
	if t >= 1.0:
		_charge = 0.0
		_consumed = true
		_pulse.flash_complete(offset)
		scan_completed.emit(target)

func _reset() -> void:
	_charge = 0.0
	_consumed = false
	_blocked_announced = false
	_pulse.hide_hold()

func _is_scanned(p_node: Node) -> bool:
	return p_node.has_meta("scanned") and bool(p_node.get_meta("scanned"))

# Alvo mais próximo do centro da área, dentro do raio (checagem por distância no grupo).
func _best_target(p_origin: Vector2) -> Node:
	var best: Node = null
	var best_dist := radius
	for node in get_tree().get_nodes_in_group(SCAN_GROUP):
		if node is Node2D:
			var d := p_origin.distance_to((node as Node2D).global_position)
			if d <= best_dist:
				best_dist = d
				best = node
	return best

func _facing() -> Vector2:
	if _facing_source != null and _facing_source.has_method("get_facing"):
		return Vector2(_facing_source.get_facing())
	return Vector2(0, 1)
