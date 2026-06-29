## scenes/vfx/guardian_aegis/guardian_aegis_test.gd
## Cena de QA isolada da Guardian Aegis (Muro de Aço da Valkar).
## Cria slots-dummy (guardião + 3 aliados de retaguarda) e ativa o VFX.
## Botões: Ativar / Desativar / Espelhar (testa o lado do oponente).
extends Control

const GuardianAegisScene := preload("res://scenes/vfx/guardian_aegis/GuardianAegis.tscn")

const GUARDIAN_POS := Vector2(720.0, 540.0)
const ALLY_POS := [Vector2(360.0, 540.0), Vector2(450.0, 540.0), Vector2(540.0, 540.0)]
const CARD_SIZE := Vector2(70.0, 98.0)
const ACTIVE_SIZE := Vector2(90.0, 126.0)

var _guardian_slot: Control
var _ally_slots: Array[Control] = []
var _fx: GuardianAegis = null
var _mirror: bool = false

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.039, 0.039, 0.063)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -1
	add_child(bg)

	_guardian_slot = _make_slot(GUARDIAN_POS, ACTIVE_SIZE, Color(0.35, 0.6, 0.95, 0.5), "Valkar")
	for i in ALLY_POS.size():
		_ally_slots.append(_make_slot(ALLY_POS[i], CARD_SIZE, Color(0.4, 0.7, 1.0, 0.4), "Aliado %d" % (i + 1)))

	_button("✦  Ativar", Vector2(20.0, 660.0), _on_activate)
	_button("✕  Desativar", Vector2(180.0, 660.0), _on_deactivate)
	_button("⇅  Espelhar", Vector2(360.0, 660.0), _on_toggle_mirror)

	_on_activate()

func _make_slot(center: Vector2, size: Vector2, color: Color, label: String) -> Control:
	var slot := ColorRect.new()
	slot.color = color
	slot.size = size
	slot.position = center - size * 0.5
	add_child(slot)
	var lbl := Label.new()
	lbl.text = label
	lbl.position = center + Vector2(-size.x * 0.5, size.y * 0.5 + 2.0)
	lbl.add_theme_font_size_override("font_size", 9)
	add_child(lbl)
	return slot

func _button(text: String, pos: Vector2, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.custom_minimum_size = Vector2(150.0, 36.0)
	add_child(b)
	b.pressed.connect(cb)

func _on_activate() -> void:
	if is_instance_valid(_fx):
		_fx.deactivate()
		_fx = null
	_fx = GuardianAegisScene.instantiate()
	add_child(_fx)
	_fx.activate(_guardian_slot, _ally_slots, _mirror)

func _on_deactivate() -> void:
	if is_instance_valid(_fx):
		_fx.deactivate()
		_fx = null

func _on_toggle_mirror() -> void:
	_mirror = not _mirror
	_on_activate()
