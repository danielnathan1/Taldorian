## scenes/vfx/magic_missiles/magic_missiles_test.gd
## Cena de QA isolada: botão "Conjurar" testa os Mísseis Mágicos com as
## posições idênticas às de Magic Missiles.html (CASTER_ORIGIN e OPP).
extends Control

const MagicMissilesScene := preload("res://scenes/vfx/magic_missiles/MagicMissiles.tscn")

# Posições de referência — idênticas ao HTML
const SOURCE_POS := Vector2(720.0, 500.0)   # CASTER_ORIGIN (ponta do cajado)
const OPP := {
	"active": Vector2(720.0, 200.0),
	"h1":     Vector2(560.0, 200.0),
	"h2":     Vector2(470.0, 200.0),
	"h3":     Vector2(380.0, 200.0),
}

var _busy: bool = false
var _hp_bars: Dictionary = {}

func _ready() -> void:
	# Fundo escuro
	var bg := ColorRect.new()
	bg.color = Color(0.043, 0.031, 0.071)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -1
	add_child(bg)

	# Marcadores dos heróis do oponente + barras de HP fake
	for key in OPP.keys():
		var p: Vector2 = OPP[key]
		var dot := ColorRect.new()
		dot.color    = Color(0.70, 0.45, 0.95, 0.55)
		dot.size     = Vector2(12.0, 12.0)
		dot.position = p - Vector2(6.0, 6.0)
		add_child(dot)

		var bar := ProgressBar.new()
		bar.min_value      = 0.0
		bar.max_value      = 10.0
		bar.value          = 10.0
		bar.show_percentage = false
		bar.size           = Vector2(70.0, 8.0)
		bar.position       = p + Vector2(-35.0, 18.0)
		add_child(bar)
		_hp_bars[key] = bar

		var lbl := Label.new()
		lbl.text     = key.to_upper()
		lbl.position = p + Vector2(-18.0, -28.0)
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", Color(0.78, 0.55, 1.0, 0.8))
		add_child(lbl)

	# Marcador do caster (Arquimaga)
	var caster_dot := ColorRect.new()
	caster_dot.color    = Color(0.85, 0.55, 1.00, 0.65)
	caster_dot.size     = Vector2(14.0, 14.0)
	caster_dot.position = SOURCE_POS - Vector2(7.0, 7.0)
	add_child(caster_dot)

	var caster_lbl := Label.new()
	caster_lbl.text     = "ARQUIMAGA"
	caster_lbl.position = SOURCE_POS + Vector2(12.0, -10.0)
	caster_lbl.add_theme_font_size_override("font_size", 9)
	caster_lbl.add_theme_color_override("font_color", Color(0.85, 0.60, 1.00, 0.85))
	add_child(caster_lbl)

	# Botão de disparo
	var btn := Button.new()
	btn.text                = "✦  Conjurar"
	btn.position            = Vector2(20.0, 672.0)
	btn.custom_minimum_size = Vector2(160.0, 36.0)
	add_child(btn)
	btn.pressed.connect(_on_cast_pressed)

	# Dispara automaticamente ao abrir a cena
	_fire()

func _on_cast_pressed() -> void:
	if not _busy:
		_fire()

func _fire() -> void:
	_busy = true
	# Reseta as barras de HP a cada disparo
	for key in _hp_bars:
		(_hp_bars[key] as ProgressBar).value = 10.0

	var targets: Dictionary = {}
	for key in OPP.keys():
		targets[key] = { "pos": OPP[key], "hp_node": _hp_bars[key] }

	var fx: MagicMissiles = MagicMissilesScene.instantiate()
	add_child(fx)
	fx.finished.connect(func() -> void: _busy = false, CONNECT_ONE_SHOT)
	fx.play(SOURCE_POS, targets)
