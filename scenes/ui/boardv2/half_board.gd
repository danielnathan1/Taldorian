extends Control

@export var player_side: String = "player"  # "player" | "opponent"

const HeroSlotScene := preload("res://scenes/ui/hero_slot/hero_slot.tscn")
const CardViewScene  := preload("res://scenes/ui/card_view/card_view.tscn")

const SLOT_COLORS = {
	"hero":        Color(0.545, 0.471, 0.353, 0.48),
	"active":      Color(0.784, 0.627, 0.282, 1.0),
	"arsenal":     Color(0.29, 0.471, 0.831, 1.0),
	"deck":        Color(0.478, 0.416, 0.29, 0.5),
	"grave":       Color(0.541, 0.227, 0.165, 0.48),
	"combat_plr":  Color(0.227, 0.478, 0.29, 0.42),
	"combat_opp":  Color(0.165, 0.29, 0.541, 0.45),
}

var _hero_slots:           Array = []
var _active_hero_view:     Node  = null  # HeroSlot
var _arsenal_texture_rect: TextureRect   = null
var _grave_texture_rect:   TextureRect   = null
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
@onready var _hp_label         := $HalfInner/MainRow/ColD_ActiveHero/ActiveHeroWrap/HPContainer/HPLabel
@onready var _arsenal_slot_container     := $HalfInner/MainRow/ColB_Arsenal/ArsenalWrap/ArsenalSlot
@onready var _active_hero_slot_container := $HalfInner/MainRow/ColD_ActiveHero/ActiveHeroWrap/ActiveHeroSlot
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

	_grave_texture_rect = TextureRect.new()
	_grave_texture_rect.layout_mode = 1
	_grave_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grave_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_grave_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_grave_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grave_texture_rect.visible = false
	_grave_slot.add_child(_grave_texture_rect)


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
	_hp_label.scale        = Vector2(-1, -1)
	_deck_count_badge.scale = Vector2(-1, -1)
	# call_deferred ensures pivot is set AFTER the first layout pass,
	# when size is already correct (is_node_ready() alone is not enough).
	_update_mirror_pivot.call_deferred()

func _update_mirror_pivot() -> void:
	_half_inner.pivot_offset       = size / 2.0
	_hp_label.pivot_offset         = _hp_label.size / 2.0
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
	_hp_label.text = "%d / %d" % [current, maximum]

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

func set_arsenal_texture(texture: Texture2D) -> void:
	_arsenal_texture_rect.texture = texture
	_arsenal_texture_rect.visible = texture != null

func add_combat_card_view(card, sleeve: Texture2D, is_opp_card: bool) -> Node:
	var view = CardViewScene.instantiate()
	view.custom_minimum_size = Vector2(62, 87)
	_combat_cards.add_child(view)
	view.bind(card)
	if sleeve:
		view.set_sleeve(sleeve)
	if is_opp_card:
		view.is_opponent = true
	return view

func clear_combat_cards() -> void:
	for child in _combat_cards.get_children():
		child.queue_free()

func set_deck_count(count: int) -> void:
	_deck_count_badge.text = str(count)

func set_graveyard_texture(texture: Texture2D) -> void:
	_grave_texture_rect.texture = texture
	_grave_texture_rect.visible = texture != null

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

func add_combat_slot(is_opponent: bool) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(62, 87)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0.039, 0, 0.18) if not is_opponent else Color(0, 0, 0.055, 0.20)
	style.set_border_width_all(2)
	style.border_color = SLOT_COLORS["combat_opp" if is_opponent else "combat_plr"]
	style.set_corner_radius_all(5)
	slot.add_theme_stylebox_override("panel", style)
	_combat_cards.add_child(slot)
	return slot
