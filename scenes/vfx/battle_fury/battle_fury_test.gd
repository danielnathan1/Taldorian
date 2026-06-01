## scenes/vfx/battle_fury/battle_fury_test.gd
## Cena de QA isolada: botões "Ativar" e "Desativar" testam o BattleFury
## com a carta dummy posicionada em Vector2(720, 540), espelhando Battle Fury.html.
extends Control

const BattleFuryScene := preload("res://scenes/vfx/battle_fury/BattleFury.tscn")

# Posição de referência — idêntica ao HTML (KNIGHT = {x:720, y:540})
const CARD_POS  := Vector2(720.0, 540.0)
const CARD_SIZE := Vector2(90.0, 126.0)

var _fx:         BattleFury = null
var _card_dummy: Node2D     = null   # nó que representa a carta para o VFX seguir
var _btn_on:     Button     = null
var _btn_off:    Button     = null
var _state_lbl:  Label      = null

func _ready() -> void:
	# ── Fundo escuro ──────────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = Color(0.039, 0.039, 0.071)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)

	# ── Grid de orientação (linhas de meio de tela) ───────────────────────────
	var hline := ColorRect.new()
	hline.color    = Color(0.73, 0.63, 0.35, 0.15)
	hline.size     = Vector2(1280.0, 1.0)
	hline.position = Vector2(0.0, 360.0)
	add_child(hline)
	var vline := ColorRect.new()
	vline.color    = Color(0.73, 0.63, 0.35, 0.15)
	vline.size     = Vector2(1.0, 720.0)
	vline.position = Vector2(640.0, 0.0)
	add_child(vline)

	# ── Carta dummy (outline) na posição de referência ────────────────────────
	_card_dummy = Node2D.new()
	_card_dummy.position = CARD_POS
	add_child(_card_dummy)

	var card_rect := ColorRect.new()
	card_rect.color    = Color(0.20, 0.35, 0.55, 0.35)
	card_rect.size     = CARD_SIZE
	card_rect.position = -CARD_SIZE * 0.5   # centrado no _card_dummy
	_card_dummy.add_child(card_rect)

	var card_border := ColorRect.new()
	card_border.color    = Color(0.55, 0.65, 0.85, 0.50)
	card_border.size     = Vector2(CARD_SIZE.x, 1.0)
	card_border.position = Vector2(-CARD_SIZE.x * 0.5, -CARD_SIZE.y * 0.5)
	_card_dummy.add_child(card_border)

	var lbl_card := Label.new()
	lbl_card.text = "POPPY"
	lbl_card.add_theme_font_size_override("font_size", 9)
	lbl_card.add_theme_color_override("font_color", Color(0.70, 0.85, 1.00, 0.70))
	lbl_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_card.custom_minimum_size  = Vector2(CARD_SIZE.x, 14.0)
	lbl_card.position = Vector2(-CARD_SIZE.x * 0.5, CARD_SIZE.y * 0.5 - 16.0)
	_card_dummy.add_child(lbl_card)

	# ── Label de contexto ─────────────────────────────────────────────────────
	var lbl_pos := Label.new()
	lbl_pos.text     = "CAVALEIRO  (720, 540)"
	lbl_pos.position = CARD_POS + Vector2(-45.0, CARD_SIZE.y * 0.5 + 12.0)
	lbl_pos.add_theme_font_size_override("font_size", 9)
	lbl_pos.add_theme_color_override("font_color", Color(0.80, 0.70, 0.45, 0.70))
	add_child(lbl_pos)

	# ── Controles ─────────────────────────────────────────────────────────────
	var panel := ColorRect.new()
	panel.color    = Color(0.06, 0.06, 0.10, 0.90)
	panel.size     = Vector2(340.0, 52.0)
	panel.position = Vector2(470.0, 650.0)
	add_child(panel)

	_btn_on = Button.new()
	_btn_on.text                = "▶  Ativar"
	_btn_on.position            = Vector2(480.0, 658.0)
	_btn_on.custom_minimum_size = Vector2(120.0, 36.0)
	add_child(_btn_on)
	_btn_on.pressed.connect(_on_activate_pressed)

	_btn_off = Button.new()
	_btn_off.text                = "■  Desativar"
	_btn_off.position            = Vector2(614.0, 658.0)
	_btn_off.custom_minimum_size = Vector2(130.0, 36.0)
	_btn_off.disabled            = true
	add_child(_btn_off)
	_btn_off.pressed.connect(_on_deactivate_pressed)

	_state_lbl = Label.new()
	_state_lbl.text     = "IDLE"
	_state_lbl.position = Vector2(758.0, 666.0)
	_state_lbl.add_theme_font_size_override("font_size", 10)
	_state_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	add_child(_state_lbl)

	# ── Ativa automaticamente ao abrir ───────────────────────────────────────
	_do_activate()

# ── Handlers dos botões ────────────────────────────────────────────────────────

func _on_activate_pressed() -> void:
	if _fx == null:
		_do_activate()

func _on_deactivate_pressed() -> void:
	if _fx != null and is_instance_valid(_fx):
		_fx.deactivate()

# ── Lógica de activate / deactivate ──────────────────────────────────────────

func _do_activate() -> void:
	_fx = BattleFuryScene.instantiate() as BattleFury
	# Poppy: +3 ATQ (atk_base=2 → atk_buffed=5 como exemplo visual)
	_fx.ability_name     = "IMPACTO SÍSMICO"
	_fx.ability_subtitle = "Habilidade Ativa"
	_fx.atk_base         = 2
	_fx.atk_buffed       = 5
	add_child(_fx)

	_fx.activate(_card_dummy, CARD_SIZE)

	_fx.activated.connect(func() -> void:
		_btn_on.disabled  = true
		_btn_off.disabled = false
		_state_lbl.text   = "ATIVA"
		_state_lbl.add_theme_color_override("font_color", Color(0.94, 0.60, 0.25))
	)
	_fx.deactivated.connect(func() -> void:
		_fx               = null
		_btn_on.disabled  = false
		_btn_off.disabled = true
		_state_lbl.text   = "IDLE"
		_state_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	)
	_fx.atk_value_changed.connect(func(v: int) -> void:
		_state_lbl.text = "ATQ → %d" % v
	)

	_btn_on.disabled  = true
	_btn_off.disabled = true
	_state_lbl.text   = "ATIVANDO…"
	_state_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.40))
