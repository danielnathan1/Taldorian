# scenes/world/player/player_character.gd
# Personagem local do jogador — movimento tile-based com animação via Tween.
extends CharacterBody2D

const TILE_SIZE     := 16
const MOVE_DURATION := 0.15

var tile_pos: Vector2i = Vector2i(5, 5)
var _is_moving: bool   = false
var _move_tween: Tween
var _chat_timer: float = 0.0
const CHAT_DISPLAY_TIME := 4.0

@onready var name_label  : Label   = $NameLabel
@onready var chat_bubble : Control = $ChatBubble
@onready var chat_label  : Label   = $ChatBubble/Label

func _ready() -> void:
	name_label.text = NetworkState.player_name
	chat_bubble.visible = false
	GameBus.world_state_synced.connect(_on_world_synced)
	position = _tile_to_world(tile_pos)

func _unhandled_input(event: InputEvent) -> void:
	if _is_moving:
		return
	var dir := Vector2i.ZERO
	if event.is_action_pressed("ui_right"): dir = Vector2i(1, 0)
	elif event.is_action_pressed("ui_left"):  dir = Vector2i(-1, 0)
	elif event.is_action_pressed("ui_down"):  dir = Vector2i(0, 1)
	elif event.is_action_pressed("ui_up"):    dir = Vector2i(0, -1)
	if dir != Vector2i.ZERO:
		_try_move(dir)

func _process(delta: float) -> void:
	if _chat_timer > 0.0:
		_chat_timer -= delta
		if _chat_timer <= 0.0:
			chat_bubble.visible = false

func _draw() -> void:
	var half := TILE_SIZE / 2
	draw_rect(Rect2(-half, -half, TILE_SIZE, TILE_SIZE), Color(0.2, 0.4, 0.9))
	draw_rect(Rect2(-half, -half, TILE_SIZE, TILE_SIZE), Color(0.6, 0.8, 1.0), false, 1.5)

func _try_move(dir: Vector2i) -> void:
	_is_moving = true
	tile_pos += dir
	WorldState.request_move(dir)
	_animate_move(_tile_to_world(tile_pos))

func _animate_move(target_pos: Vector2) -> void:
	if _move_tween:
		_move_tween.kill()
	_move_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_move_tween.tween_property(self, "position", target_pos, MOVE_DURATION)
	_move_tween.tween_callback(func() -> void: _is_moving = false)

func show_chat(message: String) -> void:
	chat_label.text = message
	chat_bubble.visible = true
	_chat_timer = CHAT_DISPLAY_TIME

func _on_world_synced(players: Dictionary) -> void:
	var local_id := multiplayer.get_unique_id()
	if not players.has(local_id):
		return
	var server_tile: Vector2i = players[local_id]["tile"]
	if server_tile != tile_pos and not _is_moving:
		tile_pos = server_tile
		position = _tile_to_world(tile_pos)

static func _tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * TILE_SIZE + TILE_SIZE / 2.0, tile.y * TILE_SIZE + TILE_SIZE / 2.0)
