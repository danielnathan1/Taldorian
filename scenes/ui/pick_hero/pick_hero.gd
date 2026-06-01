# scenes/ui/pick_hero/pick_hero.gd
# Modal reutilizável para selecionar um herói de uma lista.
# Mostra aliados (face-up) e oponentes (face-down se não revelados).
# Emite hero_picked(hero) quando o jogador escolhe.
class_name PickHeroModal
extends Control

signal hero_picked(hero: Hero)

const HeroSlotScene := preload("res://scenes/ui/hero_slot/hero_slot.tscn")

var _title_label : Label
var _ally_row    : HBoxContainer
var _opp_row     : HBoxContainer

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
	panel.custom_minimum_size = Vector2(860, 480)
	_style_panel(panel)
	center.add_child(panel)

	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left",   28)
	margins.add_theme_constant_override("margin_right",  28)
	margins.add_theme_constant_override("margin_top",    22)
	margins.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margins)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margins.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	vbox.add_child(_title_label)

	vbox.add_child(HSeparator.new())

	# ── Seção: oponente ─────────────────────────────────────
	var opp_section := VBoxContainer.new()
	opp_section.add_theme_constant_override("separation", 8)
	vbox.add_child(opp_section)

	var opp_lbl := Label.new()
	opp_lbl.text = "── Heróis do Oponente ──"
	opp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opp_lbl.add_theme_font_size_override("font_size", 15)
	opp_lbl.add_theme_color_override("font_color", Color(0.90, 0.35, 0.35))
	opp_section.add_child(opp_lbl)

	_opp_row = HBoxContainer.new()
	_opp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_opp_row.add_theme_constant_override("separation", 12)
	opp_section.add_child(_opp_row)

	vbox.add_child(HSeparator.new())

	# ── Seção: aliados ──────────────────────────────────────
	var ally_section := VBoxContainer.new()
	ally_section.add_theme_constant_override("separation", 8)
	vbox.add_child(ally_section)

	var ally_lbl := Label.new()
	ally_lbl.text = "── Seus Heróis ──"
	ally_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ally_lbl.add_theme_font_size_override("font_size", 15)
	ally_lbl.add_theme_color_override("font_color", Color(0.35, 0.90, 0.50))
	ally_section.add_child(ally_lbl)

	_ally_row = HBoxContainer.new()
	_ally_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_ally_row.add_theme_constant_override("separation", 12)
	ally_section.add_child(_ally_row)

func _style_panel(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.14, 0.97)
	style.set_corner_radius_all(16)
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.42, 0.30, 0.72, 0.90)
	panel.add_theme_stylebox_override("panel", style)

## Abre o modal de seleção de herói.
## ally_heroes   — time do jogador local (sempre face-up).
## ally_sleeve   — textura do verso das cartas aliadas.
## opp_heroes    — time do oponente.
## opp_sleeve    — textura do verso das cartas do oponente.
## opp_revealed  — para cada herói do oponente: true = mostrar face-up; false = face-down.
## ally_active   — herói ativo do jogador local (null = nenhum).
## opp_active    — herói ativo do oponente (null = nenhum).
func open(
	title: String,
	ally_heroes: Array[Hero],
	ally_sleeve: Texture2D,
	opp_heroes: Array[Hero],
	opp_sleeve: Texture2D,
	opp_revealed: Array[bool],
	ally_active: Hero = null,
	opp_active: Hero = null
) -> void:
	_title_label.text = title

	for child in _ally_row.get_children():
		child.queue_free()
	for child in _opp_row.get_children():
		child.queue_free()

	for hero in ally_heroes:
		if not hero.is_alive():
			continue
		_spawn_slot(_ally_row, hero, false, ally_sleeve, false, hero == ally_active)

	for i in opp_heroes.size():
		var hero: Hero = opp_heroes[i]
		if not hero.is_alive():
			continue
		var revealed := opp_revealed[i] if i < opp_revealed.size() else false
		_spawn_slot(_opp_row, hero, true, opp_sleeve, not revealed, hero == opp_active)

	modulate.a = 0.0
	visible = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.22)

## Instancia e configura um slot dentro de `row`.
## O wrapper entra na árvore ANTES de bind() para garantir que @onready esteja pronto.
func _spawn_slot(row: HBoxContainer, hero: Hero, is_opp: bool, sleeve: Texture2D, face_down: bool, is_active: bool) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	row.add_child(vbox)  # entra na árvore aqui

	var slot := HeroSlotScene.instantiate() as HeroSlot
	slot.is_opponent = is_opp
	vbox.add_child(slot)  # _ready() do slot dispara, @onready inicializado
	slot.set_sleeve_texture(sleeve)
	slot.bind(hero)
	slot.set_face_down(face_down)
	slot.slot_clicked.connect(_on_hero_selected)

	var badge := Label.new()
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 13)
	if is_active:
		badge.text = "⚔ Ativo"
		badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.20))
	else:
		badge.text = "Retaguarda"
		badge.add_theme_color_override("font_color", Color(0.60, 0.60, 0.70))
	vbox.add_child(badge)

func _on_hero_selected(hero: Hero) -> void:
	visible = false
	hero_picked.emit(hero)
