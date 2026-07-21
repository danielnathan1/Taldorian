# scenes/ui/hero_slot/hero_slot.gd
class_name HeroSlot
extends Control

const _HERO_BASE_PATH  := "res://assets/heros/base_card.png"
const _FONT_REG        := preload("res://assets/fonts/palatino/palr45w.ttf")
const _FONT_BOLD       := preload("res://assets/fonts/palatino/fonnts.com-Palatino-LT-Bold.ttf")
const _FONT_ITALIC     := preload("res://assets/fonts/palatino/Palatino Italic Regular.ttf")
## Piso da fonte do bloco de habilidades quando o texto precisa encolher p/ caber.
const _ABILITY_MIN_PX := 4
const _CLASS_ICONS := {
	Hero.HeroClass.BARBARIAN: "res://assets/icons/class/Barbarian.png",
	Hero.HeroClass.WARRIOR:   "res://assets/icons/class/Warrior.png",
	Hero.HeroClass.MONK:      "res://assets/icons/class/monk.png",
	Hero.HeroClass.ROGUE:     "res://assets/icons/class/Rogue.png",
	Hero.HeroClass.CLERIC:    "res://assets/icons/class/Cleric.png",
	Hero.HeroClass.RANGER:    "res://assets/icons/class/Ranger.png",
	Hero.HeroClass.GUARDIAN:  "res://assets/icons/class/Guardian.png",
	Hero.HeroClass.WIZARD:    "res://assets/icons/class/wizard.png",
	Hero.HeroClass.SORCERER:  "res://assets/icons/class/sorcerer.png",
}

@onready var hp_capsule      := $Layout/CardRow/CardColumn/HPCapsule
@onready var hp_bar          := $Layout/CardRow/CardColumn/HPCapsule/HPRow/HPBar
@onready var hp_label        := $Layout/CardRow/CardColumn/HPCapsule/HPRow/HPLabel
@onready var heart_icon      := $Layout/CardRow/CardColumn/HPCapsule/HPRow/HeartIcon
@onready var exhausted_veil  := $CardZone/StateOverlay/ExhaustedVeil
@onready var _back           := $CardZone/Back

@onready var _hero_content   := $CardZone/HeroContent
@onready var _art            := $CardZone/HeroContent/Art
@onready var _hero_base      := $CardZone/HeroContent/HeroLayoutBase
@onready var _title_lbl      := $CardZone/HeroContent/TitleLabel
@onready var _class_icon     := $CardZone/HeroContent/ClassIcon
@onready var _ability_lbl    := $CardZone/HeroContent/AbilityText
@onready var _card_atk_lbl   := $CardZone/HeroContent/AtkValueLabel
@onready var _card_def_lbl   := $CardZone/HeroContent/DefValueLabel

signal slot_clicked(hero: Hero)

var hero: Hero = null
var is_opponent: bool = false
var _face_down: bool  = false
var _show_hp: bool    = true
var _sleeve_texture: Texture2D = preload("res://assets/sleve/default.png")
var _hp_fill_style := StyleBoxFlat.new()
var _modified_attack: int    = 0
var _modified_defense: int   = 0
var _base_attack: int        = 0
var _base_defense: int       = 0
var _scale_factor: float     = 1.0
var _last_symbols: Array[String]  = []
var _last_skill_desc: String      = ""
var _last_passive_zone: String    = ""
var _last_passive_desc: String    = ""

# Offsets base lidos do tscn — usados para escalar proporcionalmente
var _ability_offset_top: float    = 0.0
var _ability_offset_bottom: float = 0.0
var _class_icon_offset_top: float    = 0.0
var _class_icon_offset_bottom: float = 0.0

const _ACTIVABLE_ICON_PATH   := "res://assets/icons/activable.png"
const _ACTIVABLE_GLOW_SHADER := preload("res://scenes/ui/shared/activable_glow.gdshader")
var _activable_icon: TextureRect = null
var _activable_glow: ColorRect = null

# Aura de fogo (skill da Poppy) — chamas lambendo a borda do card, via o shader do
# booster. Renderizada pelo próprio slot → aparece no tabuleiro, preview e combate.
const _SKILL_FIRE_SHADER := preload("res://scenes/ui/booster_shop/card_fire.gdshader")
var _skill_fire: ColorRect = null

# Badge de Rosas Negras (Darian) — ícone da rosa + contador no canto sup-esquerdo.
const _ROSE_ICON_PATH := "res://scenes/vfx/rosas_negras/black_rose.png"
var _rose_badge: Control = null
var _rose_badge_label: Label = null

# Fumaça do Selo da Ruína (Lilith) — fumaça preta emanando da borda do card enquanto
# hero.sealed_ruin. ColorRect + shader (atrás do conteúdo, como o SkillFire), dirigida
# pelo sync de estado como o badge de rosas. Aparece no tabuleiro e no preview.
const _SEAL_MIST_SHADER := preload("res://scenes/ui/shared/seal_mist.gdshader")
var _seal_mist: ColorRect = null

# Queimadura (status negativo de Fogo) — reusa o shader de fumaça do Selo, tingido de brasa
# (laranja), enquanto hero.burn_turns > 0. Distinto do preto do Selo e das chamas da skill
# da Poppy (outro shader). Acompanha um badge com o contador de turnos restantes.
var _burn_mist: ColorRect = null
const _FIRE_ICON_PATH := "res://assets/icons/elements/fire.png"
var _burn_badge: Control = null
var _burn_badge_label: Label = null

func _ready() -> void:
	_setup_styles()
	if ResourceLoader.exists(_HERO_BASE_PATH):
		_hero_base.texture = load(_HERO_BASE_PATH)
	_back.texture = _sleeve_texture
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_build_activable_icon()
	_build_skill_fire()
	_build_rose_badge()
	_build_seal_mist()
	_build_burn_mist()
	_build_burn_badge()
	set_process(true)
	# Guarda os offsets originais definidos no editor
	_ability_offset_top    = _ability_lbl.offset_top
	_ability_offset_bottom = _ability_lbl.offset_bottom
	_class_icon_offset_top    = _class_icon.offset_top
	_class_icon_offset_bottom = _class_icon.offset_bottom
	# Reajusta a fonte do bloco de habilidades quando a caixa ganha/muda de tamanho
	# (o board pode chamar bind() antes do primeiro layout, sem altura válida ainda).
	_ability_lbl.resized.connect(_build_ability_text)

## Indicador "activable" no canto superior do slot — aceso quando o herói tem uma
## habilidade ativável agora (ex.: Alastar criar míssil no seu segmento).
func _build_activable_icon() -> void:
	# Borda brilhante pulsante ao redor da carta (overlay full-rect sobre o CardZone).
	_activable_glow = ColorRect.new()
	_activable_glow.name = "ActivableGlow"
	_activable_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_activable_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = _ACTIVABLE_GLOW_SHADER
	_activable_glow.material = mat
	_activable_glow.z_index = 10
	_activable_glow.visible = false
	$CardZone.add_child(_activable_glow)

	# Ícone (na frente), maior e centralizado no topo.
	_activable_icon = TextureRect.new()
	_activable_icon.name = "ActivableIcon"
	_activable_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_activable_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_activable_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_activable_icon.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_activable_icon.offset_left   = -30.0
	_activable_icon.offset_right  = 30.0
	_activable_icon.offset_top    = -16.0
	_activable_icon.offset_bottom = 44.0
	_activable_icon.z_index = 11
	if ResourceLoader.exists(_ACTIVABLE_ICON_PATH):
		_activable_icon.texture = load(_ACTIVABLE_ICON_PATH)
	_activable_icon.visible = false
	add_child(_activable_icon)

## Marcador de Rosas Negras (Darian) — ícone da rosa com contador ×N sobreposto,
## no canto superior-esquerdo do slot. Mostra quantas rosas estão cravadas no herói.
func _build_rose_badge() -> void:
	_rose_badge = Control.new()
	_rose_badge.name = "RoseBadge"
	_rose_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rose_badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_rose_badge.offset_left = 2.0
	_rose_badge.offset_top  = 2.0
	_rose_badge.custom_minimum_size = Vector2(38, 52)
	_rose_badge.size = Vector2(38, 52)
	_rose_badge.z_index = 12
	_rose_badge.visible = false
	$CardZone.add_child(_rose_badge)

	# Ícone da rosa negra.
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(_ROSE_ICON_PATH):
		icon.texture = load(_ROSE_ICON_PATH)
	_rose_badge.add_child(icon)

	# Contador ×N num pill escuro, canto inferior-direito do ícone.
	_rose_badge_label = Label.new()
	_rose_badge_label.name = "Count"
	_rose_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rose_badge_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_rose_badge_label.offset_left   = -18.0
	_rose_badge_label.offset_top    = -14.0
	_rose_badge_label.offset_right  = 2.0
	_rose_badge_label.offset_bottom = 2.0
	_rose_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rose_badge_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_rose_badge_label.add_theme_font_size_override("font_size", 11)
	_rose_badge_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.92))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.36, 0.05, 0.19, 0.94)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(1)
	_rose_badge_label.add_theme_stylebox_override("normal", sb)
	_rose_badge.add_child(_rose_badge_label)

## Atualiza o marcador de rosas a partir do estado atual do herói.
func _update_rose_badge() -> void:
	if _rose_badge == null or hero == null:
		return
	var n := hero.black_roses
	_rose_badge.visible = n > 0
	if n > 0 and _rose_badge_label != null:
		_rose_badge_label.text = "×%d" % n

## Acende/apaga o indicador de "pode ativar" (ícone + halo pulsante via shader).
## Mostra mesmo com a carta face-down — é o dono que precisa do aviso, e só o
## lado local recebe activable=true (o board nunca acende no oponente).
func set_activable(value: bool) -> void:
	if _activable_icon != null:
		_activable_icon.visible = value
	if _activable_glow != null:
		_activable_glow.visible = value

## Aura de fogo: ColorRect filho do CardZone (atrás do conteúdo, pra chama lamber a
## borda por fora), com o shader de fogo. Acende/apaga conforme hero.skill_fire_active.
func _build_skill_fire() -> void:
	_skill_fire = ColorRect.new()
	_skill_fire.name = "SkillFire"
	_skill_fire.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_fire.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = _SKILL_FIRE_SHADER
	mat.set_shader_parameter("mode", 1)        # vermelho/laranja/ouro
	mat.set_shader_parameter("intensity", 1.25)
	mat.set_shader_parameter("speed", 1.0)
	_skill_fire.material = mat
	_skill_fire.visible = false
	$CardZone.add_child(_skill_fire)
	$CardZone.move_child(_skill_fire, 0)       # atrás do conteúdo

func _apply_skill_fire() -> void:
	if _skill_fire == null:
		return
	_skill_fire.visible = hero != null and hero.skill_fire_active and not _face_down

## Fumaça persistente do Selo da Ruína: ColorRect com shader de fumaça preta emanando da
## borda do card enquanto hero.sealed_ruin. Filha do CardZone (atrás do conteúdo → só os
## wisps ao redor/acima aparecem), dimensionada ao card no _process (como o SkillFire).
func _build_seal_mist() -> void:
	_seal_mist = ColorRect.new()
	_seal_mist.name = "SealMist"
	_seal_mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seal_mist.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = _SEAL_MIST_SHADER
	mat.set_shader_parameter("intensity", 0.9)
	mat.set_shader_parameter("speed", 1.0)
	_seal_mist.material = mat
	_seal_mist.visible = false
	$CardZone.add_child(_seal_mist)
	$CardZone.move_child(_seal_mist, 0)   # atrás do conteúdo (fumaça ao redor da silhueta)

## Liga/desliga a fumaça conforme hero.sealed_ruin. Mostra mesmo face-down (é marcador de
## status, não revela a identidade do herói — igual ao badge de rosas).
func _apply_seal_mist() -> void:
	if _seal_mist == null:
		return
	_seal_mist.visible = hero != null and hero.sealed_ruin

func _size_seal_mist() -> void:
	if _seal_mist == null or not _seal_mist.visible:
		return
	var cz_size: Vector2 = $CardZone.size
	if cz_size.x <= 1.0:
		return
	var g: float = cz_size.x * 0.30            # quanto a fumaça extrapola a borda do card
	_seal_mist.offset_left   = -g
	_seal_mist.offset_top    = -g
	_seal_mist.offset_right  = g
	_seal_mist.offset_bottom = g
	var mat: ShaderMaterial = _seal_mist.material
	mat.set_shader_parameter("overlay_px", cz_size + Vector2(g, g) * 2.0)
	mat.set_shader_parameter("card_px",    cz_size)
	mat.set_shader_parameter("reach_px",   g - 2.0)
	mat.set_shader_parameter("corner_px",  cz_size.x * 0.07)

## Aura de Queimadura: mesma fumaça do Selo, mas laranja/brasa. Atrás do conteúdo do card.
func _build_burn_mist() -> void:
	_burn_mist = ColorRect.new()
	_burn_mist.name = "BurnMist"
	_burn_mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burn_mist.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = _SEAL_MIST_SHADER
	mat.set_shader_parameter("intensity", 0.95)
	mat.set_shader_parameter("speed", 1.4)
	mat.set_shader_parameter("smoke_color", Color(1.0, 0.42, 0.10, 1.0))
	_burn_mist.material = mat
	_burn_mist.visible = false
	$CardZone.add_child(_burn_mist)
	$CardZone.move_child(_burn_mist, 0)

## Liga/desliga a aura conforme hero.burn_turns. Mostra mesmo face-down (é marcador de
## status, não revela a identidade — igual ao Selo e ao badge de rosas).
func _apply_burn_mist() -> void:
	if _burn_mist == null:
		return
	_burn_mist.visible = hero != null and hero.burn_turns > 0

func _size_burn_mist() -> void:
	if _burn_mist == null or not _burn_mist.visible:
		return
	var cz_size: Vector2 = $CardZone.size
	if cz_size.x <= 1.0:
		return
	var g: float = cz_size.x * 0.30
	_burn_mist.offset_left   = -g
	_burn_mist.offset_top    = -g
	_burn_mist.offset_right  = g
	_burn_mist.offset_bottom = g
	var mat: ShaderMaterial = _burn_mist.material
	mat.set_shader_parameter("overlay_px", cz_size + Vector2(g, g) * 2.0)
	mat.set_shader_parameter("card_px",    cz_size)
	mat.set_shader_parameter("reach_px",   g - 2.0)
	mat.set_shader_parameter("corner_px",  cz_size.x * 0.07)

## Badge de Queimadura: ícone de fogo + contador de turnos restantes, canto superior-DIREITO
## (o badge de Rosas Negras fica à esquerda). Espelha _build_rose_badge.
func _build_burn_badge() -> void:
	_burn_badge = Control.new()
	_burn_badge.name = "BurnBadge"
	_burn_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burn_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_burn_badge.offset_left  = -40.0
	_burn_badge.offset_top   = 2.0
	_burn_badge.offset_right = -2.0
	_burn_badge.custom_minimum_size = Vector2(38, 52)
	_burn_badge.size = Vector2(38, 52)
	_burn_badge.z_index = 12
	_burn_badge.visible = false
	$CardZone.add_child(_burn_badge)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(_FIRE_ICON_PATH):
		icon.texture = load(_FIRE_ICON_PATH)
	_burn_badge.add_child(icon)

	# Contador de turnos num pill escuro, canto inferior-esquerdo do ícone.
	_burn_badge_label = Label.new()
	_burn_badge_label.name = "Count"
	_burn_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burn_badge_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_burn_badge_label.offset_left   = -2.0
	_burn_badge_label.offset_top    = -14.0
	_burn_badge_label.offset_right  = 18.0
	_burn_badge_label.offset_bottom = 2.0
	_burn_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_burn_badge_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_burn_badge_label.add_theme_font_size_override("font_size", 11)
	_burn_badge_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.85))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.5, 0.16, 0.03, 0.94)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(1)
	_burn_badge_label.add_theme_stylebox_override("normal", sb)
	_burn_badge.add_child(_burn_badge_label)

## Atualiza o badge de Queimadura (turnos restantes) a partir do estado do herói.
func _update_burn_badge() -> void:
	if _burn_badge == null or hero == null:
		return
	var n := hero.burn_turns
	_burn_badge.visible = n > 0
	if n > 0 and _burn_badge_label != null:
		_burn_badge_label.text = "%d" % n

func _process(_dt: float) -> void:
	_size_seal_mist()
	_size_burn_mist()
	# Mantém o overlay de fogo dimensionado ao card real (CardZone), que varia de
	# tamanho por contexto (slot, preview 2x, resolução de combate). Só quando aceso.
	if _skill_fire == null or not _skill_fire.visible:
		return
	var cz_size: Vector2 = $CardZone.size
	if cz_size.x <= 1.0:
		return
	var g: float = cz_size.x * 0.20            # quanto o fogo extrapola a borda
	_skill_fire.offset_left   = -g
	_skill_fire.offset_top    = -g
	_skill_fire.offset_right  = g
	_skill_fire.offset_bottom = g
	var mat: ShaderMaterial = _skill_fire.material
	mat.set_shader_parameter("overlay_px", cz_size + Vector2(g, g) * 2.0)
	mat.set_shader_parameter("card_px",    cz_size)
	mat.set_shader_parameter("reach_px",   g - 2.0)
	mat.set_shader_parameter("corner_px",  cz_size.x * 0.07)

## Bônus de ataque atual (modificado − base) — usado para feedback de buff.
func get_attack_buff() -> int:
	return _modified_attack - _base_attack

func _setup_styles() -> void:
	var capsule_bg := StyleBoxFlat.new()
	capsule_bg.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	capsule_bg.set_corner_radius_all(12)
	capsule_bg.border_width_left   = 1
	capsule_bg.border_width_right  = 1
	capsule_bg.border_width_top    = 1
	capsule_bg.border_width_bottom = 1
	capsule_bg.border_color = Color(0.3, 0.3, 0.45, 0.8)
	capsule_bg.content_margin_left   = 6.0
	capsule_bg.content_margin_right  = 6.0
	capsule_bg.content_margin_top    = 3.0
	capsule_bg.content_margin_bottom = 3.0
	hp_capsule.add_theme_stylebox_override("panel", capsule_bg)

	_hp_fill_style.bg_color = Color(0.11, 0.62, 0.46)
	_hp_fill_style.set_corner_radius_all(4)
	hp_bar.add_theme_stylebox_override("fill", _hp_fill_style)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.1, 0.1, 0.1, 0.6)
	bar_bg.set_corner_radius_all(4)
	hp_bar.add_theme_stylebox_override("background", bar_bg)

	heart_icon.add_theme_color_override("font_color", Color(0.9, 0.2, 0.3))
	heart_icon.add_theme_font_size_override("font_size", 14)
	hp_label.add_theme_font_size_override("font_size", 11)
	hp_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))


func _on_mouse_entered() -> void:
	if hero == null or hero.state == Hero.State.DEFEATED:
		return
	if is_opponent and _face_down:
		return
	GameBus.card_hovered.emit({ "type": "hero", "hero": hero, "atk": _modified_attack, "def": _modified_defense })

func _on_mouse_exited() -> void:
	GameBus.card_hover_ended.emit()

func set_sleeve_texture(texture: Texture2D) -> void:
	_sleeve_texture = texture
	_back.texture = texture if texture else _sleeve_texture

func bind(p_hero: Hero) -> void:
	_scale_factor = 1.0
	hero = p_hero
	_modified_attack  = hero.base_attack + hero.get_passive_attack_bonus()
	_modified_defense = hero.base_defense
	_base_attack      = _modified_attack
	_base_defense     = hero.base_defense

	hp_bar.max_value = hero.max_hp
	hp_bar.value     = hero.current_hp
	hp_label.text    = "%d/%d" % [hero.current_hp, hero.max_hp]

	_title_lbl.text    = hero.hero_name
	_card_atk_lbl.text = str(_modified_attack)
	_card_atk_lbl.add_theme_color_override("font_color", Color.WHITE)
	_card_def_lbl.text = str(_modified_defense)
	_card_def_lbl.add_theme_color_override("font_color", Color.WHITE)

	_last_passive_zone = hero.passive_zone_label()
	_last_passive_desc = hero.passive_desc
	_last_symbols      = hero.symbols_required
	_last_skill_desc   = hero.skill_desc

	_class_icon.texture = _load_class_icon(hero.hero_class)
	_build_ability_text()

	_apply_texture()
	_update_state_style()
	_update_hp_bar_color()
	_apply_face_down_visibility()
	_apply_skill_fire()
	_update_rose_badge()
	_apply_seal_mist()
	_apply_burn_mist()
	_update_burn_badge()
	apply_scale(1.0)

func apply_scale(factor: float) -> void:
	_scale_factor = factor
	# Escala os pixel offsets proporcionalmente para manter posição relativa
	_ability_lbl.offset_top    = _ability_offset_top    * factor
	_ability_lbl.offset_bottom = _ability_offset_bottom * factor
	_class_icon.offset_top     = _class_icon_offset_top    * factor
	_class_icon.offset_bottom  = _class_icon_offset_bottom * factor
	_fit_label(_title_lbl, int(12 * factor), int(6 * factor))
	_card_atk_lbl.add_theme_font_size_override("font_size", int(9 * factor))
	_card_def_lbl.add_theme_font_size_override("font_size", int(9 * factor))
	_build_ability_text()

## Ajusta a fonte do label para não ultrapassar o espaço disponível.
## Parte de [max_fs] e reduz até o conteúdo caber ou atingir [min_fs].
func _fit_label(lbl: Label, max_fs: int, min_fs: int) -> void:
	var avail_h := lbl.size.y
	# Fallback: calcula pela altura do HeroSlot + anchor span do label
	if avail_h <= 1.0:
		var slot_h := size.y
		if slot_h > 1.0:
			var card_h := slot_h - 30.0  # desconta offset_top do CardZone
			avail_h = (lbl.anchor_bottom - lbl.anchor_top) * card_h
	var fs := max_fs
	lbl.add_theme_font_size_override("font_size", fs)
	if avail_h <= 1.0:
		return
	while fs > min_fs and lbl.get_minimum_size().y > avail_h:
		fs -= 1
		lbl.add_theme_font_size_override("font_size", fs)

func set_modified_attack(value: int) -> void:
	_modified_attack   = value
	_card_atk_lbl.text = str(value)
	if value > _base_attack:
		_card_atk_lbl.add_theme_color_override("font_color", Color(0.408, 0.573, 0.373, 1.0))
	elif value < _base_attack:
		_card_atk_lbl.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	else:
		_card_atk_lbl.add_theme_color_override("font_color", Color.WHITE)

func set_modified_defense(value: int) -> void:
	_modified_defense  = value
	_card_def_lbl.text = str(value)
	if value > _base_defense:
		_card_def_lbl.add_theme_color_override("font_color", Color(0.18, 0.62, 0.22))
	elif value < _base_defense:
		_card_def_lbl.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	else:
		_card_def_lbl.add_theme_color_override("font_color", Color.WHITE)

func _update_hp_bar_color() -> void:
	var ratio := float(hero.current_hp) / float(hero.max_hp)
	var target: Color
	if ratio > 0.5:
		target = Color(0.11, 0.62, 0.46)
	elif ratio >= 0.2:
		target = Color(0.9, 0.55, 0.1)
	else:
		target = Color(0.85, 0.15, 0.15)
	var tw := create_tween()
	tw.tween_property(_hp_fill_style, "bg_color", target, 0.3)

## "Tell" de conjuração: a carta dá uma pulsada (cresce e volta) e brilha, sinalizando
## que uma habilidade/animação do herói vai disparar. Chamada pelo board ANTES do VFX
## (ver Board.CAST_LEAD_IN). Anima escala/modulate do CardZone — independente do
## apply_scale (que mexe só em fontes/offsets), então não conflita com o layout.
const CAST_TELL_UP   := 0.22
const CAST_TELL_BACK := 0.42

func play_cast_tell() -> void:
	var cz: Control = $CardZone
	cz.pivot_offset = cz.size * 0.5
	cz.scale    = Vector2.ONE
	cz.modulate = Color.WHITE
	var tw := create_tween()
	tw.tween_property(cz, "scale", Vector2(1.14, 1.14), CAST_TELL_UP) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(cz, "modulate", Color(1.8, 1.8, 1.8, 1.0), CAST_TELL_UP)
	tw.chain().tween_property(cz, "scale", Vector2.ONE, CAST_TELL_BACK) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tw.parallel().tween_property(cz, "modulate", Color.WHITE, CAST_TELL_BACK)

func refresh() -> void:
	if hero == null:
		return
	var saved_scale := _scale_factor
	bind(hero)
	if saved_scale != _scale_factor:
		apply_scale(saved_scale)

func set_face_down(value: bool) -> void:
	_face_down = value
	_apply_texture()
	_apply_face_down_visibility()

## Oculta/mostra a barra de HP e ajusta o CardZone para preencher o espaço.
## Use set_hp_visible(false) em contextos fora da partida (deck builder, etc).
func set_hp_visible(value: bool) -> void:
	_show_hp = value
	$Layout.visible         = value
	$CardZone.offset_top    = 30.0 if value else 0.0
	$CardZone.offset_bottom = 0.0
	_apply_face_down_visibility()

func _apply_face_down_visibility() -> void:
	var show_stats := not _face_down and hero != null
	_hero_content.visible  = not _face_down
	_back.visible          = _face_down
	hp_capsule.visible     = show_stats and _show_hp
	exhausted_veil.visible = show_stats and hero != null and hero.state == Hero.State.EXHAUSTED
	_apply_skill_fire()

func _apply_texture() -> void:
	_art.texture = hero.get_texture() if hero else null

func _update_state_style() -> void:
	match hero.state:
		Hero.State.ACTIVE:    modulate = Color.WHITE
		Hero.State.EXHAUSTED: modulate = Color(1, 1, 1, 0.4)
		Hero.State.DEFEATED:  modulate = Color(0.4, 0.4, 0.4, 0.3)

func _load_class_icon(hero_class: Hero.HeroClass) -> Texture2D:
	var path: String = _CLASS_ICONS.get(hero_class, "")
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null

## Monta o bloco unificado de habilidades em um único RichTextLabel:
##   [b]Passiva[/b]: descrição
##   [ícones]: descrição da skill ativa
## As duas linhas fluem juntas, sem âncoras fixas que se sobrepõem.
func _build_ability_text() -> void:
	_ability_lbl.add_theme_font_override("normal_font", _FONT_REG)
	_ability_lbl.add_theme_font_override("bold_font", _FONT_BOLD)
	_ability_lbl.add_theme_font_override("italics_font", _FONT_ITALIC)
	_ability_lbl.add_theme_color_override("default_color", Color(0.08, 0.06, 0.05, 1))
	# Fonte "ideal" pela escala; só encolhe (até _ABILITY_MIN_PX) se o texto estourar a caixa.
	var base_px: int = int(clamp(6.0 * _scale_factor, 5.0, 13.0))
	TextMarkup.fit_rich_label(_ability_lbl, base_px, _ABILITY_MIN_PX, _compose_ability_text)

## Monta o bloco unificado de habilidades (passiva + skill) para a fonte [px]. Os ícones
## de símbolo acompanham a fonte (proporção ~11/6, maiores p/ destaque, com teto de 24):
##   [b][u]Zona:[/u][/b] descrição da passiva
##   [ícones]: descrição da skill ativa
func _compose_ability_text(px: int) -> String:
	var icon_px: int = int(clamp(float(px) * 11.0 / 6.0, 8.0, 24.0))
	var lines: PackedStringArray = []

	# Linha da passiva
	if _last_passive_desc != "":
		var passive := ""
		if _last_passive_zone != "":
			passive += "[b][u]%s:[/u][/b] " % _last_passive_zone
		passive += TextMarkup.to_bbcode(_last_passive_desc, icon_px)
		lines.append(passive)

	# Linha da habilidade ativa (símbolos + descrição)
	if _last_skill_desc != "" or not _last_symbols.is_empty():
		var skill := ""
		for sym in _last_symbols:
			var path: String = GameSymbols.icon_path(sym)
			if path == "" or not ResourceLoader.exists(path):
				continue
			skill += "[img=%dx%d]%s[/img]" % [icon_px, icon_px, path]
		if _last_skill_desc != "":
			if not _last_symbols.is_empty():
				skill += ": "
			skill += TextMarkup.to_bbcode(_last_skill_desc, icon_px)
		lines.append(skill)

	return "\n".join(lines)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		slot_clicked.emit(hero)
