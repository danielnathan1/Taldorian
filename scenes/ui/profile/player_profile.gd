# scenes/ui/profile/player_profile.gd
# Modal "Dossiê de Campo" — perfil do jogador sobre a HUD do mundo.
# Presentation-only: recebe dados via set_profile(), não conhece regra de jogo.
# Modo edição (set_editable(true)) habilita trocar borda (anel), ícone e carta
# preferida — persistido em user://profile.cfg (compartilhado com a WorldHUD).
class_name PlayerProfile
extends CanvasLayer

signal closed
signal favorite_card_pressed(card_id: String)
signal guild_pressed

const PROFILE_PATH := "user://profile.cfg"
const ICONS_DIR    := "res://assets/profile_icons"

# ── Paleta (extraída do HTML de referência) ──────────────────────────────────────
const C_PANEL       := Color(0.0824, 0.0941, 0.1216, 0.94)
const C_INSET       := Color(0.0392, 0.0471, 0.0667, 0.55)
const C_LINE        := Color("2a2e3a")
const C_LINE_BRIGHT := Color("3a4150")
const C_INK         := Color("e7e3da")
const C_INK_DIM     := Color("b7b6ad")
const C_MUTED       := Color("8b8f9c")
const C_MUTED2      := Color("6b6f7c")
const C_GOLD        := Color("e0b04a")
const C_GOLD_BRIGHT := Color("f5cf6a")
const C_GUILD       := Color("8fd99a")
const C_DANGER      := Color("e0795f")
const C_SCRIM       := Color(0.0314, 0.0353, 0.0510, 0.62)

# Opções de cor de borda (mesmas do protótipo de tweaks).
const RING_OPTIONS: Array[Color] = [
	Color("6b7385"), Color("e0b04a"), Color("b89cff"), Color("8fd99a"), Color("e0795f"),
]

var _editable: bool = false
var _data: Dictionary = {}
var _ring_color: Color = C_GOLD
var _photo_path: String = ""
var _fav_name: String = ""

# ── Refs de nós ──────────────────────────────────────────────────────────────────
var _root: Control
var _scrim: ColorRect
var _card: PanelContainer
var _medallion: ProfileAvatarMedallion
var _nick_lbl: Label
var _crest: ProfileGuildCrest
var _gname_lbl: Label
var _role_lbl: Label
var _shield: ProfileRankShield
var _cur_rank_lbl: Label
var _cur_pts_lbl: Label
var _peak_seal: ProfilePeakSeal
var _peak_rank_lbl: Label
var _peak_season_lbl: Label
var _winbar: ProfileWinBar
var _since_val: Label
var _winrate_val: Label
var _streak_val: Label
var _favcard: ProfileFavCard
var _favname_lbl: Label
var _edit_btn: Button
var _edit_bar: Control
var _card_picker: Control
var _icon_picker: Control

# ══════════════════════════════════════════════════════════════════════════════════
# API pública
# ══════════════════════════════════════════════════════════════════════════════════

func set_profile(p_data: Dictionary) -> void:
	_data = p_data
	_fav_name = str(p_data.get("fav", {}).get("name", ""))
	_refresh()

func set_editable(p_value: bool) -> void:
	_editable = p_value
	if _edit_btn:
		_edit_btn.visible = p_value
	if not p_value and _edit_bar:
		_edit_bar.visible = false
	if p_value:
		_load_own_overrides()

func set_ring_color(p_color: Color) -> void:
	_ring_color = p_color
	if _medallion:
		_medallion.set_ring_color(p_color)

func set_avatar_photo(p_tex: Texture2D) -> void:
	if _medallion:
		_medallion.set_photo(p_tex)

func set_favorite_card(p_data: Dictionary) -> void:
	if _data.is_empty():
		_data = {}
	_data["fav"] = p_data
	_fav_name = str(p_data.get("name", ""))
	_apply_fav(p_data)

## Aplica a posição rankeada vinda do backend (resposta de GET /players/me/ranked) e
## redesenha. Mapeia os nomes de tier do backend (MADEIRA…LENDA) para os de exibição.
func apply_ranked(p_ranked: Dictionary) -> void:
	if _data.is_empty():
		_data = {}
	var to_next: Variant = p_ranked.get("pointsToNextTier", null)
	_data["current"] = {
		"tier":    _tier_display(str(p_ranked.get("tier", "MADEIRA"))),
		"pts":     int(p_ranked.get("points", 0)),
		"to_next": int(to_next) if to_next != null else -1,   # -1 = apex (Lenda, sem teto)
	}
	_data["peak"] = {
		"tier":        _tier_display(str(p_ranked.get("peakTier", "MADEIRA"))),
		"best_streak": int(p_ranked.get("bestStreak", 0)),
	}
	_data["record"] = { "w": int(p_ranked.get("wins", 0)), "l": int(p_ranked.get("losses", 0)) }
	_data["streak"] = int(p_ranked.get("winStreak", 0))
	_refresh()

## Busca a posição rankeada do próprio jogador no backend e aplica. No-op sem autenticação.
func refresh_ranked_from_backend() -> void:
	if not ApiClient.is_authenticated():
		return
	var res: Dictionary = await ApiClient.get_my_ranked()
	if res.get("ok", false) and res.get("data") is Dictionary:
		apply_ranked(res.data)

## Nome de exibição (com acento/caixa) a partir do enum RankedTier do backend.
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

# ══════════════════════════════════════════════════════════════════════════════════
# Dados padrão (seed) — usado pelo host quando não há backend de perfil.
# ══════════════════════════════════════════════════════════════════════════════════

static func default_data(p_nick: String, p_level: int = 1) -> Dictionary:
	var fav := _fav_from_card_name("Golpe Bruto")
	if fav.is_empty():
		fav = { "name": "Golpe Bruto", "element": "Fogo", "atk": 4, "art_key": "golpe_bruto" }
	return {
		"nick": p_nick,
		"level": p_level,
		# Rankeado: começa em Madeira, 0 pontos. Os valores reais vêm de
		# refresh_ranked_from_backend() (GET /players/me/ranked) para o próprio jogador.
		"current": { "tier": "Madeira", "pts": 0, "to_next": 100 },
		"peak": { "tier": "Madeira", "best_streak": 0 },
		"guild": { "name": "Ordem de Tal'dorian", "role": "Oficial", "color": C_GUILD },
		"record": { "w": 0, "l": 0 },
		"streak": 0,
		"since": "Mar 2024",
		"fav": fav,
	}

static func _fav_from_card_name(p_name: String) -> Dictionary:
	var d: Dictionary = Collection.get_card_dict(p_name)
	if d.is_empty():
		return {}
	var syms: Array[String] = []
	for s in d.get("symbols", []):
		syms.append(str(s))
	var element := GameSymbols.display_chain(syms) if not syms.is_empty() else ""
	return {
		"name": str(d.get("name", "")),
		"element": element,
		"atk": int(d.get("attack_value", 0)),
		"art_key": str(d.get("art_key", "")),
	}

# ══════════════════════════════════════════════════════════════════════════════════
# Lifecycle / construção
# ══════════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	layer = 9
	_build_ui()
	_animate_in()

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_scrim = ColorRect.new()
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.color = C_SCRIM
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.gui_input.connect(_on_scrim_input)
	_root.add_child(_scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(600, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.add_theme_stylebox_override("panel", _panel_style(C_PANEL, C_LINE_BRIGHT, 2))
	center.add_child(_card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	_card.add_child(vbox)

	vbox.add_child(_build_titlebar())
	vbox.add_child(_hline(2, C_LINE_BRIGHT))
	vbox.add_child(_build_body())
	_edit_bar = _build_edit_bar()
	vbox.add_child(_edit_bar)

func _build_titlebar() -> Control:
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 12)
	mc.add_theme_constant_override("margin_right", 10)
	mc.add_theme_constant_override("margin_top", 9)
	mc.add_theme_constant_override("margin_bottom", 9)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	mc.add_child(hb)

	var title := _lbl("PERFIL DO JOGADOR", C_GOLD_BRIGHT, 10)
	hb.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)

	_edit_btn = _icon_button("✎", C_MUTED)
	_edit_btn.visible = false
	_edit_btn.tooltip_text = "Editar perfil"
	_edit_btn.pressed.connect(_toggle_edit_bar)
	hb.add_child(_edit_btn)

	var close_btn := _icon_button("✕", C_MUTED)
	close_btn.tooltip_text = "Fechar"
	close_btn.pressed.connect(close)
	close_btn.mouse_entered.connect(func() -> void: close_btn.add_theme_color_override("font_color", C_DANGER))
	close_btn.mouse_exited.connect(func() -> void: close_btn.add_theme_color_override("font_color", C_MUTED))
	hb.add_child(close_btn)
	return mc

func _build_body() -> Control:
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 0)

	body.add_child(_build_identity())
	body.add_child(_vline(C_LINE))
	body.add_child(_build_detail())
	body.add_child(_vline(C_LINE))
	body.add_child(_build_fav())
	return body

func _build_identity() -> Control:
	var mc := _column(152, 14, 20, 14, 16)
	var col: VBoxContainer = mc.get_child(0)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_theme_constant_override("separation", 9)

	_medallion = ProfileAvatarMedallion.new()
	_medallion.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_medallion)

	_nick_lbl = _lbl("—", C_INK, 19)
	_nick_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nick_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_nick_lbl)

	# Chip da guild.
	var chip := PanelContainer.new()
	var chip_sb := _panel_style(Color(0.561, 0.851, 0.604, 0.08), Color(0.561, 0.851, 0.604, 0.2), 1)
	chip.add_theme_stylebox_override("panel", chip_sb)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var chip_mc := MarginContainer.new()
	chip_mc.add_theme_constant_override("margin_left", 8)
	chip_mc.add_theme_constant_override("margin_right", 8)
	chip_mc.add_theme_constant_override("margin_top", 4)
	chip_mc.add_theme_constant_override("margin_bottom", 4)
	chip.add_child(chip_mc)
	var chip_hb := HBoxContainer.new()
	chip_hb.add_theme_constant_override("separation", 6)
	chip_mc.add_child(chip_hb)
	_crest = ProfileGuildCrest.new()
	_crest.custom_minimum_size = Vector2(15, 15)
	chip_hb.add_child(_crest)
	_gname_lbl = _lbl("—", C_GUILD, 12)
	chip_hb.add_child(_gname_lbl)
	chip.gui_input.connect(_on_guild_input)
	col.add_child(chip)

	_role_lbl = _lbl("—", C_MUTED2, 8)
	_role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_role_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_role_lbl)
	return mc

func _build_detail() -> Control:
	var mc := _column(0, 16, 16, 16, 16)
	mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col: VBoxContainer = mc.get_child(0)
	col.add_theme_constant_override("separation", 14)

	# Linha de ranks (atual + peak).
	var ranks := HBoxContainer.new()
	ranks.add_theme_constant_override("separation", 14)
	col.add_child(ranks)

	var rank_main := HBoxContainer.new()
	rank_main.add_theme_constant_override("separation", 12)
	rank_main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ranks.add_child(rank_main)
	_shield = ProfileRankShield.new()
	_shield.set_rank("Madeira", "", 78)
	rank_main.add_child(_shield)
	var rank_text := VBoxContainer.new()
	rank_text.add_theme_constant_override("separation", 3)
	rank_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rank_main.add_child(rank_text)
	rank_text.add_child(_lbl("RANK ATUAL", C_MUTED, 8))
	_cur_rank_lbl = _lbl("—", C_GOLD_BRIGHT, 21)
	rank_text.add_child(_cur_rank_lbl)
	_cur_pts_lbl = _lbl("—", C_INK_DIM, 9)
	rank_text.add_child(_cur_pts_lbl)

	var rank_peak := HBoxContainer.new()
	rank_peak.add_theme_constant_override("separation", 9)
	rank_peak.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ranks.add_child(rank_peak)
	_peak_seal = ProfilePeakSeal.new()
	_peak_seal.set_rank("Madeira", "", 42)
	rank_peak.add_child(_peak_seal)
	var peak_text := VBoxContainer.new()
	peak_text.add_theme_constant_override("separation", 2)
	peak_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rank_peak.add_child(peak_text)
	peak_text.add_child(_lbl("MAIOR RANK", C_MUTED, 8))
	_peak_rank_lbl = _lbl("—", C_INK_DIM, 14)
	peak_text.add_child(_peak_rank_lbl)
	_peak_season_lbl = _lbl("—", C_MUTED2, 7)
	peak_text.add_child(_peak_season_lbl)

	# Bloco de estatísticas.
	var stats := PanelContainer.new()
	stats.add_theme_stylebox_override("panel", _panel_style(C_INSET, C_LINE, 1))
	col.add_child(stats)
	var stats_mc := MarginContainer.new()
	stats_mc.add_theme_constant_override("margin_left", 13)
	stats_mc.add_theme_constant_override("margin_right", 13)
	stats_mc.add_theme_constant_override("margin_top", 12)
	stats_mc.add_theme_constant_override("margin_bottom", 12)
	stats.add_child(stats_mc)
	var stats_col := VBoxContainer.new()
	stats_col.add_theme_constant_override("separation", 11)
	stats_mc.add_child(stats_col)

	var win_block := VBoxContainer.new()
	win_block.add_theme_constant_override("separation", 6)
	stats_col.add_child(win_block)
	win_block.add_child(_lbl("VITÓRIAS / DERROTAS", C_MUTED, 8))
	_winbar = ProfileWinBar.new()
	win_block.add_child(_winbar)

	stats_col.add_child(_hline(1, C_LINE))
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 22)
	stats_col.add_child(grid)
	var since_row := _stat_row("MEMBRO DESDE", "—")
	grid.add_child(since_row[0])
	_since_val = since_row[1]
	var wr_row := _stat_row("APROVEIT.", "—")
	grid.add_child(wr_row[0])
	_winrate_val = wr_row[1]
	var streak_row := _stat_row("SEQUÊNCIA", "—")
	grid.add_child(streak_row[0])
	_streak_val = streak_row[1]
	return mc

func _build_fav() -> Control:
	var mc := _column(132, 14, 18, 14, 16)
	var col: VBoxContainer = mc.get_child(0)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_theme_constant_override("separation", 9)

	var lbl := _lbl("CARTA PREFERIDA", C_GOLD, 8)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(lbl)

	_favcard = ProfileFavCard.new()
	_favcard.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_favcard.pressed.connect(_on_fav_pressed)
	col.add_child(_favcard)

	_favname_lbl = _lbl("—", C_INK_DIM, 12)
	_favname_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_favname_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_favname_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_favname_lbl)
	return mc

func _build_edit_bar() -> Control:
	var pc := PanelContainer.new()
	pc.visible = false
	pc.add_theme_stylebox_override("panel", _panel_style(C_INSET, C_LINE_BRIGHT, 0, 2))
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 12)
	mc.add_theme_constant_override("margin_right", 12)
	mc.add_theme_constant_override("margin_top", 8)
	mc.add_theme_constant_override("margin_bottom", 8)
	pc.add_child(mc)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	mc.add_child(hb)

	hb.add_child(_lbl("BORDA", C_MUTED, 8))
	for c: Color in RING_OPTIONS:
		hb.add_child(_swatch(c))

	hb.add_child(_vline(C_LINE))
	var icon_btn := _text_button("Ícone…")
	icon_btn.pressed.connect(_open_icon_picker)
	hb.add_child(icon_btn)
	var card_btn := _text_button("Carta…")
	card_btn.pressed.connect(_open_card_picker)
	hb.add_child(card_btn)
	return pc

# ══════════════════════════════════════════════════════════════════════════════════
# Preenchimento
# ══════════════════════════════════════════════════════════════════════════════════

func _refresh() -> void:
	if _card == null or _data.is_empty():
		return
	_nick_lbl.text = str(_data.get("nick", "Jogador"))
	_medallion.set_level(int(_data.get("level", 1)))
	_medallion.set_ring_color(_ring_color)

	var guild: Dictionary = _data.get("guild", {})
	var gcolor: Color = guild.get("color", C_GUILD)
	_gname_lbl.text = str(guild.get("name", "—"))
	_gname_lbl.add_theme_color_override("font_color", gcolor)
	_crest.setup(gcolor, 15)
	_role_lbl.text = str(guild.get("role", "")).to_upper()

	var cur: Dictionary = _data.get("current", {})
	var cur_tier := str(cur.get("tier", "Madeira"))
	_shield.set_rank(cur_tier, "", 78)
	_cur_rank_lbl.text = cur_tier
	var to_next := int(cur.get("to_next", -1))
	if to_next < 0:
		_cur_pts_lbl.text = "%d PTS" % int(cur.get("pts", 0))   # Lenda (apex): sem teto
	else:
		_cur_pts_lbl.text = "%d / 100 PTS" % int(cur.get("pts", 0))

	var peak: Dictionary = _data.get("peak", {})
	var peak_tier := str(peak.get("tier", "Madeira"))
	_peak_seal.set_rank(peak_tier, "", 42)
	_peak_rank_lbl.text = peak_tier
	var best_streak := int(peak.get("best_streak", 0))
	_peak_season_lbl.text = ("SEQ. MÁX. %d" % best_streak) if best_streak > 0 else ""

	var rec: Dictionary = _data.get("record", {})
	var w := int(rec.get("w", 0))
	var l := int(rec.get("l", 0))
	_winbar.set_record(w, l)
	_since_val.text = str(_data.get("since", "—"))
	var total := w + l
	var wr := 0
	if total > 0:
		wr = int(round(float(w) / float(total) * 100.0))
	_winrate_val.text = "%d%%" % wr
	var streak := int(_data.get("streak", 0))
	_streak_val.text = ("🔥 %d" % streak) if streak > 0 else "0"

	_apply_fav(_data.get("fav", {}))

func _apply_fav(p_fav: Dictionary) -> void:
	if _favcard == null:
		return
	var tex: Texture2D = p_fav.get("art", null)
	if tex == null:
		tex = CardArt.texture_for(str(p_fav.get("art_key", "")))
	_favcard.set_card({
		"name": p_fav.get("name", ""),
		"element": p_fav.get("element", ""),
		"atk": int(p_fav.get("atk", 0)),
		"art": tex,
	}, 104, -5.0)
	_favname_lbl.text = str(p_fav.get("name", "—"))

# ══════════════════════════════════════════════════════════════════════════════════
# Edição
# ══════════════════════════════════════════════════════════════════════════════════

func _toggle_edit_bar() -> void:
	if _edit_bar:
		_edit_bar.visible = not _edit_bar.visible

func _on_ring_swatch(p_color: Color) -> void:
	set_ring_color(p_color)
	_save_profile()

# Lista os ícones disponíveis em res://assets/profile_icons (no futuro: ganhos/comprados).
func _list_profile_icons() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(ICONS_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		# No editor os arquivos vêm como .png; em export, como .png.import — normaliza.
		var fname := f
		if fname.ends_with(".import"):
			fname = fname.trim_suffix(".import")
		if fname.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp", "svg"]:
			var path := "%s/%s" % [ICONS_DIR, fname]
			if not path in out and ResourceLoader.exists(path):
				out.append(path)
	out.sort()
	return out

func _open_icon_picker() -> void:
	if _icon_picker != null and is_instance_valid(_icon_picker):
		return
	_icon_picker = _build_icon_picker()
	_root.add_child(_icon_picker)

func _build_icon_picker() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.4)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			overlay.queue_free())
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(360, 0)
	pc.add_theme_stylebox_override("panel", _panel_style(C_PANEL, C_LINE_BRIGHT, 2))
	center.add_child(pc)
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 14)
	mc.add_theme_constant_override("margin_right", 14)
	mc.add_theme_constant_override("margin_top", 14)
	mc.add_theme_constant_override("margin_bottom", 14)
	pc.add_child(mc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	mc.add_child(vb)
	vb.add_child(_lbl("ESCOLHER ÍCONE", C_GOLD, 9))

	var icons := _list_profile_icons()
	if icons.is_empty():
		vb.add_child(_lbl("Nenhum ícone disponível ainda.", C_MUTED, 11))
		return overlay

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)
	for path: String in icons:
		grid.add_child(_icon_swatch(path, overlay))
	return overlay

# Botão-miniatura de um ícone (anel arredondado + foto recortada via shader).
func _icon_swatch(p_path: String, p_overlay: Control) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(64, 64)
	b.tooltip_text = p_path.get_file().get_basename()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("2c313c")
	sb.set_border_width_all(2)
	sb.border_color = C_LINE_BRIGHT
	sb.set_corner_radius_all(32)
	b.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate()
	sb_h.border_color = C_GOLD
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_stylebox_override("pressed", sb_h)
	b.add_theme_stylebox_override("focus", sb_h)

	var tex := load(p_path) as Texture2D
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 4; tr.offset_top = 4; tr.offset_right = -4; tr.offset_bottom = -4
		var mat := ShaderMaterial.new()
		mat.shader = ProfileAvatarMedallion.CIRCLE_MASK
		tr.material = mat
		b.add_child(tr)
	b.pressed.connect(_on_icon_chosen.bind(p_path, p_overlay))
	return b

func _on_icon_chosen(p_path: String, p_overlay: Control) -> void:
	var tex := load(p_path) as Texture2D
	if tex == null:
		return
	_photo_path = p_path
	set_avatar_photo(tex)
	_save_profile()
	if is_instance_valid(p_overlay):
		p_overlay.queue_free()

func _load_external_texture(p_path: String) -> Texture2D:
	if p_path.begins_with("res://") or p_path.begins_with("user://"):
		if ResourceLoader.exists(p_path):
			return load(p_path)
		return null
	var img := Image.new()
	if img.load(p_path) != OK:
		return null
	return ImageTexture.create_from_image(img)

func _open_card_picker() -> void:
	if _card_picker != null and is_instance_valid(_card_picker):
		return
	_card_picker = _build_card_picker()
	_root.add_child(_card_picker)

func _build_card_picker() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.4)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			overlay.queue_free())
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(360, 420)
	pc.add_theme_stylebox_override("panel", _panel_style(C_PANEL, C_LINE_BRIGHT, 2))
	center.add_child(pc)
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 12)
	mc.add_theme_constant_override("margin_right", 12)
	mc.add_theme_constant_override("margin_top", 12)
	mc.add_theme_constant_override("margin_bottom", 12)
	pc.add_child(mc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	mc.add_child(vb)
	vb.add_child(_lbl("ESCOLHER CARTA PREFERIDA", C_GOLD, 9))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 340)
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)

	for d: Dictionary in Collection.all_card_dicts:
		var cname := str(d.get("name", ""))
		if cname == "":
			continue
		var b := Button.new()
		b.text = cname
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(_on_card_chosen.bind(cname, overlay))
		list.add_child(b)
	return overlay

func _on_card_chosen(p_name: String, p_overlay: Control) -> void:
	var fav := _fav_from_card_name(p_name)
	if not fav.is_empty():
		set_favorite_card(fav)
		_save_profile()
	if is_instance_valid(p_overlay):
		p_overlay.queue_free()

# ══════════════════════════════════════════════════════════════════════════════════
# Persistência (compartilhada com a WorldHUD)
# ══════════════════════════════════════════════════════════════════════════════════

func _save_profile() -> void:
	if not _editable:
		return
	var cfg := ConfigFile.new()
	cfg.load(PROFILE_PATH)  # mantém chaves existentes (ex.: frame_id da HUD)
	cfg.set_value("avatar", "ring_color", _ring_color.to_html(false))
	if _photo_path != "":
		cfg.set_value("avatar", "photo_path", _photo_path)
	if _fav_name != "":
		cfg.set_value("profile", "favorite_card", _fav_name)
	cfg.save(PROFILE_PATH)

func _load_own_overrides() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) != OK:
		return
	var ring_html: String = cfg.get_value("avatar", "ring_color", "")
	if ring_html != "":
		set_ring_color(Color.html(ring_html))
	_photo_path = cfg.get_value("avatar", "photo_path", "")
	if _photo_path != "":
		var tex := _load_external_texture(_photo_path)
		if tex:
			set_avatar_photo(tex)
	var fav_name: String = cfg.get_value("profile", "favorite_card", "")
	if fav_name != "":
		var fav := _fav_from_card_name(fav_name)
		if not fav.is_empty():
			set_favorite_card(fav)

# ══════════════════════════════════════════════════════════════════════════════════
# Interação / fechamento
# ══════════════════════════════════════════════════════════════════════════════════

func _on_scrim_input(p_event: InputEvent) -> void:
	if p_event is InputEventMouseButton and p_event.pressed:
		close()

func _on_fav_pressed() -> void:
	favorite_card_pressed.emit(_fav_name)

func _on_guild_input(p_event: InputEvent) -> void:
	if p_event is InputEventMouseButton and p_event.pressed:
		guild_pressed.emit()

func _input(p_event: InputEvent) -> void:
	if p_event is InputEventKey and p_event.pressed and p_event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _animate_in() -> void:
	_scrim.modulate.a = 0.0
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.98, 0.98)
	_fix_pivot.call_deferred()  # pivot central após o layout calcular o tamanho do cartão
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_scrim, "modulate:a", 1.0, 0.18)
	tw.tween_property(_card, "modulate:a", 1.0, 0.20).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.20).set_ease(Tween.EASE_OUT)

func _fix_pivot() -> void:
	if _card:
		_card.pivot_offset = _card.size * 0.5

func close() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_scrim, "modulate:a", 0.0, 0.15)
	tw.tween_property(_card, "modulate:a", 0.0, 0.15)
	tw.tween_property(_card, "scale", Vector2(0.98, 0.98), 0.15)
	tw.chain().tween_callback(func() -> void:
		closed.emit()
		queue_free())

# ══════════════════════════════════════════════════════════════════════════════════
# Helpers de construção
# ══════════════════════════════════════════════════════════════════════════════════

func _column(p_width: float, p_l: int, p_t: int, p_r: int, p_b: int) -> MarginContainer:
	var mc := MarginContainer.new()
	if p_width > 0:
		mc.custom_minimum_size = Vector2(p_width, 0)
	mc.add_theme_constant_override("margin_left", p_l)
	mc.add_theme_constant_override("margin_top", p_t)
	mc.add_theme_constant_override("margin_right", p_r)
	mc.add_theme_constant_override("margin_bottom", p_b)
	var vb := VBoxContainer.new()
	mc.add_child(vb)
	return mc

func _stat_row(p_key: String, p_val: String) -> Array:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.add_child(_lbl(p_key, C_MUTED, 8))
	var v := _lbl(p_val, C_INK_DIM, 14)
	vb.add_child(v)
	return [vb, v]

func _swatch(p_color: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(22, 22)
	var sb := StyleBoxFlat.new()
	sb.bg_color = p_color
	sb.set_border_width_all(1)
	sb.border_color = C_LINE_BRIGHT
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(_on_ring_swatch.bind(p_color))
	return b

func _lbl(p_text: String, p_color: Color, p_size: int) -> Label:
	var l := Label.new()
	l.text = p_text
	l.add_theme_color_override("font_color", p_color)
	l.add_theme_font_size_override("font_size", p_size)
	return l

func _icon_button(p_text: String, p_color: Color) -> Button:
	var b := Button.new()
	b.text = p_text
	b.custom_minimum_size = Vector2(24, 24)
	b.add_theme_color_override("font_color", p_color)
	b.add_theme_font_size_override("font_size", 12)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(1)
	sb.border_color = C_LINE_BRIGHT
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b

func _text_button(p_text: String) -> Button:
	var b := Button.new()
	b.text = p_text
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_color_override("font_color", C_INK_DIM)
	return b

func _panel_style(p_bg: Color, p_border: Color, p_border_w: int, p_top_only: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = p_bg
	if p_top_only > 0:
		sb.border_width_top = p_top_only
	else:
		sb.set_border_width_all(p_border_w)
	sb.border_color = p_border
	return sb

func _hline(p_h: int, p_color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = p_color
	r.custom_minimum_size = Vector2(0, p_h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _vline(p_color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = p_color
	r.custom_minimum_size = Vector2(1, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
