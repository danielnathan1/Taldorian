extends CanvasLayer

@onready var _container    := $Overlay/Container
@onready var _player_label := $Overlay/Container/VBoxContainer/PlayerLabel
@onready var _card_art     := $Overlay/Container/VBoxContainer/CardArt
@onready var _name_label   := $Overlay/Container/VBoxContainer/CardNameLabel
@onready var _timing_label := $Overlay/Container/VBoxContainer/TimingLabel

const ANIM_IN  := 0.3
const HOLD     := 1.4
const ANIM_OUT := 0.3

var _queue: Array[Dictionary] = []
var _busy: bool = false

signal popup_finished

func _ready() -> void:
	_container.modulate.a = 0.0
	_container.scale = Vector2(0.5, 0.5)
	visible = false

func show_card(p_player_index: int, p_card: Card) -> void:
	_queue.push_back({ "player_index": p_player_index, "card": p_card })
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
	var pidx: int  = entry["player_index"]
	var card: Card = entry["card"]

	_player_label.text = "Você jogou" if pidx == NetworkState.local_player_index else "Oponente jogou"
	_card_art.texture  = card.get_texture()
	_name_label.text   = card.card_name
	_timing_label.text = _timing_str(card.timing)

	_container.modulate.a = 0.0
	_container.scale      = Vector2(0.5, 0.5)
	visible = true

	var tw := create_tween()
	tw.tween_property(_container, "scale",      Vector2.ONE, ANIM_IN).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(_container, "modulate:a", 1.0, ANIM_IN).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_interval(HOLD)
	tw.tween_property(_container, "modulate:a", 0.0, ANIM_OUT).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.finished.connect(_show_next, CONNECT_ONE_SHOT)

func _timing_str(t: Card.TimingType) -> String:
	match t:
		Card.TimingType.ACTION:       return "Ação"
		Card.TimingType.BONUS_ACTION: return "Ação Bônus"
		Card.TimingType.REACTION:     return "Reação"
	return ""
