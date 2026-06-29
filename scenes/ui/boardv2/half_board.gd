extends Control

@export var player_side: String = "player"  # "player" | "opponent"

const HeroSlotScene  := preload("res://scenes/ui/hero_slot/hero_slot.tscn")
const CardViewScene  := preload("res://scenes/ui/card_view/card_view.tscn")
const TokenViewScene := preload("res://scenes/ui/token_view/token_view.tscn")

const SLOT_COLORS = {
	"hero":        Color(0.545, 0.471, 0.353, 0.48),
	"active":      Color(0.784, 0.627, 0.282, 1.0),
	"arsenal":     Color(0.29, 0.471, 0.831, 1.0),
	"deck":        Color(0.478, 0.416, 0.29, 0.5),
	"grave":       Color(0.541, 0.227, 0.165, 0.48),
	"combat_plr":  Color(0.227, 0.478, 0.29, 0.42),
	"combat_opp":  Color(0.165, 0.29, 0.541, 0.45),
}

signal graveyard_clicked(side: String)

var _hero_slots:           Array = []
var _active_hero_view:     Node  = null  # HeroSlot
var _arsenal_texture_rect: TextureRect   = null
var _arsenal_card_view:    CardView      = null   # usado quando face_up = true
var _grave_card_view:      CardView      = null
var _glow_tween: Tween

@onready var _bg               := $PlaymatBackground
@onready var _glow_line        := $TurnGlowLine
@onready var _name_label       := $PlayerNameLabel
@onready var _half_inner       := $HalfInner
@onready var _combat_band      := $HalfInner/CombatBand
@onready var _combat_cards     := $HalfInner/CombatBand/CombatBandInner/CombatCards
@onready var _main_row         := $HalfInner/MainRow
@onready var _heroes_row       := $HalfInner/MainRow/ColC_Heroes/HeroesRow
@onready var _hp_bar           := $HalfInner/MainRow/ColD_ActiveHero/ActiveHeroWrap/HPContainer/HPBar
@onready var _arsenal_slot_container     := $HalfInner/MainRow/ColB_Arsenal/ArsenalWrap/ArsenalSlot
@onready var _active_hero_slot_container := $HalfInner/MainRow/ColD_ActiveHero/ActiveHeroWrap/ActiveHeroSlot
@onready var _tokens_column    := $HalfInner/MainRow/ColE_Tokens
@onready var _tokens_list      := $HalfInner/MainRow/ColE_Tokens/TokensWrap/TokensSlot/TokensScroll/TokensList
@onready var _deck_count_badge := $HalfInner/MainRow/ColA_DeckGrave/DeckWrap/DeckSlot/CountBadge
@onready var _deck_sleeve      := $HalfInner/MainRow/ColA_DeckGrave/DeckWrap/DeckSlot/DeckSleeve
@onready var _grave_slot       := $HalfInner/MainRow/ColA_DeckGrave/GraveWrap/GraveSlot

func set_playmat(tex: Texture2D) -> void:
	_bg.texture = tex
	_bg.visible = tex != null

func _ready() -> void:
	_apply_side_config()
	_setup_dynamic_nodes()
	if player_side == "opponent":
		_apply_opponent_mirror()

func _setup_dynamic_nodes() -> void:
	_active_hero_view = HeroSlotScene.instantiate()
	_active_hero_view.layout_mode = 1
	_active_hero_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_active_hero_view.visible = false
	_active_hero_slot_container.add_child(_active_hero_view)

	_arsenal_texture_rect = TextureRect.new()
	_arsenal_texture_rect.layout_mode = 1
	_arsenal_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arsenal_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_arsenal_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_arsenal_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arsenal_texture_rect.visible = false
	_arsenal_slot_container.add_child(_arsenal_texture_rect)

	# CardView completa para quando a carta está virada para cima (ex: Ecos do Passado)
	_arsenal_card_view = CardViewScene.instantiate()
	_arsenal_card_view.layout_mode = 1
	_arsenal_card_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arsenal_card_view.custom_minimum_size = Vector2(62, 87)
	_arsenal_card_view.set_interactable(false, false)
	_arsenal_card_view.visible = false
	_arsenal_slot_container.add_child(_arsenal_card_view)
	_arsenal_card_view.apply_scale(0.5)
	_set_mouse_ignore_recursive(_arsenal_card_view)

	# CardView for the top card — all children set to IGNORE so clicks fall through to _grave_slot
	_grave_card_view = CardViewScene.instantiate()
	_grave_card_view.layout_mode = 1
	_grave_card_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grave_card_view.custom_minimum_size = Vector2(62, 87)
	_grave_card_view.set_interactable(false, false)
	_grave_card_view.visible = false
	_grave_slot.add_child(_grave_card_view)
	_grave_card_view.apply_scale(0.5)
	_set_mouse_ignore_recursive(_grave_card_view)

	# GraveSlot (PanelContainer) owns the click — CardView never blocks it
	_grave_slot.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and not event.double_click:
			graveyard_clicked.emit(player_side)
	)


func _apply_side_config() -> void:
	if player_side == "player":
		_name_label.text = "Você"
		_apply_combat_style("combat_plr")
		_glow_line.anchors_preset = 10  # top edge
		_name_label.set_anchors_preset(3)  # bottom-left
		_name_label.offset_left = 14
		_name_label.offset_top = -22
		_name_label.offset_right = 120
		_name_label.offset_bottom = -8
	else:
		_name_label.text = "Oponente"
		_apply_combat_style("combat_opp")
		_glow_line.set_anchors_preset(12)  # bottom edge
		_name_label.set_anchors_preset(1)  # top-left
		_name_label.offset_left = 14
		_name_label.offset_top = 8
		_name_label.offset_right = 120
		_name_label.offset_bottom = 22

func _apply_opponent_mirror() -> void:
	_half_inner.scale = Vector2(-1, -1)
	_deck_count_badge.scale = Vector2(-1, -1)
	# call_deferred ensures pivot is set AFTER the first layout pass,
	# when size is already correct (is_node_ready() alone is not enough).
	_update_mirror_pivot.call_deferred()

func _update_mirror_pivot() -> void:
	# Espelha em torno do centro do PRÓPRIO _half_inner — não do HalfBoard.
	# O _half_inner (VBox) tem altura mínima maior que a metade da tela, então o
	# Godot o estica além do pai; usar size/2 (do HalfBoard) deslocava o flip no eixo Y.
	_half_inner.pivot_offset       = _half_inner.size / 2.0
	_deck_count_badge.pivot_offset = _deck_count_badge.size / 2.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and player_side == "opponent" and is_node_ready():
		_update_mirror_pivot()

func _apply_combat_style(slot_type: String) -> void:
	var color: Color = SLOT_COLORS[slot_type]
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.1)
	style.set_border_width_all(1)
	style.border_color = Color(color.r, color.g, color.b, 0.35)
	style.set_corner_radius_all(5)
	_combat_band.add_theme_stylebox_override("panel", style)

func set_turn_active(active: bool) -> void:
	var target_alpha := 1.0 if active else 0.0
	if _glow_tween:
		_glow_tween.kill()
	_glow_tween = create_tween()
	_glow_tween.tween_property(_glow_line, "color:a", target_alpha, 0.4)

func set_hp(current: int, maximum: int) -> void:
	_hp_bar.max_value = maximum
	_hp_bar.value = current

# ── API pública para boardv2 ──────────────────────────────────────────────────

func spawn_hero_slots(heroes: Array) -> Array:
	for child in _heroes_row.get_children():
		child.queue_free()
	_hero_slots.clear()
	for hero in heroes:
		var slot = HeroSlotScene.instantiate()
		_heroes_row.add_child(slot)
		slot.bind(hero)
		_hero_slots.append(slot)
	return _hero_slots

func get_hero_slots() -> Array:
	return _hero_slots

func get_active_hero_view() -> Node:
	return _active_hero_view

func get_arsenal_panel() -> Control:
	return _arsenal_slot_container

func set_arsenal_visible(is_visible: bool) -> void:
	_arsenal_texture_rect.visible = is_visible
	_arsenal_card_view.visible    = false

func set_arsenal_sleeve(texture: Texture2D) -> void:
	# Exibe o verso da carta (sleeve) — comportamento padrão
	_arsenal_texture_rect.texture = texture
	_arsenal_texture_rect.visible = texture != null
	_arsenal_card_view.visible    = false

func set_arsenal_face_up(card: Card) -> void:
	# Exibe a CardView completa (face-up) — apenas quando efeito explicitamente define isso
	_arsenal_card_view.bind(card)
	_arsenal_card_view.visible    = true
	_arsenal_texture_rect.visible = false

# Mantido por compatibilidade — redireciona para sleeve
func set_arsenal_texture(texture: Texture2D) -> void:
	set_arsenal_sleeve(texture)

func add_combat_card_view(card, sleeve: Texture2D, is_opp_card: bool) -> Node:
	var view = CardViewScene.instantiate()
	view.custom_minimum_size = Vector2(64, 96)  # 2:3 — bate com a arte/moldura (KEEP_ASPECT_COVERED)
	_combat_cards.add_child(view)
	view.bind(card)
	view.apply_scale(0.55)
	if sleeve:
		view.set_sleeve(sleeve)
	if is_opp_card:
		view.is_opponent = true
	return view

const _ELEMENT_ICONS := {
	"fogo":  "res://assets/icons/elements/fire.png",
	"terra": "res://assets/icons/elements/earth.png",
	"agua":  "res://assets/icons/elements/water.png",
	"wind":  "res://assets/icons/elements/wind.png",
	"lightning": "res://assets/icons/elements/lightning.png",
}

## Adiciona apenas um ícone de símbolo à combat zone (ex.: símbolo escolhido via
## Fragmento Arcano) — sem carta, só pra deixar claro a ambos qual símbolo entrou na
## chain. Usa um slot do mesmo tamanho das cartas (68x96) e centraliza o ícone, pra
## alinhar com as CardViews na mesma fila (HBox).
func add_combat_symbol_view(symbol_id: String, _is_opp: bool) -> Node:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(68, 96)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path: String = _ELEMENT_ICONS.get(symbol_id, "")
	if path != "" and ResourceLoader.exists(path):
		icon.texture = load(path)
	holder.add_child(icon)
	_combat_cards.add_child(holder)
	return holder

func clear_combat_cards() -> void:
	for child in _combat_cards.get_children():
		child.queue_free()

# ── Tokens ────────────────────────────────────────────────────────────────────
# Área puramente visual. A lógica de quem cria o token (heróis/cartas) e suas
# regras vivem no core — esta cena apenas exibe o que receber.

func get_tokens_container() -> Control:
	return _tokens_list

## Adiciona uma TokenView ao painel de tokens e a retorna (o board conecta o clique).
func add_token_view(p_token: Token, count: int = 1, activable: bool = false) -> TokenView:
	var view: TokenView = TokenViewScene.instantiate()
	view.custom_minimum_size = Vector2(70, 105)
	_tokens_list.add_child(view)
	view.bind(p_token, count)
	view.apply_scale(0.5)
	view.set_activable(activable)
	return view

func clear_tokens() -> void:
	for child in _tokens_list.get_children():
		child.queue_free()

func set_tokens_visible(is_visible: bool) -> void:
	_tokens_column.visible = is_visible

func get_tokens_global_center() -> Vector2:
	return _tokens_list.get_global_rect().get_center() as Vector2

func set_deck_count(count: int) -> void:
	_deck_count_badge.text = str(count)

func set_graveyard_card(card: Card) -> void:
	if card == null:
		_grave_card_view.visible = false
		return
	_grave_card_view.bind(card)
	_grave_card_view.visible = true

func set_deck_sleeve(texture: Texture2D) -> void:
	_deck_sleeve.texture = texture

# ── posições globais para animações ──────────────────────────────────────────

func get_deck_global_center() -> Vector2:
	return _deck_sleeve.get_global_rect().get_center() as Vector2

func get_graveyard_global_center() -> Vector2:
	return _grave_slot.get_global_rect().get_center() as Vector2

func get_combat_cards_global_center() -> Vector2:
	return _combat_cards.get_global_rect().get_center() as Vector2

func get_arsenal_global_center() -> Vector2:
	return _arsenal_slot_container.get_global_rect().get_center() as Vector2

func _set_mouse_ignore_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_ignore_recursive(child)

func add_combat_slot(is_opponent: bool) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(68, 96)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0.039, 0, 0.18) if not is_opponent else Color(0, 0, 0.055, 0.20)
	style.set_border_width_all(2)
	style.border_color = SLOT_COLORS["combat_opp" if is_opponent else "combat_plr"]
	style.set_corner_radius_all(5)
	slot.add_theme_stylebox_override("panel", style)
	_combat_cards.add_child(slot)
	return slot
