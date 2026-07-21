# scenes/ui/boardv2/tutorial/tutorial_spotlight.gd
# Destaque central ampliado de UMA carta (CardView) ou UM herói (HeroSlot), com callouts opcionais
# apontando Ataque / Defesa / HP / Elemento. Fica ACIMA do dim do TutorialCoach (layer maior).
#
# IMPORTANTE (nitidez): NÃO usar node.scale (escala a rasterização → borra). Em vez disso o card é
# RENDERIZADO já no tamanho grande (size grande) e apply_scale() ajusta só as fontes — a arte sai
# nítida direto da textura de origem.
extends CanvasLayer

const HERO_SLOT_SCENE := preload("res://scenes/ui/hero_slot/hero_slot.tscn")
const CARD_VIEW_SCENE := preload("res://scenes/ui/card_view/card_view.tscn")

const HERO_NATIVE := Vector2(288, 432)   # tamanho base do HeroSlot (igual ao hero_pick)
const CARD_NATIVE := Vector2(160, 240)   # tamanho base do CardView
const HERO_SCALE := 1.8   # 432·1.8 ≈ 778 de altura
const CARD_SCALE := 3.4   # card menor (240 base) → escala maior p/ fontes legíveis
const DIALOG_RIGHT := 690.0   # borda direita da coluna do diálogo do Blauber (coach à esquerda)

@onready var _root: Control = $Root
@onready var _callout_hp: Label = $Root/CalloutHp
@onready var _callout_atk: Label = $Root/CalloutAtk
@onready var _callout_def: Label = $Root/CalloutDef
@onready var _callout_elem: Label = $Root/CalloutElem

var _mounted: Control = null

func _ready() -> void:
	visible = false
	_hide_callouts()

## Herói ampliado (nítido) + callouts de Ataque / Defesa / HP.
func show_hero(p_hero: Hero) -> void:
	var slot: HeroSlot = HERO_SLOT_SCENE.instantiate()
	_mount(slot, HERO_NATIVE * HERO_SCALE)
	slot.bind(p_hero)
	slot.set_hp_visible(true)
	slot.set_face_down(false)
	# apply_scale espera o fator = altura_renderizada / 160 (mesma fórmula do hero_pick) para
	# posicionar corretamente os offsets internos (texto de habilidade, ícone de classe). Usar
	# HERO_SCALE direto deixava os offsets curtos → texto subia sobre a arte.
	slot.apply_scale((HERO_NATIVE.y * HERO_SCALE) / 160.0)
	# O texto de habilidade é limitado a ~13px internamente; aumenta a fonte para ficar legível
	# (sobrescreve o clamp de apply_scale, feito depois dele — só a fonte, não a posição).
	var ab := slot.get_node_or_null("CardZone/HeroContent/AbilityText")
	if ab != null:
		ab.add_theme_font_size_override("normal_font_size", 18)
		ab.add_theme_font_size_override("bold_font_size", 18)
	await _center_and_callouts([_callout_hp, _callout_atk, _callout_def])

## Carta ampliada (nítida) + callouts de Ataque / Defesa / Elemento.
func show_card(p_card: Card) -> void:
	var cv: CardView = CARD_VIEW_SCENE.instantiate()
	_mount(cv, CARD_NATIVE * CARD_SCALE)
	cv.bind(p_card)
	cv.set_interactable(false, false)
	cv.apply_scale(CARD_SCALE)
	await _center_and_callouts([_callout_atk, _callout_def, _callout_elem])

func hide_spot() -> void:
	visible = false
	_hide_callouts()
	if _mounted != null:
		_mounted.queue_free()
		_mounted = null

# ── internos ─────────────────────────────────────────────────────────────────
func _mount(node: Control, p_size: Vector2) -> void:
	if _mounted != null:
		_mounted.queue_free()
	_mounted = node
	node.custom_minimum_size = p_size
	node.size = p_size
	_root.add_child(node)
	visible = true

func _hide_callouts() -> void:
	_callout_hp.visible = false
	_callout_atk.visible = false
	_callout_def.visible = false
	_callout_elem.visible = false

func _center_and_callouts(which: Array) -> void:
	await get_tree().process_frame
	if _mounted == null:
		return
	var s: Vector2 = _mounted.size
	var vp: Vector2 = get_viewport().get_visible_rect().size
	# Centraliza na área À DIREITA do diálogo do Blauber (que fica na coluna esquerda),
	# sem transform (mantém a nitidez).
	var area_cx: float = (DIALOG_RIGHT + vp.x) * 0.5
	_mounted.position = Vector2(area_cx - s.x * 0.5, (vp.y - s.y) * 0.5)

	var left: float = _mounted.position.x
	var top: float = _mounted.position.y
	var right: float = left + s.x
	var bottom: float = top + s.y
	var cx: float = left + s.x * 0.5
	var cy: float = top + s.y * 0.5   # elemento (símbolo/moeda) fica no MEIO da carta

	_place(_callout_hp,   Vector2(cx - 90.0, top - 46.0), Vector2(180, 34))
	_place(_callout_atk,  Vector2(left - 196.0, bottom - 96.0), Vector2(176, 34))
	_place(_callout_def,  Vector2(right + 18.0, bottom - 96.0), Vector2(176, 34))
	_place(_callout_elem, Vector2(left - 196.0, cy - 17.0), Vector2(176, 34))

	for c in [_callout_hp, _callout_atk, _callout_def, _callout_elem]:
		c.visible = c in which

func _place(lbl: Label, pos: Vector2, min_size: Vector2) -> void:
	lbl.custom_minimum_size = min_size
	lbl.size = min_size
	lbl.position = pos
