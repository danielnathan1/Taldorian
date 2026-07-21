# scenes/world/ui/confirm_prompt/confirm_prompt.gd
# Prompt de confirmação REUTILIZÁVEL (Sim/Não). Uso:
#   var prompt := CONFIRM_PROMPT_SCENE.instantiate(); ui_layer.add_child(prompt)
#   prompt.show_prompt("Pagar 200 PO?")
#   var ok := await prompt.decided
# Remove-se sozinho ao decidir.
extends Control

signal decided(confirmed: bool)

@onready var _msg: Label = $Center/Panel/Margin/VBox/Message
@onready var _yes: Button = $Center/Panel/Margin/VBox/Buttons/Yes
@onready var _no: Button = $Center/Panel/Margin/VBox/Buttons/No

func _ready() -> void:
	visible = false
	_yes.pressed.connect(_on_yes)
	_no.pressed.connect(_on_no)

func show_prompt(p_message: String, p_yes: String = "Pagar", p_no: String = "Recusar") -> void:
	_msg.text = p_message
	_yes.text = p_yes
	_no.text = p_no
	visible = true
	_yes.grab_focus()

func _on_yes() -> void:
	decided.emit(true)
	queue_free()

func _on_no() -> void:
	decided.emit(false)
	queue_free()
