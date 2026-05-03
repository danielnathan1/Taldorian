# scenes/ui/hero_slot/hero_slot.gd
class_name HeroSlot
extends Control

@onready var hp_bar         := $StateOverlay/HPBar
@onready var hp_label       := $StateOverlay/HPBar/HPLabel
@onready var art            := $CardArt
@onready var exhausted_veil := $StateOverlay/ExhaustedVeil

signal slot_clicked(hero: Hero)

var hero: Hero = null
var is_opponent: bool = false
var _face_down: bool = false
var _sleeve_texture: Texture2D = preload("res://assets/sleve/default.png")
var _hover_pending_hide: bool = false

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	if hero == null or hero.state == Hero.State.DEFEATED:
		return
	if is_opponent and _face_down:
		return
	_hover_pending_hide = false
	GameBus.card_hovered.emit({ "type": "hero", "hero": hero })

func _on_mouse_exited() -> void:
	_hover_pending_hide = true
	get_tree().create_timer(0.08).timeout.connect(func():
		if _hover_pending_hide:
			_hover_pending_hide = false
			GameBus.card_hover_ended.emit()
	)

func set_sleeve_texture(texture: Texture2D) -> void:
	_sleeve_texture = texture
	if _face_down:
		_apply_texture()

func bind(p_hero: Hero) -> void:
	hero = p_hero
	hp_bar.max_value  = hero.max_hp
	hp_bar.value      = hero.current_hp
	hp_label.text     = "%d/%d" % [hero.current_hp, hero.max_hp]
	_apply_texture()
	_update_state_style()
	_apply_face_down_visibility()

func refresh() -> void:
	if hero:
		bind(hero)

func set_face_down(value: bool) -> void:
	_face_down = value
	_apply_texture()
	_apply_face_down_visibility()

func _apply_face_down_visibility() -> void:
	hp_bar.visible = not _face_down
	exhausted_veil.visible = (not _face_down) and hero != null and (hero.state == Hero.State.EXHAUSTED)

func _apply_texture() -> void:
	art.texture = _sleeve_texture if _face_down else (hero.get_texture() if hero else null)

func _update_state_style() -> void:
	match hero.state:
		Hero.State.ACTIVE:    modulate = Color.WHITE
		Hero.State.EXHAUSTED: modulate = Color(1, 1, 1, 0.4)
		Hero.State.DEFEATED:  modulate = Color(0.4, 0.4, 0.4, 0.3)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		slot_clicked.emit(hero)
