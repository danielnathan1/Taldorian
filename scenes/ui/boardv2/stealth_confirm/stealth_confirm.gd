# scenes/ui/boardv2/stealth_confirm/stealth_confirm.gd
# Popup reutilizável de confirmação para ativar uma habilidade que revela um herói furtivo.
# Exibido sempre que o jogador for ativar a habilidade de um herói que ainda está oculto:
# ativá-la quebra a furtividade. Pergunta se deseja prosseguir.
# Se confirmar: emite confirmed. Se recusar: emite cancelled.
extends Control

signal confirmed
signal cancelled

var _hero_art       : TextureRect
var _hero_name_lbl  : Label
var _skill_name_lbl : Label
var _skill_desc_lbl : Label
var _question_lbl   : Label

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 540)
	_style_panel(panel)
	center.add_child(panel)

	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left",   30)
	margins.add_theme_constant_override("margin_right",  30)
	margins.add_theme_constant_override("margin_top",    26)
	margins.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(margins)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margins.add_child(vbox)

	# Cabeçalho
	var header := Label.new()
	header.text = "✦ Quebrar Furtividade ✦"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 19)
	header.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	vbox.add_child(header)

	vbox.add_child(HSeparator.new())

	# Arte do herói — wrapper de tamanho fixo evita que o TextureRect expanda
	var art_wrap := Control.new()
	art_wrap.custom_minimum_size    = Vector2(160, 180)
	art_wrap.size_flags_horizontal  = Control.SIZE_SHRINK_CENTER
	art_wrap.size_flags_vertical    = Control.SIZE_SHRINK_CENTER
	vbox.add_child(art_wrap)

	_hero_art = TextureRect.new()
	_hero_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hero_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero_art.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	art_wrap.add_child(_hero_art)

	# Nome
	_hero_name_lbl = Label.new()
	_hero_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_name_lbl.add_theme_font_size_override("font_size", 22)
	_hero_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.80))
	vbox.add_child(_hero_name_lbl)

	# Nome da habilidade
	_skill_name_lbl = Label.new()
	_skill_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_name_lbl.add_theme_font_size_override("font_size", 15)
	_skill_name_lbl.add_theme_color_override("font_color", Color(0.55, 0.82, 1.0))
	vbox.add_child(_skill_name_lbl)

	# Descrição da habilidade
	_skill_desc_lbl = Label.new()
	_skill_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_skill_desc_lbl.add_theme_font_size_override("font_size", 14)
	_skill_desc_lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
	vbox.add_child(_skill_desc_lbl)

	vbox.add_child(HSeparator.new())

	# Aviso de furtividade + pergunta
	_question_lbl = Label.new()
	_question_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_question_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_question_lbl.add_theme_font_size_override("font_size", 16)
	_question_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.70))
	vbox.add_child(_question_lbl)

	# Botões
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	vbox.add_child(btn_row)

	var btn_no := Button.new()
	btn_no.text = "Não"
	btn_no.custom_minimum_size = Vector2(130, 46)
	_style_btn(btn_no, Color(0.50, 0.10, 0.10), Color(0.75, 0.18, 0.18))
	btn_no.pressed.connect(_on_cancel)
	btn_row.add_child(btn_no)

	var btn_yes := Button.new()
	btn_yes.text = "Sim, ativar"
	btn_yes.custom_minimum_size = Vector2(150, 46)
	_style_btn(btn_yes, Color(0.08, 0.42, 0.18), Color(0.12, 0.62, 0.28))
	btn_yes.pressed.connect(_on_confirm)
	btn_row.add_child(btn_yes)

func _style_panel(panel: PanelContainer) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.06, 0.14, 0.97)
	s.set_corner_radius_all(16)
	s.border_width_left   = 2
	s.border_width_right  = 2
	s.border_width_top    = 2
	s.border_width_bottom = 2
	s.border_color = Color(0.50, 0.34, 0.86, 0.90)
	panel.add_theme_stylebox_override("panel", s)

func _style_btn(btn: Button, normal_col: Color, hover_col: Color) -> void:
	var sn := StyleBoxFlat.new()
	sn.bg_color = normal_col
	sn.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", sn)
	var sh := StyleBoxFlat.new()
	sh.bg_color = hover_col
	sh.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_font_size_override("font_size", 18)

## Configura e exibe o popup para o herói furtivo dado.
## p_ability_name / p_ability_desc descrevem a habilidade que será ativada.
func setup(p_hero: Hero, p_ability_name: String, p_ability_desc: String) -> void:
	_hero_art.texture    = p_hero.get_texture()
	_hero_name_lbl.text  = p_hero.hero_name
	_skill_name_lbl.text = "⚡ " + p_ability_name
	_skill_desc_lbl.text = p_ability_desc
	_question_lbl.text   = "%s está furtivo. Ao ativar a habilidade ele será revelado e não ficará mais furtivo.\n\nDeseja ativá-la?" % p_hero.hero_name

	modulate.a = 0.0
	visible    = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.20)

func _on_confirm() -> void:
	_fade_out(func() -> void: confirmed.emit())

func _on_cancel() -> void:
	_fade_out(func() -> void: cancelled.emit())

func _fade_out(on_done: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func() -> void:
		visible = false
		on_done.call()
	)
