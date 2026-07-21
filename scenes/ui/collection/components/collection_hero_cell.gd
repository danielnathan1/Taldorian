# scenes/ui/collection/components/collection_hero_cell.gd
# Célula da grade de heróis da Coleção — HeroSlot clicável para preview.
# Versão de exibição do picker_hero_card (sem o botão de adicionar ao deck).
extends PanelContainer

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")

signal preview_requested(hero: Hero)

var _hero: Hero = null


func _ready() -> void:
	add_theme_stylebox_override("panel", S.panel_surface())
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_get_hero_slot().slot_clicked.connect(_on_slot_clicked)


func bind(p_hero: Hero) -> void:
	_hero = p_hero
	var slot := _get_hero_slot()
	slot.set_hp_visible(false)
	slot.bind(p_hero)
	# A célula é grande e vive num HFlowContainer: nos primeiros frames o slot ainda
	# está no tamanho mínimo (factor ~1 → fonte minúscula). Recalcular a escala a cada
	# resize garante que, quando o layout dá o tamanho final, o texto acompanhe.
	if not slot.resized.is_connected(_apply_hero_scale):
		slot.resized.connect(_apply_hero_scale)
	_apply_hero_scale()


func _on_slot_clicked(hero: Hero) -> void:
	if hero != null:
		preview_requested.emit(hero)


func _apply_hero_scale() -> void:
	var slot := _get_hero_slot()
	if not is_instance_valid(slot) or slot.size.y <= 1.0:
		return
	# Idêntico ao picker_hero_card do deck builder, porém reaplicado a cada resize
	# (a célula da Coleção é bem maior, então o factor final difere muito do inicial).
	var factor: float = clamp(slot.size.y / 240.0, 0.5, 3.0)
	slot.apply_scale(factor)


func _on_mouse_entered() -> void:
	add_theme_stylebox_override("panel", S.panel_surface2())


func _on_mouse_exited() -> void:
	add_theme_stylebox_override("panel", S.panel_surface())


func _get_hero_slot() -> HeroSlot: return $MarginContainer/VBox/HeroWrapper/HeroSlot
