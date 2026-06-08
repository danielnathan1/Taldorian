# scenes/ui/deck_list/deck_plate.gd
# Placa de um deck na DeckList. Estrutura em deck_plate.tscn; aqui só bind de dados,
# estilos (db_styles) e interação. Emite sinais para a DeckList tratar a navegação.
# Sleeve/playmat recebidos como { "name": String, "tex": Texture2D|null }.
extends Control

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")
const FONT_DECO  := preload("res://assets/fonts/CinzelDecorative-Bold.ttf")
const FONT_BLACK := preload("res://assets/fonts/CinzelDecorative-Black.ttf")

signal selected(deck_id: String)
signal edit_requested(deck_id: String)
signal delete_requested(deck_id: String)

var deck_id: String = ""
var _selected: bool = false
var _hover: bool = false

@onready var _panel: PanelContainer = %Panel
@onready var _playmat_bg: TextureRect = %PlaymatBg
@onready var _pm_pill_swatch: TextureRect = %PlaymatPillSwatch
@onready var _pm_pill_label: Label = %PlaymatPillLabel
@onready var _status_pill: PanelContainer = %StatusPill
@onready var _status_label: Label = %StatusLabel
@onready var _name_label: Label = %NameLabel
@onready var _hero_num: Label = %HeroNum
@onready var _card_num: Label = %CardNum
@onready var _meta_sleeve_swatch: TextureRect = %MetaSleeveSwatch
@onready var _meta_sleeve_value: Label = %MetaSleeveValue
@onready var _meta_playmat_swatch: TextureRect = %MetaPlaymatSwatch
@onready var _meta_playmat_value: Label = %MetaPlaymatValue
@onready var _ticks: Control = %Ticks
@onready var _quick: HBoxContainer = %Quick
@onready var _edit_btn: Button = %EditBtn
@onready var _delete_btn: Button = %DeleteBtn


func _ready() -> void:
	_ignore_subtree(_panel)
	_apply_static_styles()
	_ticks.draw.connect(_draw_ticks)
	_ticks.resized.connect(_ticks.queue_redraw)
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(func() -> void: _set_hover(true))
	mouse_exited.connect(func() -> void: _set_hover(false))
	_edit_btn.pressed.connect(func() -> void: edit_requested.emit(deck_id))
	_delete_btn.pressed.connect(func() -> void: delete_requested.emit(deck_id))


# ── Bind ────────────────────────────────────────────────────────────────────────

func bind(deck: DeckData, sleeve: Dictionary, playmat: Dictionary) -> void:
	deck_id = deck.deck_id

	# Nome
	var named := deck.deck_name.strip_edges() != "" and deck.deck_name != "Novo Deck"
	_name_label.text = deck.deck_name if named else "Deck sem nome"
	_name_label.add_theme_color_override("font_color",
		S.C_GOLD_GLOW if named else Color(S.C_PARCHMENT_D, 0.75))

	# Playmat (fundo + pill + meta)
	var pm_tex: Texture2D = playmat.get("tex", null)
	_playmat_bg.texture = pm_tex
	_pm_pill_swatch.texture = pm_tex
	_pm_pill_label.text = str(playmat.get("name", "")).to_upper()
	_meta_playmat_swatch.texture = pm_tex
	_meta_playmat_value.text = str(playmat.get("name", ""))

	# Sleeve (3 cartas em leque + meta)
	var sl_tex: Texture2D = sleeve.get("tex", null)
	for card in [%SleeveCard0, %SleeveCard1, %SleeveCard2]:
		var img := (card as Panel).get_node("Img") as TextureRect
		var crest := (card as Panel).get_node("Crest") as Label
		img.texture = sl_tex
		img.visible = sl_tex != null
		crest.visible = sl_tex == null
	_meta_sleeve_swatch.texture = sl_tex
	_meta_sleeve_value.text = str(sleeve.get("name", ""))

	# Status
	var is_ready := _is_complete(deck)
	_status_label.text = "✦ PRONTO" if is_ready else "RASCUNHO"
	_status_label.add_theme_color_override("font_color",
		S.C_GREEN if is_ready else Color(0.82, 0.66, 0.30))
	_status_pill.add_theme_stylebox_override("panel", _status_style(is_ready))

	# Heróis
	var chips := [%Chip0, %Chip1, %Chip2]
	var portraits := [%Portrait0, %Portrait1, %Portrait2]
	var initials := [%Initial0, %Initial1, %Initial2]
	for i in 3:
		var hname: String = deck.hero_names[i] if i < deck.hero_names.size() else ""
		_bind_chip(chips[i], portraits[i], initials[i], hname)

	# Contagens
	var hfull := deck.hero_names.size() == DeckData.MAX_HEROES
	var cfull := deck.total_cards() == DeckData.MAX_CARDS
	_hero_num.text = "%d/%d" % [deck.hero_names.size(), DeckData.MAX_HEROES]
	_hero_num.add_theme_color_override("font_color", S.C_GREEN if hfull else S.C_PARCHMENT)
	_card_num.text = "%d/%d" % [deck.total_cards(), DeckData.MAX_CARDS]
	_card_num.add_theme_color_override("font_color", S.C_GREEN if cfull else S.C_PARCHMENT)

	_apply_panel_style()


func _bind_chip(chip: Panel, portrait: TextureRect, initial: Label, hero_name: String) -> void:
	var s := StyleBoxFlat.new()
	s.set_border_width_all(1)
	if hero_name == "":
		s.bg_color = Color(0.10, 0.09, 0.14, 0.5)
		s.border_color = S.border_gold(0.18)
		chip.add_theme_stylebox_override("panel", s)
		portrait.visible = false
		initial.text = "+"
		initial.add_theme_color_override("font_color", Color(S.C_GOLD_DIM, 0.5))
		initial.visible = true
		return

	var hero: Hero = Collection.get_hero_by_name(hero_name)
	var cls: String = Hero.HeroClass.keys()[hero.hero_class] if hero != null else ""
	s.bg_color = DeckListData.class_color(cls)
	s.border_color = S.border_gold(0.30)
	chip.add_theme_stylebox_override("panel", s)
	chip.tooltip_text = "%s · %s" % [hero_name, cls.capitalize()] if hero != null else hero_name

	var art := "res://assets/heros/%s.png" % (hero.art_key if hero != null else "")
	if hero != null and ResourceLoader.exists(art):
		portrait.texture = load(art)
		portrait.visible = true
		initial.visible = false
	else:
		portrait.visible = false
		initial.text = hero_name.substr(0, 1).to_upper()
		initial.add_theme_font_override("font", FONT_DECO)
		initial.add_theme_font_size_override("font_size", 15)
		initial.add_theme_color_override("font_color", S.C_PARCHMENT)
		initial.visible = true


# ── Seleção / hover ───────────────────────────────────────────────────────────

func set_selected(value: bool) -> void:
	_selected = value
	_ticks.visible = value
	_apply_panel_style()
	_update_quick()


func _set_hover(value: bool) -> void:
	_hover = value
	_apply_panel_style()
	_update_quick()


func _update_quick() -> void:
	_quick.visible = _selected or _hover


func _on_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.double_click:
			edit_requested.emit(deck_id)
		else:
			selected.emit(deck_id)


# ── Estilos ───────────────────────────────────────────────────────────────────

func _apply_static_styles() -> void:
	_pm_pill_label.add_theme_font_override("font", S.FONT_REG)
	_pm_pill_label.add_theme_font_size_override("font_size", 9)
	_pm_pill_label.add_theme_color_override("font_color", S.C_PARCHMENT)
	var pm_style := StyleBoxFlat.new()
	pm_style.bg_color = Color(0.04, 0.03, 0.08, 0.62)
	pm_style.border_color = Color(1, 1, 1, 0.12)
	pm_style.set_border_width_all(1)
	pm_style.set_content_margin(SIDE_LEFT, 6)
	pm_style.set_content_margin(SIDE_RIGHT, 9)
	pm_style.set_content_margin(SIDE_TOP, 4)
	pm_style.set_content_margin(SIDE_BOTTOM, 4)
	%PlaymatPill.add_theme_stylebox_override("panel", pm_style)

	_status_label.add_theme_font_override("font", S.FONT_REG)
	_status_label.add_theme_font_size_override("font_size", 9)

	_name_label.add_theme_font_override("font", FONT_DECO)
	_name_label.add_theme_font_size_override("font_size", 18)

	# Cartas do leque: borda dourada + fundo escuro (visível atrás da arte / fallback).
	for card in [%SleeveCard0, %SleeveCard1, %SleeveCard2]:
		(card as Panel).add_theme_stylebox_override("panel", _card_style())
		var crest := (card as Panel).get_node("Crest") as Label
		crest.add_theme_font_override("font", FONT_BLACK)
		crest.add_theme_font_size_override("font_size", 30)
		crest.add_theme_color_override("font_color", Color(S.C_GOLD.r, S.C_GOLD.g, S.C_GOLD.b, 0.55))

	_hero_num.add_theme_font_override("font", S.FONT_BOLD)
	_hero_num.add_theme_font_size_override("font_size", 15)
	_card_num.add_theme_font_override("font", S.FONT_BOLD)
	_card_num.add_theme_font_size_override("font_size", 15)

	for path in ["Panel/VBox/Body/VBox/Counts/HeroCount/Lbl", "Panel/VBox/Body/VBox/Counts/CardCount/Lbl"]:
		_style_label(get_node(path), S.FONT_REG, 9, Color(S.C_PARCHMENT_D, 0.6))
	for path in ["Panel/VBox/Meta/VBox/SleeveRow/Key", "Panel/VBox/Meta/VBox/PlaymatRow/Key"]:
		_style_label(get_node(path), S.FONT_REG, 9, Color(S.C_GOLD_DIM, 0.8))
	_style_label(_meta_sleeve_value, S.FONT_REG, 11, S.C_PARCHMENT_D)
	_style_label(_meta_playmat_value, S.FONT_REG, 11, S.C_PARCHMENT_D)

	var meta_style := StyleBoxFlat.new()
	meta_style.bg_color = Color(0.06, 0.05, 0.10, 0.5)
	meta_style.border_color = S.border_gold(0.18)
	meta_style.border_width_top = 1
	meta_style.set_content_margin(SIDE_LEFT, 18)
	meta_style.set_content_margin(SIDE_RIGHT, 18)
	meta_style.set_content_margin(SIDE_TOP, 10)
	meta_style.set_content_margin(SIDE_BOTTOM, 12)
	%Meta.add_theme_stylebox_override("panel", meta_style)

	_style_quick_btn(_edit_btn, Color(0.16, 0.12, 0.04, 0.92), S.C_GOLD_GLOW)
	_style_quick_btn(_delete_btn, Color(0.14, 0.05, 0.05, 0.92), Color(0.85, 0.45, 0.40))


func _apply_panel_style() -> void:
	var s := StyleBoxFlat.new()
	s.set_border_width_all(1)
	if _selected:
		s.bg_color = S.C_BG_SURFACE
		s.border_color = S.C_GOLD
	elif _hover:
		s.bg_color = S.C_BG_MID
		s.border_color = S.border_gold(0.45)
	else:
		s.bg_color = S.C_BG_MID
		s.border_color = S.border_gold(0.18)
	_panel.add_theme_stylebox_override("panel", s)


func _draw_ticks() -> void:
	var c := S.C_GOLD
	var l := 14.0
	var w := 2.0
	var sz := _ticks.size
	_ticks.draw_rect(Rect2(0, 0, l, w), c)
	_ticks.draw_rect(Rect2(0, 0, w, l), c)
	_ticks.draw_rect(Rect2(sz.x - l, 0, l, w), c)
	_ticks.draw_rect(Rect2(sz.x - w, 0, w, l), c)
	_ticks.draw_rect(Rect2(0, sz.y - w, l, w), c)
	_ticks.draw_rect(Rect2(0, sz.y - l, w, l), c)
	_ticks.draw_rect(Rect2(sz.x - l, sz.y - w, l, w), c)
	_ticks.draw_rect(Rect2(sz.x - w, sz.y - l, w, l), c)


# ── Helpers ─────────────────────────────────────────────────────────────────────

func _card_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.09, 0.13)
	s.border_color = Color(S.C_GOLD.r, S.C_GOLD.g, S.C_GOLD.b, 0.45)
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	return s


func _status_style(ready: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.set_border_width_all(1)
	s.set_content_margin(SIDE_LEFT, 9)
	s.set_content_margin(SIDE_RIGHT, 9)
	s.set_content_margin(SIDE_TOP, 4)
	s.set_content_margin(SIDE_BOTTOM, 4)
	if ready:
		s.bg_color = Color(0.10, 0.20, 0.13, 0.6)
		s.border_color = Color(S.C_GREEN.r, S.C_GREEN.g, S.C_GREEN.b, 0.5)
	else:
		s.bg_color = Color(0.16, 0.12, 0.04, 0.6)
		s.border_color = Color(0.6, 0.45, 0.15, 0.45)
	return s


func _style_quick_btn(btn: Button, bg: Color, fg: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", s)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_stylebox_override("focus", s)
	btn.add_theme_font_override("font", S.FONT_REG)
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))


func _style_label(node: Node, font: Font, size: int, color: Color) -> void:
	var l := node as Label
	if l == null:
		return
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)


func _ignore_subtree(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_subtree(c)


func _is_complete(deck: DeckData) -> bool:
	return deck.hero_names.size() == DeckData.MAX_HEROES and deck.total_cards() == DeckData.MAX_CARDS
