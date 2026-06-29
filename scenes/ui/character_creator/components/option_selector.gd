# scenes/ui/character_creator/components/option_selector.gd
# Linha de seletor cíclico:  [Rótulo]  ‹ valor ›  [swatch de cor?]
# Toda a aparência vive em option_selector.tscn — aqui só lógica.
extends GridContainer

# field_id é o id da categoria ("race", "hair", ...). index é a posição na lista de opções.
signal changed(field_id: String, index: int)
signal color_changed(field_id: String, color: Color)

var _field_id: String = ""
var _options: Array = []      # Array[Dictionary] com ao menos { id, label }
var _index: int = 0

@onready var _label:  Label             = %FieldLabel
@onready var _value:  Label             = %ValueLabel
@onready var _prev:   Button            = %PrevBtn
@onready var _next:   Button            = %NextBtn
@onready var _swatch: ColorPickerButton = %Swatch

func _ready() -> void:
	_prev.pressed.connect(func() -> void: _cycle(-1))
	_next.pressed.connect(func() -> void: _cycle(1))
	_swatch.color_changed.connect(func(c: Color) -> void:
		emit_signal("color_changed", _field_id, c))

# Configura a linha. has_color liga o swatch de cor à direita.
func bind(field_id: String, label_text: String, options: Array, has_color: bool) -> void:
	_field_id = field_id
	_label.text = label_text
	_swatch.visible = has_color
	set_options(options)

# Troca a lista de opções (ex.: tom de pele muda quando raça/sexo muda).
func set_options(options: Array) -> void:
	_options = options
	if _index >= _options.size():
		_index = 0
	_refresh_value()

func set_index(i: int) -> void:
	if _options.is_empty():
		return
	_index = ((i % _options.size()) + _options.size()) % _options.size()
	_refresh_value()

func current_index() -> int:
	return _index

func current_option() -> Dictionary:
	if _options.is_empty() or _index >= _options.size():
		return {}
	return _options[_index]

func set_color(c: Color) -> void:
	_swatch.color = c

func _cycle(dir: int) -> void:
	if _options.is_empty():
		return
	_index = (_index + dir + _options.size()) % _options.size()
	_refresh_value()
	emit_signal("changed", _field_id, _index)

func _refresh_value() -> void:
	if _options.is_empty():
		_value.text = "—"
		return
	var opt: Dictionary = _options[_index]
	_value.text = str(opt.get("label", opt.get("id", "—")))
