# scenes/ui/boardv2/game_log/game_log.gd
# Registro da partida — painel no canto inferior esquerdo com o histórico de jogadas.
# Componente autocontido: a cena só REAGE. Escuta os sinais do GameBus que disparam
# no cliente (card_played / skill_activated / combat_resolved / phase_changed / game_over
# têm notify-RPC ou são call_local) e DERIVA revelação/derrota de herói do snapshot
# (state_synced), já que hero_revealed/hero_defeated só são emitidos no servidor.
extends Control

const MAX_ROWS := 300

# Cores (hex sem '#') por papel/tipo de evento — espelham o mockup aprovado.
const C_YOU   := "9fe1cb"   # você (verde-água)
const C_OPP   := "e0997b"   # oponente (coral)
const C_CARD  := "85b7eb"   # nome de carta clicável (azul)
const C_SKILL := "efbf6f"   # skill/passiva (âmbar)
const C_DMG   := "f09595"   # dano (vermelho claro)
const C_SYS   := "8a7a55"   # divisores/sistema (ouro apagado)
const C_TEXT  := "cfc6b0"   # texto padrão (pergaminho)

@onready var _toggle_btn : Button          = $ToggleButton
@onready var _panel      : PanelContainer  = $LogPanel
@onready var _close_btn  : Button          = $LogPanel/Margin/VBox/Header/CloseButton
@onready var _title_lbl  : Label           = $LogPanel/Margin/VBox/Header/Title
@onready var _scroll     : ScrollContainer = $LogPanel/Margin/VBox/Scroll
@onready var _messages   : VBoxContainer   = $LogPanel/Margin/VBox/Scroll/Messages

var _cards: Dictionary           = {}   # id:int → Card (para o hover→preview)
var _card_seq: int               = 0
var _last_phase: String          = ""
var _revealed_once: Dictionary   = {}   # "idx:hero" → true (1ª revelação no match)
var _defeated_logged: Dictionary = {}   # "idx:hero" → true

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_panel.visible = false
	_apply_style()
	_toggle_btn.pressed.connect(_toggle)
	_close_btn.pressed.connect(_close)

	GameBus.card_played.connect(_on_card_played)
	GameBus.skill_activated.connect(_on_skill_activated)
	GameBus.combat_resolved.connect(_on_combat_resolved)
	GameBus.phase_changed.connect(_on_phase_changed)
	GameBus.game_over.connect(_on_game_over)
	GameBus.state_synced.connect(_on_state_synced)

# ── Abrir / fechar ────────────────────────────────────────────────────────────

func _toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_autoscroll()

func _close() -> void:
	_panel.visible = false

# ── Eventos do GameBus ────────────────────────────────────────────────────────

func _on_card_played(player_index: int, card: Card) -> void:
	var verb := "reagiu com" if card.timing == Card.TimingType.REACTION else "jogou"
	_append_card("%s %s " % [_who(player_index), verb], card)

func _on_skill_activated(hero: Hero, skill_name: String) -> void:
	if hero == null:
		return
	_append("[color=#%s]⚡ %s — %s[/color]" % [C_SKILL, hero.hero_name, skill_name])

func _on_combat_resolved(dmg_p0: int, dmg_p1: int) -> void:
	var local := NetworkState.local_player_index
	var to_me  := dmg_p0 if local == 0 else dmg_p1
	var to_opp := dmg_p1 if local == 0 else dmg_p0
	var parts: Array[String] = []
	if to_opp > 0:
		parts.append("%s sofreu [color=#%s]%d[/color]" % [_who(1 - local), C_DMG, to_opp])
	if to_me > 0:
		parts.append("%s sofreu [color=#%s]%d[/color]" % [_who(local), C_DMG, to_me])
	var body := " · ".join(parts) if not parts.is_empty() else "sem dano"
	_append("[color=#%s]Combate — %s[/color]" % [C_TEXT, body])

func _on_phase_changed(phase: String) -> void:
	# state_synced reenvia a fase a cada sync — só registra quando ela MUDA de fato.
	if phase == _last_phase:
		return
	_last_phase = phase
	_append_divider(_phase_label(phase))

func _on_game_over(winner_index: int) -> void:
	var local := NetworkState.local_player_index
	var won := winner_index == local
	_append("[color=#%s]● Fim de jogo — %s[/color]" % [
		C_YOU if won else C_OPP,
		"Você venceu!" if won else "Oponente venceu.",
	])

func _on_state_synced() -> void:
	if GameState.players.size() < 2:
		return
	for idx in 2:
		var pl: Player = GameState.players[idx]
		# Revelação de herói — só a 1ª vez de cada herói no match (evita ruído por turno).
		if GameState.get_hero_revealed(idx) and pl.active_hero != null:
			var rk := "%d:%s" % [idx, pl.active_hero.hero_name]
			if not _revealed_once.has(rk):
				_revealed_once[rk] = true
				_append("%s revelou [color=#%s]%s[/color]" % [_who(idx), C_TEXT, pl.active_hero.hero_name])
		# Derrota de herói — uma vez por herói.
		for h: Hero in pl.heroes:
			if h.state == Hero.State.DEFEATED:
				var dk := "%d:%s" % [idx, h.hero_name]
				if not _defeated_logged.has(dk):
					_defeated_logged[dk] = true
					_append("%s — [color=#%s]%s foi derrotado[/color]" % [_who(idx), C_DMG, h.hero_name])

# ── Hover → card preview (reusa o overlay existente via GameBus) ───────────────

func _on_meta_hover_started(meta: Variant) -> void:
	var id := int(str(meta))
	if _cards.has(id):
		GameBus.card_hovered.emit({"type": "card", "card": _cards[id]})

func _on_meta_hover_ended(_meta: Variant) -> void:
	GameBus.card_hover_ended.emit()

# ── Construção de linhas ──────────────────────────────────────────────────────

func _append_card(prefix_bb: String, card: Card) -> void:
	var id := _card_seq
	_card_seq += 1
	_cards[id] = card
	_append("%s[url=%d][color=#%s]%s[/color][/url]" % [prefix_bb, id, C_CARD, card.card_name])

func _append(bb: String) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled        = true
	lbl.fit_content           = true
	lbl.scroll_active         = false
	lbl.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter          = Control.MOUSE_FILTER_PASS
	lbl.add_theme_font_size_override("normal_font_size", 13)
	lbl.add_theme_color_override("default_color", Color.html(C_TEXT))
	lbl.meta_hover_started.connect(_on_meta_hover_started)
	lbl.meta_hover_ended.connect(_on_meta_hover_ended)
	lbl.parse_bbcode(bb)
	_messages.add_child(lbl)
	_trim()
	_autoscroll()

func _append_divider(text: String) -> void:
	var lbl := Label.new()
	lbl.text = "— %s —" % text
	lbl.horizontal_alignment      = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal     = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color.html(C_SYS))
	_messages.add_child(lbl)
	_trim()
	_autoscroll()

func _trim() -> void:
	while _messages.get_child_count() > MAX_ROWS:
		var c := _messages.get_child(0)
		_messages.remove_child(c)
		c.queue_free()

func _autoscroll() -> void:
	if not _panel.visible:
		return
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _who(idx: int) -> String:
	if idx == NetworkState.local_player_index:
		return "[color=#%s]Você[/color]" % C_YOU
	return "[color=#%s]Oponente[/color]" % C_OPP

func _phase_label(phase: String) -> String:
	match phase:
		"OPENING_ROLL":     return "Rolagem de dados"
		"OPENING_MULLIGAN": return "Preparação"
		"DRAW":             return "Compra"
		"HERO_SELECTION":   return "Escolha de herói"
		"BACKLINE_ABILITY": return "Retaguarda"
		"ACTION":           return "Ação"
		"COMBAT":           return "Combate"
		"END":              return "Fim de turno"
		_:                  return phase

# ── Estilo (cores/stylebox; o layout/árvore vive no .tscn) ─────────────────────

func _apply_style() -> void:
	var border := Color(0.902, 0.722, 0.392, 0.45)
	var bg     := Color(0.082, 0.067, 0.043, 0.95)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color     = bg
	panel_style.border_color = border
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", panel_style)

	_title_lbl.add_theme_color_override("font_color", Color.html("e6b864"))
	_title_lbl.add_theme_font_size_override("font_size", 14)
	_close_btn.add_theme_color_override("font_color", Color.html("b5a98a"))

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color     = Color(bg.r, bg.g, bg.b, 0.92)
	btn_style.border_color = border
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(6)
	btn_style.content_margin_left = 12; btn_style.content_margin_right  = 12
	btn_style.content_margin_top  = 6;  btn_style.content_margin_bottom = 6
	for s in ["normal", "hover", "pressed"]:
		_toggle_btn.add_theme_stylebox_override(s, btn_style)
	_toggle_btn.add_theme_color_override("font_color", Color.html("e6b864"))
