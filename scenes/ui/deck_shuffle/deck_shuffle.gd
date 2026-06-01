extends Control
class_name DeckShuffle

# ────────────────────────────────────────────────────────────────────────────
# DECK SHUFFLE — Taldorian TCCG
#
# Anima uma pilha de N cartas (verso) num dos três estilos abaixo. As cartas
# são Sprite2D instanciadas em runtime e atualizadas a cada frame via
# _process(). Toda a "matemática" do shuffle vive em _riffle/_overhand/
# _fountain — funções puras que recebem (i, n, p) e devolvem um Dictionary
# com a transform daquela carta no instante p ∈ [0,1] do ciclo.
#
# Godot 2D não tem rotação 3D real, então o "yaw" (rotação em Y) é fingido
# espremendo o sprite horizontalmente via scale.x = cos(ry). É o suficiente
# para o olho aceitar o movimento como uma carta virando levemente.
# ────────────────────────────────────────────────────────────────────────────

## Emitido ao fim do primeiro ciclo quando play_once() foi chamado.
signal shuffle_done

# ── Constantes públicas ───────────────────────────────────────────────────────
const STYLE_RIFFLE   := "riffle"
const STYLE_OVERHAND := "overhand"
const STYLE_FOUNTAIN := "fountain"

const STYLE_DUR := {
	STYLE_RIFFLE:   2.4,
	STYLE_OVERHAND: 2.8,
	STYLE_FOUNTAIN: 2.6,
}

# ── Parâmetros exportados ─────────────────────────────────────────────────────
@export var card_back_texture: Texture2D:
	set(value):
		card_back_texture = value
		if is_inside_tree(): _rebuild_cards()

@export_range(4, 64, 1) var card_count: int = 18:
	set(value):
		card_count = clamp(value, 2, 96)
		if is_inside_tree(): _rebuild_cards()

@export var card_size: Vector2 = Vector2(220, 320):
	set(value):
		card_size = value
		if is_inside_tree(): _apply_base_scale()

@export_enum("riffle", "overhand", "fountain") var shuffle_style: String = STYLE_RIFFLE:
	set(value):
		shuffle_style = value
		_time = 0.0

@export_range(0.1, 4.0, 0.1) var speed: float = 1.0
@export_range(0.1, 2.5, 0.1) var stack_gap: float = 0.7
@export_range(0.0, 3.0, 0.05) var loop_pause: float = 0.35
@export var auto_play: bool = true


# ── Estado interno ────────────────────────────────────────────────────────────
var _cards: Array[Sprite2D] = []
var _time: float = 0.0
var _paused: bool = false
var _play_once: bool = false


# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_rebuild_cards()


func _process(delta: float) -> void:
	if _paused or _cards.is_empty():
		return
	if not auto_play and not _play_once:
		return
	var dur: float = STYLE_DUR.get(shuffle_style, 2.4)
	var cycle: float = dur + loop_pause
	_time = fmod(_time + delta * speed, cycle)
	var p: float = clamp(_time / dur, 0.0, 1.0)
	_apply_frame(p)
	if _play_once and _time >= dur:
		_paused = true
		_play_once = false
		shuffle_done.emit()


# ── Atalhos de teclado (debug) ────────────────────────────────────────────────
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE: _paused = not _paused
			KEY_R:     restart()


# ── API pública ───────────────────────────────────────────────────────────────
func play() -> void:
	_paused = false

func pause() -> void:
	_paused = true

func restart() -> void:
	_time = 0.0
	_paused = false
	_apply_frame(0.0)

## Toca exatamente um ciclo e emite shuffle_done ao final.
func play_once() -> void:
	_time = 0.0
	_play_once = true
	_paused = false
	_apply_frame(0.0)

## Troca o estilo e reinicia o ciclo.
func set_style(s: String) -> void:
	shuffle_style = s


# ── Construção da pilha de cartas ─────────────────────────────────────────────
func _rebuild_cards() -> void:
	for c in _cards:
		if is_instance_valid(c): c.queue_free()
	_cards.clear()

	var deck: Node2D = %DeckRoot
	for i in card_count:
		var sp := Sprite2D.new()
		sp.texture = card_back_texture
		sp.centered = true
		sp.z_index = 1000 + i
		deck.add_child(sp)
		_cards.append(sp)
	_apply_base_scale()
	_apply_frame(0.0)


func _apply_base_scale() -> void:
	var base := _base_card_scale()
	for sp in _cards:
		sp.scale = base


func _base_card_scale() -> Vector2:
	if card_back_texture == null:
		return Vector2.ONE
	var ts: Vector2 = card_back_texture.get_size()
	if ts.x <= 0 or ts.y <= 0:
		return Vector2.ONE
	return Vector2(card_size.x / ts.x, card_size.y / ts.y)


# ── Aplicação do frame atual ──────────────────────────────────────────────────
func _apply_frame(p: float) -> void:
	var n := card_count
	var base := _base_card_scale()
	for i in n:
		var tr := _compute(i, n, p)
		var sp := _cards[i]
		sp.position = Vector2(tr.x, tr.y)
		sp.rotation = deg_to_rad(tr.rz)
		var yaw_squish: float = cos(deg_to_rad(tr.ry))
		sp.scale = Vector2(base.x * max(0.05, absf(yaw_squish)), base.y)
		sp.z_index = tr.z_index


func _compute(i: int, n: int, p: float) -> Dictionary:
	match shuffle_style:
		STYLE_OVERHAND: return _overhand(i, n, p)
		STYLE_FOUNTAIN: return _fountain(i, n, p)
		_:              return _riffle(i, n, p)


# ── Easings ───────────────────────────────────────────────────────────────────
static func _ease_in_out(t: float) -> float:
	return 2.0 * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0

static func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)

static func _ease_in(t: float) -> float:
	return t * t * t

static func _clamp01(t: float) -> float:
	return clamp(t, 0.0, 1.0)


# ── RIFFLE ────────────────────────────────────────────────────────────────────
func _riffle(i: int, n: int, p: float) -> Dictionary:
	var half_n: int = n / 2
	var is_left: bool = i < half_n
	var half_pos: int = i if is_left else i - half_n
	var new_i: int = (2 * half_pos) if is_left else (2 * half_pos + 1)

	var base_y: float = -i * stack_gap
	var final_y: float = -new_i * stack_gap

	var split_end: float = 0.20
	var fall_start: float = 0.26
	var fall_end: float = 0.94

	var split_x: float = -190.0 if is_left else 190.0
	var split_y_lift: float = -30.0
	var split_tilt: float = -7.0 if is_left else 7.0
	var split_yaw: float = -14.0 if is_left else 14.0

	if p < split_end:
		var t: float = _ease_in_out(p / split_end)
		return {
			"x":  split_x * t,
			"y":  base_y + split_y_lift * t,
			"rz": split_tilt * t,
			"ry": split_yaw * t,
			"z_index": 1000 + i,
		}

	var fall_span: float = fall_end - fall_start
	var card_win: float = max(0.10, fall_span / float(n) * 2.4)
	var card_start: float = fall_start + (float(new_i) / max(1, n - 1)) * (fall_span - card_win)
	var card_end: float = card_start + card_win

	var split_x_pos: float = split_x
	var split_y_pos: float = base_y + split_y_lift

	if p < card_start:
		return {
			"x":  split_x_pos,
			"y":  split_y_pos,
			"rz": split_tilt,
			"ry": split_yaw,
			"z_index": 2000 + i,
		}

	if p < card_end:
		var t: float = _clamp01((p - card_start) / (card_end - card_start))
		var e: float = _ease_in_out(t)
		var arc: float = sin(t * PI) * 55.0
		return {
			"x":  split_x_pos * (1.0 - e),
			"y":  split_y_pos + (final_y - split_y_pos) * e - arc,
			"rz": split_tilt * (1.0 - e),
			"ry": split_yaw * (1.0 - e),
			"z_index": 3000 + int(t * 1000.0) + i,
		}

	return {
		"x":  0.0,
		"y":  final_y,
		"rz": 0.0,
		"ry": 0.0,
		"z_index": 1000 + new_i,
	}


# ── OVERHAND ──────────────────────────────────────────────────────────────────
func _overhand(i: int, n: int, p: float) -> Dictionary:
	var base_y: float = -i * stack_gap

	var packets: int = 3
	var packet_size: int = int(ceil(float(n) / packets))
	var top_idx: int = (n - 1) - i
	var packet_idx: int = top_idx / packet_size
	var card_in_packet: int = top_idx % packet_size

	var new_i: int = mini(packet_idx * packet_size + (packet_size - 1 - card_in_packet), n - 1)
	var final_y: float = -new_i * stack_gap

	var p_start: float = float(packet_idx) / packets
	var p_end: float = float(packet_idx + 1) / packets

	if p < p_start:
		return { "x": 0.0, "y": base_y, "rz": 0.0, "ry": 0.0, "z_index": 1000 + i }
	if p >= p_end:
		return { "x": 0.0, "y": final_y, "rz": 0.0, "ry": 0.0, "z_index": 1000 + new_i }

	var local_p: float = (p - p_start) / (p_end - p_start)
	var lift: float = 0.30
	var swing: float = 0.70

	if local_p < lift:
		var t: float = _ease_out(local_p / lift)
		return {
			"x":  260.0 * t,
			"y":  base_y - 10.0 * t,
			"rz": 6.0 * t,
			"ry": 18.0 * t,
			"z_index": 3000 + i,
		}
	elif local_p < swing:
		var t: float = _ease_in_out((local_p - lift) / (swing - lift))
		var arc: float = sin(t * PI) * 50.0
		var lifted_y: float = base_y - 10.0
		return {
			"x":  260.0 * (1.0 - t),
			"y":  lifted_y - arc + (final_y - lifted_y) * t,
			"rz": 6.0 * (1.0 - t),
			"ry": 18.0 * (1.0 - t),
			"z_index": 3000 + i,
		}
	else:
		var t: float = _ease_in((local_p - swing) / (1.0 - swing))
		return {
			"x":  0.0,
			"y":  lerp(final_y - 12.0, final_y, t),
			"rz": 0.0,
			"ry": 0.0,
			"z_index": 2500 + new_i,
		}


# ── FOUNTAIN ──────────────────────────────────────────────────────────────────
func _fountain(i: int, n: int, p: float) -> Dictionary:
	var base_y: float = -i * stack_gap
	var new_i: int = (n - 1) - i
	var final_y: float = -new_i * stack_gap

	var angle_range: float = 110.0
	var angle: float = -angle_range / 2.0 + (float(i) / max(1, n - 1)) * angle_range
	var rad: float = deg_to_rad(angle)
	var radius: float = 220.0 + float(i % 3) * 18.0

	var peak_x: float = sin(rad) * radius
	var peak_y: float = -cos(rad) * radius - 60.0

	if p < 0.45:
		var t: float = _ease_out(p / 0.45)
		return {
			"x":  peak_x * t,
			"y":  base_y + (peak_y - base_y) * t,
			"rz": angle * t,
			"ry": angle * 0.3 * t,
			"z_index": 2000 + i,
		}
	elif p < 0.55:
		var t: float = (p - 0.45) / 0.10
		var wob: float = sin(t * TAU) * 4.0
		return {
			"x":  peak_x + wob,
			"y":  peak_y + wob * 0.5,
			"rz": angle,
			"ry": angle * 0.3,
			"z_index": 2000 + i,
		}
	else:
		var t: float = _ease_in_out((p - 0.55) / 0.45)
		return {
			"x":  peak_x * (1.0 - t),
			"y":  peak_y + (final_y - peak_y) * t,
			"rz": angle * (1.0 - t),
			"ry": angle * 0.3 * (1.0 - t),
			"z_index": 2000 + (new_i if t > 0.9 else i),
		}
