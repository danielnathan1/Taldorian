extends PanelContainer

const S                := preload("res://scenes/ui/deck_builder/db_styles.gd")
const CosmeticsPanelGD := preload("res://scenes/ui/deck_builder/components/cosmetics_panel.gd")

signal hero_add_requested(hero: Hero)
signal hero_preview_requested(hero: Hero)
signal card_add_requested(card_name: String)
signal card_remove_requested(card_name: String)
signal card_preview_requested(card_dict: Dictionary)
signal cosmetic_sleeve_changed(sleeve_id: String)
signal cosmetic_playmat_changed(playmat_id: String)

var _active_tab: int = 0

var _tab_cosmetics: Button  = null
var _cosmetics_panel: Control = null

const _HINT_DEFAULT   := "Clique para adicionar ao deck"
const _HINT_COSMETICS := "Escolha sleeve e playmat do deck"


func _ready() -> void:
	add_theme_stylebox_override("panel", S.panel_mid())

	# Cria a aba e o painel de cosméticos em código para evitar dependência do cache do tscn
	_tab_cosmetics = Button.new()
	_tab_cosmetics.text = "✦ Cosméticos"
	_tab_cosmetics.toggle_mode = true
	_tab_cosmetics.layout_mode = 2
	_get_tab_row().add_child(_tab_cosmetics)
	# Move antes do HintLabel (que é o último filho da TabRow)
	_get_tab_row().move_child(_tab_cosmetics, _get_tab_row().get_child_count() - 2)

	_cosmetics_panel = CosmeticsPanelGD.new()
	_cosmetics_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cosmetics_panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_cosmetics_panel.visible = false
	_get_vbox().add_child(_cosmetics_panel)

	# Sinais dos pickers existentes
	_get_tab_heroes().pressed.connect(func() -> void: _switch_tab(0))
	_get_tab_cards().pressed.connect(func() -> void: _switch_tab(1))
	_tab_cosmetics.pressed.connect(func() -> void: _switch_tab(2))

	_get_hero_picker().hero_add_requested.connect(func(h: Hero) -> void: hero_add_requested.emit(h))
	_get_hero_picker().hero_preview_requested.connect(func(h: Hero) -> void: hero_preview_requested.emit(h))
	_get_card_picker().card_add_requested.connect(func(n: String) -> void: card_add_requested.emit(n))
	_get_card_picker().card_remove_requested.connect(func(n: String) -> void: card_remove_requested.emit(n))
	_get_card_picker().card_preview_requested.connect(func(d: Dictionary) -> void: card_preview_requested.emit(d))
	_cosmetics_panel.sleeve_changed.connect(func(id: String) -> void: cosmetic_sleeve_changed.emit(id))
	_cosmetics_panel.playmat_changed.connect(func(id: String) -> void: cosmetic_playmat_changed.emit(id))

	_style_tabs()
	_switch_tab(0)


func set_deck_snapshot(deck: DeckData) -> void:
	_get_hero_picker().refresh(deck)
	_get_card_picker().refresh(deck)
	_cosmetics_panel.refresh(deck)


func set_active_tab(index: int) -> void:
	_switch_tab(index)


func _switch_tab(index: int) -> void:
	_active_tab = index
	_get_hero_picker().visible = (index == 0)
	_get_card_picker().visible = (index == 1)
	_cosmetics_panel.visible   = (index == 2)
	_get_hint_label().text = _HINT_COSMETICS if index == 2 else _HINT_DEFAULT
	_update_tab_styles()


func _style_tabs() -> void:
	for btn: Button in [_get_tab_heroes(), _get_tab_cards(), _tab_cosmetics]:
		btn.add_theme_font_override("font", S.FONT_REG)
		btn.add_theme_font_size_override("font_size", 12)


func _update_tab_styles() -> void:
	S.apply_chip(_get_tab_heroes(),  _active_tab == 0)
	S.apply_chip(_get_tab_cards(),   _active_tab == 1)
	S.apply_chip(_tab_cosmetics,     _active_tab == 2)


func _get_tab_row()    -> HBoxContainer:  return $MarginContainer/VBox/TabRow
func _get_vbox()       -> VBoxContainer:  return $MarginContainer/VBox
func _get_tab_heroes() -> Button:         return $MarginContainer/VBox/TabRow/TabHeroes
func _get_tab_cards()  -> Button:         return $MarginContainer/VBox/TabRow/TabCards
func _get_hint_label() -> Label:          return $MarginContainer/VBox/TabRow/HintLabel
func _get_hero_picker() -> Control:       return $MarginContainer/VBox/HeroPicker
func _get_card_picker() -> Control:       return $MarginContainer/VBox/CardPicker
