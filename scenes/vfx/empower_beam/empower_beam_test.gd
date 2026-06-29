## scenes/vfx/empower_beam/empower_beam_test.gd
## Cena de QA isolada do EmpowerBeam: botão "Conjurar" + 5 botões de cor.
## Posições fixas equivalentes às do protótipo (carta jogada → herói ativo).
extends Control

const EmpowerBeamScene := preload("res://scenes/vfx/empower_beam/EmpowerBeam.tscn")

# Origem = carta recém-jogada (zona de combate) · Alvo = herói ativo.
const SOURCE_POS := Vector2(620.0, 470.0)
const TARGET_POS := Vector2(360.0, 524.0)
const CARD_SIZE  := Vector2(90.0, 126.0)

var _color_key: String = "azul"
var _busy: bool = false

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.031, 0.031, 0.055)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -1
	add_child(bg)

	_marker(SOURCE_POS, Color(0.9, 0.8, 0.3, 0.5), "CARTA")
	_marker(TARGET_POS, Color(0.4, 0.7, 1.0, 0.5), "HERÓI ATIVO", CARD_SIZE)

	var btn := Button.new()
	btn.text = "✦  Conjurar"
	btn.position = Vector2(20.0, 660.0)
	btn.custom_minimum_size = Vector2(150.0, 36.0)
	add_child(btn)
	btn.pressed.connect(_on_cast_pressed)

	var x := 190.0
	for key in EmpowerBeam.PALETTES.keys():
		var cb := Button.new()
		cb.text = String(key).capitalize()
		cb.position = Vector2(x, 660.0)
		cb.custom_minimum_size = Vector2(96.0, 36.0)
		add_child(cb)
		cb.pressed.connect(func() -> void: _color_key = key)
		x += 102.0

	_cast()

func _marker(pos: Vector2, color: Color, label: String, card_size: Vector2 = Vector2(10.0, 10.0)) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.size = card_size
	rect.position = pos - card_size * 0.5
	add_child(rect)
	var lbl := Label.new()
	lbl.text = label
	lbl.position = pos + Vector2(card_size.x * 0.5 + 4.0, -8.0)
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(color.r, color.g, color.b, 0.9))
	add_child(lbl)

func _on_cast_pressed() -> void:
	if not _busy:
		_cast()

func _cast() -> void:
	_busy = true
	var fx: EmpowerBeam = EmpowerBeamScene.instantiate()
	add_child(fx)
	fx.finished.connect(func() -> void: _busy = false, CONNECT_ONE_SHOT)
	fx.play(SOURCE_POS, TARGET_POS, _color_key, 3, 2, CARD_SIZE)
