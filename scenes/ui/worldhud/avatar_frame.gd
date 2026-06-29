# scenes/ui/worldhud/avatar_frame.gd
# Moldura de avatar customizável — foto + moldura + badge de nível.
extends Control

# Emitido ao clicar no avatar (abre o perfil do próprio jogador).
signal clicked

const FRAMES: Dictionary = {
	"iron": {
		"a": Color(0.2902, 0.3176, 0.3725, 1.0),
		"b": Color(0.5451, 0.5725, 0.6275, 1.0),
	},
	"ouro": {
		"a": Color(0.5412, 0.4157, 0.1176, 1.0),
		"b": Color(0.9412, 0.7882, 0.3725, 1.0),
	},
	"azure": {
		"a": Color(0.2275, 0.4314, 0.5020, 1.0),
		"b": Color(0.5294, 0.8078, 0.8941, 1.0),
	},
	"carmesim": {
		"a": Color(0.4784, 0.1843, 0.1647, 1.0),
		"b": Color(0.8784, 0.4745, 0.3725, 1.0),
	},
}

@onready var frame_bg    : ColorRect   = $FrameBg
@onready var photo       : TextureRect = $PhotoClip/Photo
@onready var level_badge : Label       = $LevelBadge
@onready var corner_tl   : ColorRect   = $CornerTL
@onready var corner_tr   : ColorRect   = $CornerTR
@onready var corner_bl   : ColorRect   = $CornerBL
@onready var corner_br   : ColorRect   = $CornerBR

func _ready() -> void:
	# Botão transparente por cima do avatar — captura o clique acima dos ColorRects
	# (que por padrão consomem o input). Emite `clicked` para abrir o perfil.
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.tooltip_text = "Ver perfil"
	btn.z_index = 5
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)
	btn.pressed.connect(func() -> void: clicked.emit())
	add_child(btn)

func set_photo(p_tex: Texture2D) -> void:
	photo.texture = p_tex

func set_frame(p_id: String) -> void:
	if not FRAMES.has(p_id):
		return
	var f: Dictionary = FRAMES[p_id]
	frame_bg.color = f["a"]
	for corner: ColorRect in [corner_tl, corner_tr, corner_bl, corner_br]:
		corner.color = f["b"]

func set_level(p_level: int) -> void:
	level_badge.text = "LV %d" % p_level
