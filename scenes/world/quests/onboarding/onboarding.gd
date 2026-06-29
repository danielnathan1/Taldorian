# scenes/world/quests/onboarding/onboarding.gd
# Sequenciador da cutscene de abertura (fase instanciada, solo). Orquestra os passos
# com await — player entra → encapuzado se aproxima → diálogo → item → handoff p/ tutorial.
# O cenário é placeholder (a arte do mapa entra depois, SEM mexer nesta lógica).
#
# Para testar: abra esta cena e rode com F6 (Run Current Scene).
extends Node2D

const PLAYER_SCENE   := preload("res://scenes/world/player/player_character.tscn")
const NPC_SCENE      := preload("res://scenes/world/npc/npc.tscn")
const DIALOGUE_SCENE := preload("res://scenes/world/ui/dialogue/dialogue_box.tscn")
const SCANNER_SCENE  := preload("res://scenes/world/scanner/scanner.tscn")
const REWARD_POPUP_SCENE := preload("res://scenes/world/ui/reward_popup/reward_popup.tscn")
const SLIME_ART := "res://assets/heros/hero_blue_slime.png"

@onready var _ui_layer: CanvasLayer = $UILayer
@onready var _item_reveal: Label = $UILayer/ItemReveal
@onready var _camera: Camera2D = $Camera2D
@onready var _slime: Node2D = $Slime
@onready var _toast_label: Label = $UILayer/Toast

var _player: CharacterBody2D
var _npc: Node2D
var _scanner: Node2D
var _follow_player: bool = false
var _toast_tween: Tween

func _ready() -> void:
	_item_reveal.visible = false
	_spawn_actors()
	_slime.add_to_group("scannable")   # alvo do scanner (vira Scannable de verdade no próximo passo)
	_run_intro()   # corrotina (fire-and-forget)

# ═══════════════════════════════════════════════════════════════════════════════

func _spawn_actors() -> void:
	_player = PLAYER_SCENE.instantiate()
	_player.cutscene_mode = true
	add_child(_player)
	_player.set_movement_locked(true)          # sem input durante a cutscene
	_player.position = Vector2(0, -72)
	_player.face(Vector2i(0, 1))               # de frente (pra baixo)

	_npc = NPC_SCENE.instantiate()
	add_child(_npc)
	_npc.setup("encapuzado")
	_npc.position = Vector2(0, 150)
	_npc.face("up")

# Coreografia. Cada passo é legível em await — fácil de reordenar/editar depois.
func _run_intro() -> void:
	await _wait(0.6)
	# 1. Player entra andando e para, de frente.
	await _walk(_player, Vector2(0, 0), 50.0)
	_player.face(Vector2i(0, 1))
	await _wait(0.4)
	# 2. Encapuzado se aproxima e vira para o player.
	await _walk(_npc, Vector2(0, 64), 45.0)
	_npc.face("up")
	await _wait(0.3)
	# 3. Diálogo de introdução + entrega do item.
	await _play_dialogue("intro_encapuzado")
	await _reveal_item("✦  Olho Arcano  ✦")
	# 4. Encapuzado aponta o slime; a câmera viaja até ele.
	await _play_dialogue("encapuzado_aponta_slime")
	await _pan_camera_to(_slime.position, 1.2)
	await _wait(0.3)
	# 5. Instrução do tutorial (câmera no slime).
	await _play_dialogue("tutorial_escanear_slime")
	# 6. Câmera volta ao player e o controle vai pras mãos do jogador (câmera seguindo).
	await _pan_camera_to(_player.position, 1.0)
	_start_camera_follow()
	_release_player()
	# A partir daqui: scanner (Espaço) + Scannable do slime → conclui a quest. (próximo passo)
	print("[Onboarding] movimento liberado → pronto p/ o scanner")

# ═══════════════════════════════════════════════════════════════════════════════
# Helpers

func _walk(p_actor: Node, p_target: Vector2, p_speed: float) -> void:
	var tw: Tween = p_actor.walk_to(p_target, p_speed)
	if tw != null:
		await tw.finished

func _play_dialogue(p_id: String) -> void:
	var box := DIALOGUE_SCENE.instantiate()
	_ui_layer.add_child(box)
	box.play(p_id)
	await box.finished

func _reveal_item(p_text: String) -> void:
	_item_reveal.text = p_text
	_item_reveal.modulate.a = 0.0
	_item_reveal.visible = true
	var tw_in := create_tween()
	tw_in.tween_property(_item_reveal, "modulate:a", 1.0, 0.5)
	await tw_in.finished
	await _wait(1.4)
	# Some antes do próximo diálogo, para não sobrepor a fala.
	var tw_out := create_tween()
	tw_out.tween_property(_item_reveal, "modulate:a", 0.0, 0.4)
	await tw_out.finished
	_item_reveal.visible = false

# Move a câmera suavemente até um ponto do mundo (ex.: enquadrar o slime).
func _pan_camera_to(p_target: Vector2, p_duration: float) -> void:
	var tw := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_camera, "position", p_target, p_duration)
	await tw.finished

# Câmera passa a seguir o player (suave). Chamado ao devolver o controle.
func _start_camera_follow() -> void:
	_camera.position_smoothing_enabled = true
	_follow_player = true

# Devolve o controle. O movimento do player_character é TILE-BASED (passos de 16px via
# tile_pos), mas na cutscene movemos só a 'position' (walk_to) — então tile_pos ficou no
# valor antigo. Sincronizamos tile_pos com a posição atual antes de destravar, senão o
# primeiro passo teleportaria o player. cutscene_mode mantém o movimento LOCAL (sem WorldState).
func _release_player() -> void:
	_player.tile_pos = Vector2i(floori(_player.position.x / 16.0), floori(_player.position.y / 16.0))
	_player.set_movement_locked(false)
	_attach_scanner()

# Anexa o scanner ao player e o liga (só agora que o controle é do jogador).
func _attach_scanner() -> void:
	_scanner = SCANNER_SCENE.instantiate()
	_player.add_child(_scanner)
	_scanner.scan_completed.connect(_on_scan_completed)
	_scanner.scan_blocked.connect(_on_scan_blocked)
	_scanner.enable(_player)

func _on_scan_completed(p_target: Node) -> void:
	p_target.set_meta("scanned", true)   # marca como rastreado por mim (→ "já rastreou" depois)
	_scanner.disable()                   # pausa enquanto o popup está aberto
	# Payoff imediato: revela a recompensa.
	_show_reward(SLIME_ART, "Slime", "Novo herói rastreado!")
	# Conclui a quest em background — autoritativo: o backend concede o slime herói.
	await QuestStore.complete(QuestStore.TUTORIAL_ID)

func _on_scan_blocked(_p_target: Node) -> void:
	_toast("Você já rastreou isto.")

func _show_reward(p_art: String, p_title: String, p_subtitle: String) -> void:
	var popup := REWARD_POPUP_SCENE.instantiate()
	_ui_layer.add_child(popup)
	popup.closed.connect(_on_reward_closed)
	popup.show_reward(p_art, p_title, p_subtitle)

func _on_reward_closed() -> void:
	# Volta a permitir rastrear (o slime já está marcado → mostrará "já rastreou").
	_scanner.enable(_player)

# Mensagem efêmera no rodapé (ex.: "Você já rastreou isto").
func _toast(p_text: String) -> void:
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_label.text = p_text
	_toast_label.modulate.a = 0.0
	_toast_label.visible = true
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_label, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(1.1)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(func() -> void: _toast_label.visible = false)

func _process(_delta: float) -> void:
	if _follow_player:
		_camera.position = _player.position

func _wait(p_seconds: float) -> void:
	await get_tree().create_timer(p_seconds).timeout
