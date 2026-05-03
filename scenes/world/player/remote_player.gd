# scenes/world/player/remote_player.gd
# Representação de outro jogador no mapa — sem input, só recebe posição via sync.
extends Node2D

const TILE_SIZE  := 16
const LERP_SPEED := 10.0

var _target_pos: Vector2
var _chat_timer: float = 0.0
const CHAT_DISPLAY_TIME := 4.0

@onready var name_label  : Label   = $NameLabel
@onready var chat_bubble : Control = $ChatBubble
@onready var chat_label  : Label   = $ChatBubble/Label

func setup(p_name: String, p_tile: Vector2i) -> void:
	_target_pos = _tile_to_world(p_tile)
	position    = _target_pos
	name_label.text = p_name

func set_target_tile(tile: Vector2i) -> void:
	_target_pos = _tile_to_world(tile)

func _process(delta: float) -> void:
	position = position.lerp(_target_pos, delta * LERP_SPEED)
	if _chat_timer > 0.0:
		_chat_timer -= delta
		if _chat_timer <= 0.0:
			chat_bubble.visible = false

func _draw() -> void:
	var half := TILE_SIZE / 2
	draw_rect(Rect2(-half, -half, TILE_SIZE, TILE_SIZE), Color(0.9, 0.3, 0.2))
	draw_rect(Rect2(-half, -half, TILE_SIZE, TILE_SIZE), Color(1.0, 0.7, 0.6), false, 1.5)

func show_chat(message: String) -> void:
	chat_label.text = message
	chat_bubble.visible = true
	_chat_timer = CHAT_DISPLAY_TIME

static func _tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * TILE_SIZE + TILE_SIZE / 2.0, tile.y * TILE_SIZE + TILE_SIZE / 2.0)
