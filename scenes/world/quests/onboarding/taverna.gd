# scenes/world/quests/onboarding/taverna.gd
# Segundo trecho do onboarding: a TAVERNA. Continua após o encapuzado (fade "algumas horas depois").
# Cutscene scriptada (solo), no estilo do onboarding.gd:
#   Blauber se apresenta e convida a batalhar → o jogador diz que não tem cartas/heróis fortes →
#   Blauber aponta 3 heróis (Poppy/Nox/Irena) → a câmera viaja até eles → o jogador escaneia os 3
#   (fluxo REAL de scan, com minigames/diálogos) → Blauber volta, empresta cartas e ensina →
#   inicia a PARTIDA-TUTORIAL local/offline (board real) — este passo vai só até a rolagem de dados.
#
# O cenário da taverna ainda é placeholder (fundo simples; arte do mapa entra depois, SEM mexer
# nesta lógica). Blauber já tem sprite (scenes/world/assets/npc/blauber) e retrato (assets/portraits/blauber.png).
#
# Testar: abra esta cena e rode com F6.
extends Node2D

const PLAYER_SCENE   := preload("res://scenes/world/player/player_character.tscn")
const NPC_SCENE      := preload("res://scenes/world/npc/npc.tscn")
const DIALOGUE_SCENE := preload("res://scenes/world/ui/dialogue/dialogue_box.tscn")
const SCANNER_SCENE  := preload("res://scenes/world/scanner/scanner.tscn")
const SCANNABLE_HERO_SCENE := preload("res://scenes/world/scannable_hero/scannable_hero.tscn")
const REWARD_POPUP_SCENE := preload("res://scenes/world/ui/reward_popup/reward_popup.tscn")
const BOARD_SCENE := "res://scenes/ui/boardv2/board.tscn"
const WORLD_SCENE := "res://scenes/world/world_root.tscn"
const GOLD_ART := "res://assets/sprites/sword-free/Terrain/Resources/Gold/Gold Resource/Gold_Resource.png"

const BLAUBER_SPRITE := "blauber"
# Heróis que o jogador escaneia na taverna (config no catálogo COMPARTILHADO — mesmo scan do mundo).
const TAVERN_HERO_KEYS := ["hero_poppy", "hero_nox", "hero_irena"]

@onready var _ui_layer: CanvasLayer = $UILayer
@onready var _camera: Camera2D = $Camera2D
@onready var _fade: ColorRect = $UILayer/Fade
@onready var _hint_label: Label = $UILayer/Hint
@onready var _toast_label: Label = $UILayer/Toast

var _player: CharacterBody2D
var _npc: Node2D
var _scanner: Node2D
var _heroes: Array[ScannableHero] = []
var _scanned_count: int = 0
var _follow_player: bool = false
var _hint_tween: Tween
var _toast_tween: Tween

func _ready() -> void:
	_fade.color = Color(0, 0, 0, 1)   # começa preta → fade-from-black costura a transição
	if NetworkState.tutorial_return:
		# Voltou da partida-tutorial (vitória): encerramento do Blauber, sem repetir o scan.
		NetworkState.tutorial_return = false
		_spawn_actors(false)
		_run_post_tutorial()
		return
	_spawn_actors()
	_run()   # corrotina (fire-and-forget)

# ═══════════════════════════════════════════════════════════════════════════════

func _spawn_actors(with_heroes: bool = true) -> void:
	_player = PLAYER_SCENE.instantiate()
	_player.cutscene_mode = true
	add_child(_player)
	_player.set_movement_locked(true)
	_player.position = Vector2(0, -72)
	_player.face(Vector2i(0, 1))

	_npc = NPC_SCENE.instantiate()
	add_child(_npc)
	_npc.setup(BLAUBER_SPRITE)
	_npc.position = Vector2(0, 140)
	_npc.face("up")

	# 3 heróis rastreáveis numa fileira à direita (posições da taverna; config do catálogo).
	if not with_heroes:
		return
	var xs := [200.0, 248.0, 296.0]
	for i in TAVERN_HERO_KEYS.size():
		var cfg := ScannableCatalog.get_by_key(TAVERN_HERO_KEYS[i])
		if cfg.is_empty():
			continue
		var sh: ScannableHero = SCANNABLE_HERO_SCENE.instantiate()
		sh.creature_id = cfg["creature_id"]
		sh.hero_name   = cfg["hero_name"]
		sh.hero_art    = cfg["hero_art"]
		sh.hero_key    = cfg["hero_key"]
		sh.dialogue_id = cfg["dialogue_id"]
		sh.facing      = "down"
		sh.minigame_id     = cfg.get("minigame_id", "")
		sh.minigame_config = cfg.get("minigame_config", {})
		sh.fail_dialogue_id = cfg.get("fail_dialogue_id", "")
		sh.win_dialogue_id  = cfg.get("win_dialogue_id", "")
		sh.always_grant     = cfg.get("always_grant", false)
		sh.already_dialogue_id = cfg.get("already_dialogue_id", "")
		sh.cost            = cfg.get("cost", 0)
		sh.position = Vector2(xs[i], -8)
		add_child(sh)
		# Tutorial: sempre rastreável, mesmo se a conta já possui o herói (grant é idempotente).
		sh.set_meta("scanned", false)
		_heroes.append(sh)

# Coreografia principal. Passos legíveis em await (fácil reordenar/editar).
func _run() -> void:
	await _fade_from_black(0.8)
	await _wait(0.4)
	# 1. Player entra andando e para, de frente.
	await _walk(_player, Vector2(0, 0), 50.0)
	_player.face(Vector2i(0, 1))
	await _wait(0.3)
	# 2. Blauber se aproxima e vira pro player.
	await _walk(_npc, Vector2(0, 56), 110.0)
	_npc.face("up")
	await _wait(0.3)
	# 3. Apresentação + convite + aponta os 3 heróis.
	await _play_dialogue("blauber_intro")
	# 4. A câmera viaja até os heróis.
	await _pan_camera_to(Vector2(248, -8), 1.2)
	await _wait(0.3)
	# 5. Controle + scanner nas mãos do jogador (segue no _on_scan_completed → _after_all_scans).
	_release_player_for_scan()

# Encerramento pós-partida-tutorial: Blauber parabeniza o jogador (sem repetir o scan).
func _run_post_tutorial() -> void:
	await _fade_from_black(0.8)
	await _wait(0.4)
	_player.face(Vector2i(0, 1))
	await _walk(_npc, Vector2(0, 56), 110.0)
	_npc.face("up")
	await _wait(0.3)
	await _play_dialogue("blauber_pos_tutorial")
	# Recompensa de conclusão do tutorial (1200 de ouro).
	await _show_tutorial_reward()
	# Vai para a CIDADE offline (encapuzado + dicas) — ver world_root._run_city_onboarding.
	await _fade_to_black(0.6)
	NetworkState.onboarding_city = true
	NetworkState.match_origin_world = false
	NetworkState.just_created_character = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().change_scene_to_file(WORLD_SCENE)

func _show_tutorial_reward() -> void:
	var popup := REWARD_POPUP_SCENE.instantiate()
	_ui_layer.add_child(popup)
	if popup.has_node("BtnClose"):
		(popup.get_node("BtnClose") as Button).text = "Pegar recompensa"
	popup.show_reward(GOLD_ART, "Tutorial concluído!", "Recompensa: 1200 de ouro")
	await popup.closed

# ═══════════════════════════════════════════════════════════════════════════════
# Scan dos 3 heróis

func _release_player_for_scan() -> void:
	# Movimento TILE-BASED: sincroniza tile_pos com a posição atual antes de destravar (ver onboarding).
	_player.tile_pos = Vector2i(floori(_player.position.x / 16.0), floori(_player.position.y / 16.0))
	_player.set_movement_locked(false)
	_start_camera_follow()
	_attach_scanner()
	_show_scan_hint()

func _attach_scanner() -> void:
	_scanner = SCANNER_SCENE.instantiate()
	_player.add_child(_scanner)
	_scanner.scan_completed.connect(_on_scan_completed)
	_scanner.scan_blocked.connect(_on_scan_blocked)
	_scanner.enable(_player)

func _on_scan_completed(p_target: Node) -> void:
	if not (p_target is ScannableHero):
		return
	_scanner.disable()
	_player.set_movement_locked(true)
	_hide_hint()
	# Fluxo de scan COMPARTILHADO — idêntico ao mundo (diálogo → minigame → grant → popup).
	var res: Dictionary = await HeroScanFlow.run(p_target as ScannableHero, _ui_layer, 0, _player)
	if res.get("granted", false):
		_scanned_count += 1
	if _scanned_count >= _heroes.size():
		_after_all_scans()
		return
	# Ainda faltam heróis (ou falhou o minigame): libera p/ continuar, mas só após soltar a tecla.
	_player.set_movement_locked(false)
	await _wait_scan_key_released()
	_scanner.enable(_player)
	_show_scan_hint()

func _on_scan_blocked(_p_target: Node) -> void:
	_toast("Você já rastreou este.")

func _after_all_scans() -> void:
	_hide_hint()
	if _scanner != null:
		_scanner.disable()
	_player.set_movement_locked(true)
	_follow_player = false
	# Blauber volta até o jogador (ele está junto dos heróis, à direita).
	await _walk(_npc, _player.position + Vector2(0, 40), 110.0)
	_npc.face("up")
	await _pan_camera_to(_player.position, 0.8)
	await _wait(0.2)
	# Empresta cartas + promete ensinar → inicia o tutorial.
	await _play_dialogue("blauber_pos_scan")
	_start_tutorial_match()

# ═══════════════════════════════════════════════════════════════════════════════
# Handoff para a partida-tutorial (board local/offline)

func _start_tutorial_match() -> void:
	await _fade_to_black(0.6)
	NetworkState.tutorial_mode = true
	NetworkState.match_origin_world = false
	NetworkState.local_player_index = 0
	# Board local/offline: o cliente vira a AUTORIDADE local (OfflineMultiplayerPeer → is_server()=true,
	# uid=1, sem peers). Isso destrava o caminho standalone do GameState (oponente fantasma). Sem esse
	# peer offline, is_server() seria false e os RPCs call_local NÃO rodariam (verificado no headless).
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().change_scene_to_file(BOARD_SCENE)

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

func _pan_camera_to(p_target: Vector2, p_duration: float) -> void:
	var tw := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_camera, "position", p_target, p_duration)
	await tw.finished

func _start_camera_follow() -> void:
	_camera.position_smoothing_enabled = true
	_follow_player = true

func _process(_delta: float) -> void:
	if _follow_player and _player != null:
		_camera.position = _player.position

func _fade_from_black(p_dur: float) -> void:
	_fade.color = Color(0, 0, 0, 1)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, p_dur)
	await tw.finished

func _fade_to_black(p_dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, p_dur)
	await tw.finished

# Reabilitar o scanner com a tecla ainda pressionada re-dispararia o gatilho no mesmo frame.
func _wait_scan_key_released() -> void:
	while Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame

func _show_scan_hint() -> void:
	_show_hint("Segure [Espaço] perto de cada herói para rastreá-lo (%d/%d)" % [_scanned_count, _heroes.size()])

func _show_hint(p_text: String) -> void:
	_hint_label.text = p_text
	_hint_label.visible = true
	_hint_label.modulate.a = 1.0
	if _hint_tween != null:
		_hint_tween.kill()
	_hint_tween = create_tween().set_loops()
	_hint_tween.tween_property(_hint_label, "modulate:a", 0.45, 0.8)
	_hint_tween.tween_property(_hint_label, "modulate:a", 1.0, 0.8)

func _hide_hint() -> void:
	if _hint_tween != null:
		_hint_tween.kill()
		_hint_tween = null
	_hint_label.visible = false

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

func _wait(p_seconds: float) -> void:
	await get_tree().create_timer(p_seconds).timeout
