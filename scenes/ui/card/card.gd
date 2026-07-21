extends Control
class_name CardVisual

## Tamanho "ideal" (design) da fonte da descrição; o auto-fit encolhe a partir daqui.
var _desc_base_px: int = 22

# ── Textures ─────────────────────────────────────────────────────────────────
@export var frame_texture: Texture2D:
	set(value):
		frame_texture = value
		if is_inside_tree(): %FrameTexture.texture = value

@export var art_texture: Texture2D:
	set(value):
		art_texture = value
		if is_inside_tree():
			%ArtTexture.texture = value
			_update_art_visibility()

@export var element_texture: Texture2D:
	set(value):
		element_texture = value
		if is_inside_tree(): %ElementSymbol.texture = value

# ── Texto / números ───────────────────────────────────────────────────────────
@export var title: String = "":
	set(value):
		title = value
		if is_inside_tree(): %TitleLabel.text = value

@export_multiline var description: String = "":
	set(value):
		description = value
		if is_inside_tree(): _render_desc()

@export var card_type: String = "":
	set(value):
		card_type = value
		if is_inside_tree():
			%TypeTopLabel.text    = value
			%TypeBottomLabel.text = value

@export_enum("C","U","R","L") var rarity: String = "C":
	set(value):
		rarity = value
		if is_inside_tree(): %RarityLabel.text = value

@export var attack: int = 0:
	set(value):
		attack = value
		if is_inside_tree(): %AtkValueLabel.text = _format_signed(value)

@export var defense: int = 0:
	set(value):
		defense = value
		if is_inside_tree(): %DefValueLabel.text = str(value)


func _ready() -> void:
	%FrameTexture.texture  = frame_texture
	%ArtTexture.texture    = art_texture
	%ElementSymbol.texture = element_texture
	%TitleLabel.text       = title       if title       != "" else %TitleLabel.text
	# Captura o tamanho-base da fonte (design) antes de qualquer encolhimento e reajusta
	# a descrição quando a caixa muda de tamanho.
	_desc_base_px = maxi(1, %DescLabel.get_theme_font_size("normal_font_size"))
	%DescLabel.resized.connect(_render_desc)
	_render_desc()
	%TypeTopLabel.text     = card_type   if card_type   != "" else %TypeTopLabel.text
	%TypeBottomLabel.text  = card_type   if card_type   != "" else %TypeBottomLabel.text
	%RarityLabel.text      = rarity
	%AtkValueLabel.text    = _format_signed(attack)
	%DefValueLabel.text    = str(defense)
	_update_art_visibility()


## Renderiza a descrição no DescLabel (RichTextLabel): keywords (*palavra*) em negrito,
## símbolos {X} em ícone, bloco centralizado, e a fonte encolhe SÓ se estourar a caixa.
## Descrição vazia mantém o placeholder do editor.
func _render_desc() -> void:
	if not is_inside_tree() or description == "":
		return
	var min_px := maxi(6, _desc_base_px * 5 / 8)
	TextMarkup.fit_rich_label(%DescLabel, _desc_base_px, min_px, _compose_desc)

## Descrição em BBCode centralizada para a fonte [px] (ícones acompanham a fonte).
func _compose_desc(px: int) -> String:
	return "[center]%s[/center]" % TextMarkup.to_bbcode(description, px)


func _update_art_visibility() -> void:
	var has_art := %ArtTexture.texture != null
	%ArtTexture.visible    = has_art
	%FrameTexture.visible  = has_art
	%FallbackLayer.visible = not has_art


## Recebe um Dictionary com os campos da carta (chaves ausentes são ignoradas).
func bind(data: Dictionary) -> void:
	if data.has("frame_texture"):    frame_texture   = data.frame_texture
	if data.has("art_texture"):      art_texture     = data.art_texture
	if data.has("element_texture"):  element_texture = data.element_texture
	if data.has("title"):            title           = data.title
	if data.has("description"):      description     = data.description
	if data.has("card_type"):        card_type       = data.card_type
	if data.has("rarity"):           rarity          = data.rarity
	if data.has("attack"):           attack          = int(data.attack)
	if data.has("defense"):          defense         = int(data.defense)
	if is_inside_tree():
		_update_art_visibility()


func _format_signed(v: int) -> String:
	return "+%d" % v if v >= 0 else str(v)
