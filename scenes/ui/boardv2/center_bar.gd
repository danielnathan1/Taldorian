extends PanelContainer

signal turn_passed(from_side: String)
signal time_expired()
signal pass_pressed

var time_left: float = 90.0
var is_running: bool = false
var current_turn: String = "opponent"

@onready var _turn_gem := $HBox/LeftSection/TurnGem
@onready var _turn_label := $HBox/LeftSection/TurnVBox/TurnLabel
@onready var _phase_label := $HBox/LeftSection/TurnVBox/PhaseLabel
@onready var _clock := $HBox/ClockSection/ClockDisplay
@onready var _clock_sub := $HBox/ClockSection/ClockSub
@onready var _pass_btn := $HBox/RightSection/PassTurnButton
@onready var _gem_tween: Tween

func _ready() -> void:
	_pass_btn.pressed.connect(_on_pass_pressed)
	_update_turn_ui()
	start_timer()
	_start_gem_pulse()

func _process(delta: float) -> void:
	if not is_running:
		return
	time_left -= delta
	_update_clock_display()
	if time_left <= 0.0:
		is_running = false
		emit_signal("time_expired")

func start_timer() -> void:
	time_left = 90.0
	is_running = true
	_update_clock_display()

func pass_turn() -> void:
	var from := current_turn
	current_turn = "player" if current_turn == "opponent" else "opponent"
	emit_signal("turn_passed", from)
	start_timer()
	_update_turn_ui()

func _on_pass_pressed() -> void:
	emit_signal("pass_pressed")

func _update_clock_display() -> void:
	var mins := int(time_left) / 60
	var secs := int(time_left) % 60
	_clock.text = "%02d:%02d" % [mins, secs]
	if time_left <= 10.0:
		_clock.add_theme_color_override("font_color", Color("ff4422"))
	elif time_left <= 25.0:
		_clock.add_theme_color_override("font_color", Color("ffaa22"))
	else:
		_clock.add_theme_color_override("font_color", Color("c8a048"))

func _update_turn_ui() -> void:
	var is_player := current_turn == "player"
	_turn_label.text = "Seu Turno" if is_player else "Turno do Oponente"
	_turn_label.add_theme_color_override("font_color",
		Color("55cc77") if is_player else Color(0.8, 0.314, 0.133))
	_turn_gem.color = Color("55cc77") if is_player else Color(0.8, 0.314, 0.133)
	_pass_btn.disabled = not is_player

func _start_gem_pulse() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_turn_gem, "modulate:a", 0.5, 0.75)
	tween.tween_property(_turn_gem, "modulate:a", 1.0, 0.75)

func get_current_turn() -> String:
	return current_turn

func set_phase(phase_text: String) -> void:
	_phase_label.text = phase_text

func stop_timer() -> void:
	is_running = false

func set_turn_indicator(is_player_turn: bool) -> void:
	current_turn = "player" if is_player_turn else "opponent"
	_update_turn_ui()

func set_pass_state(is_visible: bool, label: String = "Passar Turno ▶", enabled: bool = true) -> void:
	_pass_btn.visible  = is_visible
	_pass_btn.text     = label
	_pass_btn.disabled = not enabled
