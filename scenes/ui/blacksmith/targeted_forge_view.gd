# Modo "Ritual Dirigido": escolhe a carta-ALVO no altar, oferece 10 cartas no círculo
# e canaliza para materializar exatamente o alvo (não é sorteio). Economia idêntica ao
# modo aleatório (host.commit_forge), mas a carta criada é a escolhida.
class_name TargetedForgeView
extends Control

signal back_requested

const CARD_VIEW := preload("res://scenes/ui/card_view/card_view.tscn")
const CARD_SIZE := Vector2(160, 240)
const SLOT_SCALE := 0.5
const OFFERINGS := 10
# Raridade-sentinela que nenhuma carta tem (bloqueia oferendas enquanto não há alvo).
const RESTRICT_NONE := "__none__"

@export var ritual_radius: float = 215.0

var host: Control
var _target: Dictionary = {}
var _offerings: Array = []            # tamanho OFFERINGS; null = vazio
var _phase: String = "idle"

var _circle: Control
var _dynamic: Control                 # altar + slots + linhas (recriado a cada refresh)
var _inv: ForgeInvPanel
var _caption_lbl: Label
var _target_box: VBoxContainer
var _canalize_btn: Button


func _ready() -> void:
	_offerings.resize(OFFERINGS)
	_build()


func enter() -> void:
	_target = {}
	for i in _offerings.size():
		_offerings[i] = null
	_refresh_inventory()
	_apply_offering_rule()
	_refresh_circle()
	_refresh_target_box()


# Regra do ritual: escolher o alvo primeiro; oferendas devem ser da MESMA raridade
# do alvo. Sem alvo → nada pode ser oferecido. Reflete isso no inventário (filtro +
# restrição de adição) — não dá pra trocar 10 comuns por 1 lendária.
func _apply_offering_rule() -> void:
	if _inv == null:
		return
	if _target.is_empty():
		_inv.set_restriction(ForgeInvPanel.RESTRICT_NONE, "Escolha o alvo primeiro")
	else:
		var r := str(_target.get("rarity", "COMMON"))
		_inv.set_restriction(r, "Ofereça cartas %s" % ForgeTheme.rarity_label(r))
	# set_restriction reconstrói a grade — repovoa os badges de disponibilidade.
	_update_available()


func on_gold_changed() -> void:
	_refresh_target_box()


# ── Construção ────────────────────────────────────────────────────────────────
func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 24)
	margin.add_child(split)

	# Palco do círculo (esquerda).
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(left)

	var stage_wrap := CenterContainer.new()
	stage_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(stage_wrap)

	var d := ritual_radius * 2.0 + 170.0
	_circle = Control.new()
	_circle.custom_minimum_size = Vector2(d, d)
	stage_wrap.add_child(_circle)
	_build_static_rings()
	_dynamic = Control.new()
	_dynamic.set_anchors_preset(Control.PRESET_FULL_RECT)
	_circle.add_child(_dynamic)

	var caption_row := HBoxContainer.new()
	caption_row.add_theme_constant_override("separation", 10)
	caption_row.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(caption_row)
	_caption_lbl = ForgeTheme.make_label("", ForgeTheme.font_body(), 12, ForgeTheme.PARCHMENT_D)
	caption_row.add_child(_caption_lbl)
	var clear_link := Button.new()
	clear_link.text = "limpar círculo"
	ForgeTheme.style_ghost_button(clear_link, 11)
	clear_link.pressed.connect(_on_clear)
	caption_row.add_child(clear_link)

	# Painel lateral (direita).
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 16)
	side.custom_minimum_size = Vector2(400, 0)
	split.add_child(side)

	var box_panel := PanelContainer.new()
	box_panel.add_theme_stylebox_override("panel", ForgeTheme.panel_style(
		Color(ForgeTheme.BG_MID.r, ForgeTheme.BG_MID.g, ForgeTheme.BG_MID.b, 0.7),
		ForgeTheme.GOLD_SOFT_A, 1, 0))
	side.add_child(box_panel)
	_target_box = VBoxContainer.new()
	_target_box.add_theme_constant_override("separation", 8)
	box_panel.add_child(_target_box)

	_inv = ForgeInvPanel.new()
	_inv.overlay_host = host
	_inv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inv.card_added.connect(_on_inv_card_added)
	side.add_child(_inv)


func _build_static_rings() -> void:
	var center := _circle.custom_minimum_size * 0.5
	_add_ring(center, ritual_radius * 2.0 + 30.0, 3, Color(ForgeTheme.GOLD.r, ForgeTheme.GOLD.g, ForgeTheme.GOLD.b, 0.7))
	_add_ring(center, ritual_radius * 2.0 - 60.0, 1, Color(ForgeTheme.GOLD.r, ForgeTheme.GOLD.g, ForgeTheme.GOLD.b, 0.3))
	# 12 glifos na borda.
	for i in 12:
		var a := TAU * float(i) / 12.0 - PI / 2.0
		var gp := center + Vector2(cos(a), sin(a)) * (ritual_radius + 50.0)
		var glyph := ForgeTheme.make_label("✦", ForgeTheme.font_body(), 14,
			Color(ForgeTheme.GOLD.r, ForgeTheme.GOLD.g, ForgeTheme.GOLD.b, 0.5))
		glyph.position = gp - Vector2(7, 10)
		_circle.add_child(glyph)


func _add_ring(center: Vector2, d: float, w: int, col: Color) -> void:
	var ring := PanelContainer.new()
	ring.size = Vector2(d, d)
	ring.position = center - Vector2(d, d) * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_border_width_all(w)
	style.border_color = col
	style.set_corner_radius_all(int(d * 0.5))
	ring.add_theme_stylebox_override("panel", style)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_circle.add_child(ring)


# ── Círculo dinâmico (altar + slots + linhas) ──────────────────────────────────
func _refresh_circle() -> void:
	for c in _dynamic.get_children():
		c.queue_free()
	var center := _circle.custom_minimum_size * 0.5

	# Linhas de energia (atrás dos slots).
	for i in OFFERINGS:
		var slot_pos := _ring_pos(i, center)
		var line := Line2D.new()
		line.width = 2.0
		var lit := _offerings[i] != null
		line.default_color = (Color(ForgeTheme.GOLD_GLOW.r, ForgeTheme.GOLD_GLOW.g, ForgeTheme.GOLD_GLOW.b, 0.8)
			if lit else Color(ForgeTheme.GOLD.r, ForgeTheme.GOLD.g, ForgeTheme.GOLD.b, 0.12))
		line.add_point(center)
		line.add_point(slot_pos)
		_dynamic.add_child(line)

	# Altar central.
	_dynamic.add_child(_make_altar(center))

	# 10 slots.
	for i in OFFERINGS:
		_dynamic.add_child(_make_slot(i, _ring_pos(i, center)))


func _ring_pos(i: int, center: Vector2) -> Vector2:
	var a := TAU * float(i) / float(OFFERINGS) - PI / 2.0
	return center + Vector2(cos(a) * ritual_radius, sin(a) * ritual_radius)


func _make_altar(center: Vector2) -> Control:
	var size := Vector2(150, 150)
	var btn := Button.new()
	btn.size = size
	btn.position = center - size * 0.5
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var style := ForgeTheme.panel_style(Color(0.06, 0.05, 0.1, 0.95), ForgeTheme.GOLD, 2, 6)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)
	btn.pressed.connect(_open_picker)

	if _target.is_empty():
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vb)
		vb.add_child(ForgeTheme.make_label("◆", ForgeTheme.font_display(), 30,
			Color(ForgeTheme.GOLD.r, ForgeTheme.GOLD.g, ForgeTheme.GOLD.b, 0.5), HORIZONTAL_ALIGNMENT_CENTER))
		var hint := ForgeTheme.make_label("Escolher carta\nalmejada", ForgeTheme.font_body(), 10,
			ForgeTheme.PARCHMENT_D, HORIZONTAL_ALIGNMENT_CENTER)
		vb.add_child(hint)
		# Altar vazio "respira" em dourado — sinaliza que é o primeiro passo.
		var pulse := create_tween().set_loops()
		pulse.tween_property(btn, "modulate", Color(1.7, 1.45, 0.85, 1.0), 0.75).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.75).set_trans(Tween.TRANS_SINE)
	else:
		var holder := Control.new()
		holder.set_anchors_preset(Control.PRESET_CENTER)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(holder)
		var cv := CARD_VIEW.instantiate() as CardView
		holder.add_child(cv)
		cv.position = Vector2(-CARD_SIZE.x * 0.3, -CARD_SIZE.y * 0.3)
		ForgeTheme.bind_card_tile(cv, _target, 0.6, 0.6)
		ForgeTheme.make_passive(cv)
	return btn


func _make_slot(i: int, pos: Vector2) -> Control:
	var size := CARD_SIZE * SLOT_SCALE
	var card: Variant = _offerings[i]
	var wrap := Control.new()
	wrap.size = size
	wrap.position = pos - size * 0.5
	wrap.clip_contents = true

	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border := ForgeTheme.GOLD if card != null else Color(ForgeTheme.GOLD.r, ForgeTheme.GOLD.g, ForgeTheme.GOLD.b, 0.25)
	var fstyle := StyleBoxFlat.new()
	fstyle.bg_color = Color(0.04, 0.04, 0.07, 0.92)
	fstyle.set_border_width_all(1)
	fstyle.border_color = border
	fstyle.set_corner_radius_all(4)
	frame.add_theme_stylebox_override("panel", fstyle)
	wrap.add_child(frame)

	if card == null:
		var num := ForgeTheme.make_label(str(i + 1), ForgeTheme.font_display(), 22,
			Color(ForgeTheme.GOLD.r, ForgeTheme.GOLD.g, ForgeTheme.GOLD.b, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
		num.set_anchors_preset(Control.PRESET_FULL_RECT)
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(num)
		return wrap

	var cv := CARD_VIEW.instantiate() as CardView
	wrap.add_child(cv)
	ForgeTheme.bind_card_tile(cv, card, SLOT_SCALE, SLOT_SCALE, bool(card.get("is_foil", false)))
	ForgeTheme.make_passive(cv)

	var remove := Button.new()
	remove.text = "✕"
	remove.add_theme_font_size_override("font_size", 11)
	remove.add_theme_color_override("font_color", ForgeTheme.PARCHMENT)
	remove.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	remove.offset_left = -20.0
	remove.offset_top = 2.0
	remove.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var rstyle := StyleBoxFlat.new()
	rstyle.bg_color = Color(0.5, 0.12, 0.1, 0.85)
	rstyle.set_corner_radius_all(3)
	remove.add_theme_stylebox_override("normal", rstyle)
	remove.add_theme_stylebox_override("hover", rstyle)
	remove.add_theme_stylebox_override("pressed", rstyle)
	remove.pressed.connect(_on_slot_removed.bind(i))
	wrap.add_child(remove)
	return wrap


# ── Caixa do alvo (lado direito) ───────────────────────────────────────────────
func _refresh_target_box() -> void:
	for c in _target_box.get_children():
		c.queue_free()
	_target_box.add_child(ForgeTheme.make_eyebrow("Alvo da Forja", ForgeTheme.GOLD_DIM, 10))

	if _target.is_empty():
		_target_box.add_child(ForgeTheme.make_label("Nenhum alvo escolhido", ForgeTheme.font_display(), 16, ForgeTheme.PARCHMENT_D))
	else:
		_target_box.add_child(ForgeTheme.make_label(str(_target.get("name", "?")), ForgeTheme.font_display(), 18, ForgeTheme.GOLD_GLOW))
		var meta := HBoxContainer.new()
		meta.add_theme_constant_override("separation", 8)
		var rarity := str(_target.get("rarity", "COMMON"))
		meta.add_child(ForgeTheme.make_label("◆ " + ForgeTheme.rarity_label(rarity), ForgeTheme.font_body(), 11, ForgeTheme.rarity_color(rarity)))
		meta.add_child(ForgeTheme.make_label(str(_target.get("timing", "ACTION")).capitalize(), ForgeTheme.font_body(), 11, ForgeTheme.PARCHMENT_D))
		_target_box.add_child(meta)

	var n_filled := _filled_count()
	var cost := ForgeService.targeted_cost(_target)
	var cost_row := HBoxContainer.new()
	cost_row.add_theme_constant_override("separation", 6)
	cost_row.add_child(ForgeTheme.make_eyebrow("Custo", ForgeTheme.GOLD_DIM, 9))
	var afford: bool = host == null or host.can_afford(cost)
	cost_row.add_child(ForgeTheme.make_label("◉ " + ForgeTheme.fmt_gold(cost), ForgeTheme.font_display(), 16,
		ForgeTheme.GOLD_GLOW if afford else ForgeTheme.RED_INSUFF))
	_target_box.add_child(cost_row)
	_target_box.add_child(ForgeTheme.make_label("+ 10 cartas em oferenda", ForgeTheme.font_body(), 10, ForgeTheme.PARCHMENT_D))

	_canalize_btn = Button.new()
	_canalize_btn.custom_minimum_size = Vector2(0, 56)
	_canalize_btn.add_theme_font_override("font", ForgeTheme.font_heading())
	_canalize_btn.add_theme_font_size_override("font_size", 16)
	_canalize_btn.add_theme_color_override("font_color", ForgeTheme.PARCHMENT)
	_canalize_btn.add_theme_color_override("font_disabled_color", ForgeTheme.PARCHMENT_D)
	_canalize_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_canalize_btn.add_theme_stylebox_override("normal", ForgeTheme.crimson_button_style())
	_canalize_btn.add_theme_stylebox_override("hover", ForgeTheme.crimson_button_style(true))
	_canalize_btn.add_theme_stylebox_override("pressed", ForgeTheme.crimson_button_style(true))
	_canalize_btn.add_theme_stylebox_override("focus", ForgeTheme.crimson_button_style())
	_canalize_btn.add_theme_stylebox_override("disabled", ForgeTheme.disabled_button_style())
	_canalize_btn.pressed.connect(_on_canalize)
	_target_box.add_child(_canalize_btn)

	var can := not _target.is_empty() and n_filled == OFFERINGS and afford and _phase == "idle"
	_canalize_btn.disabled = not can
	if _target.is_empty():
		_canalize_btn.text = "Escolha um alvo"
	elif n_filled < OFFERINGS:
		_canalize_btn.text = "Faltam %d oferendas" % (OFFERINGS - n_filled)
	elif not afford:
		_canalize_btn.text = "Ouro insuficiente"
	else:
		_canalize_btn.text = "CANALIZAR"

	_caption_lbl.text = ("Toque o altar central e escolha a carta que deseja forjar" if n_filled == 0
		else "%d / %d oferendas no círculo" % [n_filled, OFFERINGS])


# ── Inventário ────────────────────────────────────────────────────────────────
func _refresh_inventory() -> void:
	var typed_syms: Array[String] = []
	var typed_deck: Array[String] = []
	_inv.set_inventory(Collection.query_cards("", typed_syms, "", typed_deck))
	_update_available()


func _update_available() -> void:
	var placed_normal := {}
	var placed_foil := {}
	for c in _offerings:
		if c != null:
			var cid := int(c.get("id", -1))
			if bool(c.get("is_foil", false)):
				placed_foil[cid] = int(placed_foil.get(cid, 0)) + 1
			else:
				placed_normal[cid] = int(placed_normal.get(cid, 0)) + 1
	var avail := {}
	for c in _inv.inventory:
		var cid := int(c.get("id", -1))
		var owned_foil := Collection.get_foil_quantity(cid)
		var owned_normal := Collection.get_owned_quantity(cid) - owned_foil
		avail[cid] = {
			"normal": owned_normal - int(placed_normal.get(cid, 0)),
			"foil": owned_foil - int(placed_foil.get(cid, 0)),
		}
	_inv.set_available_counts(avail)


func _on_inv_card_added(card: Dictionary) -> void:
	if _phase != "idle":
		return
	# Regra: alvo escolhido primeiro e oferendas da MESMA raridade do alvo.
	if _target.is_empty():
		return
	if str(card.get("rarity", "COMMON")) != str(_target.get("rarity", "COMMON")):
		return
	var slot := _offerings.find(null)
	if slot == -1:
		return
	_offerings[slot] = card
	_refresh_circle()
	_update_available()
	_refresh_target_box()


func _on_slot_removed(i: int) -> void:
	if _phase != "idle" or _offerings[i] == null:
		return
	_offerings[i] = null
	_refresh_circle()
	_update_available()
	_refresh_target_box()


func _on_clear() -> void:
	if _phase != "idle":
		return
	for i in _offerings.size():
		_offerings[i] = null
	_refresh_circle()
	_update_available()
	_refresh_target_box()


func _filled_count() -> int:
	var n := 0
	for c in _offerings:
		if c != null:
			n += 1
	return n


# ── Picker / Canalizar ────────────────────────────────────────────────────────
func _open_picker() -> void:
	if _phase != "idle":
		return
	var picker := CardPicker.new()
	picker.picked.connect(func(card: Dictionary) -> void:
		_target = card
		# Nova raridade-alvo → recomeça as oferendas (não misturar raridades).
		for i in _offerings.size():
			_offerings[i] = null
		_apply_offering_rule()
		_refresh_circle()
		_update_available()
		_refresh_target_box())
	(host if host != null else self).add_child(picker)


func _on_canalize() -> void:
	if _phase != "idle" or host == null or _target.is_empty() or _filled_count() != OFFERINGS:
		return
	var cost := ForgeService.targeted_cost(_target)
	if not host.can_afford(cost):
		return
	var offerings_dicts := _offerings.duplicate()   # com nulos — usado só na animação
	_phase = "channeling"
	_refresh_target_box()

	# Servidor é autoridade: valida 10 oferendas da mesma raridade do alvo, forja e persiste.
	var res: Dictionary = await host.forge_targeted(str(_target.get("card_id", "")), _build_offerings(offerings_dicts))
	if not res.ok:
		_phase = "idle"
		_refresh_target_box()
		return

	var stage := RitualStage.new()
	host.add_child(stage)
	stage.play(_target, offerings_dicts, ritual_radius)
	await stage.kept

	# Inventário e ouro já foram aplicados por host.forge_targeted.
	_target = {}
	for i in _offerings.size():
		_offerings[i] = null
	_phase = "idle"
	_refresh_inventory()
	_apply_offering_rule()
	_refresh_circle()
	_refresh_target_box()


# Agrupa as oferendas por UUID do backend (card_id), contando foil. Ignora slots vazios.
func _build_offerings(placed: Array) -> Array:
	var by_uuid := {}
	for c in placed:
		if c == null:
			continue
		var uuid := str(c.get("card_id", ""))
		if uuid == "":
			continue
		var e: Dictionary = by_uuid.get(uuid, { "cardId": uuid, "quantity": 0, "foilQuantity": 0 })
		e.quantity += 1
		if bool(c.get("is_foil", false)):
			e.foilQuantity += 1
		by_uuid[uuid] = e
	return by_uuid.values()
