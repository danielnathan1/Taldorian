# scenes/ui/hero_slot/hero_slot.gd
class_name HeroSlot
extends PanelContainer

@onready var name_label    := $VBoxContainer/HeroName
@onready var class_label   := $VBoxContainer/HeroClass
@onready var hp_bar        := $VBoxContainer/HPBar
@onready var hp_label      := $VBoxContainer/HPLabel
@onready var symbols_label := $VBoxContainer/SymbolsLabel
@onready var art           := $VBoxContainer/CardArt

signal slot_clicked(hero: Hero)

var hero: Hero = null

func bind(p_hero: Hero) -> void:
	hero = p_hero
	name_label.text    = hero.hero_name
	class_label.text   = Hero.HeroClass.keys()[hero.hero_class]
	hp_bar.max_value   = hero.max_hp
	hp_bar.value       = hero.current_hp
	hp_label.text      = "%d / %d" % [hero.current_hp, hero.max_hp]
	symbols_label.text = " ".join(hero.symbols_required)
	art.texture = p_hero.get_texture()
	_update_state_style()

func refresh() -> void:
	if hero:
		bind(hero)  # relê os dados do herói

func _update_state_style() -> void:
	match hero.state:
		Hero.State.ACTIVE:    modulate = Color.WHITE
		Hero.State.EXHAUSTED: modulate = Color(1, 1, 1, 0.4)
		Hero.State.DEFEATED:  modulate = Color(0.4, 0.4, 0.4, 0.3)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		slot_clicked.emit(hero)
