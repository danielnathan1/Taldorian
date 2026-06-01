extends CanvasLayer

signal confirmed
signal cancelled


func _ready() -> void:
	layer = 20
	visible = false
	_get_confirm_btn().pressed.connect(_on_confirmed)
	_get_cancel_btn().pressed.connect(_on_cancelled)
	_get_dim_bg().gui_input.connect(_on_dim_input)


func show_modal(title: String, message: String) -> void:
	_get_title_label().text   = title
	_get_message_label().text = message
	visible = true
	var tw := create_tween()
	tw.tween_property(_get_panel(), "modulate:a", 1.0, 0.15).from(0.0)


func hide_modal() -> void:
	visible = false


func _on_confirmed() -> void:
	hide_modal()
	confirmed.emit()


func _on_cancelled() -> void:
	hide_modal()
	cancelled.emit()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_cancelled()


func _get_dim_bg()        -> Control:        return $DimBG
func _get_panel()         -> PanelContainer: return $DimBG/Panel
func _get_title_label()   -> Label:          return $DimBG/Panel/MarginContainer/VBox/TitleLabel
func _get_message_label() -> Label:          return $DimBG/Panel/MarginContainer/VBox/MessageLabel
func _get_confirm_btn()   -> Button:         return $DimBG/Panel/MarginContainer/VBox/Buttons/ConfirmBtn
func _get_cancel_btn()    -> Button:         return $DimBG/Panel/MarginContainer/VBox/Buttons/CancelBtn
