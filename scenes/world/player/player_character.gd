# scenes/world/player/player_character.gd
# Personagem local do jogador — movimento tile-based com animação via Tween.
# Aparência carregada dinamicamente do CharacterStore.
extends CharacterBody2D

const TILE_SIZE     := 16
const MOVE_DURATION := 0.15
const STAND_FRAME   := 18   # row 2 (frente) × hframes(9) + col 0

var tile_pos: Vector2i = Vector2i(62, 34)
var _is_moving: bool   = false
var _move_tween: Tween
var _chat_timer: float = 0.0
const CHAT_DISPLAY_TIME := 4.0

var _last_dir: Vector2i = Vector2i(0, 1)  # padrão: olhando para baixo

@onready var name_label  : Label    = $NameLabel
@onready var chat_bubble : Control  = $ChatBubble
@onready var chat_label  : Label    = $ChatBubble/Label
@onready var _body       : Sprite2D = $Skeleton/Body
@onready var _hair       : Sprite2D = $Skeleton/Hair
@onready var _chest      : Sprite2D = $Skeleton/Chest
@onready var _pants      : Sprite2D = $Skeleton/Pants
@onready var _shoes      : Sprite2D = $Skeleton/Shoes
@onready var _animation_player = $AnimationPlayer

# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	z_index = 1          # garante renderização acima dos TileMapLayers (z=0)
	chat_bubble.visible = false
	GameBus.world_state_synced.connect(_on_world_synced)
	position = _tile_to_world(tile_pos)
	_load_appearance()
	_play_idle_anim(_last_dir)

# ═══════════════════════════════════════════════════════════════════════════════
# APARÊNCIA
# ═══════════════════════════════════════════════════════════════════════════════

func _load_appearance() -> void:
	# Garante frame correto mesmo sem CharacterStore (fallback p/ textura do .tscn)
	_init_sprite_frame(_body)
	for cat_id in ["hair", "chest", "legs", "shoes"]:
		var s := _get_sprite(cat_id)
		if s:
			_init_sprite_frame(s)

	if not CharacterStore.has_character():
		name_label.text = NetworkState.player_name
		return

	var ch := CharacterStore.get_character()
	name_label.text = str(ch.get("name", NetworkState.player_name))

	# Body (sem tinting — sprite separada por tom de pele)
	_apply_sprite(_body, ch.get("body", {}), Color.WHITE)

	# Camadas com cor
	for cat_id in ["hair", "chest", "legs", "shoes"]:
		var sprite := _get_sprite(cat_id)
		if not sprite:
			continue
		var cat   := ch.get(cat_id, {}) as Dictionary
		var color := _parse_color(str(cat.get("color", "ffffffff")))
		_apply_sprite(sprite, cat, color)

# Define hframes/vframes/frame sem mexer na textura (usa o que veio do .tscn).
func _init_sprite_frame(sprite: Sprite2D) -> void:
	if sprite.texture == null:
		return
	sprite.hframes = 9
	sprite.vframes = 4
	sprite.frame   = STAND_FRAME

func _apply_sprite(sprite: Sprite2D, cat: Variant, color: Color) -> void:
	var d    := cat as Dictionary
	var path := str(d.get("path", ""))
	if path != "" and ResourceLoader.exists(path):
		sprite.texture = load(path)
	# Se não tem path (formato antigo ou dado faltando), mantém textura do .tscn
	if sprite.texture == null:
		return
	sprite.hframes  = 9
	sprite.vframes  = 4
	sprite.frame    = STAND_FRAME
	sprite.modulate = color

func _get_sprite(cat_id: String) -> Sprite2D:
	match cat_id:
		"hair":  return _hair
		"chest": return _chest
		"legs":  return _pants
		"shoes": return _shoes
	return null

# Converte string hex salva pelo CharacterStore de volta para Color.
func _parse_color(hex: String, fallback: Color = Color.WHITE) -> Color:
	if hex.length() >= 6:
		return Color(hex)
	return fallback

# ═══════════════════════════════════════════════════════════════════════════════
# MOVIMENTO
# ═══════════════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if _chat_timer > 0.0:
		_chat_timer -= delta
		if _chat_timer <= 0.0:
			chat_bubble.visible = false

	if _is_moving:
		return

	var dir := Vector2i(
		int(Input.get_axis("ui_left", "ui_right")),
		int(Input.get_axis("ui_up",   "ui_down"))
	)

	if dir != Vector2i.ZERO:
		_try_move(dir)
	else:
		_play_idle_anim(_last_dir)

func _try_move(dir: Vector2i) -> void:
	_is_moving = true
	_last_dir  = dir
	tile_pos  += dir
	WorldState.request_move(dir)
	_play_walk_anim(dir)
	_animate_move(_tile_to_world(tile_pos))

func _animate_move(target_pos: Vector2) -> void:
	if _move_tween:
		_move_tween.kill()
	_move_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_move_tween.tween_property(self, "position", target_pos, MOVE_DURATION)
	_move_tween.tween_callback(func() -> void: _is_moving = false)

func _play_walk_anim(dir: Vector2i) -> void:
	if dir.x < 0:   _play_anim("walk_left")
	elif dir.x > 0: _play_anim("walk_right")
	elif dir.y < 0: _play_anim("walk_up")
	else:            _play_anim("walk_down")

func _play_idle_anim(dir: Vector2i) -> void:
	if dir.x < 0:   _play_anim("idle_left")
	elif dir.x > 0: _play_anim("idle_right")
	elif dir.y < 0: _play_anim("idle_up")
	else:            _play_anim("idle_down")

func _play_anim(anim: StringName) -> void:
	if _animation_player and _animation_player.has_animation(anim):
		_animation_player.play(anim)

# ═══════════════════════════════════════════════════════════════════════════════
# CHAT
# ═══════════════════════════════════════════════════════════════════════════════

func show_chat(message: String) -> void:
	chat_label.text    = message
	chat_bubble.visible = true
	_chat_timer        = CHAT_DISPLAY_TIME

# ═══════════════════════════════════════════════════════════════════════════════
# SYNC
# ═══════════════════════════════════════════════════════════════════════════════

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
