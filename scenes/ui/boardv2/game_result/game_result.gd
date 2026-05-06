extends Control

# ── GameResult ────────────────────────────────────────────────────────────────
# Overlay de fim de jogo. Instancie como filho do Board.
#
# Uso:
#   $GameResult.show_victory()
#   $GameResult.show_defeat()
#   $GameResult.result_closed.connect(_on_result_closed)
#
# Integração com GameBus:
#   GameBus.game_over.connect(func(winner_idx):
#       if winner_idx == NetworkState.local_player_index:
#           $GameResult.show_victory()
#       else:
#           $GameResult.show_defeat()
#   )
# ─────────────────────────────────────────────────────────────────────────────

signal result_closed   # emitido ao clicar "Voltar ao Menu"

# ── Colors ────────────────────────────────────────────────────────────────────
const VICTORY := {
	"eyebrow":      "Batalha Encerrada",
	"title":        "Vitória!",
	"desc":         "Seus heróis provaram seu valor\nnos campos de Taldorian.",
	"accent":       Color(0.910, 0.760, 0.337, 1.0),
	"accent_dim":   Color(0.788, 0.627, 0.298, 1.0),
	"panel_border": Color(0.788, 0.627, 0.298, 0.30),
	"btn_border":   Color(0.788, 0.627, 0.298, 0.55),
	"btn_color":    Color(0.910, 0.760, 0.337, 1.0),
	"is_victory":   true,
}

const DEFEAT := {
	"eyebrow":      "Batalha Encerrada",
	"title":        "Derrota",
	"desc":         "Seus heróis caíram em batalha.\nA lenda continua…",
	"accent":       Color(0.690, 0.125, 0.125, 1.0),
	"accent_dim":   Color(0.490, 0.086, 0.086, 1.0),
	"panel_border": Color(0.545, 0.102, 0.102, 0.30),
	"btn_border":   Color(0.545, 0.102, 0.102, 0.50),
	"btn_color":    Color(0.780, 0.300, 0.300, 1.0),
	"is_victory":   false,
}

# ── Fonts ─────────────────────────────────────────────────────────────────────
const FONT_BLACK   := preload("res://assets/fonts/CinzelDecorative-Black.ttf")
const FONT_REGULAR := preload("res://assets/fonts/CinzelDecorative-Regular.ttf")

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var overlay_bg     : ColorRect        = %OverlayBG
@onready var card           : Control          = %ResultCard
@onready var crest_victory  : Control          = %CrestVictory
@onready var crest_defeat   : Control          = %CrestDefeat
@onready var eyebrow_label  : Label            = %EyebrowLabel
@onready var title_label    : Label            = %TitleLabel
@onready var desc_label     : Label            = %DescLabel
@onready var panel          : PanelContainer   = %ResultPanel
@onready var menu_button    : Button           = %MenuButton
@onready var particles      : CPUParticles2D   = %ResultParticles

var _tween : Tween

func _ready() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	menu_button.pressed.connect(_on_menu_pressed)


# ── Public API ────────────────────────────────────────────────────────────────
func show_victory() -> void:
	_show(VICTORY)

func show_defeat() -> void:
	_show(DEFEAT)


# ── Internal ──────────────────────────────────────────────────────────────────
func _show(cfg: Dictionary) -> void:
	_apply_config(cfg)
	_setup_particles(cfg.is_victory)

	var vp := get_viewport().get_visible_rect()
	position = vp.position
	size     = vp.size

	visible = true
	modulate.a = 0.0
	card.scale = Vector2(0.88, 0.88)
	card.position.y += 28.0

	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	_tween.tween_property(self, "modulate:a", 1.0, 0.50)
	_tween.tween_property(card, "scale",      Vector2(1.0, 1.0), 0.65)
	_tween.tween_property(card, "position:y", card.position.y - 28.0, 0.65)


func _apply_config(cfg: Dictionary) -> void:
	# Overlay shader
	if overlay_bg.material is ShaderMaterial:
		var mat := overlay_bg.material as ShaderMaterial
		mat.set_shader_parameter("is_victory", cfg.is_victory)

	# Crests
	crest_victory.visible = cfg.is_victory
	crest_defeat.visible  = not cfg.is_victory

	# Labels
	eyebrow_label.text = cfg.eyebrow
	title_label.text   = cfg.title
	desc_label.text    = cfg.desc

	eyebrow_label.add_theme_color_override("font_color", Color(cfg.accent_dim, 0.80))
	title_label.add_theme_color_override("font_color",   cfg.accent)
	desc_label.add_theme_color_override("font_color",    Color(0.72, 0.66, 0.55, 0.75))

	title_label.add_theme_font_override("font",   FONT_BLACK)
	eyebrow_label.add_theme_font_override("font", FONT_REGULAR)
	desc_label.add_theme_font_override("font",    FONT_REGULAR)
	menu_button.add_theme_font_override("font",   FONT_REGULAR)

	# Panel border
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.063, 0.082, 0.188, 0.88)
	panel_style.border_color = cfg.panel_border
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(0)
	panel_style.set_content_margin(SIDE_LEFT,   44.0)
	panel_style.set_content_margin(SIDE_RIGHT,  44.0)
	panel_style.set_content_margin(SIDE_TOP,    36.0)
	panel_style.set_content_margin(SIDE_BOTTOM, 32.0)
	panel.add_theme_stylebox_override("panel", panel_style)

	# Button
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.08, 0.10, 0.18, 0.90)
	btn_normal.border_color = cfg.btn_border
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(0)
	btn_normal.set_content_margin(SIDE_LEFT,   24.0)
	btn_normal.set_content_margin(SIDE_RIGHT,  24.0)
	btn_normal.set_content_margin(SIDE_TOP,    16.0)
	btn_normal.set_content_margin(SIDE_BOTTOM, 16.0)
	var btn_hover := btn_normal.duplicate() as StyleBoxFlat
	btn_hover.bg_color     = Color(0.10, 0.13, 0.22, 0.95)
	btn_hover.border_color = Color(cfg.btn_border.r, cfg.btn_border.g, cfg.btn_border.b, 0.90)
	menu_button.add_theme_stylebox_override("normal",  btn_normal)
	menu_button.add_theme_stylebox_override("hover",   btn_hover)
	menu_button.add_theme_stylebox_override("pressed", btn_normal)
	menu_button.add_theme_color_override("font_color",       cfg.btn_color)
	menu_button.add_theme_color_override("font_hover_color", cfg.accent)


func _setup_particles(is_victory: bool) -> void:
	particles.emitting = false
	particles.amount        = 32 if is_victory else 14
	particles.lifetime      = 10.0
	particles.spread        = 180.0
	particles.direction     = Vector2(0.0, -1.0)
	particles.gravity       = Vector2(0.0, -6.0)
	particles.initial_velocity_min = 25.0
	particles.initial_velocity_max = 65.0
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.5

	var grad := Gradient.new()
	if is_victory:
		grad.set_color(0, Color(0.91, 0.76, 0.34, 0.0))
		grad.add_point(0.1, Color(0.91, 0.76, 0.34, 0.85))
		grad.add_point(0.8, Color(0.91, 0.76, 0.34, 0.35))
		grad.add_point(1.0, Color(0.91, 0.76, 0.34, 0.0))
	else:
		grad.set_color(0, Color(0.69, 0.13, 0.13, 0.0))
		grad.add_point(0.1, Color(0.69, 0.13, 0.13, 0.75))
		grad.add_point(0.8, Color(0.55, 0.10, 0.10, 0.30))
		grad.add_point(1.0, Color(0.55, 0.10, 0.10, 0.0))
	particles.color_ramp = grad
	particles.emitting = true


func _on_menu_pressed() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(self, "modulate:a", 0.0, 0.35)
	_tween.tween_callback(func():
		visible = false
		particles.emitting = false
		result_closed.emit()
	)
