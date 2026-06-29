# scenes/world/player/remote_player.gd
# Representação de outro jogador — sem input, só recebe posição via sync.
# Usa a mesma estrutura visual do PlayerCharacter (Skeleton + AnimationPlayer).
extends Node2D

const TILE_SIZE     := 16
const LERP_SPEED    := 10.0
const MOVE_DURATION := 0.15

# Emitido ao clicar com o botão direito sobre este jogador (interações sociais).
signal right_clicked(remote_player: Node2D)

var _target_pos : Vector2
var _last_dir   : Vector2i = Vector2i(0, 1)   # padrão: olhando para baixo
var _chat_timer : float    = 0.0
const CHAT_DISPLAY_TIME := 4.0

@onready var _click_area      : Area2D       = $ClickArea
@onready var name_label       : Label        = $NameLabel
@onready var chat_bubble      : Control      = $ChatBubble
@onready var chat_label       : Label        = $ChatBubble/Label
@onready var _body            : Sprite2D     = $Skeleton/Body
@onready var _hair            : Sprite2D     = $Skeleton/Hair
@onready var _beard           : Sprite2D     = $Skeleton/Beard
@onready var _chest           : Sprite2D     = $Skeleton/Chest
@onready var _pants           : Sprite2D     = $Skeleton/Pants
@onready var _shoes           : Sprite2D     = $Skeleton/Shoes
@onready var _animation_player: AnimationPlayer = $AnimationPlayer

# ── Setup ──────────────────────────────────────────────────────────────────────

const STAND_FRAME := 18   # row 2 (frente) × hframes(9) + col 0

func _ready() -> void:
	_click_area.input_event.connect(_on_click_area_input_event)

# Detecta clique direito sobre a área do jogador e avisa o mundo (abre o modal).
func _on_click_area_input_event(_viewport: Node, p_event: InputEvent, _shape_idx: int) -> void:
	if p_event is InputEventMouseButton \
			and p_event.button_index == MOUSE_BUTTON_RIGHT \
			and p_event.pressed:
		right_clicked.emit(self)

func setup(p_name: String, p_tile: Vector2i, p_appearance: Dictionary = {}) -> void:
	_target_pos     = _tile_to_world(p_tile)
	position        = _target_pos
	name_label.text = p_name
	z_index         = 1
	_init_sprites()
	set_appearance(p_appearance)
	_play_idle(_last_dir)

func _init_sprites() -> void:
	for s: Sprite2D in [_body, _hair, _beard, _chest, _pants, _shoes]:
		if s.texture:
			s.hframes = 9
			s.vframes = 4
			s.frame   = STAND_FRAME

func set_appearance(p_appearance: Dictionary) -> void:
	if p_appearance.is_empty():
		return
	var char_name := str(p_appearance.get("name", ""))
	if not char_name.is_empty():
		name_label.text = char_name
	_apply_sprite(_body, p_appearance.get("body", {}), Color.WHITE)
	for cat_id: String in ["hair", "beard", "chest", "legs", "shoes"]:
		var sprite := _get_sprite(cat_id)
		if not sprite:
			continue
		var cat := p_appearance.get(cat_id, {}) as Dictionary
		var color := _parse_color(str(cat.get("color", "ffffffff")))
		_apply_sprite(sprite, cat, color)

func _apply_sprite(p_sprite: Sprite2D, p_cat: Variant, p_color: Color) -> void:
	var d    := p_cat as Dictionary
	# "none" = sem essa camada (ex.: sem cabelo / sem barba): limpa a textura.
	if str(d.get("style", "")) == "none":
		p_sprite.texture = null
		return
	var path := str(d.get("path", ""))
	if path != "" and ResourceLoader.exists(path):
		p_sprite.texture = load(path)
	if p_sprite.texture == null:
		return
	p_sprite.hframes  = 9
	p_sprite.vframes  = 4
	p_sprite.frame    = STAND_FRAME
	p_sprite.modulate = p_color

func _get_sprite(p_cat_id: String) -> Sprite2D:
	match p_cat_id:
		"hair":  return _hair
		"beard": return _beard
		"chest": return _chest
		"legs":  return _pants
		"shoes": return _shoes
	return null

func _parse_color(p_hex: String, p_fallback: Color = Color.WHITE) -> Color:
	if p_hex.length() >= 6:
		return Color(p_hex)
	return p_fallback

# ── Sync de posição ────────────────────────────────────────────────────────────

func set_target_tile(p_tile: Vector2i) -> void:
	var new_pos := _tile_to_world(p_tile)
	if new_pos == _target_pos:
		return
	# Determina direção do movimento para escolher a animação
	var diff := new_pos - _target_pos
	if abs(diff.x) > abs(diff.y):
		_last_dir = Vector2i(1, 0) if diff.x > 0 else Vector2i(-1, 0)
	else:
		_last_dir = Vector2i(0, 1) if diff.y > 0 else Vector2i(0, -1)
	_target_pos = new_pos
	_play_walk(_last_dir)

# ── Process ────────────────────────────────────────────────────────────────────

func _process(p_delta: float) -> void:
	if _beard and _beard.texture:
		_beard.frame = _body.frame  # barba sem track: espelha o frame do corpo

	var prev := position
	position  = position.lerp(_target_pos, p_delta * LERP_SPEED)

	# Quando parar de se mover, tocar idle
	if position.distance_to(_target_pos) < 0.5 and prev.distance_to(position) > 0.01:
		position = _target_pos
		_play_idle(_last_dir)

	if _chat_timer > 0.0:
		_chat_timer -= p_delta
		if _chat_timer <= 0.0:
			chat_bubble.visible = false

# ── Animação ───────────────────────────────────────────────────────────────────

func _play_walk(p_dir: Vector2i) -> void:
	if p_dir.x < 0:        _play_anim("walk_left")
	elif p_dir.x > 0:      _play_anim("walk_right")
	elif p_dir.y < 0:      _play_anim("walk_up")
	else:                   _play_anim("walk_down")

func _play_idle(p_dir: Vector2i) -> void:
	if p_dir.x < 0:        _play_anim("idle_left")
	elif p_dir.x > 0:      _play_anim("idle_right")
	elif p_dir.y < 0:      _play_anim("idle_up")
	else:                   _play_anim("idle_down")

func _play_anim(p_anim: StringName) -> void:
	if _animation_player and _animation_player.has_animation(p_anim):
		_animation_player.play(p_anim)

# ── Chat ───────────────────────────────────────────────────────────────────────

func show_chat(p_message: String) -> void:
	chat_label.text     = p_message
	chat_bubble.visible = true
	_chat_timer         = CHAT_DISPLAY_TIME

# ── Utilitário ─────────────────────────────────────────────────────────────────

static func _tile_to_world(p_tile: Vector2i) -> Vector2:
	return Vector2(p_tile.x * TILE_SIZE + TILE_SIZE / 2.0,
	               p_tile.y * TILE_SIZE + TILE_SIZE / 2.0)
