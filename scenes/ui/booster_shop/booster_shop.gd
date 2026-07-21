extends Control

const WORLD_SCENE     := "res://scenes/world/world_root.tscn"
const CARD_VIEW_SCENE := preload("res://scenes/ui/card_view/card_view.tscn")
const PACK_SIZE       := 8
const PACK_PRICE      := 100

# Carta grande do centro (+10% sobre 200x300) e miniaturas de baixo (+15%)
const STAGE_CARD_SIZE := Vector2(220, 330)
const STAGE_CARD_HALF := Vector2(110, 165)
const STAGE_CARD_FONT := 1.375   # apply_scale: 1.25 * 1.10
const THUMB_WRAP_SIZE := Vector2(60, 90)
const THUMB_SCALE     := 0.374   # 0.325 * 1.15
const STARTING_GOLD   := 0   # fallback até /players/me responder

# ── Parâmetros de abertura (ESPELHO do backend) ─────────────────────────────────
# Estes valores são apenas para EXIBIÇÃO das probabilidades ao jogador; o sorteio
# real é autoridade do taldorian-service. Mantenha em sincronia com
# `taldorian.booster.*` (application.yml / BoosterProperties.kt). Raridade com peso 0
# ou sem cartas na coleção não é sorteada.
const RARITY_WEIGHTS := {
	"COMMON":    70,
	"RARE":      20,
	"LEGENDARY": 10,
	"MYSTIC":    0,
}
const GUARANTEED_RARITY := "RARE"
const GUARANTEED_COUNT  := 1
const FOIL_CHANCE_PCT   := 5   # foil_chance 0.05 → 5% por carta

# Ordem e rótulos de exibição das raridades no modal de probabilidades.
const RARITY_ORDER := ["COMMON", "RARE", "LEGENDARY", "MYSTIC"]
const RARITY_LABEL := {
	"COMMON":    "Comuns",
	"RARE":      "Raras",
	"LEGENDARY": "Lendárias",
	"MYSTIC":    "Místicas",
}
# Chave da contagem no dict da coleção (/catalog/collections) por raridade.
const RARITY_COUNT_KEY := {
	"COMMON":    "commonCards",
	"RARE":      "rareCards",
	"LEGENDARY": "legendaryCards",
	"MYSTIC":    "mysticCards",
}

# Cartas no grid do modal "Ver Cartas" (CardView base é 160x240).
const GRID_CARD_BASE  := Vector2(160, 240)
const GRID_CARD_SCALE := 0.85
const CARDS_BUILD_BATCH := 8   # cartas instanciadas por frame (arte é pesada — evita travar)

enum Phase { NONE, ENTER, SHAKE, SPLIT, FLY, STACK, REVEAL }

# ── Colors ────────────────────────────────────────────────────────────────────
const C_GOLD        := Color(0.788, 0.627, 0.298)
const C_GOLD_GLOW   := Color(0.910, 0.784, 0.337)
const C_GOLD_DIM    := Color(0.549, 0.431, 0.192)
const C_PARCHMENT_D := Color(0.722, 0.659, 0.549)
const C_BORDER      := Color(0.788, 0.627, 0.298, 0.20)
const C_BORDER_STR  := Color(0.788, 0.627, 0.298, 0.40)
const C_SURFACE     := Color(0.078, 0.098, 0.188, 1.0)
const C_SURFACE2    := Color(0.055, 0.071, 0.145, 1.0)

const C_RARE_COMMON    := Color(0.70, 0.60, 0.50)
const C_RARE_RARE      := Color(0.45, 0.60, 0.92)
const C_RARE_LEGENDARY := Color(0.92, 0.78, 0.34)

# ── Aura de tensão (pista de raridade estilo gacha) ─────────────────────────────
# O tier é o TETO do pacote (o melhor item manda). A aura começa azul e, no
# build-up, "evolui" pra cor real (fake-out). Ver tension_aura.gdshader.
const TENSION_SHADER    := preload("res://scenes/ui/booster_shop/tension_aura.gdshader")
const CARD_SHINE_SHADER := preload("res://scenes/ui/booster_shop/card_reveal_shine.gdshader")
const CARD_FIRE_SHADER  := preload("res://scenes/ui/booster_shop/card_fire.gdshader")
const TENSION_AURA_SIZE := Vector2(900, 900)

# Fogo por carta: o overlay extrapola só um pouco a carta (chamas finas na borda).
const FIRE_GROW := Vector2(60, 74)   # quanto o overlay extrapola a carta (cada lado)

# Modos do fogo (alinhados ao mode do card_fire.gdshader); -1 = sem fogo (comum).
enum Fire { NONE = -1, BLUE = 0, MIXED = 1, PRISM = 2 }

# Camadas do reveal dramático (dourado+): a carta fica acima do escurecimento.
const Z_DARKEN      := 40
const Z_IMPACT_BURST := 45
const Z_FRONT_CARD  := 50
const Z_IMPACT_FLASH := 60

enum Tier { BLUE, PURPLE, GOLD, RAINBOW }

const TIER_COLOR := {
	Tier.BLUE:    Color(0.30, 0.55, 1.00),   # baseline: só comuns + a rara garantida
	Tier.PURPLE:  Color(0.66, 0.36, 0.96),   # 2+ raras ou foil comum/rara
	Tier.GOLD:    Color(1.00, 0.80, 0.28),   # 1+ lendária
	Tier.RAINBOW: Color(1.00, 1.00, 1.00),   # místico ou foil de lendária/místico
}

# ── @onready ──────────────────────────────────────────────────────────────────
@onready var _shop_view:         Control        = %ShopView
@onready var _opening_view:      Control        = %OpeningView
@onready var _gold_lbl:          Label          = %GoldLabel
@onready var _collections_list:  VBoxContainer  = %CollectionsList
@onready var _pack_display_wrap: CenterContainer = %PackDisplayWrap
@onready var _pack_info_row:     HBoxContainer  = %PackInfoRow
@onready var _qty_lbl:           Label          = %QtyLabel
@onready var _total_lbl:         Label          = %TotalLabel
@onready var _minus_btn:         Button         = %MinusBtn
@onready var _plus_btn:          Button         = %PlusBtn
@onready var _max_btn:           Button         = %MaxBtn
@onready var _buy_btn:           Button         = %BuyBtn
@onready var _back_btn:          Button         = %BackButton
@onready var _pack_counter_lbl:  Label          = %PackCounterLabel
@onready var _dots_row:          HBoxContainer  = %DotsRow
@onready var _exit_btn:          Button         = %ExitButton
@onready var _skip_btn:          Button         = %SkipButton
@onready var _pack_root:         Control        = %PackRoot
@onready var _card_stage:        Control        = %CardStage
@onready var _hint_lbl:          Label          = %HintLabel
@onready var _reveal_rail:       HBoxContainer  = %RevealRail
@onready var _rail_scroll:       ScrollContainer = %RailScroll
@onready var _finish_row:        Control        = %FinishRow
@onready var _back_to_shop_btn:  Button         = %BackToShopBtn
@onready var _next_pack_btn:     Button         = %NextPackBtn

# Modais de informação (probabilidades + catálogo de cartas)
@onready var _odds_btn:          Button         = %OddsBtn
@onready var _cards_btn:         Button         = %CardsBtn
@onready var _odds_modal:        Control        = %OddsModal
@onready var _odds_veil:         ColorRect      = %OddsVeil
@onready var _odds_close_btn:    Button         = %OddsCloseBtn
@onready var _odds_content:      VBoxContainer  = %OddsContent
@onready var _cards_modal:       Control        = %CardsModal
@onready var _cards_veil:        ColorRect      = %CardsVeil
@onready var _cards_close_btn:   Button         = %CardsCloseBtn
@onready var _cards_count_lbl:   Label          = %CardsCountLabel
@onready var _cards_grid:        GridContainer  = %CardsGrid

# ── State ─────────────────────────────────────────────────────────────────────
var _gold:          int   = STARTING_GOLD
var _qty:           int   = 1
var _packs_queue:   Array = []
var _cur_pack_idx:  int   = 0
var _cur_cards:     Array = []
var _revealed:      int   = 0
var _pack_count:    int   = PACK_SIZE   # nº de cartas do pacote atual (vem do backend)
var _phase:         Phase = Phase.NONE
var _skipped:       bool  = false   # true quando o jogador pula a coreografia do pacote atual
var _stage_cards:   Array[Control] = []
var _progress_dots: Array[ColorRect] = []
var _pack_top_node: Control
var _pack_bot_node: Control

var _aura:      ColorRect
var _aura_mat:  ShaderMaterial
var _aura_tws:  Array[Tween] = []
var _cur_tier:  int = Tier.BLUE

# Reveal de 2 cliques: a carta da frente vira (1º clique) e depois sai (2º clique).
var _front_flipped: bool = false
var _dramatic_dark: ColorRect

var _font_black:   FontFile
var _font_regular: FontFile

# ── Catálogo (vindo de GET /catalog/collections) ────────────────────────────────
var _collections: Array      = []                       # dicts crus da API
var _selected:    Dictionary = {}                       # coleção em destaque (compra)
var _art_path:    String     = ""                       # arte da coleção selecionada
var _sel_name:    String     = "Origens de Taldorian"   # nome da coleção selecionada
var _pack_price:  int        = PACK_PRICE                # preço por pacote da selecionada

# Modal "Ver Cartas": a grade é construída UMA vez (catálogo é estático na sessão) e
# preenchida em lotes por frame, para não congelar ao carregar ~100 artes pesadas.
var _cards_grid_built: bool = false
var _cards_building:   bool = false

# ─────────────────────────────────────────────────────────────────────────────
# INIT
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_font_black   = load("res://assets/fonts/CinzelDecorative-Black.ttf")
	_font_regular = load("res://assets/fonts/CinzelDecorative-Regular.ttf")
	_setup_buttons()
	_back_btn.pressed.connect(_on_back_pressed)
	_minus_btn.pressed.connect(func() -> void: _change_qty(-1))
	_plus_btn.pressed.connect(func() -> void: _change_qty(1))
	_max_btn.pressed.connect(_set_qty_max)
	_buy_btn.pressed.connect(_on_buy_pressed)
	_exit_btn.pressed.connect(_on_opening_exit)
	_skip_btn.pressed.connect(_on_skip_pressed)
	_back_to_shop_btn.pressed.connect(_on_opening_exit)
	_next_pack_btn.pressed.connect(_on_next_pack)
	_odds_btn.pressed.connect(_open_odds_modal)
	_cards_btn.pressed.connect(_open_cards_modal)
	_odds_close_btn.pressed.connect(func() -> void: _odds_modal.visible = false)
	_cards_close_btn.pressed.connect(func() -> void: _cards_modal.visible = false)
	_odds_veil.gui_input.connect(_on_veil_input.bind(_odds_modal))
	_cards_veil.gui_input.connect(_on_veil_input.bind(_cards_modal))
	_show_shop()
	await _refresh_gold()
	await _load_collections()
	_build_collection_list()
	_build_shop_pack_visual()
	_fill_pack_info_row()
	_update_purchase_ui()


# Busca o ouro do jogador em /players/me (autoridade do backend).
func _refresh_gold() -> void:
	var res := await ApiClient.get_me()
	if res.ok and res.data is Dictionary:
		_gold = int(res.data.get("gold", _gold))
	else:
		push_warning("[BoosterShop] Falha ao carregar ouro do jogador: %s" % res.error)


# Busca as coleções no serviço e elege a coleção em destaque (1ª ativa).
func _load_collections() -> void:
	var res := await ApiClient.get_collections()
	if res.ok and res.data is Array:
		_collections = res.data
	else:
		_collections = []
		push_warning("[BoosterShop] Falha ao carregar coleções: %s" % res.error)

	# Ordena da mais antiga para a mais nova. Não há timestamp na API, mas os ids das
	# coleções são sequenciais/hardcoded (…0001 = Origins, …0002 = Ecos), então o id
	# ascendente reflete a ordem de lançamento.
	_collections.sort_custom(_coll_sort)

	_selected = {}
	for c: Dictionary in _collections:
		if bool(c.get("active", false)):
			_selected = c
			break
	if _selected.is_empty() and not _collections.is_empty():
		_selected = _collections[0]

	if not _selected.is_empty():
		_sel_name   = str(_selected.get("name", _sel_name))
		_art_path   = _art_path_for(str(_selected.get("artKey", "")))
		_pack_price = int(_selected.get("boosterPrice", PACK_PRICE))


func _art_path_for(art_key: String) -> String:
	if art_key == "":
		return ""
	var path := "res://assets/collections/%s.png" % art_key
	return path if ResourceLoader.exists(path) else ""


# Mais antiga → mais nova (id ascendente; ver nota em _load_collections).
func _coll_sort(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("id", "")) < str(b.get("id", ""))


# ─────────────────────────────────────────────────────────────────────────────
# SETUP — called once in _ready
# ─────────────────────────────────────────────────────────────────────────────
func _setup_buttons() -> void:
	_style_btn(_back_btn,         C_GOLD_DIM,    C_GOLD,      C_SURFACE2,                   C_BORDER_STR)
	_style_btn(_exit_btn,         C_GOLD_DIM,    C_GOLD_GLOW, Color(0.04, 0.05, 0.10, 0.8), C_BORDER)
	_style_btn(_skip_btn,         C_GOLD_DIM,    C_GOLD_GLOW, Color(0.04, 0.05, 0.10, 0.8), C_BORDER)
	_style_btn(_back_to_shop_btn, C_PARCHMENT_D, C_GOLD_GLOW, Color(0.06, 0.07, 0.14, 0.75),C_BORDER_STR)
	_style_btn(_max_btn,          C_GOLD_DIM,    C_GOLD,      C_SURFACE2,                   C_BORDER)
	_style_btn(_odds_btn,         C_GOLD_DIM,    C_GOLD,      C_SURFACE2,                   C_BORDER)
	_style_btn(_cards_btn,        C_GOLD_DIM,    C_GOLD,      C_SURFACE2,                   C_BORDER)
	_style_btn(_odds_close_btn,   C_GOLD_DIM,    C_GOLD,      C_SURFACE2,                   C_BORDER)
	_style_btn(_cards_close_btn,  C_GOLD_DIM,    C_GOLD,      C_SURFACE2,                   C_BORDER)
	_style_small_btn(_minus_btn)
	_style_small_btn(_plus_btn)
	_style_cta_btn(_buy_btn)
	_style_cta_btn(_next_pack_btn)


func _build_collection_list() -> void:
	for c in _collections_list.get_children():
		c.queue_free()

	if _collections.is_empty():
		var warn := Label.new()
		warn.text = "Não foi possível carregar as coleções."
		warn.add_theme_color_override("font_color", C_PARCHMENT_D)
		warn.add_theme_font_override("font", _font_regular)
		warn.add_theme_font_size_override("font_size", 12)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_collections_list.add_child(warn)
		return

	for c: Dictionary in _collections:
		var selected := not _selected.is_empty() \
			and str(c.get("id", "")) == str(_selected.get("id", ""))
		_collections_list.add_child(_build_coll_card(c, selected))


func _coll_total(c: Dictionary) -> int:
	return int(c.get("commonCards", 0)) + int(c.get("rareCards", 0)) \
		+ int(c.get("legendaryCards", 0)) + int(c.get("mysticCards", 0)) \
		+ int(c.get("otherCards", 0))


func _coll_eyebrow(c: Dictionary) -> String:
	return "Coleção" if bool(c.get("active", false)) else "Em Breve"


func _coll_description(c: Dictionary) -> String:
	if not bool(c.get("active", false)):
		return "Em breve. Novas cartas chegando a Taldorian."
	var parts: Array[String] = []
	for entry: Array in [
		["commonCards", "comuns"], ["rareCards", "raras"],
		["legendaryCards", "lendárias"], ["mysticCards", "místicas"],
	]:
		var n := int(c.get(entry[0], 0))
		if n > 0:
			parts.append("%d %s" % [n, entry[1]])
	if parts.is_empty():
		return "Coleção de cartas de Taldorian."
	return "Cartas desta coleção: %s." % ", ".join(parts)


func _build_shop_pack_visual() -> void:
	for c in _pack_display_wrap.get_children():
		c.queue_free()
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(200, 280)
	if _art_path != "":
		var img := TextureRect.new()
		img.custom_minimum_size = Vector2(200, 280)
		img.size = Vector2(200, 280)
		img.pivot_offset = Vector2(100, 140)
		img.texture = load(_art_path)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.clip_contents = true
		wrap.add_child(img)
	else:
		var panel := _make_pack_panel(_sel_name, 200.0, 280.0)
		wrap.add_child(panel)
	_pack_display_wrap.add_child(wrap)
	# Float animation — tween ATRELADO ao wrap (wrap.create_tween), não ao shop.
	# Cada select libera o wrap anterior; um tween em loop preso ao shop seguiria vivo
	# mirando um nó liberado → duração 0 → loop infinito. Em DEBUG o Godot detecta e segue;
	# em RELEASE a checagem some e TRAVA. Atrelado ao wrap, o tween morre junto com ele.
	var tw := wrap.create_tween().set_loops()
	tw.tween_property(wrap, "rotation_degrees", -4.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(wrap, "rotation_degrees",  4.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _fill_pack_info_row() -> void:
	for c in _pack_info_row.get_children():
		c.queue_free()
	var cells: Array = [
		["Cartas / Pacote", str(PACK_SIZE)],
		["Preço Unitário",  str(_pack_price)],
		["Rara Garantida",  "✦ %d+" % GUARANTEED_COUNT],
	]
	for i in cells.size():
		if i > 0:
			var div := ColorRect.new()
			div.custom_minimum_size = Vector2(1, 32)
			div.color = C_BORDER
			div.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_pack_info_row.add_child(div)
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		cell.custom_minimum_size = Vector2(110, 0)
		_pack_info_row.add_child(cell)
		var ey := Label.new()
		ey.text = cells[i][0].to_upper()
		ey.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ey.add_theme_color_override("font_color", C_GOLD_DIM)
		ey.add_theme_font_override("font", _font_regular)
		ey.add_theme_font_size_override("font_size", 9)
		cell.add_child(ey)
		var val := Label.new()
		val.text = cells[i][1]
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val.add_theme_color_override("font_color", C_GOLD_GLOW)
		val.add_theme_font_override("font", _font_black)
		val.add_theme_font_size_override("font_size", 16)
		cell.add_child(val)


func _build_dots(n: int) -> void:
	_progress_dots.clear()
	for c in _dots_row.get_children():
		c.queue_free()
	for _i in n:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(9, 9)
		dot.color = Color(C_BORDER, 1.5)
		_progress_dots.append(dot)
		_dots_row.add_child(dot)


# ─────────────────────────────────────────────────────────────────────────────
# MAPEAMENTO — carta da API (/boosters/open) → dict que CardView.bind_dict entende
# ─────────────────────────────────────────────────────────────────────────────
func _map_api_card(c: Dictionary) -> Dictionary:
	# Liga pela identidade forte (id da API ↔ card_id local). Usa a definição local
	# canônica (mesma do jogo: efeitos, símbolos, art_key) quando encontrada.
	# Jackson serializa o boolean `foil` (getter isFoil()) sem o prefixo "is" — vem como "foil".
	var is_foil := bool(c.get("foil", false))
	var local := Collection.resolve_card(c)
	if not local.is_empty():
		# Duplicar: resolve_card devolve o dict canônico do catálogo; mutar aqui o
		# deixaria foil permanentemente. is_foil é por-cópia, não por-definição.
		local = local.duplicate()
		local["is_foil"] = is_foil
		return local
	# Sem correspondência local (ex.: coleção nova ainda não no JSON) — exibe direto da API.
	push_warning("[BoosterShop] Carta sem correspondência local (id=%s, cardKey=%s, name=%s)" % [
		c.get("id", ""), c.get("cardKey", ""), c.get("name", "")])
	return {
		"name":          str(c.get("name", "")),
		"timing":        _map_timing(str(c.get("cardType", "ACTION"))),
		"attack_value":  int(c.get("attackValue", 0)),
		"defense_value": int(c.get("defenseValue", 0)),
		"description":   str(c.get("description", "")),
		"rarity":        str(c.get("rarity", "COMMON")),
		"art_key":       str(c.get("artKey", "")),
		"symbols":       _map_symbols(c.get("symbols", [])),
		"is_stealth":    bool(c.get("isStealth", false)),
		"is_foil":       is_foil,
	}


func _map_symbols(raw: Variant) -> Array:
	# GameSymbols.from_api_list já faz FIRE→fogo, WATER→agua, EARTH→terra, WIND→wind.
	if raw is Array:
		return GameSymbols.from_api_list(raw)
	return []


func _map_timing(card_type: String) -> String:
	var t := card_type.strip_edges().to_upper()
	return t if Card.TimingType.has(t) else "ACTION"


# ─────────────────────────────────────────────────────────────────────────────
# OPENING — coreografia de fases
# ─────────────────────────────────────────────────────────────────────────────
func _start_pack(idx: int) -> void:
	_cur_cards   = _packs_queue[idx]
	_pack_count  = _cur_cards.size()
	_revealed    = 0
	_phase       = Phase.NONE
	_skipped     = false
	_front_flipped = false
	_clear_dramatic_darken()
	if is_instance_valid(_aura):
		_aura.visible = false
	_finish_row.visible  = false
	_hint_lbl.visible    = false
	_skip_btn.visible    = true
	_rail_scroll.visible = true
	_build_dots(_pack_count)

	for c in _stage_cards:
		c.queue_free()
	_stage_cards.clear()

	for c in _reveal_rail.get_children():
		c.queue_free()

	# Rebuild split pack inside PackRoot
	for c in _pack_root.get_children():
		c.queue_free()
	_pack_root.visible  = true
	_pack_root.scale    = Vector2(0.4, 0.4)
	_pack_root.rotation = 0.0
	_pack_root.modulate = Color.WHITE
	_build_split_pack(_pack_root, _sel_name)

	_pack_counter_lbl.text = "%d / %d" % [idx + 1, _packs_queue.size()]

	for dot in _progress_dots:
		dot.color = Color(C_BORDER, 1.5)

	var stage_center := get_viewport_rect().size * 0.5
	for i in _pack_count:
		var cv: CardView = CARD_VIEW_SCENE.instantiate()
		cv.pivot_offset = STAGE_CARD_HALF
		cv.z_index      = _pack_count - i
		cv.position     = stage_center - STAGE_CARD_HALF
		cv.modulate     = Color(1, 1, 1, 0)
		cv.scale        = Vector2(0.3, 0.3)
		_card_stage.add_child(cv)
		cv.size = STAGE_CARD_SIZE
		cv.bind_dict(_cur_cards[i])
		cv.apply_scale(STAGE_CARD_FONT)
		cv.set_face_down(true)
		cv.set_interactable(false, false)
		cv.set_preview_enabled(false)  # preview só nas miniaturas de baixo
		cv.visible = false  # só aparece a partir da fase FLY (não vazar sob o pacote)
		_stage_cards.append(cv)

	_run_phases.call_deferred()


func _run_phases() -> void:
	_cur_tier = _compute_pack_tier(_cur_cards)
	await _delay(0.05)
	if _skipped: return

	_phase = Phase.ENTER
	var tw_enter := create_tween()
	tw_enter.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw_enter.tween_property(_pack_root, "scale", Vector2.ONE, 0.55)
	await _delay(0.65)
	if _skipped: return

	_phase = Phase.SHAKE
	_start_tension_aura(_cur_tier)
	var tw_shake := create_tween()
	tw_shake.tween_property(_pack_root, "rotation", deg_to_rad(-2.5), 0.10)
	tw_shake.tween_property(_pack_root, "rotation", deg_to_rad( 2.5), 0.10)
	tw_shake.tween_property(_pack_root, "rotation", deg_to_rad(-1.5), 0.10)
	tw_shake.tween_property(_pack_root, "rotation", deg_to_rad( 1.5), 0.10)
	tw_shake.tween_property(_pack_root, "rotation", deg_to_rad( 0.0), 0.10)
	await _delay(0.85)
	if _skipped: return

	_phase = Phase.SPLIT
	var tw_split := create_tween().set_parallel(true)
	tw_split.tween_property(_pack_top_node, "position:y", -180.0, 0.70).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw_split.tween_property(_pack_top_node, "modulate:a",   0.0,  0.55)
	tw_split.tween_property(_pack_bot_node, "position:y",  300.0, 0.70).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw_split.tween_property(_pack_bot_node, "modulate:a",   0.0,  0.55)
	_screen_flash(Color.WHITE, 0.85)
	_spawn_burst_particles(_burst_color())
	await _delay(0.80)
	if _skipped: return
	_pack_root.visible = false

	_phase = Phase.FLY
	_fade_tension_aura()
	var screen_center := get_viewport_rect().size * 0.5
	for i in _pack_count:
		var card := _stage_cards[i]
		card.visible = true
		var arc  := _arc_position(i)
		var rot  := _arc_rotation(i)
		var target_pos := screen_center + arc - STAGE_CARD_HALF
		var tw := create_tween().set_parallel(true)
		tw.tween_property(card, "position", target_pos, 0.90).set_delay(i * 0.04).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "rotation", deg_to_rad(rot), 0.90).set_delay(i * 0.04).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale",    Vector2.ONE, 0.55).set_delay(i * 0.04).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "modulate:a", 1.0, 0.35).set_delay(i * 0.04)
	await _delay(1.00)
	if _skipped: return

	_phase = Phase.STACK
	for i in _pack_count:
		var card   := _stage_cards[i]
		var spos   := _stack_position(i)
		var target := screen_center + spos - STAGE_CARD_HALF
		var tw := create_tween().set_parallel(true)
		tw.tween_property(card, "position", target, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "rotation", 0.0,    0.40).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _delay(0.80)
	if _skipped: return

	_present_front()


func _delay(seconds: float) -> Signal:
	return get_tree().create_timer(seconds).timeout


func _arc_position(i: int) -> Vector2:
	var denom := float(maxi(1, _pack_count - 1))
	var angle := deg_to_rad(-110.0 + 220.0 * float(i) / denom)
	return Vector2(cos(angle) * 280.0, sin(angle) * 280.0 * 0.55 - 60.0)


func _arc_rotation(i: int) -> float:
	return (float(i) - float(_pack_count - 1) * 0.5) * 14.0


func _stack_position(i: int) -> Vector2:
	var off := float(i - _revealed) * 3.0
	return Vector2(off, -off)


func _spawn_burst_particles(col: Color = C_GOLD_GLOW, z: int = 0) -> void:
	var center := get_viewport_rect().size * 0.5
	for _i in 36:
		var p := ColorRect.new()
		var sz := randf_range(6.0, 12.0)
		p.custom_minimum_size = Vector2(sz, sz)
		p.color    = Color(col, 0.95)
		p.position = center - Vector2(sz, sz) * 0.5
		p.z_index  = z
		_card_stage.add_child(p)
		var bx := randf_range(-620.0, 620.0)
		var by := randf_range(-620.0, 620.0)
		var d  := randf_range(0.0, 0.14)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(p, "position",   center + Vector2(bx, by), 1.0).set_delay(d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, 0.8).set_delay(d + 0.18)
		tw.tween_callback(p.queue_free).set_delay(d + 1.0)


# Clarão de tela cheia (no "estalo" do pacote). Some sozinho.
func _screen_flash(col: Color = Color.WHITE, peak: float = 0.85, z: int = 0) -> void:
	var f := ColorRect.new()
	f.name         = "ScreenFlash"
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.color        = Color(col.r, col.g, col.b, 0.0)
	f.z_index      = z
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	_opening_view.add_child(f)
	var tw := create_tween()
	tw.tween_property(f, "color:a", peak, 0.06).set_trans(Tween.TRANS_SINE)
	tw.tween_property(f, "color:a", 0.0,  0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(f.queue_free)


# ─────────────────────────────────────────────────────────────────────────────
# AURA DE TENSÃO — pista de raridade (cor = teto do pacote, com fake-out)
# ─────────────────────────────────────────────────────────────────────────────
# Avalia de cima pra baixo: o melhor item do pacote define o tier.
func _compute_pack_tier(cards: Array) -> int:
	var has_top   := false   # místico, ou foil de lendária/mística → arco-íris
	var has_leg   := false
	var rare_n    := 0
	var has_foil  := false   # foil de comum/rara
	for c: Dictionary in cards:
		var rarity := str(c.get("rarity", "COMMON")).to_upper()
		var foil   := bool(c.get("is_foil", false))
		match rarity:
			"MYSTIC":    has_top = true
			"LEGENDARY": has_leg = true
			"RARE":      rare_n += 1
		if foil:
			if rarity == "LEGENDARY" or rarity == "MYSTIC":
				has_top = true
			else:
				has_foil = true
	if has_top:
		return Tier.RAINBOW
	if has_leg:
		return Tier.GOLD
	if rare_n >= 2 or has_foil:
		return Tier.PURPLE
	return Tier.BLUE


func _ensure_aura() -> void:
	if is_instance_valid(_aura):
		return
	_aura = ColorRect.new()
	_aura.name           = "TensionAura"
	_aura.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	_aura.size           = TENSION_AURA_SIZE
	_aura.pivot_offset   = TENSION_AURA_SIZE * 0.5
	_aura_mat            = ShaderMaterial.new()
	_aura_mat.shader     = TENSION_SHADER
	_aura.material       = _aura_mat
	_opening_view.add_child(_aura)
	_opening_view.move_child(_aura, 0)   # atrás do pacote e das cartas


# Build-up: sobe a aura em azul; se o tier for maior, evolui pra cor real (fake-out).
func _start_tension_aura(tier: int) -> void:
	_ensure_aura()
	_aura.visible  = true
	_aura.scale    = Vector2.ONE
	_aura.position = get_viewport_rect().size * 0.5 - TENSION_AURA_SIZE * 0.5
	_aura_mat.set_shader_parameter("aura_color",  TIER_COLOR[Tier.BLUE])
	_aura_mat.set_shader_parameter("rainbow_mix", 0.0)
	_aura_mat.set_shader_parameter("intensity",   0.0)

	_kill_aura_tweens()
	var bt := create_tween()
	bt.tween_property(_aura_mat, "shader_parameter/intensity", 1.10, 0.40) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if tier > Tier.BLUE:
		bt.tween_interval(0.30)               # segura o azul (suspense)
		bt.tween_callback(_flash_to_tier.bind(tier))
	_aura_tws.append(bt)


# Lampejo que "muda a cor" — o momento que faz o coração disparar.
func _flash_to_tier(tier: int) -> void:
	if not is_instance_valid(_aura_mat):
		return
	# Intensidade: pico forte (overshoot) e depois assenta num brilho alto.
	var it := create_tween()
	it.tween_property(_aura_mat, "shader_parameter/intensity", 2.2, 0.12) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	it.tween_property(_aura_mat, "shader_parameter/intensity", 1.5, 0.30) \
		.set_trans(Tween.TRANS_SINE)

	# Cor (e arco-íris) evoluem em paralelo, começando junto com o pico.
	var ct := create_tween().set_parallel(true)
	ct.tween_property(_aura_mat, "shader_parameter/aura_color", TIER_COLOR[tier], 0.30)
	if tier == Tier.RAINBOW:
		ct.tween_property(_aura_mat, "shader_parameter/rainbow_mix", 1.0, 0.40)

	# Punch de escala e volta.
	var st := create_tween()
	st.tween_property(_aura, "scale", Vector2(1.30, 1.30), 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	st.tween_property(_aura, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_SINE)

	_aura_tws.append_array([it, ct, st])


func _kill_aura_tweens() -> void:
	for tw in _aura_tws:
		if is_instance_valid(tw):
			tw.kill()
	_aura_tws.clear()


func _fade_tension_aura() -> void:
	if not is_instance_valid(_aura):
		return
	_kill_aura_tweens()
	var ot := create_tween()
	ot.tween_property(_aura_mat, "shader_parameter/intensity", 0.0, 0.55)
	ot.tween_callback(func() -> void:
		if is_instance_valid(_aura):
			_aura.visible = false)
	_aura_tws.append(ot)


# Cor das partículas do burst (arco-íris cai no dourado, que lê bem em partícula).
func _burst_color() -> Color:
	if _cur_tier == Tier.RAINBOW:
		return C_GOLD_GLOW
	return TIER_COLOR[_cur_tier]


# Cor/força do shine de revelação, por carta (não por pacote): quanto mais rara,
# mais forte; foil soma um extra.
func _card_shine_params(card: Dictionary) -> Dictionary:
	var rarity := str(card.get("rarity", "COMMON")).to_upper()
	var foil   := bool(card.get("is_foil", false))
	var color  := Color(0.90, 0.95, 1.00)
	var inten  := 0.45
	match rarity:
		"RARE":      color = Color(0.45, 0.62, 1.00); inten = 0.95
		"LEGENDARY": color = TIER_COLOR[Tier.GOLD];   inten = 1.30
		"MYSTIC":    color = Color(0.85, 0.55, 1.00); inten = 1.60
	if foil:
		inten += 0.50
		color  = color.lightened(0.20)
	return {"color": color, "intensity": inten}


# Sobrepõe um shine que varre a carta uma vez (banda diagonal) e some.
func _spawn_reveal_shine(cv: Control, card: Dictionary) -> void:
	var p := _card_shine_params(card)
	var shine := ColorRect.new()
	shine.name         = "RevealShine"
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = CARD_SHINE_SHADER
	mat.set_shader_parameter("shine_color", p.color)
	mat.set_shader_parameter("intensity",   p.intensity)
	mat.set_shader_parameter("progress",    -0.25)
	shine.material = mat
	cv.add_child(shine)
	var tw := create_tween()
	tw.tween_property(mat, "shader_parameter/progress", 1.25, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(mat, "shader_parameter/intensity", 0.0, 0.18)
	tw.tween_callback(shine.queue_free)


# ─────────────────────────────────────────────────────────────────────────────
# REVEAL — fluxo de 2 cliques: a carta da frente VIRA, depois SAI
# ─────────────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if _phase != Phase.REVEAL or _revealed >= _pack_count:
		return
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var cv := _stage_cards[_revealed] as CardView
	if not cv.get_global_rect().has_point(mb.global_position):
		return
	get_viewport().set_input_as_handled()
	if _front_flipped:
		_dismiss_front()    # 2º clique: a carta sai e a próxima entra virada p/ baixo
	else:
		_flip_front()       # 1º clique: vira a carta da frente


# Apresenta a carta da frente virada p/ baixo, já com o fogo da raridade aceso.
func _present_front() -> void:
	if _revealed >= _pack_count:
		_show_finish()
		return
	_front_flipped = false
	var cv := _stage_cards[_revealed] as CardView
	cv.visible  = true
	cv.modulate = Color.WHITE
	cv.scale    = Vector2.ONE
	cv.rotation = 0.0
	cv.z_index  = Z_FRONT_CARD
	cv.set_face_down(true)
	_apply_card_fire(cv, _cur_cards[_revealed])
	_phase = Phase.REVEAL
	_hint_lbl.text    = "Clique para virar"
	_hint_lbl.visible = true


# 1º clique — vira a carta (mantém o fogo) e revela. Dourado+ ganha reveal dramático.
func _flip_front() -> void:
	_phase = Phase.NONE
	_hint_lbl.visible = false
	var idx := _revealed
	var cv := _stage_cards[idx] as CardView
	if _card_fire_mode(_cur_cards[idx]) >= Fire.MIXED:
		_flip_front_dramatic(cv, idx)
	else:
		_flip_front_simple(cv, idx)


func _flip_front_simple(cv: CardView, idx: int) -> void:
	var tw := create_tween()
	tw.tween_property(cv, "scale:x", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		cv.set_face_down(false)
		_spawn_reveal_shine(cv, _cur_cards[idx])
	)
	tw.tween_property(cv, "scale:x", 1.0, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_on_front_flipped.bind(idx))


# Reveal dramático (lendária+): escurece o resto, tremida, 3 viradas e impacto.
func _flip_front_dramatic(cv: CardView, idx: int) -> void:
	_dramatic_dark = _show_dramatic_darken()
	var tw := create_tween()
	# aproxima + tremida (antecipação)
	tw.tween_property(cv, "scale", Vector2(1.08, 1.08), 0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_property(cv, "rotation", deg_to_rad( 3.0), 0.05)
	tw.tween_property(cv, "rotation", deg_to_rad(-3.0), 0.06)
	tw.tween_property(cv, "rotation", deg_to_rad( 2.0), 0.05)
	tw.tween_property(cv, "rotation", deg_to_rad(-2.0), 0.05)
	tw.tween_property(cv, "rotation", 0.0,              0.05)
	# 3 viradas; revela no meio da última
	for spin in 3:
		tw.tween_property(cv, "scale:x", 0.0,  0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(_dramatic_mid.bind(cv, idx, spin))
		tw.tween_property(cv, "scale:x", 1.08, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# impacto
	tw.tween_callback(_dramatic_impact.bind(idx))
	tw.tween_property(cv, "scale", Vector2(1.16, 1.16), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(cv, "scale", Vector2.ONE,          0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_on_front_flipped.bind(idx))


# Meio de cada virada: só na última (spin 2) a carta efetivamente revela.
func _dramatic_mid(cv: CardView, idx: int, spin: int) -> void:
	if spin == 2:
		cv.set_face_down(false)
		_spawn_reveal_shine(cv, _cur_cards[idx])


func _dramatic_impact(idx: int) -> void:
	_screen_flash(Color.WHITE, 0.5, Z_IMPACT_FLASH)
	_spawn_burst_particles(_card_shine_params(_cur_cards[idx]).color, Z_IMPACT_BURST)


# Escurece tudo menos a carta (que fica acima, no Z_FRONT_CARD).
func _show_dramatic_darken() -> ColorRect:
	var dark := ColorRect.new()
	dark.name         = "DramaticDarken"
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark.color        = Color(0, 0, 0, 0)
	dark.z_index      = Z_DARKEN
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	_opening_view.add_child(dark)
	create_tween().tween_property(dark, "color:a", 0.82, 0.30)
	return dark


func _clear_dramatic_darken() -> void:
	if not is_instance_valid(_dramatic_dark):
		_dramatic_dark = null
		return
	var d := _dramatic_dark
	_dramatic_dark = null
	var tw := create_tween()
	tw.tween_property(d, "color:a", 0.0, 0.25)
	tw.tween_callback(d.queue_free)


func _on_front_flipped(idx: int) -> void:
	if _skipped:
		return
	_front_flipped = true
	if idx < _progress_dots.size():
		_progress_dots[idx].color = C_GOLD
	_add_reveal_thumb(_cur_cards[idx])
	_phase = Phase.REVEAL
	_hint_lbl.text    = "Clique para avançar"
	_hint_lbl.visible = true


# 2º clique — a carta (e seu fogo) sai; a próxima é apresentada virada p/ baixo.
func _dismiss_front() -> void:
	_phase = Phase.NONE
	_hint_lbl.visible = false
	_clear_dramatic_darken()
	var cv := _stage_cards[_revealed] as CardView
	_remove_card_fire(cv)
	var dtw := create_tween().set_parallel(true)
	dtw.tween_property(cv, "position:y", cv.position.y - 300.0, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	dtw.tween_property(cv, "modulate:a", 0.0, 0.30)
	dtw.tween_property(cv, "scale", cv.scale * 0.82, 0.30)
	dtw.chain().tween_callback(func() -> void: cv.visible = false)

	_revealed += 1
	if _revealed >= _pack_count:
		# Último: deixa a saída terminar antes de montar o resumo (evita conflito de tween).
		await get_tree().create_timer(0.34).timeout
		if _skipped:
			return
		_show_finish()
		return
	_restack_remaining()
	_present_front()


# ─────────────────────────────────────────────────────────────────────────────
# FOGO POR CARTA — pista de raridade (azul / misturado / prismático)
# ─────────────────────────────────────────────────────────────────────────────
func _card_fire_mode(card: Dictionary) -> int:
	var rarity := str(card.get("rarity", "COMMON")).to_upper()
	var foil   := bool(card.get("is_foil", false))
	if rarity == "MYSTIC" or (rarity == "LEGENDARY" and foil):
		return Fire.PRISM
	if rarity == "LEGENDARY":
		return Fire.MIXED
	if rarity == "RARE" or foil:
		return Fire.BLUE
	return Fire.NONE


# Acende o fogo da carta (substitui se já houver). Sem fogo p/ comum não-foil.
func _apply_card_fire(cv: Control, card: Dictionary) -> void:
	_remove_card_fire(cv)
	var mode := _card_fire_mode(card)
	if mode == Fire.NONE:
		return
	var fire := ColorRect.new()
	fire.name         = "CardFire"
	fire.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fire.size     = STAGE_CARD_SIZE + FIRE_GROW * 2.0
	fire.position = -FIRE_GROW
	var mat := ShaderMaterial.new()
	mat.shader = CARD_FIRE_SHADER
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("overlay_px", fire.size)
	mat.set_shader_parameter("card_px", STAGE_CARD_SIZE)
	mat.set_shader_parameter("intensity", _fire_intensity(mode))
	fire.material = mat
	cv.add_child(fire)
	cv.move_child(fire, 0)   # atrás do conteúdo: chamas lambem as bordas, arte fica limpa
	fire.modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(fire, "modulate:a", 1.0, 0.35)


func _fire_intensity(mode: int) -> float:
	match mode:
		Fire.PRISM: return 1.5
		Fire.MIXED: return 1.25
	return 1.0


func _remove_card_fire(cv: Control) -> void:
	var fire := cv.get_node_or_null("CardFire")
	if fire:
		fire.queue_free()


func _clear_all_card_fire() -> void:
	for cv in _stage_cards:
		_remove_card_fire(cv)


# Adiciona a miniatura da carta revelada à esteira inferior (com animação de entrada).
func _add_reveal_thumb(card_dict: Dictionary) -> void:
	var thumb_wrap := Control.new()
	thumb_wrap.custom_minimum_size = THUMB_WRAP_SIZE
	thumb_wrap.clip_contents = true
	_reveal_rail.add_child(thumb_wrap)
	var cv_thumb: CardView = CARD_VIEW_SCENE.instantiate()
	cv_thumb.scale = Vector2(THUMB_SCALE, THUMB_SCALE)
	thumb_wrap.add_child(cv_thumb)
	cv_thumb.bind_dict(card_dict)
	cv_thumb.apply_scale(THUMB_SCALE)
	thumb_wrap.modulate   = Color(1, 1, 1, 0)
	thumb_wrap.position.y = 14.0
	var ttw := create_tween().set_parallel(true)
	ttw.tween_property(thumb_wrap, "modulate:a",  1.0, 0.3)
	ttw.tween_property(thumb_wrap, "position:y",  0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_finish() -> void:
	_phase               = Phase.NONE
	_hint_lbl.visible    = false
	_skip_btn.visible    = false
	_rail_scroll.visible = false
	_clear_all_card_fire()
	_clear_dramatic_darken()
	_showcase_cards()
	_finish_row.visible  = true
	_update_finish_btn()


# Disposição final: traz todas as cartas para o centro, ampliadas e com preview no
# hover (PreviewLayer). Substitui a esteira de miniaturas ao concluir o pacote.
func _showcase_cards() -> void:
	var n := _stage_cards.size()
	if n == 0:
		return
	var vp := get_viewport_rect().size
	var cols := mini(n, 4)
	var rows := int(ceil(float(n) / float(cols)))
	var gap := 22.0
	# Maior escala que ainda cabe entre a barra de contagem e a linha de conclusão.
	var avail_w := vp.x - 120.0
	var avail_h := vp.y - 240.0
	var full_w := cols * STAGE_CARD_SIZE.x + (cols - 1) * gap
	var full_h := rows * STAGE_CARD_SIZE.y + (rows - 1) * gap
	var card_scale := minf(1.0, minf(avail_w / full_w, avail_h / full_h))
	var dw := STAGE_CARD_SIZE.x * card_scale
	var dh := STAGE_CARD_SIZE.y * card_scale
	var grid_top := vp.y * 0.5 - (rows * dh + (rows - 1) * gap) * 0.5

	for i in n:
		var card := _stage_cards[i] as CardView
		var row := i / cols
		var col := i % cols
		var in_row := cols if row < rows - 1 else (n - row * cols)
		var row_left := vp.x * 0.5 - (in_row * dw + (in_row - 1) * gap) * 0.5
		var center := Vector2(
			row_left + col * (dw + gap) + dw * 0.5,
			grid_top  + row * (dh + gap) + dh * 0.5)

		card.visible = true
		card.set_face_down(false)
		card.set_preview_enabled(true)
		card.modulate = Color.WHITE
		card.z_index  = i
		var tw := create_tween().set_parallel(true)
		tw.tween_property(card, "position", center - STAGE_CARD_HALF, 0.45).set_delay(i * 0.04).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2(card_scale, card_scale), 0.45).set_delay(i * 0.04).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "rotation", 0.0, 0.3).set_delay(i * 0.04)


# Pular: revela todas as cartas restantes de uma vez, mandando-as direto à esteira.
func _on_skip_pressed() -> void:
	if _skipped:
		return
	_skipped = true
	_phase = Phase.NONE
	_hint_lbl.visible = false
	_pack_root.visible = false
	_fade_tension_aura()
	_clear_all_card_fire()
	_clear_dramatic_darken()
	for c in _stage_cards:
		c.visible = false
	for i in _progress_dots.size():
		_progress_dots[i].color = C_GOLD
	_revealed = _pack_count
	# O resumo (showcase) já reexibe todas as cartas de cara para cima na grade.
	_show_finish()


func _restack_remaining() -> void:
	var screen_center := get_viewport_rect().size * 0.5
	for i in range(_revealed, _pack_count):
		var card   := _stage_cards[i]
		var spos   := _stack_position(i)
		var target := screen_center + spos - STAGE_CARD_HALF
		var tw := create_tween()
		tw.tween_property(card, "position", target, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ─────────────────────────────────────────────────────────────────────────────
# UI UPDATE
# ─────────────────────────────────────────────────────────────────────────────
func _update_purchase_ui() -> void:
	if _gold_lbl:
		_gold_lbl.text = str(_gold)

	var max_buy := mini(10, _max_affordable())
	_qty = clampi(_qty, 1, maxi(1, max_buy))
	if _qty_lbl:
		_qty_lbl.text = str(_qty)

	var total := _qty * _pack_price
	if _total_lbl:
		_total_lbl.add_theme_color_override("font_color",
			C_GOLD_GLOW if total <= _gold else Color(0.92, 0.32, 0.22))
		_total_lbl.text = str(total)

	var no_collection := _selected.is_empty()
	if _minus_btn: _minus_btn.disabled = no_collection or (_qty <= 1)
	if _plus_btn:  _plus_btn.disabled  = no_collection or (_qty >= max_buy)
	if _max_btn:   _max_btn.disabled   = no_collection or (max_buy <= 0)
	if _buy_btn:
		_buy_btn.disabled = no_collection or (max_buy <= 0 or total > _gold)
		if no_collection:
			_buy_btn.text = "Indisponível"
		elif max_buy <= 0:
			_buy_btn.text = "Ouro Insuficiente"
		elif _qty == 1:
			_buy_btn.text = "⚔  Abrir Pacote"
		else:
			_buy_btn.text = "⚔  Abrir %d Pacotes" % _qty


func _update_finish_btn() -> void:
	var more := _cur_pack_idx < _packs_queue.size() - 1
	_next_pack_btn.text = "Próximo Pacote →" if more else "✓  Concluir"


func _max_affordable() -> int:
	if _pack_price <= 0:
		return 10
	return maxi(0, _gold / _pack_price)


func _change_qty(delta: int) -> void:
	var max_buy := mini(10, _max_affordable())
	_qty = clampi(_qty + delta, 1, maxi(1, max_buy))
	_update_purchase_ui()


func _set_qty_max() -> void:
	_qty = maxi(1, mini(10, _max_affordable()))
	_update_purchase_ui()


# ─────────────────────────────────────────────────────────────────────────────
# NAVIGATION
# ─────────────────────────────────────────────────────────────────────────────
func _show_shop() -> void:
	_shop_view.visible    = true
	_opening_view.visible = false
	_update_purchase_ui()


func _show_opening(packs: Array) -> void:
	_packs_queue  = packs
	_cur_pack_idx = 0
	_shop_view.visible    = false
	_opening_view.visible = true
	_start_pack(0)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_buy_pressed() -> void:
	if _selected.is_empty():
		return
	var collection_id := str(_selected.get("id", ""))
	if collection_id == "":
		push_warning("[BoosterShop] Coleção selecionada sem id.")
		return

	# Trava a UI enquanto o backend processa as aberturas.
	_buy_btn.disabled = true
	_buy_btn.text = "Abrindo..."

	# O backend valida o ouro, desconta e devolve as cartas — uma chamada por pacote.
	var packs: Array = []
	for _i in _qty:
		var res := await ApiClient.open_booster(collection_id)
		if not res.ok or not res.data is Dictionary:
			push_warning("[BoosterShop] Falha ao abrir pacote: %s" % res.error)
			break
		_gold = int(res.data.get("remainingGold", _gold))
		var raw_cards: Variant = res.data.get("cards", [])
		var pack: Array = []
		if raw_cards is Array:
			for c in raw_cards:
				if c is Dictionary:
					pack.append(_map_api_card(c))
		if not pack.is_empty():
			packs.append(pack)

	if packs.is_empty():
		# Nenhum pacote aberto (erro/saldo) — volta a loja com o estado real.
		_update_purchase_ui()
		return
	_show_opening(packs)


func _on_opening_exit() -> void:
	# Ouro e cartas já foram aplicados no backend ao abrir; só voltamos para a loja.
	_show_shop()


func _on_next_pack() -> void:
	_cur_pack_idx += 1
	if _cur_pack_idx >= _packs_queue.size():
		_show_shop()
	else:
		_start_pack(_cur_pack_idx)


# ─────────────────────────────────────────────────────────────────────────────
# MODAIS DE INFORMAÇÃO — probabilidades + catálogo de cartas
# ─────────────────────────────────────────────────────────────────────────────
# Fecha o modal ao clicar fora do painel (na área escurecida do véu).
func _on_veil_input(event: InputEvent, modal: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		modal.visible = false


func _open_odds_modal() -> void:
	_build_odds_content()
	_odds_modal.visible = true


# Monta as linhas de probabilidade por raridade + garantia + foil. Contagens vêm da
# coleção selecionada (/catalog/collections); pesos são o espelho do backend.
func _build_odds_content() -> void:
	for c in _odds_content.get_children():
		c.queue_free()

	# Peso total das raridades que entram no sorteio (peso > 0 e com cartas na coleção).
	var total_weight := 0
	var total_cards  := 0
	for r: String in RARITY_ORDER:
		total_cards += _rarity_count(r)
		if int(RARITY_WEIGHTS.get(r, 0)) > 0 and _rarity_count(r) > 0:
			total_weight += int(RARITY_WEIGHTS[r])

	var sub := _lbl(_odds_content, "%s — %d cartas no total" % [_sel_name, total_cards],
		_font_regular, 11, C_PARCHMENT_D)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Uma linha por raridade presente na coleção.
	for r: String in RARITY_ORDER:
		var count := _rarity_count(r)
		if count <= 0:
			continue
		var weight := int(RARITY_WEIGHTS.get(r, 0))
		var chance_txt := "Fora do booster"
		if weight > 0 and total_weight > 0:
			chance_txt = "%.1f%%" % (100.0 * float(weight) / float(total_weight))
		_odds_content.add_child(_make_odds_row(r, count, chance_txt))

	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = C_BORDER
	_odds_content.add_child(div)

	# Notas: garantia de rara + chance de foil + como o sorteio funciona.
	var rar_plural := str(RARITY_LABEL.get(GUARANTEED_RARITY, "Raras"))
	var rar_word := rar_plural if GUARANTEED_COUNT != 1 else rar_plural.trim_suffix("s")
	var g := _lbl(_odds_content, "✦  Pelo menos %d %s garantida por pacote." % [GUARANTEED_COUNT, rar_word],
		_font_regular, 11, C_GOLD_GLOW)
	g.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var f := _lbl(_odds_content, "✧  %d%% de chance de cada carta vir foil (brilhante)." % FOIL_CHANCE_PCT,
		_font_regular, 11, C_PARCHMENT_D)
	f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var p := _lbl(_odds_content, "As %d cartas do pacote são sorteadas por peso de raridade." % PACK_SIZE,
		_font_regular, 10, C_GOLD_DIM)
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _make_odds_row(rarity: String, count: int, chance_txt: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(10, 10)
	dot.color = _odds_rarity_color(rarity)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	_lbl(row, str(RARITY_LABEL.get(rarity, rarity)), _font_regular, 12, C_GOLD_GLOW)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_lbl(row, "%d cartas" % count, _font_regular, 10, C_GOLD_DIM)
	var ch := _lbl(row, chance_txt, _font_black, 13, C_GOLD_GLOW)
	ch.custom_minimum_size = Vector2(96, 0)
	ch.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return row


func _odds_rarity_color(rarity: String) -> Color:
	match rarity:
		"RARE":      return C_RARE_RARE
		"LEGENDARY": return C_RARE_LEGENDARY
		"MYSTIC":    return Color(0.6, 0.1, 0.8)
	return C_RARE_COMMON


# Contagem de cartas da raridade na coleção selecionada (dados da API).
func _rarity_count(rarity: String) -> int:
	if _selected.is_empty():
		return 0
	return int(_selected.get(str(RARITY_COUNT_KEY.get(rarity, "")), 0))


func _open_cards_modal() -> void:
	# Abre na hora; a grade preenche em segundo plano (uma vez por sessão).
	_cards_modal.visible = true
	if _cards_grid_built or _cards_building:
		return
	_build_cards_grid()


# Mostra todas as cartas que podem vir na coleção. Fonte: catálogo local
# (taldorian_origins.json via Collection) — set base do jogo. Ordena por raridade e nome.
# Constrói em lotes por frame: a UI fica responsiva e as cartas surgem progressivamente.
func _build_cards_grid() -> void:
	_cards_building = true
	for c in _cards_grid.get_children():
		c.queue_free()

	var cards: Array = Collection.all_card_dicts.duplicate()
	cards.sort_custom(_sort_cards)

	# Espera um frame para o layout do painel resolver antes de medir a largura.
	await get_tree().process_frame
	var disp := GRID_CARD_BASE * GRID_CARD_SCALE
	var avail_w: float = _cards_grid.get_parent().size.x
	if avail_w <= 0.0:
		avail_w = 1080.0
	var sep := 14.0
	_cards_grid.columns = maxi(1, int((avail_w + sep) / (disp.x + sep)))

	for i in cards.size():
		_add_grid_card(cards[i], disp)
		_cards_count_lbl.text = "%s · carregando %d / %d…" % [_sel_name, i + 1, cards.size()]
		if (i + 1) % CARDS_BUILD_BATCH == 0:
			await get_tree().process_frame
			# Sai do servidor de cena destruído (troca de cena no meio do load).
			if not is_instance_valid(_cards_grid):
				_cards_building = false
				return

	_cards_count_lbl.text = "%s · %d cartas" % [_sel_name, cards.size()]
	_cards_grid_built = true
	_cards_building = false


# Wrap entra na árvore ANTES da CardView ser bindada — os @onready da CardView só
# existem após o _ready, que só roda quando ela está dentro da árvore (ver _add_reveal_thumb).
func _add_grid_card(card_dict: Dictionary, disp: Vector2) -> void:
	var wrap := Control.new()
	wrap.custom_minimum_size = disp
	wrap.clip_contents = true
	_cards_grid.add_child(wrap)
	var cv: CardView = CARD_VIEW_SCENE.instantiate()
	wrap.add_child(cv)
	cv.scale = Vector2(GRID_CARD_SCALE, GRID_CARD_SCALE)
	cv.bind_dict(card_dict)
	cv.apply_scale(GRID_CARD_SCALE)
	cv.set_face_down(false)
	cv.set_interactable(false, false)
	cv.set_preview_enabled(false)


func _sort_cards(a: Dictionary, b: Dictionary) -> bool:
	var ra := RARITY_ORDER.find(str(a.get("rarity", "COMMON")))
	var rb := RARITY_ORDER.find(str(b.get("rarity", "COMMON")))
	if ra != rb:
		return ra < rb
	return str(a.get("name", "")) < str(b.get("name", ""))


# ─────────────────────────────────────────────────────────────────────────────
# BUILDERS — dynamic content (collection cards, pack panel)
# ─────────────────────────────────────────────────────────────────────────────
func _build_coll_card(c: Dictionary, selected: bool) -> PanelContainer:
	var unlocked := bool(c.get("active", false))
	var title    := str(c.get("name", "Coleção"))
	var eyebrow  := _coll_eyebrow(c)
	var desc     := _coll_description(c)
	var set_size := _coll_total(c)
	var price    := int(c.get("boosterPrice", PACK_PRICE))
	var art_path := _art_path_for(str(c.get("artKey", "")))

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.078, 0.098, 0.188, 1.0)
	style.border_color = C_BORDER if unlocked else Color(C_BORDER, 0.4)
	style.set_border_width_all(1)
	if unlocked:
		style.shadow_color = Color(C_GOLD, 0.12)
		style.shadow_size  = 8
	# Destaque da coleção selecionada (compra).
	if selected:
		style.border_color = C_GOLD
		style.set_border_width_all(2)
		style.shadow_color = Color(C_GOLD, 0.30)
		style.shadow_size  = 12
	card.add_theme_stylebox_override("panel", style)
	if not unlocked:
		card.modulate = Color(1, 1, 1, 0.42)

	var margin := MarginContainer.new()
	for side: int in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		margin.add_theme_constant_override(["margin_left","margin_right","margin_top","margin_bottom"][side], [18,18,16,16][side])
	card.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	var thumb_tex: Texture2D = null
	if art_path != "" and ResourceLoader.exists(art_path):
		thumb_tex = load(art_path)
	if thumb_tex != null:
		var thumb_rect := TextureRect.new()
		thumb_rect.custom_minimum_size = Vector2(72, 100)
		thumb_rect.texture = thumb_tex
		thumb_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		thumb_rect.clip_contents = true
		thumb_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(thumb_rect)
	else:
		var thumb := ColorRect.new()
		thumb.custom_minimum_size = Vector2(72, 100)
		thumb.color = Color(C_GOLD, 0.14)
		thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(thumb)
		var thumb_lbl := Label.new()
		thumb_lbl.text = "TCG"
		thumb_lbl.add_theme_color_override("font_color", Color(C_GOLD, 0.45))
		thumb_lbl.add_theme_font_override("font", _font_black)
		thumb_lbl.add_theme_font_size_override("font_size", 11)
		thumb_lbl.set_anchors_preset(Control.PRESET_CENTER)
		thumb.add_child(thumb_lbl)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	hbox.add_child(info)

	_lbl(info, eyebrow.to_upper(), _font_regular, 9, C_GOLD_DIM)

	var ttl := Label.new()
	ttl.text = title
	ttl.add_theme_color_override("font_color", C_GOLD_GLOW if unlocked else Color(0.929, 0.875, 0.784))
	ttl.add_theme_font_override("font", _font_black)
	ttl.add_theme_font_size_override("font_size", 14)
	info.add_child(ttl)

	var dlbl := Label.new()
	dlbl.text = desc
	dlbl.add_theme_color_override("font_color", C_PARCHMENT_D)
	dlbl.add_theme_font_override("font", _font_regular)
	dlbl.add_theme_font_size_override("font_size", 10)
	dlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(dlbl)

	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 16)
	info.add_child(meta)
	for t: String in [str(set_size) + " cartas", str(price) + " ouro / pacote"]:
		_lbl(meta, t, _font_regular, 10, C_GOLD_DIM)

	if not unlocked:
		var lock := Label.new()
		lock.text = "🔒  EM BREVE"
		lock.add_theme_color_override("font_color", C_PARCHMENT_D)
		lock.add_theme_font_override("font", _font_regular)
		lock.add_theme_font_size_override("font_size", 9)
		lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(lock)

	# Coleções ativas são clicáveis para virar a seleção de compra. Os filhos ignoram
	# o mouse para que o gui_input do card receba o clique em qualquer ponto.
	if unlocked:
		_propagate_ignore_mouse(card)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(_on_collection_gui_input.bind(c))
	return card


func _propagate_ignore_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_propagate_ignore_mouse(child)


func _on_collection_gui_input(event: InputEvent, c: Dictionary) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_select_collection(c)


# Troca a coleção em destaque (compra) e atualiza toda a UI dependente.
func _select_collection(c: Dictionary) -> void:
	if not _selected.is_empty() and str(c.get("id", "")) == str(_selected.get("id", "")):
		return
	_selected   = c
	_sel_name   = str(c.get("name", _sel_name))
	_art_path   = _art_path_for(str(c.get("artKey", "")))
	_pack_price = int(c.get("boosterPrice", PACK_PRICE))
	_qty        = 1
	_build_collection_list()   # re-renderiza para mover o destaque
	_build_shop_pack_visual()
	_fill_pack_info_row()
	_update_purchase_ui()


func _build_split_pack(parent: Control, collection_name: String) -> void:
	var half_h := 140.0
	var pack_w := 200.0

	_pack_top_node = Control.new()
	_pack_top_node.custom_minimum_size = Vector2(pack_w, half_h)
	_pack_top_node.size        = Vector2(pack_w, half_h)
	_pack_top_node.clip_contents = true
	_pack_top_node.position    = Vector2(0, 0)
	parent.add_child(_pack_top_node)
	var top_inner := _make_pack_panel(collection_name, pack_w, half_h * 2)
	top_inner.position = Vector2(0, 0)
	_pack_top_node.add_child(top_inner)

	_pack_bot_node = Control.new()
	_pack_bot_node.custom_minimum_size = Vector2(pack_w, half_h)
	_pack_bot_node.size        = Vector2(pack_w, half_h)
	_pack_bot_node.clip_contents = true
	_pack_bot_node.position    = Vector2(0, half_h)
	parent.add_child(_pack_bot_node)
	var bot_inner := _make_pack_panel(collection_name, pack_w, half_h * 2)
	bot_inner.position = Vector2(0, -half_h)
	_pack_bot_node.add_child(bot_inner)


func _make_pack_panel(collection_name: String, w: float, h: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(w, h)
	panel.size = Vector2(w, h)
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.08, 0.10, 0.22)
	style.border_color = C_GOLD
	style.set_border_width_all(2)
	style.shadow_color = Color(C_GOLD, 0.3)
	style.shadow_size  = 14
	panel.add_theme_stylebox_override("panel", style)

	# Collection art fills the panel when available (else fall back to emblem layout)
	if _art_path != "":
		var img := TextureRect.new()
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		img.texture = load(_art_path)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.clip_contents = true
		panel.add_child(img)
		return panel

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)

	_lbl(vbox, "TALDORIAN TCG", _font_regular, 9, C_GOLD_GLOW).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ttl := _lbl(vbox, collection_name, _font_black, 12, C_GOLD_GLOW)
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ttl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var emb := Label.new()
	emb.text = "✦"
	emb.add_theme_color_override("font_color", Color(C_GOLD, 0.6))
	emb.add_theme_font_override("font", _font_black)
	emb.add_theme_font_size_override("font_size", 56)
	emb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emb.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	vbox.add_child(emb)

	_lbl(vbox, str(PACK_SIZE) + " CARTAS", _font_regular, 9, C_GOLD_DIM).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return panel


# ─────────────────────────────────────────────────────────────────────────────
# BUTTON STYLING HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _style_btn(btn: Button, col: Color, col_hover: Color, bg: Color, border: Color) -> void:
	btn.add_theme_color_override("font_color",       col)
	btn.add_theme_color_override("font_hover_color", col_hover)
	var n := StyleBoxFlat.new()
	n.bg_color = bg; n.border_color = border; n.set_border_width_all(1)
	n.set_content_margin(SIDE_LEFT, 16); n.set_content_margin(SIDE_RIGHT, 16)
	n.set_content_margin(SIDE_TOP, 10);  n.set_content_margin(SIDE_BOTTOM, 10)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = bg.lightened(0.08); h.border_color = C_GOLD
	btn.add_theme_stylebox_override("normal",  n)
	btn.add_theme_stylebox_override("hover",   h)
	btn.add_theme_stylebox_override("pressed", n)


func _style_small_btn(btn: Button) -> void:
	btn.add_theme_color_override("font_color",          C_GOLD)
	btn.add_theme_color_override("font_hover_color",    C_GOLD_GLOW)
	btn.add_theme_color_override("font_disabled_color", Color(C_GOLD, 0.3))
	var n := StyleBoxFlat.new()
	n.bg_color = C_SURFACE; n.border_color = C_BORDER_STR; n.set_border_width_all(1)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.12, 0.14, 0.28); h.border_color = C_GOLD
	btn.add_theme_stylebox_override("normal",   n)
	btn.add_theme_stylebox_override("hover",    h)
	btn.add_theme_stylebox_override("pressed",  n)
	btn.add_theme_stylebox_override("disabled", StyleBoxFlat.new())


func _style_cta_btn(btn: Button) -> void:
	btn.add_theme_color_override("font_color",          Color(0.94, 0.84, 0.62))
	btn.add_theme_color_override("font_hover_color",    Color(1.00, 0.95, 0.78))
	btn.add_theme_color_override("font_pressed_color",  C_GOLD)
	btn.add_theme_color_override("font_disabled_color", Color(C_PARCHMENT_D, 0.5))
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.22, 0.14, 0.04); n.border_color = Color(C_GOLD, 0.65)
	n.set_border_width_all(1); n.set_content_margin_all(18)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.30, 0.20, 0.06); h.border_color = C_GOLD
	var d := StyleBoxFlat.new()
	d.bg_color = Color(0.06, 0.07, 0.14, 0.5); d.border_color = C_BORDER
	d.set_border_width_all(1); d.set_content_margin_all(18)
	btn.add_theme_stylebox_override("normal",   n)
	btn.add_theme_stylebox_override("hover",    h)
	btn.add_theme_stylebox_override("pressed",  n)
	btn.add_theme_stylebox_override("disabled", d)


# ─────────────────────────────────────────────────────────────────────────────
# MISC HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _lbl(parent: Control, text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"COMMON":    return C_RARE_COMMON
		"RARE":      return C_RARE_RARE
		"LEGENDARY": return C_RARE_LEGENDARY
	return C_RARE_COMMON
