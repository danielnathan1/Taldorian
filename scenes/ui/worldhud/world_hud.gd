# scenes/ui/worldhud/world_hud.gd
# HUD do mundo aberto — PlayerCard, Chat com abas e IconBar.
# Expõe sinais públicos para a cena do mundo; toda lógica fica aqui.
extends CanvasLayer

# ── Sinais públicos ────────────────────────────────────────────────────────────
signal battle_requested
signal inventory_requested
signal decks_requested
signal friends_toggled(open: bool)
signal logout_requested
signal shop_requested
signal forge_requested
signal chat_message_sent(channel: String, text: String)
signal profile_requested

# ── Configuração de chat ───────────────────────────────────────────────────────
const CHANNELS       : Array[String] = ["global", "private", "guild"]
const CHANNEL_LABELS : Array[String] = ["GLOBAL", "PRIVADO", "GUILD"]
const CHANNEL_COLORS : Array[Color]  = [
	Color(0.5294, 0.8078, 0.8941, 1.0),  # accent (global)
	Color(0.7216, 0.6118, 1.0000, 1.0),  # whisper (privado)
	Color(0.5608, 0.8510, 0.6039, 1.0),  # guild
]
const CHANNEL_PREFIXES : Array[String] = ["[G]", "[PV]", "[G]"]

# ── Estado interno ─────────────────────────────────────────────────────────────
var _active_channel : int        = 0
var _unread         : Array[int] = [0, 0, 0]
var _chat_logs      : Array      = [[], [], []]   # Array[Array[Dictionary]]
var _friends_open   : bool       = false
var _xp_ratio       : float      = 0.0

const PROFILE_PATH := "user://profile.cfg"

# ── Nós do PlayerCard ──────────────────────────────────────────────────────────
@onready var avatar_frame  : Control   = $Root/PlayerCard/PC_VBox/PC_Top/AvatarFrame
@onready var player_name   : Label     = $Root/PlayerCard/PC_VBox/PC_Top/PC_Info/PlayerName
@onready var gold_label    : Label     = $Root/PlayerCard/PC_VBox/PC_Top/PC_Info/PC_Stats/GoldBox/GoldLabel
@onready var rank_label    : Label     = $Root/PlayerCard/PC_VBox/PC_Top/PC_Info/PC_Stats/RankBox/RankLabel
@onready var xp_bar        : ProgressBar = $Root/PlayerCard/PC_VBox/XP_Wrap/XpBar
@onready var xp_val_label  : Label     = $Root/PlayerCard/PC_VBox/XP_Wrap/XP_Meta/XP_Val

# ── Nós do Chat ────────────────────────────────────────────────────────────────
@onready var tab_global       : Button        = $Root/Chat/Chat_VBox/Chat_Tabs/TabGlobal
@onready var tab_private      : Button        = $Root/Chat/Chat_VBox/Chat_Tabs/TabPrivate
@onready var tab_guild        : Button        = $Root/Chat/Chat_VBox/Chat_Tabs/TabGuild
@onready var badge_global     : Label         = $Root/Chat/Chat_VBox/Chat_Tabs/TabGlobal/BadgeGlobal
@onready var badge_private    : Label         = $Root/Chat/Chat_VBox/Chat_Tabs/TabPrivate/BadgePrivate
@onready var badge_guild      : Label         = $Root/Chat/Chat_VBox/Chat_Tabs/TabGuild/BadgeGuild
@onready var underline_global : ColorRect     = $Root/Chat/Chat_VBox/Chat_Tabs/TabGlobal/Underline
@onready var underline_private: ColorRect     = $Root/Chat/Chat_VBox/Chat_Tabs/TabPrivate/Underline
@onready var underline_guild  : ColorRect     = $Root/Chat/Chat_VBox/Chat_Tabs/TabGuild/Underline
@onready var messages         : VBoxContainer = $Root/Chat/Chat_VBox/Chat_Log/Messages
@onready var chat_scroll      : ScrollContainer = $Root/Chat/Chat_VBox/Chat_Log
@onready var field            : LineEdit      = $Root/Chat/Chat_VBox/Chat_Input/Field
@onready var channel_prefix   : Label         = $Root/Chat/Chat_VBox/Chat_Input/ChannelPrefix

# ── Nós da IconBar ─────────────────────────────────────────────────────────────
@onready var btn_battle    : Button        = $Root/IconBar/IB_HBox/BtnBattle
@onready var btn_inventory : Button        = $Root/IconBar/IB_HBox/BtnInventory
@onready var btn_decks     : Button        = $Root/IconBar/IB_HBox/BtnDecks
@onready var btn_shop      : Button        = $Root/IconBar/IB_HBox/BtnShop
@onready var btn_forge     : Button        = $Root/IconBar/IB_HBox/BtnForge
@onready var btn_friends   : Button        = $Root/IconBar/IB_HBox/BtnFriends
@onready var btn_logout    : Button        = $Root/IconBar/IB_HBox/BtnLogout
@onready var friends_popover : PanelContainer = $Root/IconBar/IB_HBox/BtnFriends/FriendsPopover
@onready var friends_list  : VBoxContainer = $Root/IconBar/IB_HBox/BtnFriends/FriendsPopover/Popover_VBox/FriendsList
@onready var friends_badge : Label         = $Root/IconBar/IB_HBox/BtnFriends/Badge

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	GameBus.world_chat_received.connect(_on_world_chat_received)

	tab_global.pressed.connect(func() -> void: _switch_tab(0))
	tab_private.pressed.connect(func() -> void: _switch_tab(1))
	tab_guild.pressed.connect(func() -> void: _switch_tab(2))

	field.text_submitted.connect(_on_field_submitted)

	btn_battle.pressed.connect(func() -> void: battle_requested.emit())
	btn_inventory.pressed.connect(func() -> void: inventory_requested.emit())
	btn_decks.pressed.connect(func() -> void: decks_requested.emit())
	btn_shop.pressed.connect(func() -> void: shop_requested.emit())
	btn_forge.pressed.connect(func() -> void: forge_requested.emit())
	btn_friends.pressed.connect(_toggle_friends)
	btn_logout.pressed.connect(func() -> void: logout_requested.emit())

	_setup_avatar_click()

	friends_popover.visible = false

	_switch_tab(0)
	_load_profile()

# ── API pública ────────────────────────────────────────────────────────────────

func set_player(p_data: Dictionary) -> void:
	player_name.text = p_data.get("name", "Jogador")
	gold_label.text  = _format_num(p_data.get("gold", 0))
	rank_label.text  = p_data.get("rank", "—")
	var level: int   = p_data.get("level", 1)
	var xp: float    = p_data.get("xp", 0.0)
	if avatar_frame.has_method("set_level"):
		avatar_frame.set_level(level)
	_xp_ratio = clampf(xp, 0.0, 1.0)
	xp_bar.value = _xp_ratio * 100.0

## Atualiza só o ouro exibido no PlayerCard (ex.: após uma troca), sem refazer o resto.
func set_gold(p_amount: int) -> void:
	gold_label.text = _format_num(p_amount)

func set_avatar_photo(p_tex: Texture2D) -> void:
	if avatar_frame.has_method("set_photo"):
		avatar_frame.set_photo(p_tex)
	_save_profile()

# Botão transparente sobre o avatar (medalhão) — abre o perfil ao clicar.
func _setup_avatar_click() -> void:
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.tooltip_text = "Ver perfil"
	btn.z_index = 5
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)
	btn.pressed.connect(func() -> void: profile_requested.emit())
	avatar_frame.add_child(btn)

func push_chat(p_channel: String, p_who: String, p_body: String, p_system := false) -> void:
	var ch := CHANNELS.find(p_channel)
	if ch < 0:
		ch = 0
	_add_message(ch, p_who, p_body, p_system)

# Oculta/mostra o conteúdo da HUD (PlayerCard, Chat, IconBar) sem afetar overlays
# adicionados como filhos deste CanvasLayer (ex.: tela de Salas). Necessário porque
# vários nós da HUD usam z_index positivo (badges, cantos do avatar) e vazariam por
# cima de um overlay de z_index 0.
func set_content_visible(p_visible: bool) -> void:
	$Root.visible = p_visible


func set_friends(p_list: Array) -> void:
	for child in friends_list.get_children():
		child.queue_free()
	var online := 0
	for f: Dictionary in p_list:
		friends_list.add_child(_make_friend_row(f))
		if f.get("status", "off") == "on":
			online += 1
	if btn_friends.has_method("set_badge"):
		btn_friends.set_badge(online)

# ── Chat interno ───────────────────────────────────────────────────────────────

func _switch_tab(p_idx: int) -> void:
	_active_channel   = p_idx
	_unread[p_idx]    = 0
	_update_tab_visuals()
	_rebuild_messages()
	channel_prefix.text = CHANNEL_PREFIXES[p_idx]

func _update_tab_visuals() -> void:
	var tabs       := [tab_global,       tab_private,       tab_guild]
	var badges     := [badge_global,     badge_private,     badge_guild]
	var underlines := [underline_global, underline_private, underline_guild]
	for i in 3:
		var active := (i == _active_channel)
		var col: Color = CHANNEL_COLORS[i] if active else Color(0.5451, 0.5608, 0.6118, 1.0)
		tabs[i].add_theme_color_override("font_color", col)
		underlines[i].visible = active
		badges[i].visible     = _unread[i] > 0
		badges[i].text        = str(_unread[i])

func _rebuild_messages() -> void:
	for child in messages.get_children():
		child.queue_free()
	for entry: Dictionary in (_chat_logs[_active_channel] as Array):
		messages.add_child(_make_msg_label(entry))
	_scroll_to_bottom()

func _add_message(p_ch: int, p_who: String, p_body: String, p_system: bool) -> void:
	var time  := Time.get_time_string_from_system().left(5)
	var entry := { "time": time, "who": p_who, "body": p_body, "system": p_system }
	_chat_logs[p_ch].append(entry)
	if p_ch == _active_channel:
		messages.add_child(_make_msg_label(entry))
		_scroll_to_bottom()
	else:
		_unread[p_ch] += 1
		_update_tab_visuals()

func _make_msg_label(p_entry: Dictionary) -> RichTextLabel:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled             = true
	lbl.fit_content                = true
	lbl.scroll_active              = false
	lbl.size_flags_horizontal      = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("normal_font_size", 12)

	var time_col  := "6b6f7c"
	var body_text := ""

	if p_entry.get("system", false):
		var body_col := "e0b04a"
		body_text     = "[color=#%s]%s[/color]" % [body_col, p_entry["body"]]
	else:
		var name_col: String = (CHANNEL_COLORS[_active_channel] as Color).to_html(false)
		body_text = "[color=#%s][b]%s[/b][/color] [color=#e7e3da]%s[/color]" % [
			name_col, p_entry["who"], p_entry["body"]
		]

	lbl.parse_bbcode("[color=#%s]%s[/color]  %s" % [time_col, p_entry["time"], body_text])
	return lbl

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	chat_scroll.scroll_vertical = chat_scroll.get_v_scroll_bar().max_value

func _on_field_submitted(p_text: String) -> void:
	var msg := p_text.strip_edges()
	field.clear()
	if msg.is_empty():
		return
	var ch_name: String = CHANNELS[_active_channel]
	chat_message_sent.emit(ch_name, msg)
	WorldState.request_chat(msg)
	var who := ("você → %s" % "alvo") if _active_channel == 1 else NetworkState.player_name
	_add_message(_active_channel, who, msg, false)

func _on_world_chat_received(p_peer_id: int, p_message: String) -> void:
	# O servidor ecoa a mensagem de volta a todos os peers, inclusive ao remetente.
	# A própria mensagem já foi adicionada localmente em _on_field_submitted, então
	# ignoramos o eco para não duplicar no log.
	if p_peer_id == multiplayer.get_unique_id():
		return
	var players := WorldState.get_players()
	var name := "???"
	if players.has(p_peer_id):
		name = str(players[p_peer_id]["player_name"])
	_add_message(0, name, p_message, false)

# ── Amigos ─────────────────────────────────────────────────────────────────────

func _toggle_friends() -> void:
	_friends_open = not _friends_open
	if _friends_open:
		friends_popover.visible  = true
		friends_popover.modulate = Color(1, 1, 1, 0)
		var tw := create_tween()
		tw.tween_property(friends_popover, "modulate:a", 1.0, 0.15)
	else:
		friends_popover.visible = false
	friends_toggled.emit(_friends_open)

func _make_friend_row(p_f: Dictionary) -> HBoxContainer:
	const DOT_COLORS := {
		"on":   Color(0.5608, 0.8510, 0.6039, 1.0),
		"idle": Color(0.8784, 0.6902, 0.2902, 1.0),
		"off":  Color(0.2902, 0.3059, 0.3451, 1.0),
	}
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	row.add_theme_constant_override("margin_top",    6)
	row.add_theme_constant_override("margin_bottom", 6)

	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(8.0, 8.0)
	dot.color = DOT_COLORS.get(p_f.get("status", "off"), DOT_COLORS["off"]) as Color
	row.add_child(dot)

	var name_lbl := Label.new()
	name_lbl.text = p_f.get("name", "")
	name_lbl.add_theme_color_override("font_color", Color(0.7176, 0.7137, 0.6784, 1.0))
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var status_lbl := Label.new()
	status_lbl.text = p_f.get("status_text", "")
	status_lbl.add_theme_color_override("font_color", Color(0.4196, 0.4353, 0.4824, 1.0))
	status_lbl.add_theme_font_size_override("font_size", 10)
	row.add_child(status_lbl)

	return row

# ── Persistência de avatar ─────────────────────────────────────────────────────

func _save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PROFILE_PATH)  # preserva chaves do perfil (ring_color, favorite_card…)
	cfg.set_value("avatar", "frame_id", "azure")
	cfg.save(PROFILE_PATH)

func _load_profile() -> void:
	# Espelha o avatar do perfil: cor do anel (borda) + ícone escolhido.
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) != OK:
		return
	var ring_html: String = cfg.get_value("avatar", "ring_color", "e0b04a")  # ouro por padrão
	if avatar_frame.has_method("set_ring_color"):
		avatar_frame.set_ring_color(Color.html(ring_html))
	var photo_path: String = cfg.get_value("avatar", "photo_path", "")
	if photo_path != "" and ResourceLoader.exists(photo_path):
		avatar_frame.set_photo(load(photo_path))

## Recarrega o avatar (moldura + ícone) do profile.cfg — chamado quando o jogador
## fecha o modal de perfil, para refletir mudanças sem recarregar o mundo.
func reload_avatar() -> void:
	_load_profile()

# ── Utilitários ────────────────────────────────────────────────────────────────

func _format_num(p_n: int) -> String:
	var s      := str(p_n)
	var result := ""
	var count  := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "." + result
		result  = s[i] + result
		count  += 1
	return result
