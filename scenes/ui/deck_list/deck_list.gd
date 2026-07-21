# scenes/ui/deck_list/deck_list.gd
# Lógica da tela de listagem de decks. Estrutura em deck_list.tscn; placas são
# instâncias de deck_plate.tscn populadas a partir do DeckStore.
# Fluxo: World HUD "Decks" / Lobby → DeckList → DeckBuilder.
extends Control

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")
const DECK_PLATE := preload("res://scenes/ui/deck_list/deck_plate.tscn")
const FONT_DECO  := preload("res://assets/fonts/CinzelDecorative-Bold.ttf")
const FONT_BLACK := preload("res://assets/fonts/CinzelDecorative-Black.ttf")

const DECK_BUILDER_SCENE := "res://scenes/ui/deck_builder/deck_builder.tscn"
const LOGIN_SCENE        := "res://scenes/ui/login/login.tscn"
const WORLD_SCENE        := "res://scenes/world/world_root.tscn"
const AB_H := 74.0

var _selected_id: String = ""
var _modal_target: String = ""
var _plates: Array = []          # instâncias de deck_plate
var _ab_tween: Tween

@onready var _header: PanelContainer = %Header
@onready var _back_btn: Button = %BackBtn
@onready var _tally: Label = %Tally
@onready var _new_btn: Button = %NewDeckButton
@onready var _scroll: ScrollContainer = %Scroll
@onready var _grid: GridContainer = %DeckGrid
@onready var _new_tile: Control = %NewTile
@onready var _action_bar: PanelContainer = %ActionBar
@onready var _ab_sleeve: TextureRect = %AbSleeve
@onready var _ab_name: Label = %AbName
@onready var _ab_delete: Button = %AbDelete
@onready var _ab_edit: Button = %AbEdit
@onready var _modal: Control = %Modal
@onready var _modal_body: RichTextLabel = %Body
@onready var _modal_cancel: Button = %Cancel
@onready var _modal_confirm: Button = %Confirm
@onready var _toast_layer: Control = %ToastLayer


func _ready() -> void:
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_apply_styles()
	_wire()
	DeckStore.decks_changed.connect(_rebuild_grid)
	await _initial_load()


# Puxa os decks do jogador do backend (DeckStore.refresh) antes de montar o grid.
func _initial_load() -> void:
	var overlay := _make_loading_overlay("Carregando decks…")
	add_child(overlay)
	var res := await DeckStore.refresh()
	if is_instance_valid(overlay):
		overlay.queue_free()
	if not res.ok:
		_toast("Falha ao carregar decks: %s" % res.error)
	_rebuild_grid()


func _make_loading_overlay(p_msg: String) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 30
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(S.C_BG_DEEP, 0.85)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var label := Label.new()
	label.text = p_msg
	label.add_theme_font_override("font", S.FONT_REG)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", S.C_GOLD_GLOW)
	center.add_child(label)
	return layer


func _wire() -> void:
	_back_btn.pressed.connect(_go_back)
	_new_btn.pressed.connect(_new_deck)
	_scroll.resized.connect(_recompute_columns)
	%Veil.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_close_modal())
	_modal_cancel.pressed.connect(_close_modal)
	_modal_confirm.pressed.connect(_do_delete)
	_ab_delete.pressed.connect(func() -> void:
		if _selected_id != "":
			_confirm_delete(_selected_id))
	_ab_edit.pressed.connect(func() -> void:
		if _selected_id != "":
			_open_builder(_selected_id))
	_new_tile.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_new_deck())


# ── Grid ────────────────────────────────────────────────────────────────────────

func _rebuild_grid() -> void:
	for p in _plates:
		if is_instance_valid(p):
			p.queue_free()
	_plates.clear()

	for deck in DeckStore.decks:
		var plate := DECK_PLATE.instantiate()
		_grid.add_child(plate)
		plate.bind(deck, _sleeve_info(deck.sleeve), _playmat_info(deck.playmat))
		plate.selected.connect(_set_selected)
		plate.edit_requested.connect(_open_builder)
		plate.delete_requested.connect(_confirm_delete)
		_plates.append(plate)

	# Mantém o tile "Novo deck" sempre por último.
	_grid.move_child(_new_tile, _grid.get_child_count() - 1)

	if _selected_id != "" and DeckStore.get_deck(_selected_id) == null:
		_selected_id = ""
	_refresh_selection()
	_update_action_bar(false)

	var n := DeckStore.decks.size()
	_tally.text = "%d %s" % [n, "DECK" if n == 1 else "DECKS"]
	_recompute_columns()


func _recompute_columns() -> void:
	var avail := _scroll.size.x - 72.0
	if avail <= 0:
		return
	_grid.columns = maxi(1, int(floor((avail + 22.0) / 352.0)))


# ── Seleção ───────────────────────────────────────────────────────────────────

func _set_selected(deck_id: String) -> void:
	_selected_id = deck_id
	_refresh_selection()
	_update_action_bar(true)


func _refresh_selection() -> void:
	for p in _plates:
		if is_instance_valid(p):
			p.set_selected(p.deck_id == _selected_id)


func _update_action_bar(animate: bool) -> void:
	var deck: DeckData = DeckStore.get_deck(_selected_id) if _selected_id != "" else null
	var target_top: float = -AB_H if deck != null else 0.0
	var target_bottom: float = 0.0 if deck != null else AB_H
	if deck != null:
		_ab_name.text = deck.deck_name if deck.deck_name.strip_edges() != "" else "Deck sem nome"
		_ab_sleeve.texture = _sleeve_info(deck.sleeve).get("tex", null)

	if _ab_tween != null and _ab_tween.is_valid():
		_ab_tween.kill()
	if not animate:
		_action_bar.offset_top = target_top
		_action_bar.offset_bottom = target_bottom
		return
	_ab_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_ab_tween.tween_property(_action_bar, "offset_top", target_top, 0.28)
	_ab_tween.tween_property(_action_bar, "offset_bottom", target_bottom, 0.28)


# ── Modal / Toast ─────────────────────────────────────────────────────────────

func _confirm_delete(deck_id: String) -> void:
	var deck := DeckStore.get_deck(deck_id)
	if deck == null:
		return
	_modal_target = deck_id
	_modal_body.text = "Esta ação não pode ser desfeita. O deck [b]%s[/b] será removido permanentemente da sua coleção." % deck.deck_name
	_modal.visible = true


func _close_modal() -> void:
	_modal.visible = false
	_modal_target = ""


func _do_delete() -> void:
	if _modal_target == "":
		return
	var id := _modal_target
	_close_modal()
	if _selected_id == id:
		_selected_id = ""
	var res := await DeckStore.delete_deck(id)   # DELETE /decks/{id} → decks_changed → _rebuild_grid
	if res.ok:
		_toast("Deck apagado")
	else:
		_toast("Falha ao apagar: %s" % res.error)


func _toast(msg: String) -> void:
	var pill := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = S.C_BG_MID
	s.border_color = S.border_gold(0.35)
	s.set_border_width_all(1)
	s.set_content_margin(SIDE_LEFT, 22)
	s.set_content_margin(SIDE_RIGHT, 22)
	s.set_content_margin(SIDE_TOP, 12)
	s.set_content_margin(SIDE_BOTTOM, 12)
	pill.add_theme_stylebox_override("panel", s)
	pill.add_child(_make_label(msg.to_upper(), S.FONT_REG, 12, S.C_GOLD_GLOW))
	pill.modulate.a = 0.0
	_toast_layer.add_child(pill)
	await get_tree().process_frame
	pill.position = Vector2((size.x - pill.size.x) * 0.5, size.y - 150)
	var t := create_tween()
	t.tween_property(pill, "modulate:a", 1.0, 0.2)
	t.tween_interval(1.8)
	t.tween_property(pill, "modulate:a", 0.0, 0.3)
	t.tween_callback(pill.queue_free)


# ── Navegação ─────────────────────────────────────────────────────────────────

func _open_builder(deck_id: String) -> void:
	DeckStore.active_deck_id = deck_id
	get_tree().change_scene_to_file(DECK_BUILDER_SCENE)


func _new_deck() -> void:
	if DeckStore.decks.size() >= DeckStore.MAX_DECKS:
		_toast("Limite de %d decks atingido" % DeckStore.MAX_DECKS)
		return
	DeckStore.active_deck_id = ""
	get_tree().change_scene_to_file(DECK_BUILDER_SCENE)


func _go_back() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		get_tree().change_scene_to_file(WORLD_SCENE)
	else:
		get_tree().change_scene_to_file(LOGIN_SCENE)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _modal.visible:
			_close_modal()
		elif _selected_id != "":
			_set_selected("")
		get_viewport().set_input_as_handled()


# ── Estilos ───────────────────────────────────────────────────────────────────

func _apply_styles() -> void:
	# Header
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(0.05, 0.05, 0.10, 0.85)
	hs.border_color = S.border_gold(0.18)
	hs.border_width_bottom = 1
	hs.set_content_margin(SIDE_LEFT, 26)
	hs.set_content_margin(SIDE_RIGHT, 26)
	hs.set_content_margin(SIDE_TOP, 10)
	hs.set_content_margin(SIDE_BOTTOM, 10)
	_header.add_theme_stylebox_override("panel", hs)

	_flat_btn(_back_btn, S.C_GOLD_DIM, S.C_GOLD, 12)
	_style_lbl(%EyebrowLine, S.FONT_REG, 10, Color(S.C_GOLD_DIM, 0.7))
	_style_lbl(%EyebrowTitle, FONT_DECO, 20, S.C_GOLD_GLOW)
	_style_lbl(_tally, S.FONT_REG, 12, S.C_PARCHMENT_D)
	S.apply_button_gold(_new_btn)
	_new_btn.add_theme_color_override("font_color", S.C_GOLD_GLOW)

	_style_lbl(%GhTitle, S.FONT_REG, 13, S.C_GOLD_DIM)
	_style_lbl(%GhHint, S.FONT_REG, 13, Color(S.C_PARCHMENT_D, 0.55))

	# Action bar
	var abs := StyleBoxFlat.new()
	abs.bg_color = Color(0.05, 0.045, 0.10, 0.95)
	abs.border_color = S.border_gold(0.35)
	abs.border_width_top = 1
	abs.set_content_margin(SIDE_LEFT, 30)
	abs.set_content_margin(SIDE_RIGHT, 30)
	abs.set_content_margin(SIDE_TOP, 14)
	abs.set_content_margin(SIDE_BOTTOM, 14)
	_action_bar.add_theme_stylebox_override("panel", abs)
	_style_lbl(%AbLabel, S.FONT_REG, 9, Color(S.C_GOLD_DIM, 0.85))
	_style_lbl(_ab_name, FONT_DECO, 17, S.C_GOLD_GLOW)
	S.apply_button_crimson(_ab_delete)
	S.apply_button_gold(_ab_edit)
	_ab_edit.add_theme_color_override("font_color", S.C_GOLD_GLOW)

	# Modal
	var mp := StyleBoxFlat.new()
	mp.bg_color = S.C_BG_MID
	mp.border_color = S.border_gold(0.35)
	mp.set_border_width_all(1)
	mp.set_content_margin(SIDE_LEFT, 28)
	mp.set_content_margin(SIDE_RIGHT, 28)
	mp.set_content_margin(SIDE_TOP, 24)
	mp.set_content_margin(SIDE_BOTTOM, 24)
	(%Modal.get_node("Center/Panel") as PanelContainer).add_theme_stylebox_override("panel", mp)
	_style_lbl(%Title, FONT_DECO, 20, S.C_GOLD_GLOW)
	_modal_body.add_theme_font_override("normal_font", S.FONT_REG)
	_modal_body.add_theme_font_size_override("normal_font_size", 14)
	_modal_body.add_theme_color_override("default_color", S.C_PARCHMENT_D)
	S.apply_button_gold(_modal_cancel)
	S.apply_button_crimson(_modal_confirm)

	# New tile
	var nt_panel := %NewTile.get_node("Panel") as PanelContainer
	var nts := StyleBoxFlat.new()
	nts.bg_color = Color(0.07, 0.07, 0.12, 0.4)
	nts.border_color = S.border_gold(0.35)
	nts.set_border_width_all(1)
	nt_panel.add_theme_stylebox_override("panel", nts)
	_ignore_subtree(nt_panel)   # clique chega no NewTile
	_style_lbl(%Mark, FONT_BLACK, 40, S.C_GOLD)
	_style_lbl(%NewLabel, S.FONT_REG, 13, S.C_GOLD_DIM)
	_style_lbl(%NewSub, S.FONT_REG, 11, Color(S.C_PARCHMENT_D, 0.55))
	_new_tile.mouse_entered.connect(func() -> void:
		nts.border_color = S.border_gold(0.9)
		nt_panel.queue_redraw())
	_new_tile.mouse_exited.connect(func() -> void:
		nts.border_color = S.border_gold(0.35)
		nt_panel.queue_redraw())


# Resolve sleeve/playmat do CosmeticsStore → { "name", "tex" }.
func _sleeve_info(id: String) -> Dictionary:
	var c := CosmeticsStore.get_sleeve(id)
	var art := str(c.get("art_key", ""))
	return { "name": str(c.get("name", id)), "tex": _tex("res://assets/sleve/%s.png" % art) }


func _playmat_info(id: String) -> Dictionary:
	var c := CosmeticsStore.get_playmat(id)
	var art := str(c.get("art_key", ""))
	return { "name": str(c.get("name", id)), "tex": _tex("res://assets/playmats/%s.png" % art) }


func _tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


func _ignore_subtree(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_subtree(c)


func _flat_btn(btn: Button, fg: Color, fg_hover: Color, size: int) -> void:
	btn.add_theme_font_override("font", S.FONT_REG)
	btn.add_theme_font_size_override("font_size", size)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg_hover)


func _style_lbl(node: Node, font: Font, size: int, color: Color) -> void:
	var l := node as Label
	if l == null:
		return
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)


func _make_label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
