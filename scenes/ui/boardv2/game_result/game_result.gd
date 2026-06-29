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

# ── Reward module colors ──────────────────────────────────────────────────────
const DELTA_POS := Color(0.435, 0.890, 0.604, 1.0)   # ganho de pontos (verde)
const DELTA_NEG := Color(0.843, 0.337, 0.251, 1.0)   # perda de pontos (vermelho)
const GOLD_COIN := Color(0.949, 0.812, 0.416, 1.0)   # ouro (sempre dourado)
const PTS_INK   := Color(0.957, 0.941, 0.902, 1.0)   # número de pontos (claro)

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

# ── Reward module (rank + pontos + ouro), construído em código e oculto até chegar
#    o RPC de recompensa (partidas rankeadas). Casual nunca recebe → fica oculto. ──
var _rank_module   : HBoxContainer = null
var _rank_shield   : ProfileRankShield = null
var _rank_tier_lbl : Label = null
var _rank_label_lbl: Label = null
var _delta_badge   : PanelContainer = null
var _delta_lbl     : Label = null
var _pts_value     : Label = null
var _pts_unit      : Label = null
var _pts_track     : ColorRect = null
var _pts_fill      : ColorRect = null
var _reward_row    : HBoxContainer = null
var _reward_value  : Label = null
var _reward_spacers: Array[Control] = []   # espaçadores do módulo (escondem junto com ele)

var _shown           : bool = false       # card já revelado (gate da animação de rank/ouro)
var _pending_rewards : Dictionary = {}     # recompensa que chegou antes do card aparecer

func _ready() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	menu_button.pressed.connect(_on_menu_pressed)
	_build_reward_ui()


# ── Public API ────────────────────────────────────────────────────────────────
func show_victory() -> void:
	_show(VICTORY)

func show_defeat() -> void:
	_show(DEFEAT)


# ── Internal ──────────────────────────────────────────────────────────────────
func _show(cfg: Dictionary) -> void:
	_apply_config(cfg)
	_setup_particles(cfg.is_victory)

	# Módulo de rank/ouro começa oculto; só aparece se chegar apply_rewards (rankeada).
	if _rank_module:
		_rank_module.visible = false
	if _reward_row:
		_reward_row.visible = false
	for sp in _reward_spacers:
		sp.visible = false

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

	# Card revelado: se a recompensa já chegou (corrida com o HTTP), anima agora.
	_shown = true
	if not _pending_rewards.is_empty():
		_play_rewards(_pending_rewards)


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


# ── Reward module — construção (uma vez) ──────────────────────────────────────
# Monta o escudo de rank, contador de pontos + barra e a linha de ouro, e os insere
# no painel logo acima do botão "Voltar". Tudo oculto até apply_rewards().
func _build_reward_ui() -> void:
	var vbox := menu_button.get_parent() as VBoxContainer
	if vbox == null:
		return
	var insert_at := menu_button.get_index()   # inserir antes do botão

	# Espaço acima do módulo de rank.
	var top_spacer := Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 18)

	# ── Rank module ───────────────────────────────────────────────────────────
	_rank_module = HBoxContainer.new()
	_rank_module.add_theme_constant_override("separation", 16)
	_rank_module.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rank_module.visible = false

	_rank_shield = ProfileRankShield.new()
	_rank_shield.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_rank_shield.set_rank("Madeira", "", 54.0)
	_rank_module.add_child(_rank_shield)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 5)
	_rank_module.add_child(info)

	var top := HBoxContainer.new()
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(top)

	var name_wrap := VBoxContainer.new()
	name_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_wrap.add_theme_constant_override("separation", 1)
	top.add_child(name_wrap)

	_rank_label_lbl = _make_label("Rank Atual", FONT_REGULAR, 10, true)
	name_wrap.add_child(_rank_label_lbl)
	_rank_tier_lbl = _make_label("Madeira", FONT_REGULAR, 17, false)
	name_wrap.add_child(_rank_tier_lbl)

	_delta_badge = PanelContainer.new()
	_delta_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var badge_margin := MarginContainer.new()
	badge_margin.add_theme_constant_override("margin_left", 9)
	badge_margin.add_theme_constant_override("margin_right", 9)
	badge_margin.add_theme_constant_override("margin_top", 3)
	badge_margin.add_theme_constant_override("margin_bottom", 3)
	_delta_badge.add_child(badge_margin)
	_delta_lbl = _make_label("+0", null, 15, false)
	badge_margin.add_child(_delta_lbl)
	top.add_child(_delta_badge)

	var pts_row := HBoxContainer.new()
	pts_row.add_theme_constant_override("separation", 6)
	info.add_child(pts_row)
	_pts_value = _make_label("0", null, 26, false)
	_pts_value.add_theme_color_override("font_color", PTS_INK)
	pts_row.add_child(_pts_value)
	_pts_unit = _make_label("/ 100 pts", FONT_REGULAR, 11, true)
	_pts_unit.size_flags_vertical = Control.SIZE_SHRINK_END
	pts_row.add_child(_pts_unit)

	# Barra de progresso (track + fill por anchor).
	_pts_track = ColorRect.new()
	_pts_track.color = Color(0.094, 0.094, 0.180, 1.0)
	_pts_track.custom_minimum_size = Vector2(0, 9)
	_pts_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pts_track.clip_contents = true
	info.add_child(_pts_track)
	_pts_fill = ColorRect.new()
	_pts_fill.color = Color(0.91, 0.76, 0.337, 1.0)
	_pts_fill.anchor_left = 0.0
	_pts_fill.anchor_top = 0.0
	_pts_fill.anchor_bottom = 1.0
	_pts_fill.anchor_right = 0.0
	_pts_fill.offset_left = 0.0
	_pts_fill.offset_top = 0.0
	_pts_fill.offset_right = 0.0
	_pts_fill.offset_bottom = 0.0
	_pts_track.add_child(_pts_fill)

	# ── Reward row (ouro) ─────────────────────────────────────────────────────
	var reward_spacer := Control.new()
	reward_spacer.custom_minimum_size = Vector2(0, 14)

	_reward_row = HBoxContainer.new()
	_reward_row.add_theme_constant_override("separation", 8)
	_reward_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reward_row.visible = false
	var coin := _make_label("●", null, 16, false)
	coin.add_theme_color_override("font_color", GOLD_COIN)
	_reward_row.add_child(coin)
	var reward_label := _make_label("Ouro Ganho", FONT_REGULAR, 10, true)
	reward_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_label.add_theme_color_override("font_color", Color(0.761, 0.655, 0.400, 0.9))
	_reward_row.add_child(reward_label)
	_reward_value = _make_label("+0", null, 19, false)
	_reward_value.add_theme_color_override("font_color", GOLD_COIN)
	_reward_row.add_child(_reward_value)

	var bottom_spacer := Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 22)

	# Espaçadores escondem junto com o módulo (sem buraco em partidas casuais).
	_reward_spacers = [top_spacer, reward_spacer, bottom_spacer]
	for sp in _reward_spacers:
		sp.visible = false

	# Inserir na ordem, todos antes do botão.
	for node in [top_spacer, _rank_module, reward_spacer, _reward_row, bottom_spacer]:
		vbox.add_child(node)
		vbox.move_child(node, insert_at)
		insert_at += 1


func _make_label(p_text: String, p_font: Variant, p_size: int, p_upper: bool) -> Label:
	var lbl := Label.new()
	lbl.text = p_text
	lbl.uppercase = p_upper
	if p_font != null:
		lbl.add_theme_font_override("font", p_font)
	lbl.add_theme_font_size_override("font_size", p_size)
	return lbl


# ── Reward module — população + animação ──────────────────────────────────────
# data = { result, tier_enum, points, points_delta, gold, apex }
# Pode chegar antes do card aparecer (corrida com o HTTP) — nesse caso, bufferiza e
# anima quando _show terminar.
func apply_rewards(data: Dictionary) -> void:
	if _rank_module == null:
		return
	_pending_rewards = data
	if _shown:
		_play_rewards(data)


func _play_rewards(data: Dictionary) -> void:
	var is_victory := str(data.get("result", "victory")) == "victory"
	var cfg: Dictionary = VICTORY if is_victory else DEFEAT
	var accent: Color = cfg.accent
	var accent_dim: Color = cfg.accent_dim

	var delta: int = int(data.get("points_delta", 0))
	var delta_color: Color = DELTA_POS if delta >= 0 else DELTA_NEG
	var tier_name := _tier_display(str(data.get("tier_enum", "MADEIRA")))
	var apex: bool = bool(data.get("apex", false))
	var gold: int = int(data.get("gold", 0))

	var lp_after: int = int(data.get("points", 0))
	var lp_max := 100
	var lp_before: int
	if apex:
		lp_before = maxi(0, lp_after - delta)
		lp_max = maxi(maxi(lp_after, lp_before), 1)
	else:
		lp_after = clampi(lp_after, 0, lp_max)
		lp_before = clampi(lp_after - delta, 0, lp_max)

	# População.
	_rank_shield.set_rank(tier_name, "", 54.0)
	_rank_tier_lbl.text = tier_name
	_rank_tier_lbl.add_theme_color_override("font_color", Color(0.902, 0.886, 0.933, 1.0))
	_rank_label_lbl.add_theme_color_override("font_color", Color(accent_dim, 0.85))
	_pts_unit.text = "pts" if apex else "/ %d pts" % lp_max
	_pts_unit.add_theme_color_override("font_color", accent_dim)
	_pts_fill.color = accent

	_delta_lbl.text = ("+%d" % delta) if delta >= 0 else ("−%d" % absi(delta))
	_delta_lbl.add_theme_color_override("font_color", delta_color)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(delta_color.r, delta_color.g, delta_color.b, 0.14)
	badge_style.border_color = Color(delta_color.r, delta_color.g, delta_color.b, 0.5)
	badge_style.set_border_width_all(1)
	_delta_badge.add_theme_stylebox_override("panel", badge_style)

	# Estado inicial (antes da animação).
	_pts_value.text = str(lp_before)
	_pts_value.add_theme_color_override("font_color", PTS_INK)
	_pts_fill.anchor_right = float(lp_before) / float(lp_max)
	_delta_badge.modulate.a = 0.0
	_rank_module.modulate.a = 0.0
	_rank_module.visible = true
	_reward_row.modulate.a = 0.0
	_reward_row.visible = true
	_reward_value.text = "+0"
	for sp in _reward_spacers:
		sp.visible = true

	# Timeline: fade do módulo → pop do delta + contagem dos pontos/barra → ouro.
	var t := create_tween()
	t.tween_property(_rank_module, "modulate:a", 1.0, 0.35)
	t.tween_callback(_pop_delta_badge)
	t.tween_method(
		func(v: float) -> void: _pts_value.text = str(int(round(v))),
		float(lp_before), float(lp_after), 1.0
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(
		_pts_fill, "anchor_right", float(lp_after) / float(lp_max), 1.0
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.1)
	t.tween_property(_reward_row, "modulate:a", 1.0, 0.3)
	t.parallel().tween_method(
		func(v: float) -> void: _reward_value.text = "+%d" % int(round(v)),
		0.0, float(gold), 0.8
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _pop_delta_badge() -> void:
	_delta_badge.pivot_offset = _delta_badge.size / 2.0
	_delta_badge.scale = Vector2(0.85, 0.85)
	var t := create_tween()
	t.parallel().tween_property(_delta_badge, "modulate:a", 1.0, 0.3)
	t.parallel().tween_property(_delta_badge, "scale", Vector2(1.12, 1.12), 0.32)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(_delta_badge, "scale", Vector2.ONE, 0.18)


static func _tier_display(p_enum: String) -> String:
	match p_enum:
		"MADEIRA":    return "Madeira"
		"BRONZE":     return "Bronze"
		"PRATA":      return "Prata"
		"OURO":       return "Ouro"
		"DIAMANTE":   return "Diamante"
		"PRISMATICO": return "Prismático"
		"LENDA":      return "Lenda"
		_:            return "Madeira"


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
