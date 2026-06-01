extends Control
class_name CardVisual

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
		if is_inside_tree(): %DescLabel.text = value

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
	%DescLabel.text        = description if description != "" else %DescLabel.text
	%TypeTopLabel.text     = card_type   if card_type   != "" else %TypeTopLabel.text
	%TypeBottomLabel.text  = card_type   if card_type   != "" else %TypeBottomLabel.text
	%RarityLabel.text      = rarity
	%AtkValueLabel.text    = _format_signed(attack)
	%DefValueLabel.text    = str(defense)
	_update_art_visibility()


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
