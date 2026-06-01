extends Control

const LOBBY_SCENE     := "res://scenes/ui/lobby/lobby.tscn"
const CARD_VIEW_SCENE := preload("res://scenes/ui/card_view/card_view.tscn")
const PACK_SIZE       := 8
const PACK_PRICE      := 100
const STARTING_GOLD   := 1500
const GOLD_SAVE_PATH  := "user://booster_gold.json"

const RARITY_WEIGHTS: Dictionary = {
	"COMMON":    70,
	"RARE":      20,
	"LEGENDARY": 10,
}

enum Phase { NONE, ENTER, SHAKE, SPLIT, FLY, STACK, REVEAL }

# ── Colors ────────────────────────────────────────────────────────────────────
const C_GOLD        := Color(0.788, 0.627, 0.298)
const C_GOLD_GLOW   := Color(0.910, 0.784, 0.337)
const C_GOLD_DIM    := Color(0.549, 0.431, 0.192)
const C_PARCHMENT_D := Color(0.722, 0.659, 0.549)
const C_BORDER      := Color(0.788, 0.627, 0.298, 0.20)
const C_BORDER_STR  := Color(0.788, 0.627, 0.298, 0.40)
const C_SURFACE     := Color(0.078, 0.098, 0.188, 1.0)
const C_SURFACE2    := Color(0.055, 0.071, 0.145, 1.0)

const C_RARE_COMMON    := Color(0.70, 0.60, 0.50)
const C_RARE_RARE      := Color(0.45, 0.60, 0.92)
const C_RARE_LEGENDARY := Color(0.92, 0.78, 0.34)

# ── @onready ──────────────────────────────────────────────────────────────────
@onready var _shop_view:         Control        = %ShopView
@onready var _opening_view:      Control        = %OpeningView
@onready var _gold_lbl:          Label          = %GoldLabel
@onready var _collections_list:  VBoxContainer  = %CollectionsList
@onready var _pack_display_wrap: CenterContainer = %PackDisplayWrap
@onready var _pack_info_row:     HBoxContainer  = %PackInfoRow
@onready var _qty_lbl:           Label          = %QtyLabel
@onready var _total_lbl:         Label          = %TotalLabel
@onready var _minus_btn:         Button         = %MinusBtn
@onready var _plus_btn:          Button         = %PlusBtn
@onready var _max_btn:           Button         = %MaxBtn
@onready var _buy_btn:           Button         = %BuyBtn
@onready var _back_btn:          Button         = %BackButton
@onready var _pack_counter_lbl:  Label          = %PackCounterLabel
@onready var _dots_row:          HBoxContainer  = %DotsRow
@onready var _exit_btn:          Button         = %ExitButton
@onready var _pack_root:         Control        = %PackRoot
@onready var _card_stage:        Control        = %CardStage
@onready var _hint_lbl:          Label          = %HintLabel
@onready var _reveal_rail:       HBoxContainer  = %RevealRail
@onready var _finish_row:        Control        = %FinishRow
@onready var _back_to_shop_btn:  Button         = %BackToShopBtn
@onready var _next_pack_btn:     Button         = %NextPackBtn

# ── State ─────────────────────────────────────────────────────────────────────
var _gold:          int   = STARTING_GOLD
var _qty:           int   = 1
var _packs_queue:   Array = []
var _cur_pack_idx:  int   = 0
var _cur_cards:     Array = []
var _revealed:      int   = 0
var _phase:         Phase = Phase.NONE
var _stage_cards:   Array[Control] = []
var _progress_dots: Array[ColorRect] = []
var _pack_top_node: Control
var _pack_bot_node: Control

var _font_black:   FontFile
var _font_regular: FontFile

# ─────────────────────────────────────────────────────────────────────────────
# INIT
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_font_black   = load("res://assets/fonts/CinzelDecorative-Black.ttf")
	_font_regular = load("res://assets/fonts/CinzelDecorative-Regular.ttf")
	_load_gold()
	_setup_buttons()
	_build_collection_list()
	_build_shop_pack_visual()
	_fill_pack_info_row()
	_build_dots()
	_back_btn.pressed.connect(_on_back_pressed)
	_minus_btn.pressed.connect(func() -> void: _change_qty(-1))
	_plus_btn.pressed.connect(func() -> void: _change_qty(1))
	_max_btn.pressed.connect(_set_qty_max)
	_buy_btn.pressed.connect(_on_buy_pressed)
	_exit_btn.pressed.connect(_on_opening_exit)
	_back_to_shop_btn.pressed.connect(_on_opening_exit)
	_next_pack_btn.pressed.connect(_on_next_pack)
	_show_shop()


# ─────────────────────────────────────────────────────────────────────────────
# SETUP — called once in _ready
# ─────────────────────────────────────────────────────────────────────────────
func _setup_buttons() -> void:
	_style_btn(_back_btn,         C_GOLD_DIM,    C_GOLD,      C_SURFACE2,                   C_BORDER_STR)
	_style_btn(_exit_btn,         C_GOLD_DIM,    C_GOLD_GLOW, Color(0.04, 0.05, 0.10, 0.8), C_BORDER)
	_style_btn(_back_to_shop_btn, C_PARCHMENT_D, C_GOLD_GLOW, Color(0.06, 0.07, 0.14, 0.75),C_BORDER_STR)
	_style_btn(_max_btn,          C_GOLD_DIM,    C_GOLD,      C_SURFACE2,                   C_BORDER)
	_style_small_btn(_minus_btn)
	_style_small_btn(_plus_btn)
	_style_cta_btn(_buy_btn)
	_style_cta_btn(_next_pack_btn)


func _build_collection_list() -> void:
	var total := Collection.all_card_dicts.size()
	_collections_list.add_child(_build_coll_card(
		"Origens de Taldorian", "Coleção Inicial",
		"A primeira leva de cartas com os cinco elementos. Sorteio: %d%% Comum · %d%% Rara · %d%% Lendária." % [
			RARITY_WEIGHTS["COMMON"], RARITY_WEIGHTS["RARE"], RARITY_WEIGHTS["LEGENDARY"]
		], total, PACK_PRICE, true))
	for cfg: Array in [
		["A Sombra Caída",    "Expansão I",  "Em breve. Heróis corrompidos pelo véu sombrio.", 24, 150],
		["Os Reis das Marés", "Expansão II", "Em breve. Convocações abissais de Aldérion.",     28, 150],
	]:
		_collections_list.add_child(_build_coll_card(cfg[0], cfg[1], cfg[2], cfg[3], cfg[4], false))


func _build_shop_pack_visual() -> void:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(200, 280)
	var panel := _make_pack_panel("Origens de Taldorian", 200.0, 280.0)
	wrap.add_child(panel)
	_pack_display_wrap.add_child(wrap)
	# Float animation
	var tw := create_tween().set_loops()
	tw.tween_property(wrap, "rotation_degrees", -4.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(wrap, "rotation_degrees",  4.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _fill_pack_info_row() -> void:
	var cells: Array = [
		["Cartas / Pacote", str(PACK_SIZE)],
		["Preço Unitário",  str(PACK_PRICE)],
		["Rara Garantida",  "✦ 0+"],
	]
	for i in cells.size():
		if i > 0:
			var div := ColorRect.new()
			div.custom_minimum_size = Vector2(1, 32)
			div.color = C_BORDER
			div.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_pack_info_row.add_child(div)
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		cell.custom_minimum_size = Vector2(110, 0)
		_pack_info_row.add_child(cell)
		var ey := Label.new()
		ey.text = cells[i][0].to_upper()
		ey.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ey.add_theme_color_override("font_color", C_GOLD_DIM)
		ey.add_theme_font_override("font", _font_regular)
		ey.add_theme_font_size_override("font_size", 9)
		cell.add_child(ey)
		var val := Label.new()
		val.text = cells[i][1]
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val.add_theme_color_override("font_color", C_GOLD_GLOW)
		val.add_theme_font_override("font", _font_black)
		val.add_theme_font_size_override("font_size", 16)
		cell.add_child(val)


func _build_dots() -> void:
	_progress_dots.clear()
	for _i in PACK_SIZE:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(9, 9)
		dot.color = Color(C_BORDER, 1.5)
		_progress_dots.append(dot)
		_dots_row.add_child(dot)


# ─────────────────────────────────────────────────────────────────────────────
# GOLD
# ─────────────────────────────────────────────────────────────────────────────
func _load_gold() -> void:
	if not FileAccess.file_exists(GOLD_SAVE_PATH):
		_gold = STARTING_GOLD
		return
	var f := FileAccess.open(GOLD_SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_gold = int(parsed.get("gold", STARTING_GOLD))


func _save_gold() -> void:
	var f := FileAccess.open(GOLD_SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"gold": _gold}))
	f.close()


# ─────────────────────────────────────────────────────────────────────────────
# PACK GENERATION
# ─────────────────────────────────────────────────────────────────────────────
func _roll_rarity() -> String:
	var r := randi_range(1, 100)
	var acc := 0
	for rar in RARITY_WEIGHTS:
		acc += RARITY_WEIGHTS[rar]
		if r <= acc:
			return rar
	return "COMMON"


func _pick_of_rarity(rarity: String) -> Dictionary:
	var pool: Array[Dictionary] = []
	for d in Collection.all_card_dicts:
		if d.get("rarity", "COMMON") == rarity:
			pool.append(d)
	if pool.is_empty():
		return Collection.all_card_dicts[randi() % Collection.all_card_dicts.size()]
	return pool[randi() % pool.size()]


func _generate_pack() -> Array:
	var slots: Array = []
	for _i in PACK_SIZE:
		slots.append(_pick_of_rarity(_roll_rarity()))
	slots.shuffle()
	return slots


# ─────────────────────────────────────────────────────────────────────────────
# OPENING — coreografia de fases
# ─────────────────────────────────────────────────────────────────────────────
func _start_pack(idx: int) -> void:
	_cur_cards  = _packs_queue[idx]
	_revealed   = 0
	_phase      = Phase.NONE
	_finish_row.visible = false
	_hint_lbl.visible   = false

	for c in _stage_cards:
		c.queue_free()
	_stage_cards.clear()

	for c in _reveal_rail.get_children():
		c.queue_free()

	# Rebuild split pack inside PackRoot
	for c in _pack_root.get_children():
		c.queue_free()
	_pack_root.visible  = true
	_pack_root.scale    = Vector2(0.4, 0.4)
	_pack_root.rotation = 0.0
	_pack_root.modulate = Color.WHITE
	_build_split_pack(_pack_root, "Origens de Taldorian")

	_pack_counter_lbl.text = "%d / %d" % [idx + 1, _packs_queue.size()]

	for dot in _progress_dots:
		dot.color = Color(C_BORDER, 1.5)

	var stage_center := get_viewport_rect().size * 0.5
	for i in PACK_SIZE:
		var cv: CardView = CARD_VIEW_SCENE.instantiate()
		cv.pivot_offset = Vector2(100, 150)
		cv.z_index      = PACK_SIZE - i
		cv.position     = stage_center - Vector2(100, 150)
		cv.modulate     = Color(1, 1, 1, 0)
		cv.scale        = Vector2(0.3, 0.3)
		_card_stage.add_child(cv)
		cv.size = Vector2(200, 300)
		cv.bind_dict(_cur_cards[i])
		cv.apply_scale(1.25)
		cv.set_face_down(true)
		cv.set_interactable(false, false)
		_stage_cards.append(cv)

	_run_phases.call_deferred()


func _run_phases() -> void:
	await _delay(0.05)

	_phase = Phase.ENTER
	var tw_enter := create_tween()
	tw_enter.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw_enter.tween_property(_pack_root, "scale", Vector2.ONE, 0.55)
	await _delay(0.65)

	_phase = Phase.SHAKE
	var tw_shake := create_tween()
	tw_shake.tween_property(_pack_root, "rotation", deg_to_rad(-2.5), 0.10)
	tw_shake.tween_property(_pack_root, "rotation", deg_to_rad( 2.5), 0.10)
	tw_shake.tween_property(_pack_root, "rotation", deg_to_rad(-1.5), 0.10)
	tw_shake.tween_property(_pack_root, "rotation", deg_to_rad( 1.5), 0.10)
	tw_shake.tween_property(_pack_root, "rotation", deg_to_rad( 0.0), 0.10)
	await _delay(0.85)

	_phase = Phase.SPLIT
	var tw_split := create_tween().set_parallel(true)
	tw_split.tween_property(_pack_top_node, "position:y", -180.0, 0.70).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw_split.tween_property(_pack_top_node, "modulate:a",   0.0,  0.55)
	tw_split.tween_property(_pack_bot_node, "position:y",  300.0, 0.70).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw_split.tween_property(_pack_bot_node, "modulate:a",   0.0,  0.55)
	_spawn_burst_particles()
	await _delay(0.80)
	_pack_root.visible = false

	_phase = Phase.FLY
	var screen_center := get_viewport_rect().size * 0.5
	for i in PACK_SIZE:
		var card := _stage_cards[i]
		var arc  := _arc_position(i)
		var rot  := _arc_rotation(i)
		var target_pos := screen_center + arc - Vector2(100, 150)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(card, "position", target_pos, 0.90).set_delay(i * 0.04).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "rotation", deg_to_rad(rot), 0.90).set_delay(i * 0.04).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale",    Vector2.ONE, 0.55).set_delay(i * 0.04).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "modulate:a", 1.0, 0.35).set_delay(i * 0.04)
	await _delay(1.00)

	_phase = Phase.STACK
	for i in PACK_SIZE:
		var card   := _stage_cards[i]
		var spos   := _stack_position(i)
		var target := screen_center + spos - Vector2(100, 150)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(card, "position", target, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "rotation", 0.0,    0.40).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _delay(0.80)

	_phase = Phase.REVEAL
	_hint_lbl.visible = true


func _delay(seconds: float) -> Signal:
	return get_tree().create_timer(seconds).timeout


func _arc_position(i: int) -> Vector2:
	var angle := deg_to_rad(-110.0 + 220.0 * float(i) / float(PACK_SIZE - 1))
	return Vector2(cos(angle) * 280.0, sin(angle) * 280.0 * 0.55 - 60.0)


func _arc_rotation(i: int) -> float:
	return (float(i) - float(PACK_SIZE - 1) * 0.5) * 14.0


func _stack_position(i: int) -> Vector2:
	var off := float(i - _revealed) * 3.0
	return Vector2(off, -off)


func _spawn_burst_particles() -> void:
	var center := get_viewport_rect().size * 0.5
	for _i in 18:
		var p := ColorRect.new()
		p.custom_minimum_size = Vector2(6, 6)
		p.color    = Color(C_GOLD_GLOW, 0.9)
		p.position = center - Vector2(3, 3)
		_card_stage.add_child(p)
		var bx := randf_range(-400.0, 400.0)
		var by := randf_range(-400.0, 400.0)
		var d  := randf_range(0.0, 0.15)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(p, "position",   center + Vector2(bx, by), 0.9).set_delay(d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, 0.7).set_delay(d + 0.15)
		tw.tween_callback(p.queue_free).set_delay(d + 0.9)


# ─────────────────────────────────────────────────────────────────────────────
# INPUT — captura clique durante REVEAL
# ─────────────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if _phase != Phase.REVEAL or _revealed >= PACK_SIZE:
		return
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var cv := _stage_cards[_revealed] as CardView
	if not cv.get_global_rect().has_point(mb.global_position):
		return
	get_viewport().set_input_as_handled()
	_flip_and_reveal(_revealed)


func _flip_and_reveal(idx: int) -> void:
	_phase = Phase.NONE
	_hint_lbl.visible = false
	var cv := _stage_cards[idx] as CardView
	var tw := create_tween()
	tw.tween_property(cv, "scale:x", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		cv.set_face_down(false)
		var rarity: String = _cur_cards[idx].get("rarity", "COMMON")
		if rarity in ["RARE", "LEGENDARY"]:
			cv.modulate = Color(C_GOLD_GLOW, 1.0)
	)
	tw.tween_property(cv, "scale:x", 1.0, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		cv.modulate = Color.WHITE
		_after_reveal(idx, _cur_cards[idx])
	)


func _after_reveal(idx: int, card_dict: Dictionary) -> void:
	_revealed += 1

	if idx < _progress_dots.size():
		_progress_dots[idx].color = C_GOLD

	var thumb_wrap := Control.new()
	thumb_wrap.custom_minimum_size = Vector2(52, 78)
	thumb_wrap.clip_contents = true
	_reveal_rail.add_child(thumb_wrap)
	var cv_thumb: CardView = CARD_VIEW_SCENE.instantiate()
	cv_thumb.scale = Vector2(0.325, 0.325)
	thumb_wrap.add_child(cv_thumb)
	cv_thumb.bind_dict(card_dict)
	cv_thumb.apply_scale(0.325)
	thumb_wrap.modulate   = Color(1, 1, 1, 0)
	thumb_wrap.position.y = 14.0
	var ttw := create_tween().set_parallel(true)
	ttw.tween_property(thumb_wrap, "modulate:a",  1.0, 0.3)
	ttw.tween_property(thumb_wrap, "position:y",  0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_restack_remaining()

	if _revealed >= PACK_SIZE:
		Collection.add_cards(_cur_cards)
		var ftw := create_tween()
		ftw.tween_interval(0.45)
		ftw.tween_callback(func() -> void:
			_hint_lbl.visible   = false
			_finish_row.visible = true
			_update_finish_btn()
		)
	else:
		await get_tree().create_timer(0.35).timeout
		_phase = Phase.REVEAL
		_hint_lbl.visible = true


func _restack_remaining() -> void:
	var screen_center := get_viewport_rect().size * 0.5
	for i in range(_revealed, PACK_SIZE):
		var card   := _stage_cards[i]
		var spos   := _stack_position(i)
		var target := screen_center + spos - Vector2(100, 150)
		var tw := create_tween()
		tw.tween_property(card, "position", target, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ─────────────────────────────────────────────────────────────────────────────
# UI UPDATE
# ─────────────────────────────────────────────────────────────────────────────
func _update_purchase_ui() -> void:
	if _gold_lbl:
		_gold_lbl.text = str(_gold)

	var max_buy := mini(10, _max_affordable())
	_qty = clampi(_qty, 1, maxi(1, max_buy))
	if _qty_lbl:
		_qty_lbl.text = str(_qty)

	var total := _qty * PACK_PRICE
	if _total_lbl:
		_total_lbl.add_theme_color_override("font_color",
			C_GOLD_GLOW if total <= _gold else Color(0.92, 0.32, 0.22))
		_total_lbl.text = str(total)

	if _minus_btn: _minus_btn.disabled = (_qty <= 1)
	if _plus_btn:  _plus_btn.disabled  = (_qty >= max_buy)
	if _max_btn:   _max_btn.disabled   = (max_buy <= 0)
	if _buy_btn:
		_buy_btn.disabled = (max_buy <= 0 or total > _gold)
		if max_buy <= 0:
			_buy_btn.text = "Ouro Insuficiente"
		elif _qty == 1:
			_buy_btn.text = "⚔  Abrir Pacote"
		else:
			_buy_btn.text = "⚔  Abrir %d Pacotes" % _qty


func _update_finish_btn() -> void:
	var more := _cur_pack_idx < _packs_queue.size() - 1
	_next_pack_btn.text = "Próximo Pacote →" if more else "✓  Concluir"


func _max_affordable() -> int:
	return maxi(0, _gold / PACK_PRICE)


func _change_qty(delta: int) -> void:
	var max_buy := mini(10, _max_affordable())
	_qty = clampi(_qty + delta, 1, maxi(1, max_buy))
	_update_purchase_ui()


func _set_qty_max() -> void:
	_qty = maxi(1, mini(10, _max_affordable()))
	_update_purchase_ui()


# ─────────────────────────────────────────────────────────────────────────────
# NAVIGATION
# ─────────────────────────────────────────────────────────────────────────────
func _show_shop() -> void:
	_shop_view.visible    = true
	_opening_view.visible = false
	_update_purchase_ui()


func _show_opening(packs: Array) -> void:
	_packs_queue  = packs
	_cur_pack_idx = 0
	_shop_view.visible    = false
	_opening_view.visible = true
	_start_pack(0)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_buy_pressed() -> void:
	var total := _qty * PACK_PRICE
	if total > _gold:
		return
	_gold -= total
	_save_gold()
	var packs: Array = []
	for _i in _qty:
		packs.append(_generate_pack())
	_show_opening(packs)


func _on_opening_exit() -> void:
	for pi in range(_cur_pack_idx, _packs_queue.size()):
		Collection.add_cards(_packs_queue[pi])
	_show_shop()


func _on_next_pack() -> void:
	_cur_pack_idx += 1
	if _cur_pack_idx >= _packs_queue.size():
		_show_shop()
	else:
		_start_pack(_cur_pack_idx)


# ─────────────────────────────────────────────────────────────────────────────
# BUILDERS — dynamic content (collection cards, pack panel)
# ─────────────────────────────────────────────────────────────────────────────
func _build_coll_card(title: String, eyebrow: String, desc: String,
		set_size: int, price: int, unlocked: bool) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.078, 0.098, 0.188, 1.0)
	style.border_color = C_BORDER if unlocked else Color(C_BORDER, 0.4)
	style.set_border_width_all(1)
	if unlocked:
		style.shadow_color = Color(C_GOLD, 0.12)
		style.shadow_size  = 8
	card.add_theme_stylebox_override("panel", style)
	if not unlocked:
		card.modulate = Color(1, 1, 1, 0.42)

	var margin := MarginContainer.new()
	for side: int in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		margin.add_theme_constant_override(["margin_left","margin_right","margin_top","margin_bottom"][side], [18,18,16,16][side])
	card.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	var thumb := ColorRect.new()
	thumb.custom_minimum_size = Vector2(72, 100)
	thumb.color = Color(C_GOLD, 0.14)
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(thumb)
	var thumb_lbl := Label.new()
	thumb_lbl.text = "TCG"
	thumb_lbl.add_theme_color_override("font_color", Color(C_GOLD, 0.45))
	thumb_lbl.add_theme_font_override("font", _font_black)
	thumb_lbl.add_theme_font_size_override("font_size", 11)
	thumb_lbl.set_anchors_preset(Control.PRESET_CENTER)
	thumb.add_child(thumb_lbl)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	hbox.add_child(info)

	_lbl(info, eyebrow.to_upper(), _font_regular, 9, C_GOLD_DIM)

	var ttl := Label.new()
	ttl.text = title
	ttl.add_theme_color_override("font_color", C_GOLD_GLOW if unlocked else Color(0.929, 0.875, 0.784))
	ttl.add_theme_font_override("font", _font_black)
	ttl.add_theme_font_size_override("font_size", 14)
	info.add_child(ttl)

	var dlbl := Label.new()
	dlbl.text = desc
	dlbl.add_theme_color_override("font_color", C_PARCHMENT_D)
	dlbl.add_theme_font_override("font", _font_regular)
	dlbl.add_theme_font_size_override("font_size", 10)
	dlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(dlbl)

	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 16)
	info.add_child(meta)
	for t: String in [str(set_size) + " cartas", str(price) + " ouro / pacote"]:
		_lbl(meta, t, _font_regular, 10, C_GOLD_DIM)

	if not unlocked:
		var lock := Label.new()
		lock.text = "🔒  EM BREVE"
		lock.add_theme_color_override("font_color", C_PARCHMENT_D)
		lock.add_theme_font_override("font", _font_regular)
		lock.add_theme_font_size_override("font_size", 9)
		lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(lock)
	return card


func _build_split_pack(parent: Control, collection_name: String) -> void:
	var half_h := 140.0
	var pack_w := 200.0

	_pack_top_node = Control.new()
	_pack_top_node.custom_minimum_size = Vector2(pack_w, half_h)
	_pack_top_node.size        = Vector2(pack_w, half_h)
	_pack_top_node.clip_contents = true
	_pack_top_node.position    = Vector2(0, 0)
	parent.add_child(_pack_top_node)
	var top_inner := _make_pack_panel(collection_name, pack_w, half_h * 2)
	top_inner.position = Vector2(0, 0)
	_pack_top_node.add_child(top_inner)

	_pack_bot_node = Control.new()
	_pack_bot_node.custom_minimum_size = Vector2(pack_w, half_h)
	_pack_bot_node.size        = Vector2(pack_w, half_h)
	_pack_bot_node.clip_contents = true
	_pack_bot_node.position    = Vector2(0, half_h)
	parent.add_child(_pack_bot_node)
	var bot_inner := _make_pack_panel(collection_name, pack_w, half_h * 2)
	bot_inner.position = Vector2(0, -half_h)
	_pack_bot_node.add_child(bot_inner)


func _make_pack_panel(collection_name: String, w: float, h: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(w, h)
	panel.size = Vector2(w, h)
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.08, 0.10, 0.22)
	style.border_color = C_GOLD
	style.set_border_width_all(2)
	style.shadow_color = Color(C_GOLD, 0.3)
	style.shadow_size  = 14
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)

	_lbl(vbox, "TALDORIAN TCG", _font_regular, 9, C_GOLD_GLOW).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ttl := _lbl(vbox, collection_name, _font_black, 12, C_GOLD_GLOW)
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ttl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var emb := Label.new()
	emb.text = "✦"
	emb.add_theme_color_override("font_color", Color(C_GOLD, 0.6))
	emb.add_theme_font_override("font", _font_black)
	emb.add_theme_font_size_override("font_size", 56)
	emb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emb.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	vbox.add_child(emb)

	_lbl(vbox, str(PACK_SIZE) + " CARTAS", _font_regular, 9, C_GOLD_DIM).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return panel


# ─────────────────────────────────────────────────────────────────────────────
# BUTTON STYLING HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _style_btn(btn: Button, col: Color, col_hover: Color, bg: Color, border: Color) -> void:
	btn.add_theme_color_override("font_color",       col)
	btn.add_theme_color_override("font_hover_color", col_hover)
	var n := StyleBoxFlat.new()
	n.bg_color = bg; n.border_color = border; n.set_border_width_all(1)
	n.set_content_margin(SIDE_LEFT, 16); n.set_content_margin(SIDE_RIGHT, 16)
	n.set_content_margin(SIDE_TOP, 10);  n.set_content_margin(SIDE_BOTTOM, 10)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = bg.lightened(0.08); h.border_color = C_GOLD
	btn.add_theme_stylebox_override("normal",  n)
	btn.add_theme_stylebox_override("hover",   h)
	btn.add_theme_stylebox_override("pressed", n)


func _style_small_btn(btn: Button) -> void:
	btn.add_theme_color_override("font_color",          C_GOLD)
	btn.add_theme_color_override("font_hover_color",    C_GOLD_GLOW)
	btn.add_theme_color_override("font_disabled_color", Color(C_GOLD, 0.3))
	var n := StyleBoxFlat.new()
	n.bg_color = C_SURFACE; n.border_color = C_BORDER_STR; n.set_border_width_all(1)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.12, 0.14, 0.28); h.border_color = C_GOLD
	btn.add_theme_stylebox_override("normal",   n)
	btn.add_theme_stylebox_override("hover",    h)
	btn.add_theme_stylebox_override("pressed",  n)
	btn.add_theme_stylebox_override("disabled", StyleBoxFlat.new())


func _style_cta_btn(btn: Button) -> void:
	btn.add_theme_color_override("font_color",          Color(0.94, 0.84, 0.62))
	btn.add_theme_color_override("font_hover_color",    Color(1.00, 0.95, 0.78))
	btn.add_theme_color_override("font_pressed_color",  C_GOLD)
	btn.add_theme_color_override("font_disabled_color", Color(C_PARCHMENT_D, 0.5))
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.22, 0.14, 0.04); n.border_color = Color(C_GOLD, 0.65)
	n.set_border_width_all(1); n.set_content_margin_all(18)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.30, 0.20, 0.06); h.border_color = C_GOLD
	var d := StyleBoxFlat.new()
	d.bg_color = Color(0.06, 0.07, 0.14, 0.5); d.border_color = C_BORDER
	d.set_border_width_all(1); d.set_content_margin_all(18)
	btn.add_theme_stylebox_override("normal",   n)
	btn.add_theme_stylebox_override("hover",    h)
	btn.add_theme_stylebox_override("pressed",  n)
	btn.add_theme_stylebox_override("disabled", d)


# ─────────────────────────────────────────────────────────────────────────────
# MISC HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _lbl(parent: Control, text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"COMMON":    return C_RARE_COMMON
		"RARE":      return C_RARE_RARE
		"LEGENDARY": return C_RARE_LEGENDARY
	return C_RARE_COMMON
