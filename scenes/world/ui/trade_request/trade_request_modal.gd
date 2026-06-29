# scenes/world/ui/trade_request/trade_request_modal.gd
# Modal centralizado que pergunta ao jogador se aceita iniciar uma troca.
# Só exibe e emite a decisão — quem age sobre a rede é o world_root via WorldTrade.
extends Control

signal accepted
signal declined

@onready var _message    : Label  = $Center/Panel/Margin/VBox/Message
@onready var _btn_accept : Button = $Center/Panel/Margin/VBox/Buttons/BtnAccept
@onready var _btn_decline: Button = $Center/Panel/Margin/VBox/Buttons/BtnDecline

func _ready() -> void:
	_btn_accept.pressed.connect(func() -> void: accepted.emit())
	_btn_decline.pressed.connect(func() -> void: declined.emit())

func setup(p_from_name: String) -> void:
	_message.text = "O jogador %s deseja iniciar uma troca com você. Deseja aceitar?" % p_from_name
