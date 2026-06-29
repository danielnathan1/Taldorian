## scenes/vfx/arcane_fragments/arcane_fragments_test.gd
## Cena de QA isolada para os Fragmentos Arcanos. Botões I/II/III escolhem a
## variante e "Conjurar" reinicia. Marcadores mostram ORIGEM (token) e DESTINO
## (deck p/ efeito 1; combat zone p/ efeitos 2/3) em coordenadas de tela.
extends Control

const ArcaneFragmentsScene := preload("res://scenes/vfx/arcane_fragments/ArcaneFragments.tscn")

const _ROMAN := ["I", "II", "III"]

# Posições-mock em espaço de tela (token embaixo; deck no canto; combat no centro).
var _origin := Vector2(360.0, 600.0)
var _dest_deck := Vector2(1120.0, 150.0)
var _dest_combat := Vector2(640.0, 360.0)

var _variant := 1
var _btns: Array[Button] = []
var _fx: ArcaneFragments = null
var _markers: Control = null


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.020, 0.020, 0.047)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)

	_markers = _Markers.new()
	_markers.set_anchors_preset(Control.PRESET_FULL_RECT)
	_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_markers)

	var row := HBoxContainer.new()
	row.position = Vector2(20.0, 20.0)
	row.add_theme_constant_override("separation", 8)
	add_child(row)

	var tag := Label.new()
	tag.text = "FRAGMENTOS ARCANOS"
	tag.add_theme_color_override("font_color", Color(0.74, 0.49, 0.94))
	tag.add_theme_font_size_override("font_size", 12)
	row.add_child(tag)

	for v in 3:
		var b := Button.new()
		b.text = _ROMAN[v]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(44.0, 30.0)
		b.pressed.connect(_on_pick.bind(v + 1))
		row.add_child(b)
		_btns.append(b)

	var play := Button.new()
	play.text = "✦  Conjurar"
	play.custom_minimum_size = Vector2(120.0, 30.0)
	play.pressed.connect(_play)
	row.add_child(play)

	_refresh()
	_play()


func _on_pick(variant: int) -> void:
	_variant = variant
	_refresh()
	_play()


func _refresh() -> void:
	for i in _btns.size():
		_btns[i].button_pressed = (i + 1 == _variant)


func _current_dest() -> Vector2:
	# Espelha o mapa de gameplay: symbol (variante 2) → combat zone; peek/draw → deck.
	return _dest_combat if _variant == 2 else _dest_deck


func _play() -> void:
	if _fx != null and is_instance_valid(_fx):
		_fx.queue_free()
	_markers.origin = _origin
	_markers.dest = _current_dest()
	_markers.queue_redraw()
	var fx: ArcaneFragments = ArcaneFragmentsScene.instantiate()
	add_child(fx)
	fx.play(_variant, _origin, _current_dest())
	_fx = fx


# Marcadores de origem/destino (anel + rótulo), só para QA.
class _Markers extends Control:
	var origin := Vector2.ZERO
	var dest := Vector2.ZERO
	var _font: Font = ThemeDB.fallback_font

	func _draw() -> void:
		_marker(origin, Color(0.55, 0.85, 1.0), "TOKEN")
		_marker(dest, Color(1.0, 0.7, 0.45), "DESTINO")

	func _marker(c: Vector2, col: Color, label: String) -> void:
		if c == Vector2.ZERO:
			return
		draw_arc(c, 14.0, 0.0, TAU, 28, col, 1.5, true)
		draw_line(c - Vector2(20, 0), c + Vector2(20, 0), col, 1.0)
		draw_line(c - Vector2(0, 20), c + Vector2(0, 20), col, 1.0)
		draw_string(_font, c + Vector2(18, -18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
