# scenes/ui/boardv2/tutorial/tutorial_coach.gd
# Coaching da partida-tutorial. Dois modos:
#   show_message(text) -> await : EXPLICAÇÃO bloqueante (dim + retrato do Blauber + fala). Segue com
#                                 clique/Espaço; ao seguir, SOME (dim sai) para o jogador poder agir.
#   show_hint(text) / hide_hint : INSTRUÇÃO DE AÇÃO — texto piscando no TOPO, sem dim e sem retrato,
#                                 não bloqueia (não cobre botões/cartas). Estilo "Segure [Espaço]...".
# Layout no .tscn. Ver TutorialDirector.
extends CanvasLayer

signal advanced

@onready var _dim: ColorRect = $Dim
@onready var _portrait: TextureRect = $Root/Portrait
@onready var _speech: PanelContainer = $Root/SpeechPanel
@onready var _body_label: RichTextLabel = $Root/SpeechPanel/Margin/VBox/BodyLabel
@onready var _continue_hint: Label = $Root/ContinueHint
@onready var _top_hint: Label = $Root/TopHint

var _blocking: bool = false
var _hint_tween: Tween

func _ready() -> void:
	_hide_message()
	_hide_top_hint()

## Explicação bloqueante (dim + retrato). Segue com clique/Espaço; ao seguir some tudo.
func show_message(p_text: String) -> void:
	_hide_top_hint()
	_body_label.text = p_text
	_dim.visible = true
	_portrait.visible = true
	_speech.visible = true
	_continue_hint.visible = true
	_blocking = true
	await advanced
	_blocking = false
	_hide_message()

## Instrução de ação: texto piscando no topo (sem dim, sem retrato — não cobre nada).
func show_hint(p_text: String) -> void:
	_hide_message()
	_top_hint.text = p_text
	_top_hint.visible = true
	_top_hint.modulate.a = 1.0
	if _hint_tween != null:
		_hint_tween.kill()
	_hint_tween = create_tween().set_loops()
	_hint_tween.tween_property(_top_hint, "modulate:a", 0.35, 0.7)
	_hint_tween.tween_property(_top_hint, "modulate:a", 1.0, 0.7)

func hide_hint() -> void:
	_hide_top_hint()

# ── internos ─────────────────────────────────────────────────────────────────
func _hide_message() -> void:
	_dim.visible = false
	_portrait.visible = false
	_speech.visible = false
	_continue_hint.visible = false

func _hide_top_hint() -> void:
	if _hint_tween != null:
		_hint_tween.kill()
		_hint_tween = null
	_top_hint.visible = false

# Usa _input (antes do GUI) para capturar o "continuar" mesmo com o Dim por cima.
func _input(event: InputEvent) -> void:
	if not _blocking:
		return
	var accept: bool = event.is_action_pressed("ui_accept")
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if accept or click:
		get_viewport().set_input_as_handled()
		advanced.emit()
