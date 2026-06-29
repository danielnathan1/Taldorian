# scenes/ui/boardv2/debug_card_picker/debug_card_picker.gd
# Overlay de TESTE (sala debug) — lista todas as cartas do catálogo numa grade.
# Clicar numa carta emite `card_picked(card_id)`; o board encaminha para
# GameState.rpc_debug_give_card. Fica aberto após escolher (dá pra adicionar várias).
#
# É puramente UI: não decide regra, só exibe e emite a escolha. Construído por código
# (sem .tscn) seguindo o padrão dos overlays dinâmicos do board.
extends CanvasLayer

signal card_picked(card_id: int)
signal closed

const CardViewScene := preload("res://scenes/ui/card_view/card_view.tscn")

# Tamanho de EXIBIÇÃO de cada carta na grade (o CardView nasce 160x240). Redimensionamos
# o card de verdade (âncoras refluem) em vez de usar `.scale` — assim as fontes ficam
# nítidas. As fontes do CardView nascem em 1px e SÓ aparecem via apply_scale(); o fator
# CELL_W/160 mantém a MESMA proporção de uma carta normal, só maior (padrão arsenal_screen).
const NATIVE_W := 160.0
const CELL_W := 210.0
const CELL_H := 315.0
const COLUMNS := 5

var _grid: GridContainer = null
var _search: LineEdit = null

func _ready() -> void:
	layer = 60
	visible = false
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(1180, 840)
	bg.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	root.custom_minimum_size = Vector2(1180, 840)
	panel.add_child(_pad(root, 18))

	# Cabeçalho
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "DEBUG — Dar carta à mão"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "Fechar"
	close_btn.custom_minimum_size = Vector2(130, 44)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(close)
	header.add_child(close_btn)
	root.add_child(header)

	# Busca
	_search = LineEdit.new()
	_search.placeholder_text = "Buscar carta pelo nome…"
	_search.clear_button_enabled = true
	_search.custom_minimum_size.y = 44
	_search.add_theme_font_size_override("font_size", 18)
	_search.text_changed.connect(func(_t: String) -> void: _populate())
	root.add_child(_search)

	# Grade rolável
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)
	# Popula a grade UMA vez, na construção. Em partida debug o board cria o picker já no
	# load (pré-carrega), então clicar DEBUG abre instantâneo — sem reconstruir as cartas.
	_populate()

# Margem interna simples para o conteúdo do painel.
func _pad(child: Control, m: int) -> MarginContainer:
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", m)
	mc.add_theme_constant_override("margin_right", m)
	mc.add_theme_constant_override("margin_top", m)
	mc.add_theme_constant_override("margin_bottom", m)
	mc.add_child(child)
	return mc

func _populate() -> void:
	if _grid == null:
		return
	for c in _grid.get_children():
		c.queue_free()
	var filter := _search.text.strip_edges().to_lower() if _search != null else ""
	for d in Collection.all_card_dicts:
		var cname := str(d.get("name", ""))
		if filter != "" and not cname.to_lower().contains(filter):
			continue
		_add_card_cell(d)

# Célula: um CardView escalado dentro de um Control de tamanho fixo (pra alinhar a grade).
# IMPORTANTE: o CardView usa @onready ($CardContent/Art etc.), então só pode ser bindado
# DEPOIS de entrar na árvore. Por isso adicionamos cell→grid antes de bind_dict.
#
# Não usamos o sinal `card_clicked` do CardView: ele dispara em QUALQUER botão do mouse
# (inclusive a roda → adicionava carta ao rolar). Em vez disso detectamos o clique na
# própria célula, só no botão esquerdo. Tudo fica em MOUSE_FILTER_PASS pra a roda do mouse
# continuar propagando até o ScrollContainer (scroll segue funcionando). O CardView NÃO é
# tocado — zero impacto no modo normal.
func _add_card_cell(d: Dictionary) -> void:
	var card_id := int(d.get("id", -1))
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(CELL_W, CELL_H)
	cell.mouse_filter = Control.MOUSE_FILTER_PASS

	var cv: CardView = CardViewScene.instantiate()
	cell.add_child(cv)
	_grid.add_child(cell)   # entra na árvore → _ready do CardView dispara
	cv.set_anchors_preset(Control.PRESET_FULL_RECT)   # card preenche a célula (redimensiona de verdade)
	cv.bind_dict(d)         # seguro: @onready já resolvidos
	cv.apply_scale(CELL_W / NATIVE_W)   # fontes nascem em 1px; fator proporcional à carta normal
	cv.set_preview_enabled(false)
	cv.mouse_filter = Control.MOUSE_FILTER_PASS   # deixa clique/roda propagarem até a célula
	cell.gui_input.connect(func(event: InputEvent) -> void: _on_cell_input(event, card_id))

func _on_cell_input(event: InputEvent, card_id: int) -> void:
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_on_card_chosen(card_id)

func _on_card_chosen(card_id: int) -> void:
	if card_id < 0:
		return
	card_picked.emit(card_id)

func open() -> void:
	# A grade já foi construída no _ready — abrir é só exibir (instantâneo).
	visible = true
	if _search != null:
		_search.grab_focus()

func close() -> void:
	visible = false
	closed.emit()
