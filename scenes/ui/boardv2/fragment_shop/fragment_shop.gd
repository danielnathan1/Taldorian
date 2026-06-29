# scenes/ui/boardv2/fragment_shop/fragment_shop.gd
# Loja do Fragmento Arcano (Relicar). Fragmentos são a "carteira"; cada efeito custa
# um número de fragmentos. Aberto ao clicar no token de Fragmento durante o seu turno.
# Emite `buy(effect_id)` ao comprar (o board envia o RPC) e `closed` ao fechar.
extends Control

signal buy(effect_id: String)
signal closed

# effect_id, rótulo, custo em fragmentos. (Custos espelham GameState.FRAGMENT_COSTS.)
const OPTIONS := [
	{ "id": "peek",   "label": "Olhar a carta do topo do deck", "cost": 1 },
	{ "id": "symbol", "label": "Adicionar 1 símbolo à sua Chain", "cost": 2 },
	{ "id": "draw",   "label": "Comprar 1 carta",                 "cost": 3 },
]

var _count_lbl: Label
var _rows: Array = []   # [{ "btn": Button, "cost": int }]

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	_style_panel(panel)
	center.add_child(panel)

	var margins := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margins.add_theme_constant_override(m, 28)
	panel.add_child(margins)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margins.add_child(vbox)

	var header := Label.new()
	header.text = "✦ Fragmentos Arcanos ✦"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.78, 0.62, 1.0))
	vbox.add_child(header)

	_count_lbl = Label.new()
	_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_lbl.add_theme_font_size_override("font_size", 15)
	_count_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(_count_lbl)

	vbox.add_child(HSeparator.new())

	for opt in OPTIONS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 56)
		btn.add_theme_font_size_override("font_size", 16)
		_style_btn(btn)
		btn.pressed.connect(_on_buy_pressed.bind(str(opt["id"])))
		vbox.add_child(btn)
		_rows.append({ "btn": btn, "cost": int(opt["cost"]), "label": str(opt["label"]) })

	vbox.add_child(HSeparator.new())

	var close_btn := Button.new()
	close_btn.text = "Fechar"
	close_btn.custom_minimum_size = Vector2(0, 44)
	close_btn.add_theme_font_size_override("font_size", 16)
	_style_btn(close_btn, Color(0.30, 0.10, 0.10), Color(0.55, 0.16, 0.16))
	close_btn.pressed.connect(_on_close_pressed)
	vbox.add_child(close_btn)

## Exibe a loja com a quantidade atual de fragmentos; desabilita o que não dá pra pagar.
func setup(fragment_count: int) -> void:
	_count_lbl.text = "Você tem %d fragmento%s" % [fragment_count, "" if fragment_count == 1 else "s"]
	for row in _rows:
		var cost: int = row["cost"]
		var affordable := fragment_count >= cost
		var btn: Button = row["btn"]
		btn.text = "%s   —   %d ◈" % [row["label"], cost]
		btn.disabled = not affordable
		btn.modulate = Color(1, 1, 1, 1) if affordable else Color(1, 1, 1, 0.45)
	modulate.a = 0.0
	visible = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.18)

func _on_buy_pressed(effect_id: String) -> void:
	_fade_out(func() -> void: buy.emit(effect_id))

func _on_close_pressed() -> void:
	_fade_out(func() -> void: closed.emit())

func _fade_out(on_done: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func() -> void:
		visible = false
		on_done.call())

func _style_panel(panel: PanelContainer) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.06, 0.14, 0.97)
	s.set_corner_radius_all(16)
	s.set_border_width_all(2)
	s.border_color = Color(0.50, 0.34, 0.86, 0.90)
	panel.add_theme_stylebox_override("panel", s)

func _style_btn(btn: Button, normal_col := Color(0.16, 0.13, 0.28), hover_col := Color(0.26, 0.20, 0.46)) -> void:
	var sn := StyleBoxFlat.new()
	sn.bg_color = normal_col
	sn.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", sn)
	var sh := StyleBoxFlat.new()
	sh.bg_color = hover_col
	sh.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("hover", sh)
	var sd := StyleBoxFlat.new()
	sd.bg_color = Color(0.12, 0.10, 0.16)
	sd.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("disabled", sd)
