# Paleta e helpers visuais compartilhados pelas telas do Ferreiro (hub + modos).
# Espelha as constantes do protótipo `Ferreiro.html`, adaptadas às fontes que o
# projeto realmente tem (família CinzelDecorative; não há Cinzel/CrimsonPro).
class_name ForgeTheme
extends RefCounted

# ── Cores (sRGB) ────────────────────────────────────────────────────────────────
const BG_DEEP     := Color("0a0a18")
const BG_MID      := Color("12121f")
const BG_SURFACE  := Color("171724")
const GOLD        := Color("c89d4a")
const GOLD_DIM    := Color("9a7434")
const GOLD_GLOW   := Color("e6b455")
const GOLD_SOFT_A := Color(0.78, 0.62, 0.29, 0.25)
const PARCHMENT   := Color("e8dccb")
const PARCHMENT_D := Color("b6a78f")
const CRIMSON      := Color("8a2d22")
const CRIMSON_BR   := Color("c0432e")
const CRIMSON_GLOW := Color("e0552a")
const RED_INSUFF   := Color("e36a3a")
const EMBER        := Color("e09a3a")
const PURPLE       := Color("8a5bd0")   # acento do modo Encantar (locked)

# Raridades de carta (pips) — alinhadas à BoosterShop.
const RAR_COMMON    := Color("b3b3a8")
const RAR_RARE      := Color("5aa3ec")
const RAR_LEGENDARY := Color("e6b94a")
const RAR_MYSTIC    := Color("b376e8")

# ── Fontes (cache estático) ─────────────────────────────────────────────────────
static var _f_display: FontFile
static var _f_heading: FontFile
static var _f_body: FontFile

static func font_display() -> FontFile:
	if _f_display == null:
		_f_display = load("res://assets/fonts/CinzelDecorative-Black.ttf")
	return _f_display

static func font_heading() -> FontFile:
	if _f_heading == null:
		_f_heading = load("res://assets/fonts/CinzelDecorative-Bold.ttf")
	return _f_heading

static func font_body() -> FontFile:
	if _f_body == null:
		_f_body = load("res://assets/fonts/CinzelDecorative-Regular.ttf")
	return _f_body


# ── Helpers de cor de raridade ───────────────────────────────────────────────────
static func rarity_color(rarity: String) -> Color:
	match rarity.to_upper():
		"RARE": return RAR_RARE
		"LEGENDARY": return RAR_LEGENDARY
		"MYSTIC": return RAR_MYSTIC
		_: return RAR_COMMON

static func rarity_label(rarity: String) -> String:
	match rarity.to_upper():
		"RARE": return "Rara"
		"LEGENDARY": return "Lendária"
		"MYSTIC": return "Mística"
		_: return "Comum"


# ── Labels prontos ───────────────────────────────────────────────────────────────
static func make_label(text: String, font: FontFile, size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l

# Eyebrow: Cinzel regular, pequeno, dourado escuro, caixa alta (letter spacing via tema padrão).
static func make_eyebrow(text: String, color := GOLD_DIM, size := 11) -> Label:
	return make_label(text.to_upper(), font_body(), size, color)


# ── StyleBoxes ───────────────────────────────────────────────────────────────────
# Painel padrão: superfície semi-transparente com borda dourada suave.
static func panel_style(bg := Color(BG_MID.r, BG_MID.g, BG_MID.b, 0.7),
		border := GOLD_SOFT_A, border_w := 1, corner := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(border_w)
	s.border_color = border
	s.set_corner_radius_all(corner)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s

# Botão CTA vermelho (FORJAR / CANALIZAR).
static func crimson_button_style(hover := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = CRIMSON_BR if hover else CRIMSON
	s.set_border_width_all(1)
	s.border_color = CRIMSON_GLOW
	s.set_corner_radius_all(0)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 16
	s.content_margin_bottom = 16
	return s

static func disabled_button_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.12, 0.16, 0.7)
	s.set_border_width_all(1)
	s.border_color = Color(GOLD_SOFT_A.r, GOLD_SOFT_A.g, GOLD_SOFT_A.b, 0.18)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 16
	s.content_margin_bottom = 16
	return s


# Aplica o visual de botão "fantasma" dourado (Voltar, links). Reutilizável.
static func style_ghost_button(btn: Button, size := 13) -> void:
	btn.add_theme_font_override("font", font_body())
	btn.add_theme_font_size_override("font_size", size)
	btn.add_theme_color_override("font_color", GOLD_DIM)
	btn.add_theme_color_override("font_hover_color", GOLD_GLOW)
	btn.add_theme_color_override("font_pressed_color", GOLD)
	btn.add_theme_color_override("font_focus_color", GOLD_GLOW)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(BG_SURFACE.r, BG_SURFACE.g, BG_SURFACE.b, 0.6)
	normal.set_border_width_all(1)
	normal.border_color = GOLD_SOFT_A
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = GOLD
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", normal)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


# ── CardView ─────────────────────────────────────────────────────────────────────
# Liga um CardView e o reduz por `scale` (natural 160×240 → node_scale uniforme), igual
# ao inventário da troca. CRÍTICO: bind_dict toca @onready (_art etc.); se o CardView
# ainda não entrou na árvore, adia o setup para o sinal `ready` (senão dá "Nil.texture").
static func bind_card_tile(cv: CardView, card: Dictionary, font_scale: float,
		node_scale: float, foil := false) -> void:
	var apply := func() -> void:
		cv.set_preview_enabled(false)
		cv.bind_dict(card)
		cv.set_foil(foil)
		cv.apply_scale(font_scale)
		cv.set_face_down(false)
		cv.size = Vector2(160, 240)
		cv.pivot_offset = Vector2.ZERO
		cv.scale = Vector2(node_scale, node_scale)
	if cv.is_node_ready():
		apply.call()
	else:
		cv.ready.connect(apply, CONNECT_ONE_SHOT)


# Torna um CardView 100% passivo (só visual) — não rouba clique/roda do tile pai.
static func make_passive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		make_passive(c)


# Format pt-BR de ouro (12.345). Espelha o helper da HUD do mundo.
static func fmt_gold(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "." + out
		out = s[i] + out
		count += 1
	return ("-" + out) if n < 0 else out
