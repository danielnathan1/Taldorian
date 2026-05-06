extends Control

# ── TurnTransition ─────────────────────────────────────────────────────────────
# Reutilizável: instancie como filho do Board e chame play("seu_turno"), etc.
#
# Tipos disponíveis:
#   "seu_turno"         — Dourado   — Fase de Ação
#   "turno_oponente"    — Carmesim  — Fase de Ação
#   "sua_reacao"        — Teal      — Janela de Reação
#   "reacao_oponente"   — Âmbar     — Janela de Reação
#
# Uso:
#   $TurnTransition.play("seu_turno")
#   $TurnTransition.transition_finished.connect(_on_transition_done)
# ──────────────────────────────────────────────────────────────────────────────

# ── Constants ─────────────────────────────────────────────────────────────────
const BANNER_HEIGHT   := 72.0
const ENTER_DURATION  := 0.55
const HOLD_DURATION   := 1.50
const EXIT_DURATION   := 0.45
const STREAK_COUNT    := 3          # streaks above AND below the bar
const EDGE_WIDTH_PCT  := 0.14       # fraction of screen width for edge fade

# Pixel offsets of streak lines above/below the banner bar
const STREAK_OFFSETS_ABOVE := [-20.0, -11.0, -6.0]
const STREAK_OFFSETS_BELOW := [  5.0,  11.0, 18.0]
const STREAK_HEIGHTS       := [  1.5,   1.0,  1.0]
const STREAK_ALPHAS        := [  0.70,  0.40, 0.20]

# ── Transition configs ────────────────────────────────────────────────────────
const CONFIGS := {
	"seu_turno": {
		"label":      "Seu Turno",
		"sub":        "Fase de Ação",
		"accent":     Color(0.910, 0.760, 0.337, 1.0),   # gold glow
		"accent_dim": Color(0.788, 0.627, 0.298, 1.0),   # gold
		"stripe":     Color(0.063, 0.082, 0.188, 0.92),  # deep blue-navy
	},
	"turno_oponente": {
		"label":      "Turno do Oponente",
		"sub":        "Fase de Ação",
		"accent":     Color(0.835, 0.150, 0.150, 1.0),   # crimson bright
		"accent_dim": Color(0.690, 0.125, 0.125, 1.0),   # crimson
		"stripe":     Color(0.110, 0.047, 0.047, 0.92),  # dark red
	},
	"sua_reacao": {
		"label":      "Sua Reação",
		"sub":        "Janela de Reação",
		"accent":     Color(0.082, 0.753, 0.769, 1.0),   # teal glow
		"accent_dim": Color(0.071, 0.620, 0.631, 1.0),   # teal
		"stripe":     Color(0.027, 0.075, 0.110, 0.92),  # dark teal
	},
	"reacao_oponente": {
		"label":      "Reação do Oponente",
		"sub":        "Janela de Reação",
		"accent":     Color(0.878, 0.529, 0.082, 1.0),   # amber glow
		"accent_dim": Color(0.769, 0.420, 0.071, 1.0),   # amber
		"stripe":     Color(0.118, 0.071, 0.027, 0.92),  # dark amber
	},
}

# ── Node references ───────────────────────────────────────────────────────────
@onready var banner_track    : Control    = %BannerTrack
@onready var banner_bg       : ColorRect  = %BannerBG
@onready var border_top      : ColorRect  = %BorderTop
@onready var border_bottom   : ColorRect  = %BorderBottom
@onready var content_center  : CenterContainer = %ContentCenter
@onready var main_label      : Label      = %MainLabel
@onready var sub_label       : Label      = %SubLabel
@onready var diamond_left    : ColorRect  = %DiamondLeft
@onready var diamond_right   : ColorRect  = %DiamondRight
@onready var rune_left       : Label      = %RuneLeft
@onready var rune_right      : Label      = %RuneRight
@onready var edge_left       : ColorRect  = %EdgeLeft
@onready var edge_right      : ColorRect  = %EdgeRight

# ── State ─────────────────────────────────────────────────────────────────────
var _tween        : Tween
var _streaks      : Array[ColorRect] = []

signal transition_finished

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	_build_streaks()
	_resize_to_viewport()
	get_viewport().size_changed.connect(_resize_to_viewport)


# ── Public API ────────────────────────────────────────────────────────────────
func play(type: String) -> void:
	if not CONFIGS.has(type):
		push_warning("TurnTransition.play(): tipo desconhecido '%s'" % type)
		return
	_apply_config(CONFIGS[type])
	_run_animation()


func stop() -> void:
	if _tween:
		_tween.kill()
	visible = false


# ── Config application ────────────────────────────────────────────────────────
func _apply_config(cfg: Dictionary) -> void:
	main_label.text = cfg["label"]
	sub_label.text  = cfg["sub"]

	main_label.add_theme_color_override("font_color", cfg["accent"])
	sub_label.add_theme_color_override("font_color",  Color(cfg["accent_dim"], 0.75))
	rune_left.add_theme_color_override("font_color",  Color(cfg["accent_dim"], 0.50))
	rune_right.add_theme_color_override("font_color", Color(cfg["accent_dim"], 0.50))

	diamond_left.color  = cfg["accent"]
	diamond_right.color = cfg["accent"]

	_set_param(banner_bg,     "stripe_color", cfg["stripe"])
	_set_param(border_top,    "line_color",   cfg["accent"])
	_set_param(border_bottom, "line_color",   cfg["accent"])

	# Tint the streaks to match the accent colour
	for sr in _streaks:
		sr.color = Color(cfg["accent_dim"], sr.color.a)


func _set_param(node: ColorRect, param: String, value: Variant) -> void:
	if node.material is ShaderMaterial:
		(node.material as ShaderMaterial).set_shader_parameter(param, value)


# ── Animation ─────────────────────────────────────────────────────────────────
func _run_animation() -> void:
	if _tween:
		_tween.kill()

	_resize_to_viewport()
	var vp_w := get_viewport_rect().size.x

	banner_track.position.x = -vp_w
	modulate.a = 0.0
	visible = true

	_tween = create_tween()

	# ── Enter: slide in from left + fade in ─────────────────────────────────
	_tween.set_parallel(true)
	_tween.tween_property(banner_track, "position:x", 0.0, ENTER_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	_tween.tween_property(self, "modulate:a", 1.0, ENTER_DURATION * 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# ── Hold ─────────────────────────────────────────────────────────────────
	_tween.set_parallel(false)
	_tween.tween_interval(HOLD_DURATION)

	# ── Exit: slide out to right + fade out ──────────────────────────────────
	_tween.set_parallel(true)
	_tween.tween_property(banner_track, "position:x", vp_w, EXIT_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	_tween.tween_property(self, "modulate:a", 0.0, EXIT_DURATION * 0.45) \
		.set_delay(EXIT_DURATION * 0.55) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	_tween.set_parallel(false)
	_tween.tween_callback(_on_animation_finished)


func _on_animation_finished() -> void:
	visible = false
	transition_finished.emit()


# ── Layout ────────────────────────────────────────────────────────────────────
func _resize_to_viewport() -> void:
	var vp    := get_viewport_rect().size
	var bx    := 0.0
	var by    := vp.y * 0.5 - BANNER_HEIGHT * 0.5
	var bw    := vp.x
	var edge_w := bw * EDGE_WIDTH_PCT

	# Banner track (off-screen left by default, animation moves it)
	if not visible:
		banner_track.position = Vector2(-bw, by)
	else:
		banner_track.position.y = by
	banner_track.size = Vector2(bw, BANNER_HEIGHT)

	# Children that fill the track
	for node in [banner_bg, content_center]:
		(node as Control).position = Vector2.ZERO
		(node as Control).size     = Vector2(bw, BANNER_HEIGHT)

	# Border lines
	border_top.position    = Vector2.ZERO
	border_top.size        = Vector2(bw, 2.0)
	border_bottom.position = Vector2(0.0, BANNER_HEIGHT - 2.0)
	border_bottom.size     = Vector2(bw, 2.0)

	# Edge fades
	edge_left.position  = Vector2.ZERO
	edge_left.size      = Vector2(edge_w, BANNER_HEIGHT)
	edge_right.position = Vector2(bw - edge_w, 0.0)
	edge_right.size     = Vector2(edge_w, BANNER_HEIGHT)

	# Streaks
	_resize_streaks(bw)


func _resize_streaks(width: float) -> void:
	for i in _streaks.size():
		_streaks[i].size.x = width


# ── Streak construction ───────────────────────────────────────────────────────
func _build_streaks() -> void:
	var default_color := Color(0.788, 0.627, 0.298, 1.0)  # gold, overridden in _apply_config

	# Above
	for i in STREAK_COUNT:
		var sr := ColorRect.new()
		sr.mouse_filter = MOUSE_FILTER_IGNORE
		sr.position     = Vector2(0.0, STREAK_OFFSETS_ABOVE[i] - STREAK_HEIGHTS[i])
		sr.size         = Vector2(1920.0, STREAK_HEIGHTS[i])
		sr.color        = Color(default_color, STREAK_ALPHAS[i])
		banner_track.add_child(sr)
		_streaks.append(sr)

	# Below
	for i in STREAK_COUNT:
		var sr := ColorRect.new()
		sr.mouse_filter = MOUSE_FILTER_IGNORE
		sr.position     = Vector2(0.0, BANNER_HEIGHT + STREAK_OFFSETS_BELOW[i])
		sr.size         = Vector2(1920.0, STREAK_HEIGHTS[i])
		sr.color        = Color(default_color, STREAK_ALPHAS[STREAK_COUNT - 1 - i])
		banner_track.add_child(sr)
		_streaks.append(sr)
