# scenes/minigames/memory_path/memory_path.gd
# Minigame de memória em RODADAS: a cada rodada, pegadas popam na ordem numa grade (um caminho),
# somem, e o jogador clica na ordem. 1 erro (em qualquer rodada) = perdeu tudo. Vencer = concluir
# todas as rodadas. Cada rodada fica mais difícil (caminho mais longo + reveal mais rápido).
# Config: { rounds:int, grid_size:int, path_length:int, path_increment:int, reveal_step:float }.
extends Minigame

const FOOT := "👣"

# Sinal interno: uma rodada terminou (await em _play_round).
signal _round_done(success: bool)

@onready var _grid: GridContainer = $Center/Panel/Margin/VBox/Grid
@onready var _title: Label = $Center/Panel/Margin/VBox/Title
@onready var _status: Label = $Center/Panel/Margin/VBox/Status

var _cells: Array[Button] = []
var _path: Array[int] = []     # índices das células, na ordem do caminho
var _input_idx: int = 0
var _accepting: bool = false

func start(p_config: Dictionary) -> void:
	var rounds: int = int(p_config.get("rounds", 3))
	var n: int = int(p_config.get("grid_size", 5))
	var base_len: int = int(p_config.get("path_length", 3))
	var inc: int = int(p_config.get("path_increment", 1))
	var step: float = float(p_config.get("reveal_step", 0.5))
	print("[MemoryPath] config=%s  → última rodada terá %d blocos" % [p_config, base_len + (rounds - 1) * inc])
	for r in rounds:
		var path_len: int = base_len + r * inc           # caminho cresce a cada rodada
		var step_r: float = maxf(0.2, step - r * 0.05)    # reveal acelera a cada rodada
		_title.text = "Rodada %d / %d" % [r + 1, rounds]
		var ok: bool = await _play_round(n, path_len, step_r)
		if not ok:
			finished.emit(false)
			return
	finished.emit(true)

# Uma rodada: monta a grade, gera o caminho, revela, espera o jogador repetir. Devolve se acertou.
func _play_round(p_n: int, p_len: int, p_step: float) -> bool:
	_input_idx = 0
	_accepting = false
	_status.text = "Observe..."
	_build_grid(p_n)
	_path = _generate_path(p_n, p_len)
	await _reveal(p_step)
	_accepting = true
	_status.text = "Repita o caminho!"
	var success: bool = await _round_done
	_accepting = false
	_status.text = "Boa!" if success else "Errou o caminho..."
	await get_tree().create_timer(0.6).timeout
	return success

func _build_grid(p_n: int) -> void:
	for c in _cells:
		c.queue_free()
	_cells.clear()
	_grid.columns = p_n
	for i in p_n * p_n:
		var b := Button.new()
		b.custom_minimum_size = Vector2(60, 60)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 28)
		b.pressed.connect(_on_cell.bind(i))
		_grid.add_child(b)
		_cells.append(b)

# Caminho de células adjacentes não repetidas, com BACKTRACKING — assim alcança caminhos longos
# (até a grade quase cheia) de forma CONFIÁVEL, sem "encalhar" cedo como um random walk ingênuo.
func _generate_path(p_n: int, p_len: int) -> Array[int]:
	var target := clampi(p_len, 1, p_n * p_n)
	var path: Array[int] = []
	var used := {}
	var start := Vector2i(randi() % p_n, randi() % p_n)
	_walk(p_n, start, target, used, path)
	return path

func _walk(p_n: int, p_cur: Vector2i, p_target: int, p_used: Dictionary, p_path: Array[int]) -> bool:
	p_path.append(p_cur.y * p_n + p_cur.x)
	p_used[p_cur] = true
	if p_path.size() >= p_target:
		return true
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	dirs.shuffle()
	for d in dirs:
		var nx := p_cur + d
		if nx.x >= 0 and nx.x < p_n and nx.y >= 0 and nx.y < p_n and not p_used.has(nx):
			if _walk(p_n, nx, p_target, p_used, p_path):
				return true
	# beco sem saída → desfaz e tenta outro ramo
	p_path.pop_back()
	p_used.erase(p_cur)
	return false

# Pega cada célula do caminho na ordem (mantém visível), segura, depois limpa tudo.
func _reveal(p_step: float) -> void:
	for idx in _path:
		_cells[idx].text = FOOT
		await get_tree().create_timer(p_step).timeout
	await get_tree().create_timer(0.6).timeout
	for idx in _path:
		_cells[idx].text = ""

func _on_cell(p_i: int) -> void:
	if not _accepting:
		return
	if p_i == _path[_input_idx]:
		_cells[p_i].text = FOOT
		_input_idx += 1
		if _input_idx >= _path.size():
			_accepting = false
			_round_done.emit(true)
	else:
		_cells[p_i].text = "✗"
		_accepting = false
		_round_done.emit(false)
