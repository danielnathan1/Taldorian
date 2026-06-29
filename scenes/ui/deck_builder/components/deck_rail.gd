extends PanelContainer

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")

signal hero_remove_requested(hero_name: String)
signal card_remove_requested(card_name: String)
signal foil_change_requested(card_name: String)
signal clear_cards_requested

const RAIL_HERO_SLOT_SCENE := preload("res://scenes/ui/deck_builder/components/rail_hero_slot.tscn")
const RAIL_CARD_ROW_SCENE  := preload("res://scenes/ui/deck_builder/components/rail_card_row.tscn")

var _hero_slots: Array = []

@onready var _hero_row: HBoxContainer    = $MarginContainer/VBox/HeroSection/HeroRow
@onready var _heroes_label: Label        = $MarginContainer/VBox/HeroSection/HeroesLabel
@onready var _cards_label: Label         = $MarginContainer/VBox/CardSection/CardHeader/CardsLabel
@onready var _clear_btn: Button          = $MarginContainer/VBox/CardSection/CardHeader/ClearCardsBtn
@onready var _card_list: VBoxContainer   = $MarginContainer/VBox/CardSection/Scroll/CardList


func _ready() -> void:
	add_theme_stylebox_override("panel", S.panel_mid())
	_build_hero_slots()
	_style_labels()
	_clear_btn.pressed.connect(func() -> void: clear_cards_requested.emit())
	S.apply_button_crimson(_clear_btn)


func _build_hero_slots() -> void:
	var row := _hero_row
	for i in DeckData.MAX_HEROES:
		var slot := RAIL_HERO_SLOT_SCENE.instantiate()
		row.add_child(slot)
		_hero_slots.append(slot)
		slot.bind_empty(i)
		var idx := i
		slot.remove_pressed.connect(func(name: String) -> void: hero_remove_requested.emit(name))


func _style_labels() -> void:
	for lbl: Label in [_heroes_label, _cards_label]:
		lbl.add_theme_color_override("font_color", S.C_GOLD)
		lbl.add_theme_font_override("font", S.FONT_BOLD)
		lbl.add_theme_font_size_override("font_size", 11)


func bind(deck: DeckData) -> void:
	_rebuild_heroes(deck)
	_rebuild_cards(deck)
	_update_labels(deck)


func _rebuild_heroes(deck: DeckData) -> void:
	for i in _hero_slots.size():
		var slot = _hero_slots[i]
		if i < deck.hero_names.size():
			var hero := Collection.get_hero_by_name(deck.hero_names[i])
			if hero:
				slot.bind_hero(hero)
			else:
				slot.bind_empty(i)
		else:
			slot.bind_empty(i)


func _rebuild_cards(deck: DeckData) -> void:
	var list := _get_card_list()
	for child in list.get_children():
		child.queue_free()

	var sorted := deck.card_entries.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["name"] as String) < (b["name"] as String))

	for entry in sorted:
		var card_name: String = entry["name"]
		var count: int        = entry["count"]
		var card_dict         := Collection.get_card_dict(card_name)
		var atk: int          = card_dict.get("attack_value", 0)
		var def_v: int        = card_dict.get("defense_value", 0)
		var symbols: Array    = card_dict.get("symbols", [])
		var max_foil: int     = mini(count, _owned_foil(card_name))
		var foil: int         = clampi(int(entry.get("foil", 0)), 0, max_foil)

		var row := RAIL_CARD_ROW_SCENE.instantiate()
		list.add_child(row)
		row.bind(card_name, count, atk, def_v, symbols, foil, max_foil)
		row.remove_pressed.connect(func(n: String) -> void: card_remove_requested.emit(n))
		row.foil_pressed.connect(func(n: String) -> void: foil_change_requested.emit(n))


func _update_labels(deck: DeckData) -> void:
	_heroes_label.text = "HERÓIS  %d/%d" % [deck.hero_names.size(), DeckData.MAX_HEROES]
	var foil_total := 0
	for entry in deck.card_entries:
		var max_foil: int = mini(int(entry["count"]), _owned_foil(entry["name"]))
		foil_total += clampi(int(entry.get("foil", 0)), 0, max_foil)
	var foil_suffix := "  ·  ✦ %d foil" % foil_total if foil_total > 0 else ""
	_cards_label.text  = "CARTAS  %d/%d%s" % [deck.total_cards(), DeckData.MAX_CARDS, foil_suffix]

	var card_color := S.C_GREEN if deck.total_cards() == DeckData.MAX_CARDS else S.C_GOLD
	_cards_label.add_theme_color_override("font_color", card_color)
	var hero_color := S.C_GREEN if deck.hero_names.size() == DeckData.MAX_HEROES else S.C_GOLD
	_heroes_label.add_theme_color_override("font_color", hero_color)


# Quantas cópias foil desta carta o jogador POSSUI (teto para a escolha no deck).
func _owned_foil(card_name: String) -> int:
	var card_id := int(Collection.get_card_dict(card_name).get("id", -1))
	if card_id < 0:
		return 0
	return Collection.get_foil_quantity(card_id)


func _get_card_list() -> VBoxContainer: return _card_list
