## scenes/vfx/holy_heal/holy_heal_test.gd
## Cena de QA isolada: botão "Curar" testa o HolyHeal com as posições
## idênticas às usadas no Holy Heal.html de referência.
extends Control

const HolyHealScene := preload("res://scenes/vfx/holy_heal/HolyHeal.tscn")

# Posições de referência — idênticas ao HTML (HEALER e ALLY_ZONE)
const SOURCE_POS := Vector2(720.0, 540.0)
const ALLY_ZONE  := Rect2(Vector2(280.0, 470.0), Vector2(520.0, 150.0))
const ALLIES := [
	{ "pos": Vector2(360.0, 540.0) },
	{ "pos": Vector2(450.0, 540.0) },
	{ "pos": Vector2(540.0, 540.0) },
	{ "pos": Vector2(720.0, 540.0) },
]

var _busy: bool = false

func _ready() -> void:
	# Fundo escuro
	var bg := ColorRect.new()
	bg.color = Color(0.039, 0.039, 0.071)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -1
	add_child(bg)

	# Marcador visual da zona aliada
	var zone_outline := ColorRect.new()
	zone_outline.color    = Color(0.20, 0.80, 0.35, 0.10)
	zone_outline.position = ALLY_ZONE.position
	zone_outline.size     = ALLY_ZONE.size
	add_child(zone_outline)

	# Marcadores dos 4 aliados
	for a in ALLIES:
		var dot := ColorRect.new()
		dot.color    = Color(0.40, 0.90, 0.50, 0.50)
		dot.size     = Vector2(10.0, 10.0)
		dot.position = (a["pos"] as Vector2) - Vector2(5.0, 5.0)
		add_child(dot)

	# Marcador da Irena (healer)
	var healer_dot := ColorRect.new()
	healer_dot.color    = Color(0.20, 0.95, 0.60, 0.60)
	healer_dot.size     = Vector2(14.0, 14.0)
	healer_dot.position = SOURCE_POS - Vector2(7.0, 7.0)
	add_child(healer_dot)

	# Labels de contexto
	var lbl_zone := Label.new()
	lbl_zone.text     = "ALLY ZONE"
	lbl_zone.position = ALLY_ZONE.position + Vector2(4.0, 2.0)
	lbl_zone.add_theme_font_size_override("font_size", 9)
	lbl_zone.add_theme_color_override("font_color", Color(0.50, 1.00, 0.60, 0.70))
	add_child(lbl_zone)

	var lbl_src := Label.new()
	lbl_src.text     = "IRENA"
	lbl_src.position = SOURCE_POS + Vector2(10.0, -12.0)
	lbl_src.add_theme_font_size_override("font_size", 9)
	lbl_src.add_theme_color_override("font_color", Color(0.20, 0.95, 0.60, 0.80))
	add_child(lbl_src)

	# Botão de disparo
	var btn := Button.new()
	btn.text                = "✦  Curar"
	btn.position            = Vector2(20.0, 672.0)
	btn.custom_minimum_size = Vector2(150.0, 36.0)
	add_child(btn)
	btn.pressed.connect(_on_heal_pressed)

	# Dispara automaticamente ao abrir a cena
	_fire()

func _on_heal_pressed() -> void:
	if not _busy:
		_fire()

func _fire() -> void:
	_busy = true
	var fx: HolyHeal = HolyHealScene.instantiate()
	add_child(fx)
	fx.finished.connect(func() -> void: _busy = false, CONNECT_ONE_SHOT)
	fx.play(SOURCE_POS, ALLY_ZONE, ALLIES)
