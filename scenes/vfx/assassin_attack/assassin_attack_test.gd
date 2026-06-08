## scenes/vfx/assassin_attack/assassin_attack_test.gd
## Cena de QA isolada: um botão "Ativar" instancia o AssassinAttack sobre um
## tabuleiro dummy 1280x720 e chama play(). Dispara automaticamente ao abrir.
extends Control

const AssassinAttackScene := preload("res://scenes/vfx/assassin_attack/AssassinAttack.tscn")

var _busy: bool = false

func _ready() -> void:
	# Fundo dummy do "tabuleiro": metade de cima (oponente) e de baixo (jogador),
	# com uma linha central em y=360 para conferir o corte.
	var top := ColorRect.new()
	top.color = Color(0.10, 0.07, 0.09)
	top.position = Vector2(0.0, 0.0)
	top.size = Vector2(1280.0, 360.0)
	top.z_index = -2
	add_child(top)

	var bottom := ColorRect.new()
	bottom.color = Color(0.07, 0.09, 0.12)
	bottom.position = Vector2(0.0, 360.0)
	bottom.size = Vector2(1280.0, 360.0)
	bottom.z_index = -2
	add_child(bottom)

	var mid := ColorRect.new()
	mid.color = Color(0.9, 0.9, 0.95, 0.12)
	mid.position = Vector2(0.0, 359.0)
	mid.size = Vector2(1280.0, 2.0)
	mid.z_index = -1
	add_child(mid)

	var lbl := Label.new()
	lbl.text = "DUMMY BOARD — linha central y=360"
	lbl.position = Vector2(20.0, 16.0)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 0.7))
	add_child(lbl)

	var btn := Button.new()
	btn.text = "▶  Ativar"
	btn.position = Vector2(20.0, 672.0)
	btn.custom_minimum_size = Vector2(150.0, 36.0)
	add_child(btn)
	btn.pressed.connect(_on_fire_pressed)

	_fire()

func _on_fire_pressed() -> void:
	if not _busy:
		_fire()

func _fire() -> void:
	_busy = true
	var fx: AssassinAttack = AssassinAttackScene.instantiate()
	add_child(fx)
	fx.finished.connect(func() -> void: _busy = false, CONNECT_ONE_SHOT)
	fx.play()
