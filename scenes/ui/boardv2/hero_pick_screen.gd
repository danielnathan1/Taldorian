# scenes/ui/boardv2/hero_pick_screen.gd
extends Control

const HeroSlotScene := preload("res://scenes/ui/hero_slot/hero_slot.tscn")

@onready var heroes_row    := $HeroesRow
@onready var btn_confirmar := $BtnConfirmar
@onready var waiting_label := $WaitingLabel

var _selected_hero: Hero = null
var _slots: Array = []

func _ready() -> void:
	btn_confirmar.pressed.connect(_on_btn_confirmar_pressed)
	btn_confirmar.disabled = true
	GameBus.state_synced.connect(_on_state_synced)
	if visible:
		_rebuild_heroes()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible and is_node_ready():
		_rebuild_heroes()

func _rebuild_heroes() -> void:
	if GameState.players.is_empty():
		return
	for child in heroes_row.get_children():
		child.queue_free()
	_slots.clear()
	_selected_hero = null
	var local_idx   := NetworkState.local_player_index
	var next_picker := GameState.get_next_hero_pick_player_index()
	var is_my_turn  := (next_picker == local_idx)
	waiting_label.visible = not is_my_turn
	heroes_row.visible    = is_my_turn
	btn_confirmar.visible = is_my_turn
	if not is_my_turn:
		return
	for hero in GameState.players[local_idx].heroes:
		var slot: HeroSlot = HeroSlotScene.instantiate()
		heroes_row.add_child(slot)
		slot.custom_minimum_size = Vector2(0, 0)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		slot.bind(hero)
		if hero.state == Hero.State.ACTIVE:
			slot.slot_clicked.connect(_on_hero_slot_clicked)
		_slots.append(slot)
	_refresh_confirm_button()

func _on_hero_slot_clicked(hero: Hero) -> void:
	if hero.state != Hero.State.ACTIVE:
		return
	_selected_hero = hero
	_refresh_views()
	_refresh_confirm_button()

func _on_btn_confirmar_pressed() -> void:
	if _selected_hero == null:
		return
	var local_idx := NetworkState.local_player_index
	var slot_idx  := GameState.players[local_idx].heroes.find(_selected_hero)
	if slot_idx < 0:
		return
	GameState.rpc_id(1, "rpc_submit_hero", slot_idx)
	btn_confirmar.disabled = true

func _refresh_views() -> void:
	for slot in _slots:
		if not is_instance_valid(slot):
			continue
		slot.refresh()
		if slot.hero == _selected_hero:
			slot.modulate = Color(1.3, 1.3, 0.6)

func _refresh_confirm_button() -> void:
	btn_confirmar.disabled = (_selected_hero == null)

func _on_state_synced() -> void:
	if visible:
		_rebuild_heroes()
