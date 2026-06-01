## scenes/vfx/arrow_rain/arrow_rain_test.gd
## Cena de QA isolada: botão "Disparar" testa o ArrowRain com as posições
## idênticas às usadas no Arrow Rain.html de referência.
extends Control

const ArrowRainScene := preload("res://scenes/vfx/arrow_rain/ArrowRain.tscn")

# Posições de referência — idênticas ao HTML (ARCHER e TARGET)
const SOURCE_POS  := Vector2(720.0, 540.0)
const TARGET_RECT := Rect2(Vector2(240.0, 110.0), Vector2(820.0, 230.0))

var _busy: bool = false

func _ready() -> void:
	# Fundo escuro
	var bg := ColorRect.new()
	bg.color = Color(0.039, 0.039, 0.071)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -1
	add_child(bg)

	# Marcador visual da área alvo
	var target_outline := ColorRect.new()
	target_outline.color    = Color(0.8, 0.2, 0.15, 0.12)
	target_outline.position = TARGET_RECT.position
	target_outline.size     = TARGET_RECT.size
	add_child(target_outline)

	# Marcador da posição do arqueiro
	var archer_dot := ColorRect.new()
	archer_dot.color    = Color(0.9, 0.8, 0.2, 0.5)
	archer_dot.size     = Vector2(10.0, 10.0)
	archer_dot.position = SOURCE_POS - Vector2(5.0, 5.0)
	add_child(archer_dot)

	# Labels de contexto
	var lbl_target := Label.new()
	lbl_target.text     = "TARGET RECT"
	lbl_target.position = TARGET_RECT.position + Vector2(4.0, 2.0)
	lbl_target.add_theme_font_size_override("font_size", 9)
	lbl_target.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4, 0.7))
	add_child(lbl_target)

	var lbl_src := Label.new()
	lbl_src.text     = "ARCHER"
	lbl_src.position = SOURCE_POS + Vector2(8.0, -10.0)
	lbl_src.add_theme_font_size_override("font_size", 9)
	lbl_src.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2, 0.8))
	add_child(lbl_src)

	# Botão de disparo
	var btn := Button.new()
	btn.text               = "▶  Disparar"
	btn.position           = Vector2(20.0, 672.0)
	btn.custom_minimum_size = Vector2(150.0, 36.0)
	add_child(btn)
	btn.pressed.connect(_on_fire_pressed)

	# Dispara automaticamente ao abrir a cena
	_fire()

func _on_fire_pressed() -> void:
	if not _busy:
		_fire()

func _fire() -> void:
	_busy = true
	var fx: ArrowRain = ArrowRainScene.instantiate()
	add_child(fx)
	fx.finished.connect(func() -> void: _busy = false, CONNECT_ONE_SHOT)
	fx.play(SOURCE_POS, TARGET_RECT)
