extends Control

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")

signal hero_add_requested(hero: Hero)
signal hero_preview_requested(hero: Hero)

var _active_classes: Array[String] = []
var _search_text: String = ""
var _deck_snapshot: DeckData = null

const HERO_CARD_SCENE := preload("res://scenes/ui/deck_builder/components/picker_hero_card.tscn")


func _ready() -> void:
	_get_search_input().text_changed.connect(_on_search_changed)
	_build_class_chips()
	_rebuild_list()


func refresh(deck: DeckData) -> void:
	_deck_snapshot = deck
	_rebuild_list()


func _build_class_chips() -> void:
	var chip_row := _get_chip_row()
	for child in chip_row.get_children():
		child.queue_free()

	var all_chip := _make_chip("Todos", "")
	chip_row.add_child(all_chip)

	var classes := ["BARBARIAN", "WARRIOR", "MONK", "ROGUE", "CLERIC", "RANGER", "GUARDIAN"]
	var labels  := ["Bárbaro",   "Guerreiro","Monge","Ladino","Clérigo","Patrulheiro","Guardião"]
	for i in classes.size():
		chip_row.add_child(_make_chip(labels[i], classes[i]))

	_refresh_chips()


func _make_chip(label: String, class_key: String) -> Button:
	var btn := Button.new()
	btn.text            = label
	btn.toggle_mode     = true
	btn.focus_mode      = Control.FOCUS_NONE
	btn.pressed.connect(func() -> void: _on_chip_pressed(class_key, btn))
	return btn


func _on_chip_pressed(class_key: String, btn: Button) -> void:
	if class_key == "":
		_active_classes.clear()
	else:
		if class_key in _active_classes:
			_active_classes.erase(class_key)
		else:
			_active_classes.append(class_key)
	_refresh_chips()
	_rebuild_list()


func _refresh_chips() -> void:
	var chip_row := _get_chip_row()
	for child in chip_row.get_children():
		if not child is Button:
			continue
		var btn := child as Button
		var is_all_chip := btn == chip_row.get_child(0)
		var active: bool
		if is_all_chip:
			active = _active_classes.is_empty()
		else:
			var idx: int = chip_row.get_children().find(btn)
			var classes: Array[String] = ["BARBARIAN", "WARRIOR", "MONK", "ROGUE", "CLERIC", "RANGER", "GUARDIAN"]
			var class_key: String = classes[idx - 1] if idx > 0 and idx - 1 < classes.size() else ""
			active = class_key in _active_classes
		S.apply_chip(btn, active)


func _on_search_changed(text: String) -> void:
	_search_text = text
	_rebuild_list()


func _rebuild_list() -> void:
	var list := _get_list()
	for child in list.get_children():
		child.queue_free()

	var heroes := Collection.query_heroes(_search_text, _active_classes)
	var hero_count := _deck_snapshot.hero_names.size() if _deck_snapshot else 0
	var at_limit   := hero_count >= DeckData.MAX_HEROES

	for hero in heroes:
		var in_deck := _deck_snapshot != null and _deck_snapshot.has_hero(hero.hero_name)
		var row := HERO_CARD_SCENE.instantiate() as PanelContainer
		list.add_child(row)
		row.bind(hero, in_deck, at_limit and not in_deck)
		row.add_pressed.connect(func(h: Hero) -> void: hero_add_requested.emit(h))
		row.preview_requested.connect(func(h: Hero) -> void: hero_preview_requested.emit(h))


func _get_search_input() -> LineEdit:    return $VBox/SearchRow/SearchInput
func _get_chip_row()     -> HBoxContainer: return $VBox/ChipRow
func _get_list()         -> HFlowContainer: return $VBox/Scroll/List
