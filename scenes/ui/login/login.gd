# scenes/ui/login/login.gd
# LÓGICA da tela de login/cadastro (FAKE — sem servidor real por enquanto).
# Login aceita qualquer usuário/senha não-vazios. O cadastro valida os campos
# (username, email, senha, confirmar), guarda a conta localmente em user:// e
# entra direto no mundo — mesmo comportamento do "Connect" antigo. Quando a API
# real existir, _on_enter / _on_create chamam o auth de verdade antes de conectar.
extends Control

const SETTINGS_PATH := "user://settings.cfg"
const WORLD_SCENE   := "res://scenes/world/world_root.tscn"
const CHARACTER_CREATOR_SCENE := "res://scenes/ui/character_creator/character_creator.tscn"
const ONBOARDING_SCENE := "res://scenes/world/quests/onboarding/onboarding.tscn"
const PAUSE_MENU_SCENE := preload("res://scenes/ui/pausemenu/PauseMenu.tscn")
const WORLD_PORT    := 7001   # host vem do ServerConfig (resolve por ambiente)
const MIN_PASS_LEN  := 8

# Login
@onready var _login_form: VBoxContainer = %LoginForm
@onready var _user_input: LineEdit = %UserInput
@onready var _pass_input: LineEdit = %PassInput
@onready var _error_lbl:  Label    = %ErrorLabel
@onready var _success_lbl: Label   = %SuccessLabel
@onready var _enter_btn:  Button   = %EnterButton
@onready var _go_signup:  Button   = %GoSignup

# Cadastro
@onready var _signup_form: VBoxContainer = %SignupForm
@onready var _su_user:    LineEdit = %SuUser
@onready var _su_email:   LineEdit = %SuEmail
@onready var _su_pass:    LineEdit = %SuPass
@onready var _su_confirm: LineEdit = %SuConfirm
@onready var _su_error:   Label    = %SignupError
@onready var _create_btn: Button   = %CreateButton
@onready var _go_login:   Button   = %GoLogin

# Fechar jogo
@onready var _quit_btn:   Button   = %QuitButton

# Loading
@onready var _loading:        Control = %LoadingOverlay
@onready var _loading_label:  Label   = %LoadingLabel
@onready var _spinner:        Label   = %Spinner

var _music: AudioStreamPlayer = null
var _spinner_tween: Tween = null


func _ready() -> void:
	if WorldServer.is_dedicated:
		return
	multiplayer.multiplayer_peer = null
	_user_input.text = _load_last_user()
	_error_lbl.visible = false
	_success_lbl.visible = false
	_su_error.visible = false
	_loading.visible = false

	_enter_btn.pressed.connect(_on_enter)
	_user_input.text_submitted.connect(func(_t: String) -> void: _pass_input.grab_focus())
	_pass_input.text_submitted.connect(func(_t: String) -> void: _on_enter())

	_create_btn.pressed.connect(_on_create)
	_su_user.text_submitted.connect(func(_t: String) -> void: _su_email.grab_focus())
	_su_email.text_submitted.connect(func(_t: String) -> void: _su_pass.grab_focus())
	_su_pass.text_submitted.connect(func(_t: String) -> void: _su_confirm.grab_focus())
	_su_confirm.text_submitted.connect(func(_t: String) -> void: _on_create())

	_go_signup.pressed.connect(_show_signup)
	_go_login.pressed.connect(_show_login)

	_quit_btn.pressed.connect(func() -> void: get_tree().quit())

	_start_music()
	_setup_settings_menu()
	_show_login()


# ── Configurações (ESC) ─────────────────────────────────────────────────────
# Reaproveita o PauseMenu em modo "somente configurações": ESC abre direto o
# modal de áudio (regular som / fechar), sem pausar a árvore (música segue).
func _setup_settings_menu() -> void:
	var menu := PAUSE_MENU_SCENE.instantiate()
	menu.settings_only = true
	add_child(menu)


# ── Música ────────────────────────────────────────────────────────────────────
func _start_music() -> void:
	var path := "res://audio/theme/lobby_theme.mp3"
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStreamMP3
	if stream == null:
		return
	stream.loop = true
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.stream = stream
	add_child(_music)
	_music.play()


# ── Alternância login / cadastro ─────────────────────────────────────────────
func _show_login() -> void:
	_su_error.visible = false
	_success_lbl.visible = false
	_signup_form.visible = false
	_login_form.visible = true
	if _user_input.text.is_empty():
		_user_input.grab_focus()
	else:
		_pass_input.grab_focus()

func _show_signup() -> void:
	_error_lbl.visible = false
	_success_lbl.visible = false
	_login_form.visible = false
	_signup_form.visible = true
	_su_user.grab_focus()


# ── Login ─────────────────────────────────────────────────────────────────────
func _on_enter() -> void:
	var user := _user_input.text.strip_edges()
	var pwd := _pass_input.text
	if user.is_empty() or pwd.is_empty():
		_show_error("Informe usuário e senha.")
		return

	# Chamada real ao backend — POST /auth/login (ver ApiClient.BASE_URL).
	_error_lbl.visible = false
	_show_loading(true)
	var res := await ApiClient.login(user, pwd)
	if not res.ok:
		_show_loading(false)
		_show_error(res.error if res.error != "" else "Não foi possível entrar.")
		return
	# Autenticado — segue o fluxo de entrada (mantém o loading durante a conexão).
	_login_as(user)


# ── Cadastro ──────────────────────────────────────────────────────────────────
func _on_create() -> void:
	var user := _su_user.text.strip_edges()
	var email := _su_email.text.strip_edges()
	var pwd := _su_pass.text
	var confirm := _su_confirm.text

	if user.is_empty() or email.is_empty() or pwd.is_empty():
		_show_signup_error("Preencha todos os campos.")
		return
	if not _is_valid_email(email):
		_show_signup_error("E-mail inválido.")
		return
	if pwd.length() < MIN_PASS_LEN:
		_show_signup_error("A senha precisa de ao menos %d caracteres." % MIN_PASS_LEN)
		return
	if pwd != confirm:
		_show_signup_error("As senhas não coincidem.")
		return

	# Chamada real ao backend — POST /auth/register (ver ApiClient.BASE_URL).
	_su_error.visible = false
	_set_creating(true)
	var res := await ApiClient.register(user, email, pwd)
	_set_creating(false)
	if not res.ok:
		_show_signup_error(res.error if res.error != "" else "Não foi possível criar a conta.")
		return

	# Conta criada — NÃO loga automaticamente: volta para a tela de login para o jogador entrar.
	_save_account(user, email)
	ApiClient.clear_tokens()       # registro não mantém sessão; o login refaz a auth
	_user_input.text = user        # pré-preenche o usuário no login
	_pass_input.text = ""
	_show_login()
	_success_lbl.text = "Conta criada! Faça login para entrar."
	_success_lbl.visible = true

func _is_valid_email(p_email: String) -> bool:
	var re := RegEx.new()
	re.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$")
	return re.search(p_email) != null


# ── Entrar no mundo ──────────────────────────────────────────────────────────
func _login_as(p_user: String) -> void:
	NetworkState.account_name = p_user
	NetworkState.player_name = p_user   # nome no mundo (até ter personagem próprio)
	_save_user(p_user)
	# Busca o perfil para cachear o playerId (NetworkState.player_id) — usado em trocas.
	await ApiClient.get_me()
	# Busca o personagem no backend (popula o cache do CharacterStore) antes de decidir o destino.
	await CharacterStore.fetch()
	# Progresso de quests (gate do onboarding) — autoritativo do backend.
	await QuestStore.hydrate()
	# Sem personagem criado: vai para a criação antes de entrar no mundo.
	if not CharacterStore.has_character():
		get_tree().change_scene_to_file(CHARACTER_CREATOR_SCENE)
		return
	_connect_to_world()

func _connect_to_world() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ServerConfig.server_host(), WORLD_PORT)
	if err != OK:
		_show_loading(false)
		_show_error("Falha ao iniciar a conexão (%d)." % err)
		return
	multiplayer.multiplayer_peer = peer
	NetworkState.local_player_index = 1
	if not multiplayer.connected_to_server.is_connected(_on_world_connected):
		multiplayer.connected_to_server.connect(_on_world_connected, CONNECT_ONE_SHOT)
	if not multiplayer.connection_failed.is_connected(_on_world_failed):
		multiplayer.connection_failed.connect(_on_world_failed, CONNECT_ONE_SHOT)
	_set_connecting(true)

func _on_world_connected() -> void:
	if multiplayer.connection_failed.is_connected(_on_world_failed):
		multiplayer.connection_failed.disconnect(_on_world_failed)
	# Quem ainda não fez o tutorial entra pelo onboarding; senão, direto pro mundo.
	var next_scene := ONBOARDING_SCENE if not QuestStore.is_tutorial_done() else WORLD_SCENE
	get_tree().change_scene_to_file(next_scene)

func _on_world_failed() -> void:
	if multiplayer.connected_to_server.is_connected(_on_world_connected):
		multiplayer.connected_to_server.disconnect(_on_world_connected)
	multiplayer.multiplayer_peer = null
	_set_connecting(false)
	_show_loading(false)
	_show_error("Não foi possível conectar ao servidor (%s)." % ServerConfig.server_host())

func _set_connecting(p_on: bool) -> void:
	_enter_btn.disabled = p_on
	_create_btn.disabled = p_on
	_enter_btn.text = "Conectando…" if p_on else "⚔  Entrar"
	_create_btn.text = "Conectando…" if p_on else "✦  Criar"

func _set_creating(p_on: bool) -> void:
	_create_btn.disabled = p_on
	_go_login.disabled = p_on
	_create_btn.text = "Criando…" if p_on else "✦  Criar"

# Overlay de carregamento durante chamadas à API / conexão ao mundo.
func _show_loading(p_on: bool, p_msg: String = "Carregando informações…") -> void:
	_loading.visible = p_on
	if p_on:
		_loading_label.text = p_msg
		_spinner.pivot_offset = _spinner.size / 2.0
		if _spinner_tween != null and _spinner_tween.is_valid():
			_spinner_tween.kill()
		_spinner_tween = create_tween().set_loops()
		_spinner_tween.tween_property(_spinner, "rotation", TAU, 1.2) \
			.from(0.0).set_trans(Tween.TRANS_LINEAR)
	elif _spinner_tween != null and _spinner_tween.is_valid():
		_spinner_tween.kill()
		_spinner_tween = null

func _show_error(p_msg: String) -> void:
	_success_lbl.visible = false
	_error_lbl.text = p_msg
	_error_lbl.visible = true

func _show_signup_error(p_msg: String) -> void:
	_su_error.text = p_msg
	_su_error.visible = true


# ── Persistência ──────────────────────────────────────────────────────────────
func _load_last_user() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		return str(cfg.get_value("account", "username", ""))
	return ""

func _save_user(p_user: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("account", "username", p_user)
	cfg.save(SETTINGS_PATH)

func _save_account(p_user: String, p_email: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("account", "username", p_user)
	cfg.set_value("account", "email", p_email)
	cfg.save(SETTINGS_PATH)
