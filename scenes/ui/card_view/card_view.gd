class_name CardView
extends PanelContainer

@onready var type_label    := $VBoxContainer/TypeLabel
@onready var value_label   := $VBoxContainer/ValueLabel
@onready var symbols_label := $VBoxContainer/SymbolsLabel

signal card_clicked(card: Card)
signal card_double_clicked(card: Card)

var card: Card = null
var selected: bool = false

func _ready() -> void:
	var c := Card.new()
	c.card_name = "Ataque +%d" % 1
	c.card_type = Card.CardType.ATTACK
	c.value = 1
	c.set_symbols([GameSymbols.FOGO])
	c.is_stealth = false
	bind(c)

func bind(p_card: Card) -> void:
	card = p_card
	type_label.text    = card.get_type_label()
	value_label.text   = "+%d" % card.value
	symbols_label.text = card.symbols_display()

func set_selected(value: bool) -> void:
	selected = value
	# troca StyleBox ou modulate conforme seleção
	modulate = Color(1.2, 1.2, 0.6) if selected else Color.WHITE

func set_face_down(value: bool) -> void:
	# esconde conteúdo pras cartas do oponente
	$VBoxContainer.visible = !value

func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.double_click:
		card_double_clicked.emit(card)
	else:
		card_clicked.emit(card)
