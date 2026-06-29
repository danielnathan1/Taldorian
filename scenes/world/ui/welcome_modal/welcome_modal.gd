# scenes/world/ui/welcome_modal/welcome_modal.gd
# Modal de boas-vindas exibido UMA vez, na primeira entrada do jogador no mundo
# aberto (logo após criar o personagem). Apenas narrativo: o bônus de 1200 g já
# foi creditado no backend ao criar a conta. Só exibe e emite 'closed'.
extends Control

signal closed

@onready var _btn_close: Button = $Center/Panel/Margin/VBox/BtnClose

func _ready() -> void:
	_btn_close.pressed.connect(func() -> void: closed.emit())
	_btn_close.grab_focus()
