extends CanvasLayer

## Emitido quando toda a fila de popups terminou de animar.
## Listeners devem usar CONNECT_ONE_SHOT para não acumular conexões.
signal popup_finished

const HeroSlotScene := preload("res://scenes/ui/hero_slot/hero_slot.tscn")

@onready var _container   := $Overlay/Container
@onready var _title_label := $Overlay/Container/VBoxContainer/TitleLabel
@onready var _hero_art    := $Overlay/Container/VBoxContainer/HeroArt
@onready var _hero_name   := $Overlay/Container/VBoxContainer/HeroNameLabel
@onready var _skill_name  := $Overlay/Container/VBoxContainer/SkillNameLabel

const ANIM_IN  := 0.35
const HOLD     := 1.5
const ANIM_OUT := 0.35

var _queue: Array[Dictionary] = []
var _busy: bool = false
var _hero_slot: HeroSlot = null

func _ready() -> void:
	_build_hero_slot()
	_container.modulate.a = 0.0
	_container.scale = Vector2(0.4, 0.4)
	visible = false

## Substitui a arte solta pela HeroSlot completa (nome, atk/def, habilidades).
## O slot é apenas exibição aqui — ignora clique/hover.
func _build_hero_slot() -> void:
	_hero_slot = HeroSlotScene.instantiate()
	_hero_slot.custom_minimum_size = Vector2(180, 270)
	_hero_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hero_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Insere no lugar da HeroArt e esconde a arte/nome agora redundantes.
	var vbox := _hero_art.get_parent()
	vbox.add_child(_hero_slot)
	vbox.move_child(_hero_slot, _hero_art.get_index())
	_hero_art.visible = false
	_hero_name.visible = false

## Retorna true enquanto há popup sendo exibido ou na fila.
func is_busy() -> bool:
	return _busy

func show_skill(p_hero: Hero, p_skill_name: String) -> void:
	_queue.push_back({ "hero": p_hero, "skill_name": p_skill_name })
	if not _busy:
		_show_next()

func _show_next() -> void:
	if _queue.is_empty():
		_busy = false
		visible = false
		popup_finished.emit()
		return
	_busy = true
	var entry: Dictionary = _queue.pop_front()
	var hero: Hero        = entry["hero"]
	var skill: String     = entry["skill_name"]

	_title_label.text = "✦ Habilidade Ativada! ✦"
	_hero_slot.set_hp_visible(true)
	_hero_slot.bind(hero)
	_skill_name.text  = skill

	_container.modulate.a = 0.0
	_container.scale      = Vector2(0.4, 0.4)
	visible = true

	var tw := create_tween()
	tw.tween_property(_container, "scale",      Vector2.ONE, ANIM_IN).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tw.parallel().tween_property(_container, "modulate:a", 1.0, ANIM_IN).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_interval(HOLD)
	tw.tween_property(_container, "modulate:a", 0.0, ANIM_OUT).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.finished.connect(_show_next, CONNECT_ONE_SHOT)
