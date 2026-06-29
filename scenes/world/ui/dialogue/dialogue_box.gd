# scenes/world/ui/dialogue/dialogue_box.gd
# Caixa de diálogo estilo Stardew (faixa inferior-central, retrato à esquerda).
# Data-driven: carrega data/dialogues/<id>.json e exibe linha a linha.
#
# A caixa NÃO decide nada de jogo — só exibe e avança. Quem abre o diálogo (o driver:
# OnboardingController / NPC) é responsável por travar o movimento do jogador via
# player.set_movement_locked(true), do mesmo jeito que a janela de troca faz, e por
# instanciar/await desta cena. Listeners desacoplados (ex.: sistema de missão) reagem
# por GameBus.dialogue_finished — não precisam de referência a esta cena.
#
# Uso típico:
#   var box := DIALOGUE_BOX_SCENE.instantiate()
#   world_hud.add_child(box)
#   box.finished.connect(func(_id): box.queue_free())
#   box.play("intro_encapuzado")
extends Control

## Emitido quando o jogador encerra a última linha (driver imediato escuta para encadear).
signal finished(dialogue_id: String)

const DIALOGUE_DIR := "res://data/dialogues/"
const PORTRAIT_DIR := "res://assets/portraits/"
const TYPE_SPEED   := 45.0   # caracteres por segundo (efeito máquina de escrever)

@onready var _portrait     : TextureRect   = $Dock/Portrait
@onready var _speaker_name : Label         = $Dock/NameTab/SpeakerName
@onready var _text         : RichTextLabel = $Dock/TextPanel/Margin/Text
@onready var _advance      : Control       = $Dock/AdvanceIndicator

var _lines: Array = []
var _speakers: Dictionary = {}   # chave do personagem → { name, portrait } (declarado 1x no JSON)
var _index: int = -1
var _dialogue_id: String = ""
var _typing: bool = false
var _type_tween: Tween

func _ready() -> void:
	visible = false

# ═══════════════════════════════════════════════════════════════════════════════

## Inicia o diálogo identificado por p_dialogue_id (sem extensão). Resiliente: se o
## arquivo não existir, encerra graciosamente (emite finished) em vez de quebrar.
func play(p_dialogue_id: String) -> void:
	var data := _load_dialogue(p_dialogue_id)
	var lines: Array = data.get("lines", []) if data is Dictionary else []
	if lines.is_empty():
		push_warning("Diálogo vazio ou não encontrado: %s" % p_dialogue_id)
		finished.emit(p_dialogue_id)
		queue_free()
		return
	_dialogue_id = p_dialogue_id
	_lines = lines
	_speakers = data.get("speakers", {}) if data is Dictionary else {}
	_index = -1
	visible = true
	GameBus.dialogue_started.emit(_dialogue_id)
	_advance_line()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var advance_pressed: bool = event.is_action_pressed("ui_accept") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if advance_pressed:
		get_viewport().set_input_as_handled()
		_on_advance()

# 1º toque completa a linha sendo digitada; o seguinte avança para a próxima.
func _on_advance() -> void:
	if _typing:
		_finish_typing()
	else:
		_advance_line()

func _advance_line() -> void:
	_index += 1
	if _index >= _lines.size():
		_close()
		return
	var line: Dictionary = _lines[_index]
	# Resolve nome/retrato pela tabela de personagens; a linha pode sobrescrever
	# qualquer um (ex.: name "???" antes da revelação, ou um retrato de expressão).
	# Sem tabela 'speakers', 'speaker' é tratado como o próprio nome de exibição (formato antigo).
	var sp: Dictionary = _speakers.get(str(line.get("speaker", "")), {})
	_speaker_name.text = str(line.get("name", sp.get("name", line.get("speaker", ""))))
	_set_portrait(str(line.get("portrait", sp.get("portrait", ""))))
	_start_typing(str(line.get("text", "")))
	GameBus.dialogue_advanced.emit(_index)

# ── Máquina de escrever ──────────────────────────────────────────────────────────

func _start_typing(p_text: String) -> void:
	_text.text = p_text
	_text.visible_ratio = 0.0
	_advance.visible = false
	_typing = true
	var duration := maxf(0.1, p_text.length() / TYPE_SPEED)
	if _type_tween:
		_type_tween.kill()
	_type_tween = create_tween()
	_type_tween.tween_property(_text, "visible_ratio", 1.0, duration)
	_type_tween.tween_callback(_finish_typing)

func _finish_typing() -> void:
	if _type_tween:
		_type_tween.kill()
	_text.visible_ratio = 1.0
	_typing = false
	_advance.visible = true

# ── Apresentação ─────────────────────────────────────────────────────────────────

# Resiliente a arte ausente: sem textura, esconde o retrato (não quebra).
func _set_portrait(p_portrait: String) -> void:
	var path := PORTRAIT_DIR + p_portrait + ".png"
	if p_portrait != "" and ResourceLoader.exists(path):
		_portrait.texture = load(path)
		_portrait.visible = true
	else:
		_portrait.texture = null
		_portrait.visible = false

func _close() -> void:
	visible = false
	GameBus.dialogue_finished.emit(_dialogue_id)
	finished.emit(_dialogue_id)
	queue_free()

func _load_dialogue(p_id: String) -> Dictionary:
	var path := DIALOGUE_DIR + p_id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}
