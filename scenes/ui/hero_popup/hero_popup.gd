extends CanvasLayer

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

func _ready() -> void:
	_container.modulate.a = 0.0
	_container.scale = Vector2(0.4, 0.4)
	visible = false

func show_skill(p_hero: Hero, p_skill_name: String) -> void:
	_queue.push_back({ "hero": p_hero, "skill_name": p_skill_name })
	if not _busy:
		_show_next()

func _show_next() -> void:
	if _queue.is_empty():
		_busy = false
		visible = false
		return
	_busy = true
	var entry: Dictionary = _queue.pop_front()
	var hero: Hero        = entry["hero"]
	var skill: String     = entry["skill_name"]

	_title_label.text = "✦ Habilidade Ativada! ✦"
	_hero_art.texture = hero.get_texture()
	_hero_name.text   = hero.hero_name
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
