# scenes/world/ui/hud_world.gd
extends Control

@onready var chat_panel    : Control        = $ChatPanel
@onready var chat_log      : RichTextLabel  = $ChatPanel/VBox/ChatLog
@onready var chat_input    : LineEdit       = $ChatPanel/VBox/ChatInput
@onready var chat_toggle   : Button         = $ChatToggle
@onready var esc_hint      : Label          = $EscHint

var _chat_open: bool = false
var _local_player: Node = null

func _ready() -> void:
	chat_panel.visible = false
	GameBus.world_chat_received.connect(_on_chat_received)
	chat_input.text_submitted.connect(_on_chat_submitted)
	chat_toggle.pressed.connect(_toggle_chat)

func set_local_player(p_char: Node) -> void:
	_local_player = p_char

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if not _chat_open:
				_toggle_chat()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _chat_open:
			_toggle_chat()
			get_viewport().set_input_as_handled()

func _toggle_chat() -> void:
	_chat_open = not _chat_open
	chat_panel.visible = _chat_open
	if _chat_open:
		chat_input.grab_focus()
	else:
		chat_input.release_focus()

func _on_chat_submitted(text: String) -> void:
	var msg := text.strip_edges()
	chat_input.clear()
	if msg.is_empty():
		return
	WorldState.request_chat(msg)
	if _local_player and _local_player.has_method("show_chat"):
		_local_player.show_chat(msg)

func _on_chat_received(peer_id: int, message: String) -> void:
	var players := WorldState.get_players()
	var sender_name := "???"
	if players.has(peer_id):
		sender_name = players[peer_id]["player_name"]
	chat_log.append_text("[color=#c8a050]%s:[/color] %s\n" % [sender_name, message])
	chat_log.scroll_to_line(chat_log.get_line_count())
