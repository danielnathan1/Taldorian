# A Oficina do Ferreiro — shell que hospeda os modos (hub / aleatória / dirigida).
# Concentra o header, a atmosfera da fornalha, a navegação entre views e a economia
# (ouro do backend + consumo/criação de cartas via Collection).
#
# ⚠️ Economia: NÃO há endpoint de forja no backend ainda. O ouro é lido de
# /players/me (autoridade), mas o gasto e o consumo de cartas só acontecem no CACHE
# LOCAL (Collection.* → user://player_cards.json), igual ao stub de trocas. Quando o
# serviço ganhar /forge, trocar `_commit_*` por uma chamada autoritativa. Ver TODO.
extends Control

const WORLD_SCENE := "res://scenes/world/world_root.tscn"

# ── Estado ──────────────────────────────────────────────────────────────────────
var _gold: int = 0
var _mode: String = "hub"

# ── Nós construídos em código ────────────────────────────────────────────────────
var _eyebrow_lbl: Label
var _title_lbl: Label
var _gold_lbl: Label
var _back_btn: Button
var _view_stack: Control
var _hub: HubView
var _random: RandomForgeView
var _targeted: TargetedForgeView
var _glow_rect: TextureRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_header()
	_build_view_stack()
	_show_view("hub")
	await _refresh_gold()


# ── Economia ──────────────────────────────────────────────────────────────────
func _refresh_gold() -> void:
	var res := await ApiClient.get_me()
	if res.ok and res.data is Dictionary:
		_gold = int(res.data.get("gold", _gold))
	else:
		push_warning("[Ferreiro] Falha ao carregar ouro: %s" % res.error)
	_update_gold_label()


func get_gold() -> int:
	return _gold


func can_afford(cost: int) -> bool:
	return _gold >= cost


# Forja aleatória — o BACKEND é autoridade: valida posse/ouro, consome as oferendas,
# sorteia a carta e persiste. Recarrega inventário + ouro e devolve
# { ok, result|error }, com result = { tier_key, tier, card (dict local) }.
# offerings: Array de { cardId (UUID), quantity, foilQuantity }.
func forge_random(offerings: Array) -> Dictionary:
	var resp := await ApiClient.forge_random(offerings)
	if not resp.ok or not (resp.data is Dictionary):
		return { "ok": false, "error": _forge_error(resp) }
	var data: Dictionary = resp.data
	await _apply_forge_result(data)
	var tier_key := str(data.get("tierKey", "comum"))
	var card := Collection.resolve_card(data)
	_toast("Forjado: %s" % str(card.get("name", "?")))
	return { "ok": true, "result": {
		"tier_key": tier_key,
		"tier": ForgeService.TIERS.get(tier_key, ForgeService.TIERS["comum"]),
		"card": card,
	} }


# Ritual dirigido — idem; o resultado é o próprio alvo escolhido.
func forge_targeted(target_card_id: String, offerings: Array) -> Dictionary:
	var resp := await ApiClient.forge_targeted(target_card_id, offerings)
	if not resp.ok or not (resp.data is Dictionary):
		return { "ok": false, "error": _forge_error(resp) }
	var data: Dictionary = resp.data
	await _apply_forge_result(data)
	var card := Collection.resolve_card(data)
	_toast("Forjado: %s" % str(card.get("name", "?")))
	return { "ok": true, "result": { "card": card } }


# Aplica o estado pós-forja: ouro autoritativo (remainingGold) + recarrega o inventário
# do backend para refletir consumo/criação. Atualiza a bolsa de ouro com flash.
func _apply_forge_result(data: Dictionary) -> void:
	_gold = int(data.get("remainingGold", _gold))
	var inv := await ApiClient.get_inventory()
	if inv.ok and inv.data is Dictionary:
		Collection.load_inventory(inv.data)
	_update_gold_label()
	_flash_gold()


func _forge_error(resp: Dictionary) -> String:
	if resp.data is Dictionary and (resp.data as Dictionary).has("message"):
		return str((resp.data as Dictionary).get("message"))
	var e := str(resp.get("error", ""))
	return e if e != "" else "Falha na forja"


# ── Navegação ─────────────────────────────────────────────────────────────────
func _show_view(mode: String) -> void:
	_mode = mode
	_hub.visible = mode == "hub"
	_random.visible = mode == "random"
	_targeted.visible = mode == "targeted"

	match mode:
		"random":
			_set_header("01 · Sorte do Metal", "Forjar Carta Aleatória")
			_random.enter()
		"targeted":
			_set_header("02 · Ritual Dirigido", "Forjar Carta")
			_targeted.enter()
		_:
			_set_header("Oficina", "O Ferreiro")

	# Fade-in leve da view ativa.
	var active := _active_view()
	if active != null:
		active.modulate = Color(1, 1, 1, 0)
		active.position.y = 12.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(active, "modulate:a", 1.0, 0.25)
		tw.tween_property(active, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _active_view() -> Control:
	match _mode:
		"random": return _random
		"targeted": return _targeted
		_: return _hub


func _on_back_pressed() -> void:
	if _mode == "hub":
		_toast("Retornando ao saguão...")
		get_tree().change_scene_to_file(WORLD_SCENE)
	else:
		_show_view("hub")


# ── Construção: fundo / atmosfera da fornalha ────────────────────────────────────
func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = ForgeTheme.BG_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Glow quente que "respira" no rodapé (escala vertical em loop).
	_glow_rect = TextureRect.new()
	_glow_rect.texture = _make_radial_texture(Color(ForgeTheme.EMBER.r, ForgeTheme.EMBER.g, ForgeTheme.EMBER.b, 0.5))
	_glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_glow_rect.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_glow_rect.offset_top = -360.0
	_glow_rect.offset_bottom = 120.0
	_glow_rect.modulate = Color(1, 1, 1, 0.35)
	add_child(_glow_rect)
	var breathe := create_tween().set_loops()
	breathe.tween_property(_glow_rect, "modulate:a", 0.18, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breathe.tween_property(_glow_rect, "modulate:a", 0.40, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Brasas subindo continuamente do rodapé.
	var embers := CPUParticles2D.new()
	embers.texture = _make_radial_texture(ForgeTheme.EMBER)
	embers.amount = 60
	embers.lifetime = 5.0
	embers.preprocess = 3.0
	embers.position = Vector2(0, 0)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(960, 4)
	embers.direction = Vector2(0, -1)
	embers.spread = 18.0
	embers.gravity = Vector2(0, -28)
	embers.initial_velocity_min = 24.0
	embers.initial_velocity_max = 70.0
	embers.scale_amount_min = 0.12
	embers.scale_amount_max = 0.4
	embers.color = Color(ForgeTheme.EMBER.r, ForgeTheme.EMBER.g, ForgeTheme.EMBER.b, 0.7)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 0.7, 0.3, 0.0))
	ramp.add_point(0.2, Color(1, 0.65, 0.25, 0.8))
	ramp.set_color(1, Color(0.9, 0.4, 0.15, 0.0))
	embers.color_ramp = ramp
	add_child(embers)
	# Reposiciona as brasas na base da viewport.
	var vp := get_viewport_rect().size
	embers.position = Vector2(vp.x * 0.5, vp.y + 8.0)
	_glow_rect.offset_left = 0.0
	_glow_rect.offset_right = 0.0
	get_viewport().size_changed.connect(func() -> void:
		var s := get_viewport_rect().size
		embers.position = Vector2(s.x * 0.5, s.y + 8.0)
		embers.emission_rect_extents = Vector2(s.x * 0.5, 4))


# ── Construção: header ───────────────────────────────────────────────────────────
func _build_header() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size = Vector2(0, 64)
	bar.add_theme_stylebox_override("panel", ForgeTheme.panel_style(
		Color(ForgeTheme.BG_MID.r, ForgeTheme.BG_MID.g, ForgeTheme.BG_MID.b, 0.85),
		ForgeTheme.GOLD_SOFT_A, 0))
	add_child(bar)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	bar.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(row)

	_back_btn = Button.new()
	_back_btn.text = "←  Voltar"
	_back_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ForgeTheme.style_ghost_button(_back_btn)
	_back_btn.pressed.connect(_on_back_pressed)
	row.add_child(_back_btn)

	var sep := ColorRect.new()
	sep.color = ForgeTheme.GOLD_SOFT_A
	sep.custom_minimum_size = Vector2(1, 30)
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sep)

	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(titles)
	_eyebrow_lbl = ForgeTheme.make_eyebrow("Oficina", ForgeTheme.GOLD_DIM, 10)
	titles.add_child(_eyebrow_lbl)
	_title_lbl = ForgeTheme.make_label("O Ferreiro", ForgeTheme.font_display(), 18, ForgeTheme.GOLD_GLOW)
	titles.add_child(_title_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	# Bolsa de ouro.
	var purse := PanelContainer.new()
	purse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	purse.add_theme_stylebox_override("panel", ForgeTheme.panel_style(
		Color(ForgeTheme.BG_SURFACE.r, ForgeTheme.BG_SURFACE.g, ForgeTheme.BG_SURFACE.b, 0.8),
		ForgeTheme.GOLD_SOFT_A, 1, 0))
	row.add_child(purse)
	var purse_row := HBoxContainer.new()
	purse_row.add_theme_constant_override("separation", 8)
	purse.add_child(purse_row)
	var coin := ForgeTheme.make_label("◉", ForgeTheme.font_display(), 16, ForgeTheme.GOLD_GLOW)
	purse_row.add_child(coin)
	_gold_lbl = ForgeTheme.make_label("0", ForgeTheme.font_display(), 16, ForgeTheme.GOLD)
	purse_row.add_child(_gold_lbl)


func _update_gold_label() -> void:
	if _gold_lbl:
		_gold_lbl.text = ForgeTheme.fmt_gold(_gold)
	# Avisa as views que o ouro mudou (re-gate dos botões).
	if _random: _random.on_gold_changed()
	if _targeted: _targeted.on_gold_changed()


func _flash_gold() -> void:
	if _gold_lbl == null:
		return
	_gold_lbl.add_theme_color_override("font_color", ForgeTheme.RED_INSUFF)
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(func() -> void:
		_gold_lbl.add_theme_color_override("font_color", ForgeTheme.GOLD))


func _set_header(eyebrow: String, title: String) -> void:
	_eyebrow_lbl.text = eyebrow.to_upper()
	_title_lbl.text = title


# ── Construção: pilha de views ───────────────────────────────────────────────────
func _build_view_stack() -> void:
	_view_stack = Control.new()
	_view_stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view_stack.offset_top = 72.0
	_view_stack.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_view_stack)

	_hub = HubView.new()
	_hub.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hub.option_picked.connect(_show_view)
	_view_stack.add_child(_hub)

	_random = RandomForgeView.new()
	_random.set_anchors_preset(Control.PRESET_FULL_RECT)
	_random.host = self
	_random.back_requested.connect(func() -> void: _show_view("hub"))
	_view_stack.add_child(_random)

	_targeted = TargetedForgeView.new()
	_targeted.set_anchors_preset(Control.PRESET_FULL_RECT)
	_targeted.host = self
	_targeted.back_requested.connect(func() -> void: _show_view("hub"))
	_view_stack.add_child(_targeted)


# ── Utilitários ──────────────────────────────────────────────────────────────────
# Textura radial branca (recolorida via modulate/color). Usada em brasas/glows.
func _make_radial_texture(tint: Color, size := 64) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(tint.r, tint.g, tint.b, tint.a))
	g.set_color(1, Color(tint.r, tint.g, tint.b, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = size
	tex.height = size
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


# Toast minimalista (canto inferior). Some sozinho.
func _toast(text: String) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ForgeTheme.panel_style(
		Color(ForgeTheme.BG_SURFACE.r, ForgeTheme.BG_SURFACE.g, ForgeTheme.BG_SURFACE.b, 0.95),
		ForgeTheme.GOLD, 1, 0))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := ForgeTheme.make_label(text, ForgeTheme.font_body(), 13, ForgeTheme.PARCHMENT)
	panel.add_child(lbl)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -340.0
	panel.offset_top = -90.0
	panel.offset_right = -28.0
	panel.offset_bottom = -44.0
	panel.modulate = Color(1, 1, 1, 0)
	add_child(panel)
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.0)
	tw.tween_property(panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(panel.queue_free)
