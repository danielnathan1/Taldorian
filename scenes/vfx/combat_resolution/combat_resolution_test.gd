## scenes/vfx/combat_resolution/combat_resolution_test.gd
## Cena de QA isolada para a Resolução de Combate.
## Botões escolhem o arquétipo (Lâmina / Machado / Magia) e o dano de cada golpe,
## espelhando os controles do "Combat Resolution.html". Botão "Tocar" reinicia.
extends Control

const CombatResolutionScene := preload("res://scenes/vfx/combat_resolution/CombatResolution.tscn")

const _LABELS := ["Lâmina", "Machado", "Magia"]

var _atk1: int = CombatResolution.AtkType.LAMINA
var _atk2: int = CombatResolution.AtkType.MACHADO
var _dmg1: int = 6
var _dmg2: int = 4

var _dmg1_lbl: Label = null
var _dmg2_lbl: Label = null
var _seg1: Array[Button] = []
var _seg2: Array[Button] = []


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.039, 0.039, 0.071)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -1
	add_child(bg)

	var row := HBoxContainer.new()
	row.position = Vector2(20.0, 1000.0)
	row.add_theme_constant_override("separation", 10)
	add_child(row)

	var btn_play := Button.new()
	btn_play.text = "▶  Tocar"
	btn_play.custom_minimum_size = Vector2(120.0, 36.0)
	btn_play.pressed.connect(_play)
	row.add_child(btn_play)

	row.add_child(_make_tag("ALIADO", Color(0.45, 0.7, 0.85)))
	_seg1 = _make_segment(true)
	for b in _seg1: row.add_child(b)
	_dmg1_lbl = _make_dmg_stepper(true, row)

	row.add_child(_make_tag("INIMIGO", Color(0.85, 0.45, 0.4)))
	_seg2 = _make_segment(false)
	for b in _seg2: row.add_child(b)
	_dmg2_lbl = _make_dmg_stepper(false, row)

	_refresh_segments()
	_play()


func _make_tag(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", 12)
	return l


func _make_segment(is_ally: bool) -> Array[Button]:
	var out: Array[Button] = []
	for t in 3:
		var b := Button.new()
		b.text = _LABELS[t]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(76.0, 30.0)
		b.pressed.connect(_on_pick_type.bind(is_ally, t))
		out.append(b)
	return out


func _make_dmg_stepper(is_ally: bool, parent: HBoxContainer) -> Label:
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(28.0, 28.0)
	minus.pressed.connect(_on_step_dmg.bind(is_ally, -1))
	parent.add_child(minus)
	var lbl := Label.new()
	lbl.text = "dano %d" % (_dmg1 if is_ally else _dmg2)
	lbl.custom_minimum_size = Vector2(64.0, 28.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(lbl)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(28.0, 28.0)
	plus.pressed.connect(_on_step_dmg.bind(is_ally, 1))
	parent.add_child(plus)
	return lbl


func _on_pick_type(is_ally: bool, t: int) -> void:
	if is_ally: _atk1 = t
	else: _atk2 = t
	_refresh_segments()


func _on_step_dmg(is_ally: bool, delta: int) -> void:
	if is_ally:
		_dmg1 = clampi(_dmg1 + delta, 1, 20)
		_dmg1_lbl.text = "dano %d" % _dmg1
	else:
		_dmg2 = clampi(_dmg2 + delta, 1, 20)
		_dmg2_lbl.text = "dano %d" % _dmg2


func _refresh_segments() -> void:
	for i in _seg1.size():
		_seg1[i].button_pressed = (i == _atk1)
	for i in _seg2.size():
		_seg2[i].button_pressed = (i == _atk2)


func _play() -> void:
	# Heróis reais para o HeroSlot exibir (Poppy x Hakai), com HP cheio.
	var ally: Hero = HeroPoppy.new()
	var enemy: Hero = HeroHakai.new()
	ally.current_hp = ally.max_hp
	enemy.current_hp = enemy.max_hp

	var cfg := CombatResolution.Config.new()
	cfg.ally_hero  = ally
	cfg.enemy_hero = enemy
	cfg.atk1_type = _atk1   # override manual (controles da cena de teste)
	cfg.atk2_type = _atk2
	cfg.dmg1 = _dmg1
	cfg.dmg2 = _dmg2

	var fx: CombatResolution = CombatResolutionScene.instantiate()
	add_child(fx)
	fx.play(cfg)
