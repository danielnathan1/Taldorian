class_name CardView
extends Control

const SLEEVE_DEFAULT := preload("res://assets/sleve/default.png")
const FOIL_SHADER    := preload("res://scenes/ui/card_view/foil.gdshader")
const GRAYSCALE_SHADER := preload("res://scenes/ui/card_view/grayscale.gdshader")

@onready var card_content    := $CardContent
@onready var back_rect       := $Back
@onready var _art            := $CardContent/Art
@onready var _card_base      := $CardContent/CardLayoutBase
@onready var _title_lbl      := $CardContent/TitleLabel
@onready var _element_sym    := $CardContent/ElementSymbol
@onready var _desc_lbl       := $CardContent/DescLabel
@onready var _atk_icon       := $CardContent/AtkIcon
@onready var _atk_lbl        := $CardContent/AtkValueLabel
@onready var _def_icon       := $CardContent/DefIcon
@onready var _def_lbl        := $CardContent/DefValueLabel
@onready var _rarity_bg      := $CardContent/RarityBg
@onready var _rarity_lbl     := $CardContent/RarityLabel
@onready var _type_footer    := $CardContent/CardTypeFooter

signal card_clicked(card: Card)
signal card_double_clicked(card: Card)

var card: Card = null
var selected: bool = false
var is_opponent: bool = false
var _face_down: bool = false
var _interactable: bool = true
var _preview_enabled: bool = true
var _base_position: Vector2
var _base_rotation_deg: float
var _base_z: int
var _hover_tween: Tween
var _foil_overlay: ColorRect = null
var _grayscale_mat: ShaderMaterial = null
## Tamanho "ideal" da fonte da descrição (design × escala). O auto-fit encolhe a partir
## daqui; guardado para o resized recompor sem partir de um valor já reduzido.
var _desc_base_px: int = 8

const _ELEMENT_ICONS := {
	"fogo":  "res://assets/icons/elements/fire.png",
	"terra": "res://assets/icons/elements/earth.png",
	"agua":  "res://assets/icons/elements/water.png",
	"wind":  "res://assets/icons/elements/wind.png",
	"lightning": "res://assets/icons/elements/lightning.png",
	"trevas": "res://assets/icons/elements/dark.png",
}

func _ready() -> void:
	back_rect.texture = SLEEVE_DEFAULT
	_build_foil_overlay()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	# Reajusta a descrição quando a caixa ganha/muda de tamanho (bind pode ocorrer antes
	# do primeiro layout, sem altura válida para medir o overflow).
	_desc_lbl.resized.connect(_refit_desc)

# Overlay cromático no topo do CardContent. Aditivo (ver foil.gdshader): só as
# bandas acendem, o resto da carta aparece normal. Inicia oculto.
func _build_foil_overlay() -> void:
	_foil_overlay = ColorRect.new()
	_foil_overlay.name         = "FoilOverlay"
	_foil_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foil_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = FOIL_SHADER
	_foil_overlay.material = mat
	_foil_overlay.visible  = false
	card_content.add_child(_foil_overlay)

func _update_foil() -> void:
	# Foil anima sozinho pelo TIME do shader; não precisa de _process nem do mouse.
	var on := card != null and card.is_foil and not _face_down
	_foil_overlay.visible = on

func bind(p_card: Card) -> void:
	card = p_card
	_art.texture         = card.get_texture()
	_title_lbl.text      = card.card_name
	_render_desc(_desc_base_px)
	_atk_lbl.text        = _fmt_signed(card.attack_value)
	_def_lbl.text        = str(card.defense_value)
	_rarity_lbl.text     = _rarity_letter(card.rarity)
	_type_footer.text    = _timing_str(card.timing)
	_apply_rarity_style(card.rarity)
	_element_sym.texture = _load_element_icon(card.symbols)
	_element_sym.visible = _element_sym.texture != null
	_update_foil()

## Monta a descrição em BBCode (keywords em negrito, símbolos {X} em ícone), centraliza e
## encolhe a fonte SÓ se estourar a caixa. [base_px] é o tamanho "ideal" (design/escala),
## nunca o já reduzido — guardado em _desc_base_px para o resized recompor corretamente.
func _render_desc(base_px: int) -> void:
	if card == null:
		return
	_desc_base_px = base_px
	var min_px := maxi(4, base_px * 5 / 8)
	TextMarkup.fit_rich_label(_desc_lbl, base_px, min_px, _compose_desc)

## Descrição em BBCode centralizada para a fonte [px] (ícones acompanham a fonte).
func _compose_desc(px: int) -> String:
	return "[center]%s[/center]" % TextMarkup.to_bbcode(_format_description(card), maxi(1, px))

## Refaz o ajuste quando a caixa muda de tamanho, mantendo o tamanho-base pretendido.
func _refit_desc() -> void:
	_render_desc(_desc_base_px)

# Cartas sem efeito têm a descrição (flavor text) exibida entre aspas e em itálico.
func _format_description(p_card: Card) -> String:
	if p_card.effects.is_empty() and p_card.description != "":
		return '[i]"%s"[/i]' % p_card.description
	return p_card.description

func bind_dict(d: Dictionary) -> void:
	var c := Card.new()
	c.card_name     = d.get("name", "")
	c.timing        = Card.TimingType[d.get("timing", "ACTION")]
	c.attack_value  = int(d.get("attack_value", 0))
	c.defense_value = int(d.get("defense_value", 0))
	c.description   = d.get("description", "")
	c.rarity        = Card.Rarity.get(d.get("rarity", "COMMON"), Card.Rarity.COMMON)
	c.is_foil       = d.get("is_foil", false)
	c.art_key       = d.get("art_key", "")
	var syms: Array[String] = []
	for s in d.get("symbols", []):
		syms.append(str(s))
	c.symbols = syms
	# Efeitos: o dict canônico do catálogo (Collection.resolve_card) traz "effects";
	# popular aqui faz a regra de flavor text (aspas quando sem efeito) valer nestes previews.
	for entry in d.get("effects", []):
		var eff := CardEffectRegistry.create(entry.get("id", ""), entry)
		if eff != null:
			c.effects.append(eff)
	bind(c)

func set_sleeve(tex: Texture2D) -> void:
	back_rect.texture = tex if tex else SLEEVE_DEFAULT

func set_selected(value: bool) -> void:
	selected = value
	var base := Color(1.2, 1.2, 0.6) if selected else Color.WHITE
	base.a = modulate.a
	modulate = base

func set_face_down(value: bool) -> void:
	_face_down = value
	back_rect.visible     = value
	card_content.visible  = not value
	_update_foil()

## Liga/desliga o efeito holográfico (foil) desta carta após o bind.
func set_foil(value: bool) -> void:
	if card != null:
		card.is_foil = value
	_update_foil()

## Deixa a carta inteira em preto-e-branco — usado no fichário do Catálogo para cartas
## que o jogador nunca teve. Aplica o shader de dessaturação em TODOS os elementos
## coloridos (arte, moldura, símbolo de elemento, ícones de atk/def) e apaga a cor do
## selo de raridade; false restaura a cor.
func set_grayscale(value: bool) -> void:
	if value and _grayscale_mat == null:
		_grayscale_mat = ShaderMaterial.new()
		_grayscale_mat.shader = GRAYSCALE_SHADER
		_grayscale_mat.set_shader_parameter("amount", 1.0)
	var mat: ShaderMaterial = _grayscale_mat if value else null
	for n: CanvasItem in [_art, _card_base, _element_sym, _atk_icon, _def_icon]:
		n.material = mat
	# O selo de raridade é um Panel (cor via stylebox) — dessatura via modulate.
	_rarity_bg.modulate = Color(0.6, 0.6, 0.6) if value else Color.WHITE

func set_interactable(value: bool, dim_when_blocked: bool = true) -> void:
	_interactable = value
	modulate.a = 1.0 if (value or not dim_when_blocked) else 0.45

func set_preview_enabled(value: bool) -> void:
	_preview_enabled = value

func setup_fan(base_pos: Vector2, rot_deg: float, pivot: Vector2, z: int) -> void:
	_base_position     = base_pos
	_base_rotation_deg = rot_deg
	_base_z            = z
	pivot_offset       = pivot
	position           = base_pos
	rotation_degrees   = rot_deg
	z_index            = z

func apply_scale(factor: float) -> void:
	_title_lbl.add_theme_font_size_override("font_size", int(9 * factor))
	# Descrição: base = 8×fator; o auto-fit define as font-size overrides e encolhe se estourar.
	_render_desc(int(8 * factor))
	_atk_lbl.add_theme_font_size_override("font_size", int(8 * factor))
	_def_lbl.add_theme_font_size_override("font_size", int(8 * factor))
	_rarity_lbl.add_theme_font_size_override("font_size", int(4 * factor))
	_type_footer.add_theme_font_size_override("font_size", int(7 * factor))

func _load_element_icon(symbols: Array[String]) -> Texture2D:
	for sym in symbols:
		var path: String = _ELEMENT_ICONS.get(sym, "")
		if path != "" and ResourceLoader.exists(path):
			return load(path)
	return null

func _animate_hover(hover_in: bool) -> void:
	if _base_z == 0:
		return
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween().set_parallel(true)
	_hover_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if hover_in:
		z_index = 100
		_hover_tween.tween_property(self, "position", _base_position + Vector2(0.0, -40.0), 0.18)
		_hover_tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.18)
	else:
		_hover_tween.tween_property(self, "position", _base_position, 0.18)
		_hover_tween.tween_property(self, "scale", Vector2.ONE, 0.18)
		_hover_tween.chain().tween_callback(func() -> void: z_index = _base_z)

func _on_mouse_entered() -> void:
	if card == null:
		return
	if is_opponent and _face_down:
		return
	if not _preview_enabled:
		return
	GameBus.card_hovered.emit({ "type": "card", "card": card })
	_animate_hover(true)

func _on_mouse_exited() -> void:
	GameBus.card_hover_ended.emit()
	_animate_hover(false)

func _gui_input(event: InputEvent) -> void:
	if not _interactable:
		return
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.double_click:
		card_double_clicked.emit(card)
	else:
		card_clicked.emit(card)

func _timing_str(t: Card.TimingType) -> String:
	match t:
		Card.TimingType.ACTION:       return "Ação"
		Card.TimingType.BONUS_ACTION: return "Ação Bônus"
		Card.TimingType.REACTION:     return "Reação"
	return ""

func _apply_rarity_style(r: Card.Rarity) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(100)
	style.bg_color = _rarity_color(r)
	_rarity_bg.add_theme_stylebox_override("panel", style)

func _rarity_color(r: Card.Rarity) -> Color:
	match r:
		Card.Rarity.COMMON:    return Color(0.5, 0.5, 0.5)
		Card.Rarity.RARE:      return Color(0.2, 0.4, 0.85)
		Card.Rarity.LEGENDARY: return Color(0.85, 0.68, 0.1)
		Card.Rarity.MYSTIC:    return Color(0.6, 0.1, 0.8)
	return Color(0.5, 0.5, 0.5)

func _rarity_letter(r: Card.Rarity) -> String:
	match r:
		Card.Rarity.COMMON:    return "C"
		Card.Rarity.RARE:      return "R"
		Card.Rarity.LEGENDARY: return "L"
		Card.Rarity.MYSTIC:    return "M"
	return "C"

func _fmt_signed(v: int) -> String:
	return "+%d" % v if v >= 0 else str(v)
