# scenes/ui/worldhud/hud_button.gd
# Botão quadrado da barra de ícones — ícone, badge e tooltip com animações.
extends Button

@export var icon_texture : Texture2D
@export var hud_tooltip : String = ""
@export var badge_count  : int    = 0

@onready var icon_rect    : TextureRect = $Icon
@onready var badge_label  : Label       = $Badge
@onready var tooltip_node : Label       = $Tooltip

var _base_y: float = 0.0

func _ready() -> void:
	_base_y = position.y

	if icon_texture:
		icon_rect.texture = icon_texture

	tooltip_node.text    = hud_tooltip.to_upper()
	tooltip_node.visible = false

	_refresh_badge()

	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)
	button_down.connect(_on_press)
	button_up.connect(_on_release)

func set_badge(p_count: int) -> void:
	badge_count = p_count
	_refresh_badge()

func _refresh_badge() -> void:
	badge_label.visible = badge_count > 0
	badge_label.text    = str(badge_count)

func _on_hover_enter() -> void:
	tooltip_node.visible = not hud_tooltip.is_empty()
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "position:y", _base_y - 2.0, 0.10)

func _on_hover_exit() -> void:
	tooltip_node.visible = false
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "position:y", _base_y, 0.10)

func _on_press() -> void:
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "scale", Vector2(0.92, 0.92), 0.08)

func _on_release() -> void:
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)
