# scenes/world/npc/npc.gd
# NPC genérico do mundo (personagem NÃO-customizável, ao contrário do player).
# Cada ação é uma folha LPC única em scenes/world/assets/npc/<id>/ (walk.png, idle.png, ...).
# As animações direcionais são montadas em runtime a partir dessas folhas — assim
# qualquer NPC funciona só passando o id da pasta, sem criar SpriteFrames à mão.
#
# Quem encena (o sequenciador de cutscene) chama setup(), face(), walk_to().
#
# Uso:
#   var npc := NPC_SCENE.instantiate()
#   add_child(npc)
#   npc.setup("encapuzado")
#   await npc.walk_to(target_pos).finished
#   npc.face("down")
extends Node2D

const NPC_DIR    := "res://scenes/world/assets/npc/"
const FRAME_SIZE := 64
const ROWS       := { "up": 0, "left": 1, "down": 2, "right": 3 }  # ordem das linhas no LPC

# Walk: 9 frames/linha (col 0 é a pose parada → pulamos para um ciclo limpo de 8).
const WALK_START := 1
const WALK_COUNT := 8
const WALK_FPS   := 10.0
# Idle: neste export LPC só as 2 primeiras colunas têm conteúdo (o resto da linha
# é transparente) — usar 13 fazia o NPC "piscar". 2 frames = respiração sutil.
const IDLE_START := 0
const IDLE_COUNT := 2
const IDLE_FPS   := 2.5

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var _facing: String = "down"

func _ready() -> void:
	z_index = 1   # acima dos TileMapLayers (z=0), igual ao player

# ═══════════════════════════════════════════════════════════════════════════════

## Carrega as folhas do NPC pelo id (= nome da pasta) e monta as animações.
func setup(p_npc_id: String) -> void:
	_sprite.sprite_frames = _build_frames(p_npc_id)
	face("down")

## Vira o NPC para uma direção ("up"/"down"/"left"/"right") e fica parado (idle).
func face(p_dir: String) -> void:
	_facing = p_dir
	_play("idle")

## Toca a animação de andar na direção dada (sem mover — o deslocamento é do walk_to).
func play_walk(p_dir: String) -> void:
	_facing = p_dir
	_play("walk")

func play_idle() -> void:
	_play("idle")

## Caminha até uma posição do mundo, virando-se na direção do movimento e tocando
## walk; ao chegar volta para idle. Retorna o Tween (use `await npc.walk_to(...).finished`).
func walk_to(p_target: Vector2, p_speed: float = 48.0) -> Tween:
	var delta := p_target - position
	if delta.is_zero_approx():
		return null
	play_walk(_dir_from_vector(delta))
	var duration := delta.length() / maxf(1.0, p_speed)
	var tween := create_tween()
	tween.tween_property(self, "position", p_target, duration)
	tween.tween_callback(play_idle)
	return tween

# ═══════════════════════════════════════════════════════════════════════════════

func _play(p_state: String) -> void:
	var anim := "%s_%s" % [p_state, _facing]
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)

func _dir_from_vector(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "right" if v.x > 0.0 else "left"
	return "down" if v.y > 0.0 else "up"

func _build_frames(p_npc_id: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var walk_tex := _load_sheet(p_npc_id, "walk")
	var idle_tex := _load_sheet(p_npc_id, "idle")
	for dir: String in ROWS:
		var row: int = ROWS[dir]
		_add_dir_anim(frames, "walk_" + dir, walk_tex, row, WALK_START, WALK_COUNT, WALK_FPS)
		_add_dir_anim(frames, "idle_" + dir, idle_tex, row, IDLE_START, IDLE_COUNT, IDLE_FPS)
	return frames

func _load_sheet(p_npc_id: String, p_action: String) -> Texture2D:
	var path := NPC_DIR + p_npc_id + "/" + p_action + ".png"
	return load(path) if ResourceLoader.exists(path) else null

# Fatia uma linha (direção) do sheet em frames 64×64 via AtlasTexture.
func _add_dir_anim(p_frames: SpriteFrames, p_name: String, p_tex: Texture2D, p_row: int, p_start: int, p_count: int, p_fps: float) -> void:
	if p_tex == null:
		return
	p_frames.add_animation(p_name)
	p_frames.set_animation_speed(p_name, p_fps)
	p_frames.set_animation_loop(p_name, true)
	for i in p_count:
		var col := p_start + i
		var atlas := AtlasTexture.new()
		atlas.atlas = p_tex
		atlas.region = Rect2(col * FRAME_SIZE, p_row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
		p_frames.add_frame(p_name, atlas)
