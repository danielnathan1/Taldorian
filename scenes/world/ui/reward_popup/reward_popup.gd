# scenes/world/ui/reward_popup/reward_popup.gd
# Popup de recompensa estilo "abertura de booster": a tela escurece e a carta/herói vem
# GIRANDO e para no centro com um pop (overshoot), aí o título/subtítulo aparecem. Genérico
# e reutilizável (arte + título + subtítulo). Emite 'closed' e se remove ao fechar.
extends Control

signal closed

@onready var _dim: ColorRect = $Dim
@onready var _card: TextureRect = $Card
@onready var _title: Label = $TextBox/Title
@onready var _subtitle: Label = $TextBox/Subtitle
@onready var _btn: Button = $BtnClose

func _ready() -> void:
	visible = false
	_btn.pressed.connect(_on_close)

## Mostra a recompensa. p_art_path = caminho res:// da arte (ex.: a do herói/carta).
func show_reward(p_art_path: String, p_title: String, p_subtitle: String = "") -> void:
	if p_art_path != "" and ResourceLoader.exists(p_art_path):
		_card.texture = load(p_art_path)
		_card.visible = true
	else:
		_card.visible = false
	_title.text = p_title
	_subtitle.text = p_subtitle
	visible = true
	_animate_in()

# Escurece → carta gira e "pop" no centro → textos e botão entram.
func _animate_in() -> void:
	_dim.modulate.a = 0.0
	_card.scale = Vector2(0.2, 0.2)
	_card.rotation = deg_to_rad(540.0)   # ~1,5 voltas, desacelerando até parar reto
	_card.modulate.a = 0.0
	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	_btn.modulate.a = 0.0
	_btn.disabled = true

	create_tween().tween_property(_dim, "modulate:a", 1.0, 0.25)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "rotation", 0.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "modulate:a", 1.0, 0.4)
	await tw.finished

	# Pequeno "respiro" + entrada dos textos/botão.
	var bump := create_tween()
	bump.tween_property(_card, "scale", Vector2(1.06, 1.06), 0.12)
	bump.tween_property(_card, "scale", Vector2.ONE, 0.12)

	var fade := create_tween().set_parallel(true)
	fade.tween_property(_title, "modulate:a", 1.0, 0.3)
	fade.tween_property(_subtitle, "modulate:a", 1.0, 0.3)
	fade.tween_property(_btn, "modulate:a", 1.0, 0.3)
	await fade.finished
	_btn.disabled = false
	_btn.grab_focus()

func _on_close() -> void:
	closed.emit()
	queue_free()
