# scenes/ui/character_creator/character_creator.gd
# Lógica da tela de criação de personagem.
# A estrutura visual está em character_creator.tscn.
extends Control

const LOBBY_SCENE := "res://scenes/ui/lobby/lobby.tscn"

# ── Fontes ────────────────────────────────────────────────────────────────────
const _FONT_BOLD := preload("res://assets/fonts/CinzelDecorative-Bold.ttf")
const _FONT_REG  := preload("res://assets/fonts/CinzelDecorative-Regular.ttf")

# ── Cores ─────────────────────────────────────────────────────────────────────
const C_GOLD        := Color(0.902, 0.722, 0.392)
const C_GOLD_DIM    := Color(0.627, 0.490, 0.227)
const C_GOLD_GLOW   := Color(1.000, 0.843, 0.463)
const C_CRIMSON     := Color(0.635, 0.227, 0.173)
const C_CRIMSON_BR  := Color(0.827, 0.353, 0.247)
const C_PARCHMENT   := Color(0.941, 0.918, 0.839)
const C_PARCHMENT_D := Color(0.706, 0.659, 0.541)
const C_BG          := Color(0.102, 0.082, 0.051)
const C_LINE        := Color(0.902, 0.722, 0.392, 0.18)

# Frame index do walk.png usado no preview (vframes=4, hframes=9 → row 2 × 9 + 0 = 18)
const PREVIEW_FRAME := 18

# ── Dados ─────────────────────────────────────────────────────────────────────
const RACES := [
	{ "id": "human", "label": "Humano",
	  "skins": {
		  "male": [
			  { "id": "white",  "label": "Clara",   "path": "res://assets/character/body/human/male/white/walk.png" },
			  { "id": "brown",  "label": "Morena",  "path": "res://assets/character/body/human/male/brown/walk.png" },
			  { "id": "olive",  "label": "Oliva",   "path": "res://assets/character/body/human/male/olivie/walk.png" },
			  { "id": "black",  "label": "Escura",  "path": "res://assets/character/body/human/male/black/walk.png" },
		  ],
		  "female": [
			  { "id": "white",  "label": "Clara",   "path": "res://assets/character/body/human/female/white/walk.png" },
			  { "id": "brown",  "label": "Morena",  "path": "res://assets/character/body/human/female/brown/walk.png" },
			  { "id": "olive",  "label": "Oliva",   "path": "res://assets/character/body/human/female/olive/walk.png" },
			  { "id": "black",  "label": "Escura",  "path": "res://assets/character/body/human/female/black/walk.png" },
		  ],
	  }
	},
	{ "id": "orc", "label": "Orc",
	  "skins": {
		  "male": [
			  { "id": "green",  "label": "Verde",   "path": "res://assets/character/body/orc/orc_male/green/walk.png" },
			  { "id": "brown",  "label": "Marrom",  "path": "res://assets/character/body/orc/orc_male/brown/walk.png" },
		  ],
		  "female": [
			  { "id": "green",  "label": "Verde",   "path": "res://assets/character/body/orc/orc_female/green/walk.png" },
			  { "id": "brown",  "label": "Marrom",  "path": "res://assets/character/body/orc/orc_female/brown/walk.png" },
			  { "id": "black",  "label": "Escura",  "path": "res://assets/character/body/orc/orc_female/black/walk.png" },
		  ],
	  }
	},
]

const CATEGORIES := [
	{ "id": "body",  "label": "Pele",    "group": "Aparência" },
	{ "id": "hair",  "label": "Cabelo",  "group": "Aparência" },
	{ "id": "chest", "label": "Blusa",   "group": "Vestuário" },
	{ "id": "legs",  "label": "Calça",   "group": "Vestuário" },
	{ "id": "shoes", "label": "Sapatos", "group": "Vestuário" },
]

const STYLES := {
	"hair": [
		{ "id": "spiked_1",     "label": "Espetado",      "path": "res://assets/character/hair/spiked_1/walk.png" },
		{ "id": "spiked_2",     "label": "Espetado 2",    "path": "res://assets/character/hair/spiked_2/walk.png" },
		{ "id": "afro",         "label": "Afro",          "path": "res://assets/character/hair/afro/walk.png" },
		{ "id": "carecabeludo", "label": "Careca",        "path": "res://assets/character/hair/carecabeludo/walk.png" },
		{ "id": "dread",        "label": "Dreads",        "path": "res://assets/character/hair/dread/walk.png" },
		{ "id": "half_up",      "label": "Meio Preso",    "path": "res://assets/character/hair/half_up/walk.png" },
		{ "id": "long_1",       "label": "Cabelo Longo",  "path": "res://assets/character/hair/long_1/walk.png" },
	],
	"chest": [
		{ "id": "basic_tshirt", "label": "Camiseta",
		  "paths": { "male":   "res://assets/character/chest/male/basic_tshirt/walk.png",
					 "female": "res://assets/character/chest/female/basic_tshirt/walk.png" } },
	],
	"legs": [
		{ "id": "basic_pants", "label": "Calça Básica",
		  "paths": { "male":   "res://assets/character/pants/male/basic_pants/walk.png",
					 "female": "res://assets/character/pants/female/basic_pants/walk.png" } },
	],
	"shoes": [
		{ "id": "basic_shoes", "label": "Sapatos Básicos",
		  "paths": { "male":   "res://assets/character/shoes/male/basic_shoes/walk.png",
					 "female": "res://assets/character/shoes/female/basic_shoes/walk.png" } },
	],
}

# Cores usadas no aleatório
const RANDOM_COLORS := [
	Color(0.08, 0.04, 0.02), Color(0.35, 0.18, 0.08), Color(0.62, 0.28, 0.08),
	Color(0.88, 0.68, 0.20), Color(0.92, 0.90, 0.85), Color(0.58, 0.58, 0.58),
	Color(0.85, 0.10, 0.10), Color(0.15, 0.70, 0.25), Color(0.15, 0.35, 0.90),
	Color(0.70, 0.10, 0.80), Color(0.95, 0.65, 0.65), Color(0.65, 0.80, 0.95),
]

const RANDOM_NAMES := [
	"Aelwyn", "Brimstone", "Calyx", "Drakir", "Eowyn",
	"Faelin", "Gareth", "Hekla", "Ilyra", "Joren",
	"Kalix", "Lyren", "Mireth", "Nalos", "Orvyn",
]

# ── Estado ────────────────────────────────────────────────────────────────────
var _state := {
	"name":  "",
	"race":  "human",
	"sex":   "male",
	"body":  { "style": "white" },          # skin ID — sem cor, sprite separada por tom
	"hair":  { "style": "", "color": Color(0.08, 0.04, 0.02) },
	"chest": { "style": "basic_tshirt", "color": Color(0.70, 0.70, 0.80) },
	"legs":  { "style": "basic_pants",  "color": Color(0.25, 0.30, 0.50) },
	"shoes": { "style": "basic_shoes",  "color": Color(0.40, 0.25, 0.15) },
}
var _active_cat  := "hair"
var _race_btns   := {}
var _sex_btns    := {}
var _cat_btns    := {}
var _color_picker: ColorPickerButton

# ── @onready — nós do .tscn ───────────────────────────────────────────────────
@onready var _bg            : ColorRect      = $Background
@onready var _header        : PanelContainer = $RootLayout/Header
@onready var _eyebrow       : Label          = $RootLayout/Header/HeaderBox/HeaderCenter/Eyebrow
@onready var _title_lbl     : Label          = $RootLayout/Header/HeaderBox/HeaderCenter/Title
@onready var _back_btn      : Button         = %BackBtn
@onready var _random_top    : Button         = %RandomTopBtn
@onready var _left_panel    : PanelContainer = $RootLayout/BodyRow/LeftPanel
@onready var _name_label    : Label          = $RootLayout/BodyRow/LeftPanel/LeftInner/NameSection/NameLabel
@onready var _name_input_row: PanelContainer = $RootLayout/BodyRow/LeftPanel/LeftInner/NameSection/NameInputRow
@onready var _name_input    : LineEdit       = %NameInput
@onready var _dice_btn      : Button         = %DiceBtn
@onready var _race_label    : Label          = $RootLayout/BodyRow/LeftPanel/LeftInner/RaceSection/RaceLabel
@onready var _race_row      : HBoxContainer  = %RaceRow
@onready var _sex_label     : Label          = $RootLayout/BodyRow/LeftPanel/LeftInner/SexSection/SexLabel
@onready var _sex_row       : HBoxContainer  = %SexRow
@onready var _category_nav  : VBoxContainer  = %CategoryNav
@onready var _preview_frame : PanelContainer = $RootLayout/BodyRow/CenterMargin/CenterInner/PreviewFrame
@onready var _body_sprite   : Sprite2D = $RootLayout/BodyRow/CenterMargin/CenterInner/PreviewFrame/Skeleton/Body/Sprite2D
@onready var _chest_sprite  : Sprite2D = $RootLayout/BodyRow/CenterMargin/CenterInner/PreviewFrame/Skeleton/Chest/Sprite2D
@onready var _pants_sprite  : Sprite2D = $RootLayout/BodyRow/CenterMargin/CenterInner/PreviewFrame/Skeleton/Pants/Sprite2D
@onready var _shoes_sprite  : Sprite2D = $RootLayout/BodyRow/CenterMargin/CenterInner/PreviewFrame/Skeleton/Shoes/Sprite2D
@onready var _hair_sprite   : Sprite2D = $RootLayout/BodyRow/CenterMargin/CenterInner/PreviewFrame/Skeleton/Hair/Sprite2D
@onready var _preview_name  : Label          = %PreviewName
@onready var _preview_race  : Label          = %PreviewRace
@onready var _right_panel   : PanelContainer = $RootLayout/BodyRow/RightPanel
@onready var _panel_title   : Label          = %PanelTitle
@onready var _panel_count   : Label          = %PanelCount
@onready var _panel_sep     : HSeparator     = $RootLayout/BodyRow/RightPanel/RightInner/PanelSep
@onready var _style_label   : Label          = $RootLayout/BodyRow/RightPanel/RightInner/StyleLabel
@onready var _style_grid    : GridContainer  = %StyleGrid
@onready var _color_label   : Label          = $RootLayout/BodyRow/RightPanel/RightInner/ColorLabel
@onready var _palette_row   : HBoxContainer  = %PaletteRow
@onready var _swatch_grid   : GridContainer  = %SwatchGrid
@onready var _footer        : PanelContainer = $RootLayout/Footer
@onready var _status_name   : Label          = %StatusName
@onready var _status_sep    : Label          = $RootLayout/Footer/FooterBox/FooterStatus/StatusSep
@onready var _status_race   : Label          = %StatusRace
@onready var _status_dim    : Label          = %StatusDim
@onready var _random_btn    : Button         = %RandomBtn
@onready var _confirm_btn   : Button         = %ConfirmBtn

# ═══════════════════════════════════════════════════════════════════════════════
# READY
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_state.name             = RANDOM_NAMES.pick_random()
	_state["hair"]["style"] = STYLES.hair[0].id
	_reset_body_skin()  # inicializa skin correto para raça/sexo padrão
	_apply_styles()
	_setup_dynamic_content()
	_wire_signals()
	_name_input.text = _state.name
	_refresh_all_layers()
	_update_info_labels()
	_show_category("hair")
	_animate_entrance()

# ═══════════════════════════════════════════════════════════════════════════════
# ESTILOS — aplica cores, fontes e StyleBox nos nós do .tscn
# ═══════════════════════════════════════════════════════════════════════════════

func _apply_styles() -> void:
	_bg.color = C_BG

	# ── Header ──
	var h_style := _flat_style(Color(C_BG, 0.95), C_LINE)
	h_style.border_width_top   = 0
	h_style.border_width_left  = 0
	h_style.border_width_right = 0
	h_style.border_width_bottom = 1
	h_style.set_content_margin(SIDE_LEFT, 32);  h_style.set_content_margin(SIDE_RIGHT,  32)
	h_style.set_content_margin(SIDE_TOP,  12);  h_style.set_content_margin(SIDE_BOTTOM, 12)
	_header.add_theme_stylebox_override("panel", h_style)

	_eyebrow.add_theme_font_override("font", _FONT_BOLD)
	_eyebrow.add_theme_font_size_override("font_size", 10)
	_eyebrow.add_theme_color_override("font_color", Color(C_GOLD_DIM, 0.75))
	_title_lbl.add_theme_font_override("font", _FONT_BOLD)
	_title_lbl.add_theme_font_size_override("font_size", 22)
	_title_lbl.add_theme_color_override("font_color", C_GOLD)

	_apply_ghost_style(_back_btn)
	_apply_ghost_style(_random_top)

	# ── Coluna Esquerda ──
	var l_style := _flat_style(Color(0.063, 0.051, 0.035, 0.40), C_LINE)
	l_style.border_width_top    = 0
	l_style.border_width_left   = 0
	l_style.border_width_bottom = 0
	l_style.border_width_right  = 1
	l_style.set_content_margin_all(20)
	_left_panel.add_theme_stylebox_override("panel", l_style)

	for lbl in [_name_label, _race_label, _sex_label]:
		lbl.add_theme_font_override("font", _FONT_BOLD)
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", C_GOLD_DIM)

	var inp_style := _flat_style(Color(0.102, 0.078, 0.051, 0.70), Color(C_GOLD, 0.30))
	_name_input_row.add_theme_stylebox_override("panel", inp_style)

	_name_input.add_theme_font_override("font", _FONT_BOLD)
	_name_input.add_theme_font_size_override("font_size", 13)
	_name_input.add_theme_color_override("font_color", C_PARCHMENT)
	_name_input.add_theme_color_override("font_placeholder_color", Color(C_PARCHMENT_D, 0.40))
	_name_input.add_theme_color_override("caret_color", C_GOLD)
	_name_input.add_theme_stylebox_override("normal",    StyleBoxEmpty.new())
	_name_input.add_theme_stylebox_override("focus",     StyleBoxEmpty.new())
	_name_input.add_theme_stylebox_override("read_only", StyleBoxEmpty.new())

	_dice_btn.add_theme_font_size_override("font_size", 18)
	_dice_btn.add_theme_color_override("font_color",       C_GOLD_DIM)
	_dice_btn.add_theme_color_override("font_hover_color", C_GOLD_GLOW)
	_dice_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_dice_btn.add_theme_stylebox_override("hover",  StyleBoxEmpty.new())

	# ── Centro ──
	var pf_style := _flat_style(Color(0.102, 0.078, 0.059, 0.70), C_LINE)
	_preview_frame.add_theme_stylebox_override("panel", pf_style)

	_preview_name.add_theme_font_override("font", _FONT_BOLD)
	_preview_name.add_theme_font_size_override("font_size", 22)
	_preview_name.add_theme_color_override("font_color", C_PARCHMENT)

	_preview_race.add_theme_font_override("font", _FONT_BOLD)
	_preview_race.add_theme_font_size_override("font_size", 10)
	_preview_race.add_theme_color_override("font_color", C_GOLD_DIM)

	# ── Coluna Direita ──
	var r_style := _flat_style(Color(0.063, 0.051, 0.035, 0.40), C_LINE)
	r_style.border_width_top    = 0
	r_style.border_width_right  = 0
	r_style.border_width_bottom = 0
	r_style.border_width_left   = 1
	r_style.set_content_margin_all(20)
	_right_panel.add_theme_stylebox_override("panel", r_style)

	_panel_title.add_theme_font_override("font", _FONT_BOLD)
	_panel_title.add_theme_font_size_override("font_size", 15)
	_panel_title.add_theme_color_override("font_color", C_PARCHMENT)

	_panel_count.add_theme_font_override("font", _FONT_BOLD)
	_panel_count.add_theme_font_size_override("font_size", 9)
	_panel_count.add_theme_color_override("font_color", Color(C_GOLD_DIM, 0.70))

	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = C_LINE
	_panel_sep.add_theme_stylebox_override("separator", sep_style)

	for lbl in [_style_label, _color_label]:
		lbl.add_theme_font_override("font", _FONT_BOLD)
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", C_GOLD_DIM)

	# ── Footer ──
	var f_style := _flat_style(Color(0, 0, 0, 0.40), C_LINE)
	f_style.border_width_top    = 1
	f_style.border_width_bottom = 0
	f_style.border_width_left   = 0
	f_style.border_width_right  = 0
	f_style.set_content_margin(SIDE_LEFT, 32);  f_style.set_content_margin(SIDE_RIGHT,  32)
	f_style.set_content_margin(SIDE_TOP,  14);  f_style.set_content_margin(SIDE_BOTTOM, 14)
	_footer.add_theme_stylebox_override("panel", f_style)

	_status_name.add_theme_font_override("font", _FONT_BOLD)
	_status_name.add_theme_font_size_override("font_size", 15)
	_status_name.add_theme_color_override("font_color", C_GOLD)

	_status_sep.add_theme_font_override("font", _FONT_BOLD)
	_status_sep.add_theme_font_size_override("font_size", 13)
	_status_sep.add_theme_color_override("font_color", Color(C_GOLD_DIM, 0.60))

	_status_race.add_theme_font_size_override("font_size", 11)
	_status_race.add_theme_color_override("font_color", C_PARCHMENT_D)

	_status_dim.add_theme_font_size_override("font_size", 11)
	_status_dim.add_theme_color_override("font_color", Color(C_PARCHMENT_D, 0.55))

	_apply_ghost_style(_random_btn)
	_apply_primary_style(_confirm_btn)

# ═══════════════════════════════════════════════════════════════════════════════
# CONTEÚDO DINÂMICO — botões de raça/sexo/categoria gerados por script
# ═══════════════════════════════════════════════════════════════════════════════

func _setup_dynamic_content() -> void:
	# Botões de raça
	for race in RACES:
		var race_id: String = race.id
		var btn := _make_toggle_button(race.label)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func() -> void: _on_race_changed(race_id))
		_race_btns[race_id] = btn
		_race_row.add_child(btn)
	_update_toggle_group(_race_btns, _state.race)

	# Botões de sexo
	for entry in [{ "id": "male", "label": "Masculino" }, { "id": "female", "label": "Feminino" }]:
		var sex_id: String = entry.id
		var btn := _make_toggle_button(entry.label)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func() -> void: _on_sex_changed(sex_id))
		_sex_btns[sex_id] = btn
		_sex_row.add_child(btn)
	_update_toggle_group(_sex_btns, _state.sex)

	# Navegação de categorias agrupada
	var groups: Dictionary = {}
	for cat in CATEGORIES:
		if not groups.has(cat.group):
			groups[cat.group] = []
		groups[cat.group].append(cat)

	for group_name in groups.keys():
		var grp_lbl := Label.new()
		grp_lbl.text = group_name.to_upper()
		grp_lbl.add_theme_font_override("font", _FONT_BOLD)
		grp_lbl.add_theme_font_size_override("font_size", 9)
		grp_lbl.add_theme_color_override("font_color", Color(C_GOLD_DIM, 0.60))
		_category_nav.add_child(grp_lbl)

		for cat in groups[group_name]:
			var cat_id: String = cat.id
			var btn := Button.new()
			btn.text = cat.label
			btn.flat = true
			btn.custom_minimum_size = Vector2(0, 36)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_font_override("font", _FONT_BOLD)
			btn.add_theme_font_size_override("font_size", 13)
			btn.pressed.connect(func() -> void: _show_category(cat_id))
			_cat_btns[cat_id] = btn
			_category_nav.add_child(btn)

	# ColorPickerButton único — cor da categoria ativa
	_color_picker = ColorPickerButton.new()
	_color_picker.custom_minimum_size = Vector2(0, 36)
	_color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_color_picker.add_theme_font_override("font", _FONT_BOLD)
	_color_picker.add_theme_font_size_override("font_size", 10)
	_color_picker.color_changed.connect(func(c: Color) -> void:
		_on_color_selected(_active_cat, c)
	)
	_palette_row.add_child(_color_picker)
	_swatch_grid.hide()

# ═══════════════════════════════════════════════════════════════════════════════
# SINAIS
# ═══════════════════════════════════════════════════════════════════════════════

func _wire_signals() -> void:
	_back_btn.pressed.connect(_on_back_pressed)
	_random_top.pressed.connect(_on_randomize)
	_random_btn.pressed.connect(_on_randomize)
	_confirm_btn.pressed.connect(_on_confirm)
	_dice_btn.pressed.connect(func() -> void:
		_state.name = RANDOM_NAMES.pick_random()
		_name_input.text = _state.name
		_update_info_labels()
	)
	_name_input.text_changed.connect(func(t: String) -> void:
		_state.name = t
		_update_info_labels()
	)

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORIA ATIVA — painel direito
# ═══════════════════════════════════════════════════════════════════════════════

func _show_category(cat_id: String) -> void:
	_active_cat = cat_id

	for cid in _cat_btns:
		_apply_cat_btn_style(_cat_btns[cid], cid == cat_id)

	var cat := _find_category(cat_id)
	_panel_title.text = cat.label.to_upper()

	if cat_id == "body":
		var race      := _find_race(str(_state.get("race", "")))
		var skins     := race.get("skins", {}) as Dictionary
		var sex       := str(_state.get("sex", "male"))
		var count: int = (skins.get(sex, []) as Array).size()
		_panel_count.text = "%d TONS DE PELE" % count
		_color_label.visible = false
		_color_picker.visible = false
	else:
		var styles: Array = STYLES.get(cat_id, [])
		_panel_count.text = "%d ESTILOS" % styles.size()
		_color_label.visible = true
		_color_picker.visible = true
		var cat_state := _state.get(cat_id, {}) as Dictionary
		_color_picker.color = cat_state.get("color", Color.WHITE) as Color

	_populate_style_grid(cat_id)

func _populate_style_grid(cat_id: String) -> void:
	for c in _style_grid.get_children():
		c.queue_free()

	_style_grid.columns = 1

	var styles_to_show: Array
	var current: String

	if cat_id == "body":
		# Skins vêm da raça atual, filtradas por sexo
		var race      := _find_race(str(_state.get("race", "")))
		var skins     := race.get("skins", {}) as Dictionary
		var sex       := str(_state.get("sex", "male"))
		styles_to_show = skins.get(sex, []) as Array
		current = str((_state.get("body", {}) as Dictionary).get("style", ""))
	else:
		styles_to_show = STYLES.get(cat_id, [])
		current = str((_state.get(cat_id, {}) as Dictionary).get("style", ""))

	for item in styles_to_show:
		var item_id: String = str(item.get("id", ""))
		var tile := _build_style_tile(item, item_id == current)
		tile.pressed.connect(func() -> void: _on_style_selected(cat_id, item_id))
		_style_grid.add_child(tile)


# ═══════════════════════════════════════════════════════════════════════════════
# HANDLERS
# ═══════════════════════════════════════════════════════════════════════════════

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(LOBBY_SCENE)

func _on_randomize() -> void:
	_state["name"] = RANDOM_NAMES.pick_random()
	_state["race"] = RACES[randi() % RACES.size()].id
	_state["sex"]  = (["male", "female"] as Array).pick_random()
	# Skin aleatório da raça/sexo sorteados
	var rnd_race  := _find_race(str(_state.get("race", "")))
	var rnd_skins := rnd_race.get("skins", {}) as Dictionary
	var rnd_sex   := str(_state.get("sex", "male"))
	var rnd_sex_skins: Array = rnd_skins.get(rnd_sex, [])
	if rnd_sex_skins.size() > 0:
		(_state["body"] as Dictionary)["style"] = str(rnd_sex_skins[randi() % rnd_sex_skins.size()].get("id", ""))
	for cat in CATEGORIES:
		var cid: String = str(cat.get("id", ""))
		if cid == "body":
			continue  # skin do body já definido acima
		var styles: Array = STYLES.get(cid, [])
		if styles.size() > 0:
			(_state[cid] as Dictionary)["style"] = str(styles[randi() % styles.size()].get("id", ""))
		(_state[cid] as Dictionary)["color"] = RANDOM_COLORS[randi() % RANDOM_COLORS.size()]
	_name_input.text = str(_state.get("name", ""))
	_update_toggle_group(_race_btns, str(_state.get("race", "")))
	_update_toggle_group(_sex_btns,  str(_state.get("sex", "")))
	_refresh_all_layers()
	_show_category(_active_cat)
	_update_info_labels()

func _on_race_changed(race_id: String) -> void:
	_state.race = race_id
	_update_toggle_group(_race_btns, race_id)
	_reset_body_skin()   # reseta para primeiro skin disponível da nova raça
	_refresh_body_layer()
	if _active_cat == "body":
		_show_category("body")
	_update_info_labels()

func _on_sex_changed(sex_id: String) -> void:
	_state["sex"] = sex_id
	_update_toggle_group(_sex_btns, sex_id)
	_validate_body_skin()  # garante que o skin atual existe para o novo sexo
	_refresh_all_layers()
	if _active_cat == "body":
		_populate_style_grid("body")

func _on_style_selected(cat_id: String, style_id: String) -> void:
	(_state[cat_id] as Dictionary)["style"] = style_id
	if cat_id == "body":
		_refresh_body_layer()
	else:
		_refresh_layer(cat_id)
	_populate_style_grid(cat_id)

func _on_color_selected(cat_id: String, color: Color) -> void:
	(_state[cat_id] as Dictionary)["color"] = color
	_apply_layer_color(cat_id)

func _on_confirm() -> void:
	if _state.name.strip_edges().is_empty():
		_state.name      = RANDOM_NAMES.pick_random()
		_name_input.text = _state.name
	CharacterStore.save_character(_build_save_data())
	get_tree().change_scene_to_file(LOBBY_SCENE)

# Constrói o dicionário salvo com paths resolvidos e cores em hex,
# para que player_character.gd possa carregar sem conhecer RACES/STYLES.
func _build_save_data() -> Dictionary:
	var data := {}
	data["name"] = str(_state.get("name", ""))
	data["race"] = str(_state.get("race", ""))
	data["sex"]  = str(_state.get("sex",  ""))

	# Body — path do tom de pele selecionado
	var body_state := _state.get("body", {}) as Dictionary
	var skin_id    := str(body_state.get("style", ""))
	var race_data  := _find_race(str(_state.get("race", "")))
	var skins      := race_data.get("skins", {}) as Dictionary
	var sex_skins: Array = skins.get(str(_state.get("sex", "")), [])
	var body_path  := ""
	for s in sex_skins:
		if str(s.get("id", "")) == skin_id:
			body_path = str(s.get("path", ""))
			break
	data["body"] = { "style": skin_id, "path": body_path }

	# Demais categorias — path resolvido por sexo + cor em hex
	for cat_id in ["hair", "chest", "legs", "shoes"]:
		var cat_state := _state.get(cat_id, {}) as Dictionary
		var style_id  := str(cat_state.get("style", ""))
		var style_d   := _find_style(cat_id, style_id)
		var path      := ""
		if not style_d.is_empty():
			if style_d.has("paths"):
				var paths := style_d.get("paths", {}) as Dictionary
				path = str(paths.get(str(_state.get("sex", "")), ""))
			else:
				path = str(style_d.get("path", ""))
		var color := cat_state.get("color", Color.WHITE) as Color
		data[cat_id] = {
			"style": style_id,
			"path":  path,
			"color": color.to_html(true),   # ex: "1466FFff"
		}

	return data

# ═══════════════════════════════════════════════════════════════════════════════
# PREVIEW
# ═══════════════════════════════════════════════════════════════════════════════

func _refresh_all_layers() -> void:
	_refresh_body_layer()
	for cat in CATEGORIES:
		_refresh_layer(cat.id)

func _refresh_body_layer() -> void:
	var race := _find_race(str(_state.get("race", "")))
	if race.is_empty():
		return
	var skins    := race.get("skins", {}) as Dictionary
	var sex      := str(_state.get("sex", "male"))
	var sex_skins: Array = skins.get(sex, [])
	var skin_id  := str((_state.get("body", {}) as Dictionary).get("style", ""))
	# Procura o path do skin selecionado
	var path := ""
	for s in sex_skins:
		if str(s.get("id", "")) == skin_id:
			path = str(s.get("path", ""))
			break
	# Fallback: primeiro skin disponível
	if path == "" and sex_skins.size() > 0:
		path = str(sex_skins[0].get("path", ""))
		(_state["body"] as Dictionary)["style"] = str(sex_skins[0].get("id", ""))
	if path == "" or not ResourceLoader.exists(path):
		_body_sprite.texture = null
		return
	_body_sprite.texture = load(path)
	_body_sprite.hframes = 9
	_body_sprite.vframes = 4
	_body_sprite.frame   = PREVIEW_FRAME
	_body_sprite.modulate = Color.WHITE  # sem tinting, sprite já tem a cor certa

func _refresh_layer(cat_id: String) -> void:
	# Body tem sprite própria por raça/sexo/tom — gerenciada por _refresh_body_layer()
	if cat_id == "body":
		return
	var sprite := _get_sprite(cat_id)
	if not sprite:
		return
	var cat_state := _state.get(cat_id, {}) as Dictionary
	var style     := _find_style(cat_id, str(cat_state.get("style", "")))
	if style.is_empty():
		sprite.texture = null
		_apply_layer_color(cat_id)
		return
	# Estilos com variante por sexo usam "paths", os demais usam "path"
	var path: String
	if style.has("paths"):
		var sex   := str(_state.get("sex", "male"))
		var paths := style.get("paths", {}) as Dictionary
		path = str(paths.get(sex, ""))
	else:
		path = str(style.get("path", ""))
	if path == "" or not ResourceLoader.exists(path):
		sprite.texture = null
		_apply_layer_color(cat_id)
		return
	sprite.texture = load(path)
	sprite.hframes = 9
	sprite.vframes = 4
	sprite.frame   = PREVIEW_FRAME
	_apply_layer_color(cat_id)

func _apply_layer_color(cat_id: String) -> void:
	var sprite := _get_sprite(cat_id)
	if sprite:
		var cat_state := _state.get(cat_id, {}) as Dictionary
		sprite.modulate = cat_state.get("color", Color.WHITE) as Color

func _get_sprite(cat_id: String) -> Sprite2D:
	match cat_id:
		"body":  return _body_sprite
		"hair":  return _hair_sprite
		"chest": return _chest_sprite
		"legs":  return _pants_sprite
		"shoes": return _shoes_sprite
	return null

func _update_info_labels() -> void:
	var name_raw  := str(_state.get("name", ""))
	var name_txt  := name_raw if name_raw.strip_edges() != "" else "—"
	var race_data := _find_race(str(_state.get("race", "")))
	var race_txt  := str(race_data.get("label", "—")).to_upper()
	var sex_txt   := "Masculino" if _state.get("sex", "") == "male" else "Feminino"
	_preview_name.text = name_txt
	_preview_race.text = "%s · %s" % [race_txt, sex_txt]
	_status_name.text  = name_txt
	_status_race.text  = str(race_data.get("label", ""))

# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS DE DADOS
# ═══════════════════════════════════════════════════════════════════════════════

func _find_race(race_id: String) -> Dictionary:
	for r in RACES:
		if r.id == race_id: return r
	return {}

func _find_category(cat_id: String) -> Dictionary:
	for c in CATEGORIES:
		if c.id == cat_id: return c
	return {}

func _find_style(cat_id: String, style_id: String) -> Dictionary:
	for s in STYLES.get(cat_id, []):
		if s.id == style_id: return s
	return {}

# Reseta skin do body para o primeiro disponível da raça/sexo atual
func _reset_body_skin() -> void:
	var race      := _find_race(str(_state.get("race", "")))
	var skins     := race.get("skins", {}) as Dictionary
	var sex       := str(_state.get("sex", "male"))
	var sex_skins: Array = skins.get(sex, [])
	if sex_skins.size() > 0:
		(_state["body"] as Dictionary)["style"] = str(sex_skins[0].get("id", ""))

# Garante que o skin atual existe para o sexo atual; se não, usa o primeiro disponível
func _validate_body_skin() -> void:
	var race      := _find_race(str(_state.get("race", "")))
	var skins     := race.get("skins", {}) as Dictionary
	var sex       := str(_state.get("sex", "male"))
	var sex_skins: Array = skins.get(sex, [])
	var current   := str((_state.get("body", {}) as Dictionary).get("style", ""))
	for s in sex_skins:
		if str(s.get("id", "")) == current:
			return  # skin ainda disponível, não precisa resetar
	if sex_skins.size() > 0:
		(_state["body"] as Dictionary)["style"] = str(sex_skins[0].get("id", ""))

# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS DE UI
# ═══════════════════════════════════════════════════════════════════════════════

func _flat_style(bg: Color, border: Color, bw: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	return s

func _make_toggle_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.flat = true
	btn.custom_minimum_size = Vector2(0, 34)
	btn.add_theme_font_override("font", _FONT_BOLD)
	btn.add_theme_font_size_override("font_size", 10)
	return btn

func _build_style_tile(item: Dictionary, selected: bool) -> Button:
	var btn := Button.new()
	btn.text = str(item.get("label", item.get("id", "")))
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 36)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_override("font", _FONT_BOLD)
	btn.add_theme_font_size_override("font_size", 12)

	if selected:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(C_GOLD, 0.12)
		s.border_color = C_GOLD_DIM
		s.border_width_left = 2
		s.set_content_margin(SIDE_LEFT, 14)
		s.set_content_margin(SIDE_RIGHT, 10)
		s.set_content_margin(SIDE_TOP, 8)
		s.set_content_margin(SIDE_BOTTOM, 8)
		btn.add_theme_stylebox_override("normal",  s)
		btn.add_theme_stylebox_override("hover",   s)
		btn.add_theme_stylebox_override("pressed", s)
		btn.add_theme_color_override("font_color",       C_GOLD)
		btn.add_theme_color_override("font_hover_color", C_GOLD_GLOW)
	else:
		var n := StyleBoxEmpty.new()
		var h := _flat_style(Color(C_GOLD, 0.05), Color(0, 0, 0, 0))
		h.set_content_margin(SIDE_LEFT, 14)
		h.set_content_margin(SIDE_RIGHT, 10)
		h.set_content_margin(SIDE_TOP, 8)
		h.set_content_margin(SIDE_BOTTOM, 8)
		btn.add_theme_stylebox_override("normal",  n)
		btn.add_theme_stylebox_override("hover",   h)
		btn.add_theme_stylebox_override("pressed", h)
		btn.add_theme_color_override("font_color",       C_PARCHMENT_D)
		btn.add_theme_color_override("font_hover_color", C_PARCHMENT)
	return btn

func _apply_ghost_style(btn: Button) -> void:
	var n := _flat_style(Color(0, 0, 0, 0), C_LINE)
	n.set_content_margin(SIDE_LEFT, 16);  n.set_content_margin(SIDE_RIGHT,  16)
	n.set_content_margin(SIDE_TOP,  10);  n.set_content_margin(SIDE_BOTTOM, 10)
	var h := _flat_style(Color(C_GOLD, 0.05), C_GOLD_DIM)
	h.set_content_margin(SIDE_LEFT, 16);  h.set_content_margin(SIDE_RIGHT,  16)
	h.set_content_margin(SIDE_TOP,  10);  h.set_content_margin(SIDE_BOTTOM, 10)
	btn.add_theme_stylebox_override("normal",  n)
	btn.add_theme_stylebox_override("hover",   h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_font_override("font", _FONT_BOLD)
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color",         C_PARCHMENT_D)
	btn.add_theme_color_override("font_hover_color",   C_GOLD)
	btn.add_theme_color_override("font_pressed_color", C_GOLD_DIM)

func _apply_primary_style(btn: Button) -> void:
	var n := _flat_style(Color(0.180, 0.063, 0.043), Color(C_CRIMSON_BR, 0.70))
	n.set_content_margin(SIDE_LEFT, 24);  n.set_content_margin(SIDE_RIGHT,  24)
	n.set_content_margin(SIDE_TOP, 12);   n.set_content_margin(SIDE_BOTTOM, 12)
	var h := _flat_style(Color(0.220, 0.082, 0.055), C_CRIMSON_BR)
	h.set_content_margin(SIDE_LEFT, 24);  h.set_content_margin(SIDE_RIGHT,  24)
	h.set_content_margin(SIDE_TOP, 12);   h.set_content_margin(SIDE_BOTTOM, 12)
	btn.add_theme_stylebox_override("normal",  n)
	btn.add_theme_stylebox_override("hover",   h)
	btn.add_theme_stylebox_override("pressed", n)
	btn.add_theme_font_override("font", _FONT_BOLD)
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color",         Color(0.941, 0.816, 0.784))
	btn.add_theme_color_override("font_hover_color",   Color(1.00, 0.90, 0.87))
	btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.70, 0.67))

func _update_toggle_group(btns: Dictionary, selected_id: String) -> void:
	for id in btns:
		_apply_toggle_style(btns[id], id == selected_id)

func _apply_toggle_style(btn: Button, selected: bool) -> void:
	var s_on := _flat_style(Color(C_GOLD, 0.12), C_GOLD_DIM)
	s_on.set_content_margin(SIDE_LEFT, 12); s_on.set_content_margin(SIDE_RIGHT,  12)
	s_on.set_content_margin(SIDE_TOP,  8);  s_on.set_content_margin(SIDE_BOTTOM, 8)
	var s_off := _flat_style(Color(0, 0, 0, 0), C_LINE)
	s_off.set_content_margin(SIDE_LEFT, 12); s_off.set_content_margin(SIDE_RIGHT,  12)
	s_off.set_content_margin(SIDE_TOP,  8);  s_off.set_content_margin(SIDE_BOTTOM, 8)
	var s_hov := _flat_style(Color(C_GOLD, 0.05), C_GOLD_DIM)
	s_hov.set_content_margin(SIDE_LEFT, 12); s_hov.set_content_margin(SIDE_RIGHT,  12)
	s_hov.set_content_margin(SIDE_TOP,  8);  s_hov.set_content_margin(SIDE_BOTTOM, 8)
	if selected:
		btn.add_theme_stylebox_override("normal",  s_on)
		btn.add_theme_stylebox_override("hover",   s_on)
		btn.add_theme_stylebox_override("pressed", s_on)
		btn.add_theme_color_override("font_color",       C_GOLD)
		btn.add_theme_color_override("font_hover_color", C_GOLD_GLOW)
	else:
		btn.add_theme_stylebox_override("normal",  s_off)
		btn.add_theme_stylebox_override("hover",   s_hov)
		btn.add_theme_stylebox_override("pressed", s_hov)
		btn.add_theme_color_override("font_color",       C_PARCHMENT_D)
		btn.add_theme_color_override("font_hover_color", C_PARCHMENT)

func _apply_cat_btn_style(btn: Button, selected: bool) -> void:
	if selected:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(C_GOLD, 0.10)
		s.border_color = C_GOLD_DIM
		s.border_width_left = 2
		s.set_content_margin(SIDE_LEFT, 14); s.set_content_margin(SIDE_RIGHT,  10)
		s.set_content_margin(SIDE_TOP,  8);  s.set_content_margin(SIDE_BOTTOM, 8)
		btn.add_theme_stylebox_override("normal", s)
		btn.add_theme_stylebox_override("hover",  s)
		btn.add_theme_color_override("font_color",       C_GOLD)
		btn.add_theme_color_override("font_hover_color", C_GOLD_GLOW)
	else:
		var h := _flat_style(Color(C_GOLD, 0.05), Color(0, 0, 0, 0))
		h.set_content_margin(SIDE_LEFT, 14); h.set_content_margin(SIDE_RIGHT,  10)
		h.set_content_margin(SIDE_TOP,  8);  h.set_content_margin(SIDE_BOTTOM, 8)
		btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("hover",  h)
		btn.add_theme_color_override("font_color",       C_PARCHMENT_D)
		btn.add_theme_color_override("font_hover_color", C_PARCHMENT)

func _animate_entrance() -> void:
	modulate.a = 0.0
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(self, "modulate:a", 1.0, 0.40)
