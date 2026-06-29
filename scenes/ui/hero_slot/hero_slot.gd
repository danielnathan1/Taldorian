# scenes/ui/hero_slot/hero_slot.gd
class_name HeroSlot
extends Control

const _HERO_BASE_PATH  := "res://assets/heros/base_card.png"
const _FONT_REG        := preload("res://assets/fonts/palatino/palr45w.ttf")
const _FONT_BOLD       := preload("res://assets/fonts/palatino/fonnts.com-Palatino-LT-Bold.ttf")
const _ELEMENT_ICONS := {
	"fogo":  "res://assets/icons/elements/fire.png",
	"terra": "res://assets/icons/elements/earth.png",
	"agua":  "res://assets/icons/elements/water.png",
	"wind":  "res://assets/icons/elements/wind.png",
	"lightning": "res://assets/icons/elements/lightning.png",
}
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
var _last_passive_name: String    = ""
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

func _ready() -> void:
	_setup_styles()
	if ResourceLoader.exists(_HERO_BASE_PATH):
		_hero_base.texture = load(_HERO_BASE_PATH)
	_back.texture = _sleeve_texture
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_build_activable_icon()
	_build_skill_fire()
	set_process(true)
	# Guarda os offsets originais definidos no editor
	_ability_offset_top    = _ability_lbl.offset_top
	_ability_offset_bottom = _ability_lbl.offset_bottom
	_class_icon_offset_top    = _class_icon.offset_top
	_class_icon_offset_bottom = _class_icon.offset_bottom

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

func _process(_dt: float) -> void:
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

	_last_passive_name = hero.passive_name
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
	var px: int = int(clamp(6.0 * _scale_factor, 5.0, 13.0))
	# Ícones de símbolo são maiores que a fonte para ganhar destaque.
	var icon_px: int = int(clamp(11.0 * _scale_factor, 10.0, 24.0))
	var lines: PackedStringArray = []

	# Linha da passiva
	if _last_passive_desc != "":
		var passive := ""
		if _last_passive_name != "":
			passive += "[b]%s[/b]: " % _last_passive_name
		passive += _last_passive_desc
		lines.append(passive)

	# Linha da habilidade ativa (símbolos + descrição)
	if _last_skill_desc != "" or not _last_symbols.is_empty():
		var skill := ""
		for sym in _last_symbols:
			var path: String = _ELEMENT_ICONS.get(sym, "")
			if path == "" or not ResourceLoader.exists(path):
				continue
			skill += "[img=%dx%d]%s[/img]" % [icon_px, icon_px, path]
		if _last_skill_desc != "":
			if not _last_symbols.is_empty():
				skill += ": "
			skill += _last_skill_desc
		lines.append(skill)

	_ability_lbl.add_theme_font_override("normal_font", _FONT_REG)
	_ability_lbl.add_theme_font_override("bold_font", _FONT_BOLD)
	_ability_lbl.add_theme_font_size_override("normal_font_size", px)
	_ability_lbl.add_theme_font_size_override("bold_font_size", px)
	_ability_lbl.add_theme_color_override("default_color", Color(0.08, 0.06, 0.05, 1))
	_ability_lbl.text = "\n".join(lines)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		slot_clicked.emit(hero)
