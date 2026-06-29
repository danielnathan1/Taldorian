# scenes/world/mob/mob.gd
# Mob genérico do mundo — criatura autônoma. NÃO é humanoide LPC (ver npc.gd para esse
# caso); o visual é ART-AGNÓSTICO: o SpriteFrames é atribuído no editor por criatura, e o
# script toca animações POR NOME com fallback (serve tanto p/ criatura de animação única
# quanto direcional). Até a arte existir, mostra um placeholder.
#
# Comportamento: vagueia aleatoriamente num raio em torno do ponto de spawn. Projetado para
# virar Scannable depois (Fase 3). SEM combate/aggro/spawn ainda — entram quando um mapa
# real precisar (não adivinhar a abstração agora).
#
# Convenção de animações no SpriteFrames (qualquer subconjunto serve):
#   "idle" / "walk"                              → criatura de animação única
#   "idle_down/up/left/right" / "walk_*"         → criatura direcional
extends Node2D

const MOB_DIR := "res://scenes/world/assets/mob/"
const FRAME := 64
# Ordem das linhas (direção → índice da linha no sheet) PADRÃO. A ordem das direções é uma
# propriedade do PACK de arte, não da cena — packs diferentes podem ordenar diferente. Por
# isso NÃO é global e fixa: quem diverge declara um override em CREATURE_ROWS; o resto cai
# aqui. O slime usa este padrão (down, up, left, right).
const DEFAULT_ROWS := { "down": 0, "up": 1, "left": 2, "right": 3 }
# Overrides por criatura (id da pasta → ordem das linhas). Liste SÓ os packs que diferem do
# padrão. Ex.: "Goblin1": { "down": 2, "up": 0, "left": 3, "right": 1 }.
const CREATURE_ROWS := {}
# Estado do mob → subpasta/arquivo da animação + fps. Usa as folhas *_full.png (corpo + sombra).
const ANIMS := {
	"idle": { "dir": "Idle", "fps": 6.0 },
	"walk": { "dir": "Walk", "fps": 10.0 },
}

## Criatura: nome da pasta em scenes/world/assets/mob/ (ex.: "Slime1"). Se preenchido e não
## houver SpriteFrames atribuído no editor, o mob fatia as folhas *_full.png em runtime.
@export var creature_id: String = ""

## Liga/desliga o vaguear. Mobs de mapa = true; slime de tutorial = false (1º scan calmo).
@export var wander_enabled: bool = true
## Distância máxima do ponto de spawn percorrida ao vaguear.
@export var wander_radius: float = 48.0
@export var move_speed: float = 24.0
## Faixa de pausa (segundos) entre um destino e o próximo.
@export var idle_time_min: float = 1.5
@export var idle_time_max: float = 3.5

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _placeholder: Node2D = $Placeholder

var _home: Vector2
var _facing: String = "down"

func _ready() -> void:
	z_index = 1
	_home = position
	# Se há um id de criatura e nenhum SpriteFrames no editor, fatia as folhas em runtime.
	if creature_id != "" and _sprite.sprite_frames == null:
		_sprite.sprite_frames = _build_frames(creature_id)
	# Placeholder visível só enquanto não há arte.
	_placeholder.visible = _sprite.sprite_frames == null
	_play("idle")
	if wander_enabled:
		_wander_loop()

# ═══════════════════════════════════════════════════════════════════════════════

# Roda enquanto o mob estiver na árvore. Cada ciclo: pausa → escolhe destino → anda.
func _wander_loop() -> void:
	while is_inside_tree():
		await _wait(randf_range(idle_time_min, idle_time_max))
		if not wander_enabled:
			continue
		var target := _home + Vector2(
			randf_range(-wander_radius, wander_radius),
			randf_range(-wander_radius, wander_radius))
		await _move_to(target)

func _move_to(p_target: Vector2) -> void:
	var delta := p_target - position
	if delta.is_zero_approx():
		return
	_facing = _dir_from_vector(delta)
	_play("walk")
	var duration := delta.length() / maxf(1.0, move_speed)
	var tween := create_tween()
	tween.tween_property(self, "position", p_target, duration)
	await tween.finished
	_play("idle")

# ── Animação (art-agnóstica: tenta direcional, cai pra genérica) ─────────────────

func _play(p_state: String) -> void:
	if _sprite.sprite_frames == null:
		return
	var anim := _pick_anim([
		"%s_%s" % [p_state, _facing],   # ex.: walk_down (criatura direcional)
		p_state,                        # ex.: walk / idle (animação única)
	])
	if anim != "":
		_sprite.play(anim)

func _pick_anim(p_candidates: Array) -> String:
	for anim_name in p_candidates:
		if _sprite.sprite_frames.has_animation(anim_name):
			return anim_name
	# Último recurso: a primeira animação disponível.
	var names := _sprite.sprite_frames.get_animation_names()
	return names[0] if not names.is_empty() else ""

func _dir_from_vector(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "right" if v.x > 0.0 else "left"
	return "down" if v.y > 0.0 else "up"

# ── Fatiação de sheet em runtime (criatura uniforme, ex.: slimes 64×64) ──────────
# Colunas/linhas são derivadas do tamanho da folha (largura÷64, altura÷64); as linhas
# mapeiam direções via a ordem do pack (CREATURE_ROWS ou DEFAULT_ROWS). Usa as folhas
# *_full.png de cada animação em ANIMS.

func _build_frames(p_creature: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var rows_map: Dictionary = CREATURE_ROWS.get(p_creature, DEFAULT_ROWS)
	for state: String in ANIMS:
		var cfg: Dictionary = ANIMS[state]
		var tex := _load_full(p_creature, str(cfg["dir"]))
		if tex == null:
			continue
		var cols := int(tex.get_width() / FRAME)
		var rows := int(tex.get_height() / FRAME)
		for dir: String in rows_map:
			var row: int = rows_map[dir]
			if row < rows:
				_add_anim(frames, "%s_%s" % [state, dir], tex, row, cols, float(cfg["fps"]))
	return frames

func _load_full(p_creature: String, p_anim_dir: String) -> Texture2D:
	var path := "%s%s/%s/%s_%s_full.png" % [MOB_DIR, p_creature, p_anim_dir, p_creature, p_anim_dir]
	return load(path) if ResourceLoader.exists(path) else null

func _add_anim(p_frames: SpriteFrames, p_name: String, p_tex: Texture2D, p_row: int, p_cols: int, p_fps: float) -> void:
	p_frames.add_animation(p_name)
	p_frames.set_animation_speed(p_name, p_fps)
	p_frames.set_animation_loop(p_name, true)
	for col in p_cols:
		var atlas := AtlasTexture.new()
		atlas.atlas = p_tex
		atlas.region = Rect2(col * FRAME, p_row * FRAME, FRAME, FRAME)
		p_frames.add_frame(p_name, atlas)

func _wait(p_seconds: float) -> void:
	await get_tree().create_timer(p_seconds).timeout
