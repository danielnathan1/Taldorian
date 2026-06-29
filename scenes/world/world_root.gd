# scenes/world/world_root.gd
extends Node2D

const LOBBY_SCENE         := "res://scenes/ui/lobby/lobby.tscn"
const LOGIN_SCENE         := "res://scenes/ui/login/login.tscn"
const REMOTE_PLAYER_SCENE := preload("res://scenes/world/player/remote_player.tscn")
const DECK_BUILDER_SCENE  := "res://scenes/ui/deck_builder/deck_builder.tscn"
const DECK_LIST_SCENE     := "res://scenes/ui/deck_list/deck_list.tscn"
const BOOSTER_SHOP_SCENE  := "res://scenes/ui/booster_shop/booster_shop.tscn"
const BLACKSMITH_SCENE    := "res://scenes/ui/blacksmith/blacksmith.tscn"
const ROOM_LOBBY_SCENE    := preload("res://scenes/ui/room_lobby/room_lobby.tscn")
const PAUSE_MENU_SCENE    := preload("res://scenes/ui/pausemenu/PauseMenu.tscn")
const PLAYER_CONTEXT_MENU_SCENE := preload("res://scenes/world/ui/player_context_menu/player_context_menu.tscn")
const PLAYER_PROFILE_SCENE := preload("res://scenes/ui/profile/PlayerProfile.tscn")
const TRADE_REQUEST_SCENE := preload("res://scenes/world/ui/trade_request/trade_request_modal.tscn")
const TRADE_WINDOW_SCENE  := preload("res://scenes/world/ui/trade/trade_window.tscn")
const WELCOME_MODAL_SCENE := preload("res://scenes/world/ui/welcome_modal/welcome_modal.tscn")
const CITY_MUSIC := [
	"res://audio/theme/cities/taldorian.mp3",
	"res://audio/theme/cities/Cidade de Cinza.mp3",
]

var _room_lobby: Control = null
var _pause_menu: PauseMenu = null
var _context_menu: PanelContainer = null
var _context_menu_target: int = -1   # peer_id do jogador alvo do menu social
var _context_menu_target_name: String = ""
var _profile: CanvasLayer = null     # modal de perfil aberto (próprio ou de outro)
var _trade_request: Control = null   # modal de convite de troca recebido
var _trade_window: Control = null    # janela de troca ativa
var _trade_request_from: int = -1    # peer que enviou o convite atual
var _world_music: AudioStreamPlayer = null
var _player_gold: int = 0             # último ouro conhecido (de /players/me) p/ aplicar deltas
var _music_tracks: Array = []
var _music_idx: int = 0

@onready var map_container     : Node2D      = $MapContainer
@onready var players_container : Node2D      = $PlayersContainer
@onready var local_player      : CharacterBody2D = $PlayerCharacter
@onready var world_hud         : CanvasLayer = $WorldHUD

# peer_id (int) → RemotePlayer node
var _remote_players: Dictionary = {}

func _ready() -> void:
	# 1. Conecta sinais ANTES de qualquer ativação para não perder emits.
	GameBus.world_state_synced.connect(_on_world_state_synced)
	GameBus.world_player_left.connect(_on_player_left)
	GameBus.world_chat_received.connect(_on_world_chat_received)
	GameBus.trade_requested.connect(_on_trade_requested)
	GameBus.trade_request_declined.connect(_on_trade_request_declined)
	GameBus.trade_started.connect(_on_trade_started)
	# Troca concluída: aplica o delta de ouro ao card do HUD na hora (ver _on_trade_completed).
	GameBus.trade_completed.connect(_on_trade_completed)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# 1b. Habilita picking 2D para que os Area2D dos jogadores recebam cliques
	#     (botão direito → menu social). Desligado por padrão no viewport raiz.
	get_viewport().physics_object_picking = true

	# 2. Garante estado limpo (evita _active=true de sessão anterior).
	WorldState.reset()

	var appearance: Dictionary = {}
	if CharacterStore.has_character():
		appearance = CharacterStore.get_character()
		# Usa o nome do personagem como nome de rede (mundo, chat e Match Room).
		var char_name := str(appearance.get("name", "")).strip_edges()
		if char_name != "":
			NetworkState.player_name = char_name

	# 3. Ativa: servidor registra-se; cliente envia _rpc_enter_world ao servidor.
	WorldState.activate(appearance)

	# 4. Cliente pede re-sync explícito após um frame — garante que o servidor
	#    envie o estado completo mesmo que haja qualquer delay no processamento.
	if not multiplayer.is_server():
		_request_sync_deferred()

	_setup_hud()
	_load_map("taldorian_city")
	_setup_pause_menu()
	_setup_world_music()
	# Carrega o inventário autoritativo do backend uma vez (posse de cartas/heróis).
	# A troca e o resto do mundo leem do Collection cacheado — sem rebater no backend.
	_load_inventory()
	# Progresso de quests (gate do onboarding, etc.) — fonte de verdade no backend.
	QuestStore.hydrate()
	# Primeira entrada (logo após criar o personagem): mostra o modal de boas-vindas.
	_maybe_show_welcome()

# Exibe o modal de boas-vindas UMA vez, na primeira entrada no mundo. O flag é
# transitório (definido na criação do personagem) e limpo aqui para não repetir.
func _maybe_show_welcome() -> void:
	if not NetworkState.just_created_character:
		return
	NetworkState.just_created_character = false
	var modal := WELCOME_MODAL_SCENE.instantiate()
	world_hud.add_child(modal)
	modal.closed.connect(func() -> void: modal.queue_free())

# Busca /players/me/inventory e popula o Collection (fonte de posse do jogador).
func _load_inventory() -> void:
	if not ApiClient.is_authenticated():
		return
	var res := await ApiClient.get_inventory()
	if res.get("ok", false):
		Collection.load_inventory(res.get("data", {}))

# Música ambiente do mapa: alterna entre as faixas de audio/theme/cities/.
# No bus "Music" (controlado pelo slider de volume) e PROCESS_MODE_ALWAYS para
# continuar tocando enquanto o menu de pausa estiver aberto.
func _setup_world_music() -> void:
	for path in CITY_MUSIC:
		if ResourceLoader.exists(path):
			var s = load(path)
			if s is AudioStreamMP3:
				s.loop = false  # garante que 'finished' dispare para alternar
			_music_tracks.append(s)
	if _music_tracks.is_empty():
		return
	_world_music = AudioStreamPlayer.new()
	_world_music.bus = "Music"
	_world_music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_world_music)
	_world_music.finished.connect(_on_world_music_finished)
	_music_idx = randi() % _music_tracks.size()
	_play_world_music()

func _play_world_music() -> void:
	if _world_music == null or _music_tracks.is_empty():
		return
	_world_music.stream = _music_tracks[_music_idx]
	_world_music.play()

func _on_world_music_finished() -> void:
	_music_idx = (_music_idx + 1) % _music_tracks.size()
	_play_world_music()

func _setup_pause_menu() -> void:
	# Menu de pausa do mundo (ESC): volume + voltar ao menu. O próprio PauseMenu
	# trata o ESC (abre/fecha); por isso o world_root não intercepta mais a tecla.
	_pause_menu = PAUSE_MENU_SCENE.instantiate()
	_pause_menu.world_mode = true
	add_child(_pause_menu)
	_pause_menu.quit_to_menu_requested.connect(_return_to_login)

func _request_sync_deferred() -> void:
	await get_tree().process_frame
	if multiplayer.multiplayer_peer != null:
		WorldState._rpc_request_sync.rpc_id(1)

# ── HUD ────────────────────────────────────────────────────────────────────────

func _setup_hud() -> void:
	world_hud.set_player({
		"name":  NetworkState.player_name,
		"level": 1,
		"gold":  0,
		"rank":  "Madeira",
		"xp":    0.0,
	})
	world_hud.set_friends([
		{ "name": "Bromm",   "status": "on",   "status_text": "No mundo"   },
		{ "name": "Sayen",   "status": "on",   "status_text": "Em partida" },
		{ "name": "Mirae",   "status": "on",   "status_text": "No mundo"   },
		{ "name": "Korrin",  "status": "on",   "status_text": "Loja"       },
		{ "name": "Thalwen", "status": "idle", "status_text": "Ausente"    },
		{ "name": "Dorne",   "status": "off",  "status_text": "Offline · 2h" },
		{ "name": "Vael",    "status": "off",  "status_text": "Offline · 1d" },
	])
	world_hud.battle_requested.connect(_on_battle_requested)
	world_hud.logout_requested.connect(_return_to_login)
	world_hud.decks_requested.connect(func() -> void:
		get_tree().change_scene_to_file(DECK_LIST_SCENE)
	)
	world_hud.shop_requested.connect(func() -> void:
		get_tree().change_scene_to_file(BOOSTER_SHOP_SCENE)
	)
	world_hud.forge_requested.connect(func() -> void:
		get_tree().change_scene_to_file(BLACKSMITH_SCENE)
	)
	world_hud.profile_requested.connect(_on_own_profile_requested)
	_refresh_player_card()

# Atualiza o card do HUD com os dados reais do jogador (ouro de /players/me; tier
# rankeado de /players/me/ranked). O ícone vem do profile.cfg (carregado pela WorldHUD).
func _refresh_player_card() -> void:
	if not ApiClient.is_authenticated():
		return
	var res := await ApiClient.get_me()
	if not res.get("ok", false) or not (res.get("data") is Dictionary):
		return
	var data: Dictionary = res.data
	# Tier rankeado real (fallback Madeira se ainda não jogou / sem backend).
	var rank_name := "Madeira"
	var ranked := await ApiClient.get_my_ranked()
	if ranked.get("ok", false) and ranked.get("data") is Dictionary:
		rank_name = PlayerProfile._tier_display(str((ranked.data as Dictionary).get("tier", "MADEIRA")))
	_player_gold = int(data.get("gold", 0))
	world_hud.set_player({
		"name":  NetworkState.player_name,
		"level": int(data.get("level", 1)),
		"gold":  _player_gold,
		"rank":  rank_name,
		"xp":    float(data.get("xp", 0.0)),
	})

# Troca concluída: aplica o delta líquido de ouro (recebido − ofertado) ao card do HUD.
# O backend (autoridade) faz o mesmo cálculo ao efetivar — addGold(outro − meu) — então o
# valor exibido bate com o persistido. O valor autoritativo é recarregado de /players/me ao
# reentrar no mundo. Funciona também no modo dev (sem token de serviço), onde a troca não
# rebate no backend mas a expectativa do jogador é ver o ouro acordado.
func _on_trade_completed(p_state: Dictionary) -> void:
	var sides: Dictionary = p_state.get("sides", {})
	var peers: Array      = p_state.get("peers", [])
	var my_peer := multiplayer.get_unique_id()
	if peers.size() != 2 or not sides.has(my_peer):
		return
	var other_peer: int = int(peers[0]) if int(peers[1]) == my_peer else int(peers[1])
	var my_gold: int    = int((sides.get(my_peer, {}) as Dictionary).get("gold", 0))
	var their_gold: int = int((sides.get(other_peer, {}) as Dictionary).get("gold", 0))
	_player_gold = maxi(0, _player_gold + their_gold - my_gold)
	world_hud.set_gold(_player_gold)

func _on_battle_requested() -> void:
	# Abre a tela de Salas de Batalha como overlay (sem trocar de cena, para
	# manter a conexão ENet do mundo viva — Modelo A).
	if _room_lobby != null and is_instance_valid(_room_lobby):
		return
	_room_lobby = ROOM_LOBBY_SCENE.instantiate()
	world_hud.set_content_visible(false)
	_room_lobby.closed.connect(func() -> void:
		_room_lobby = null
		world_hud.set_content_visible(true))
	world_hud.add_child(_room_lobby)

# ── Mapa ───────────────────────────────────────────────────────────────────────

func _load_map(p_map_name: String) -> void:
	for child in map_container.get_children():
		child.queue_free()
	var scene := MapLoader.load_map(p_map_name)
	if scene == null:
		return
	var map_node := scene.instantiate()
	map_container.add_child(map_node)

# ── Sync de jogadores ──────────────────────────────────────────────────────────

func _on_world_state_synced(p_players: Dictionary) -> void:
	var local_id := multiplayer.get_unique_id()
	for peer_id: int in p_players:
		if peer_id == local_id:
			continue
		var data: Dictionary = p_players[peer_id]
		if not _remote_players.has(peer_id):
			_spawn_remote_player(peer_id, data)
		else:
			_remote_players[peer_id].set_target_tile(data["tile"])
			if data.has("appearance"):
				_remote_players[peer_id].set_appearance(data["appearance"])
	for peer_id: int in _remote_players.keys():
		if not p_players.has(peer_id):
			_despawn_remote_player(peer_id)

func _on_player_left(p_peer_id: int) -> void:
	_despawn_remote_player(p_peer_id)

func _on_peer_disconnected(_peer_id: int) -> void:
	if not multiplayer.is_server():
		_return_to_lobby()

func _on_world_chat_received(p_peer_id: int, _p_message: String) -> void:
	# Exibe a bolha de chat na cabeça de quem falou — inclusive o próprio jogador
	# (o servidor ecoa a mensagem de volta ao remetente com o peer_id dele).
	if p_peer_id == multiplayer.get_unique_id():
		if local_player != null and local_player.has_method("show_chat"):
			local_player.show_chat(_p_message)
	elif _remote_players.has(p_peer_id):
		_remote_players[p_peer_id].show_chat(_p_message)

func _spawn_remote_player(p_peer_id: int, p_data: Dictionary) -> void:
	var rp: Node2D = REMOTE_PLAYER_SCENE.instantiate()
	players_container.add_child(rp)
	rp.setup(p_data["player_name"], p_data["tile"], p_data.get("appearance", {}))
	rp.right_clicked.connect(_on_remote_player_right_clicked.bind(p_peer_id))
	_remote_players[p_peer_id] = rp

func _despawn_remote_player(p_peer_id: int) -> void:
	if not _remote_players.has(p_peer_id):
		return
	_remote_players[p_peer_id].queue_free()
	_remote_players.erase(p_peer_id)

# ── Menu social (clique direito e12345678m outro jogador) ────────────────────────────────

func _on_remote_player_right_clicked(p_remote_player: Node2D, p_peer_id: int) -> void:
	_context_menu_target = p_peer_id
	var menu := _ensure_context_menu()
	var screen_pos := p_remote_player.get_global_transform_with_canvas().origin
	var player_name: String = p_remote_player.name_label.text
	_context_menu_target_name = player_name
	menu.open_for(player_name, screen_pos)

func _ensure_context_menu() -> PanelContainer:
	if _context_menu != null and is_instance_valid(_context_menu):
		return _context_menu
	_context_menu = PLAYER_CONTEXT_MENU_SCENE.instantiate()
	world_hud.add_child(_context_menu)
	_context_menu.option_selected.connect(_on_context_menu_option)
	return _context_menu

func _on_context_menu_option(p_option_id: String) -> void:
	match p_option_id:
		"trade":
			if _context_menu_target > 0:
				WorldTrade.request_trade(_context_menu_target)
		"details":
			# Ver perfil de outro jogador — somente leitura (sem edição).
			_open_profile(_context_menu_target_name, false)
		_:
			# friend / report ainda não implementados.
			print("[Social] opção '%s' para peer %d" % [p_option_id, _context_menu_target])

# ── Perfil do jogador ─────────────────────────────────────────────────────────────

# Avatar da HUD (topo-esquerda) → abre o próprio perfil, com edição habilitada.
func _on_own_profile_requested() -> void:
	_open_profile(NetworkState.player_name, true)

func _open_profile(p_nick: String, p_editable: bool) -> void:
	if _profile != null and is_instance_valid(_profile):
		return
	_profile = PLAYER_PROFILE_SCENE.instantiate()
	add_child(_profile)
	# set_profile preenche o seed; set_editable depois aplica overrides persistidos
	# (borda/ícone/carta) por cima — não pode inverter a ordem.
	_profile.set_profile(PlayerProfile.default_data(p_nick))
	_profile.set_editable(p_editable)
	# Próprio perfil: puxa a posição rankeada real do backend (assíncrono).
	if p_editable:
		_profile.refresh_ranked_from_backend()
	_profile.closed.connect(func() -> void:
		_profile = null
		# Reflete no card do HUD se o jogador trocou o ícone/moldura no próprio perfil.
		if p_editable:
			world_hud.reload_avatar())

# ── Troca entre jogadores ────────────────────────────────────────────────────────

func _on_trade_requested(p_from_peer: int, p_from_name: String) -> void:
	# Já há um convite ou troca em andamento → ignora (servidor também protege).
	if (_trade_request != null and is_instance_valid(_trade_request)) \
			or (_trade_window != null and is_instance_valid(_trade_window)):
		return
	_trade_request_from = p_from_peer
	_trade_request = TRADE_REQUEST_SCENE.instantiate()
	world_hud.add_child(_trade_request)
	_trade_request.setup(p_from_name)
	_trade_request.accepted.connect(_on_trade_request_accepted)
	_trade_request.declined.connect(_on_trade_request_declined_local)
	_update_movement_lock()

func _on_trade_request_accepted() -> void:
	WorldTrade.respond_trade(_trade_request_from, true)
	_dismiss_trade_request()

func _on_trade_request_declined_local() -> void:
	WorldTrade.respond_trade(_trade_request_from, false)
	_dismiss_trade_request()

func _dismiss_trade_request() -> void:
	if _trade_request != null and is_instance_valid(_trade_request):
		_trade_request.queue_free()
	_trade_request = null
	_trade_request_from = -1
	_update_movement_lock()

func _on_trade_request_declined(_p_by_peer: int, p_by_name: String) -> void:
	# Quem solicitou recebe o aviso da recusa.
	print("[Social] %s recusou a troca." % p_by_name)

func _on_trade_started(p_other_peer: int, p_other_name: String, p_state: Dictionary) -> void:
	if _trade_window != null and is_instance_valid(_trade_window):
		return
	# Convite ainda aberto na tela do solicitante? (não há, mas garante consistência)
	_trade_window = TRADE_WINDOW_SCENE.instantiate()
	world_hud.add_child(_trade_window)
	_trade_window.closed.connect(_on_trade_window_closed)
	_trade_window.open(p_other_peer, p_other_name, p_state)
	_update_movement_lock()

func _on_trade_window_closed() -> void:
	_trade_window = null
	_update_movement_lock()

# Trava o movimento do jogador local enquanto houver convite ou janela de troca aberta.
func _update_movement_lock() -> void:
	var busy := (_trade_request != null and is_instance_valid(_trade_request)) \
			or (_trade_window != null and is_instance_valid(_trade_window))
	if local_player != null and local_player.has_method("set_movement_locked"):
		local_player.set_movement_locked(busy)

# ── Navegação ──────────────────────────────────────────────────────────────────

func _return_to_lobby() -> void:
	WorldState.reset()
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file(LOBBY_SCENE)

# Botão "Sair" da HUD: desconecta do mundo e volta à tela de login.
func _return_to_login() -> void:
	WorldState.reset()
	multiplayer.multiplayer_peer = null
	ApiClient.clear_tokens()
	get_tree().change_scene_to_file(LOGIN_SCENE)
