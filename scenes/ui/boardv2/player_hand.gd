class_name PlayerHand
extends Control

const CardViewScene := preload("res://scenes/ui/card_view/card_view.tscn")

signal card_clicked(card: Card, hand_idx: int)

func rebuild(hand: Array, sleeve: Texture2D) -> void:
	for child in get_children():
		child.queue_free()
	var n := hand.size()
	if n == 0:
		return

	const CARD_W := 160.0
	const CARD_H := 240.0
	const ARC_R  := 700.0

	var container_w: float = size.x if size.x > 100.0 else 1920.0
	var container_h: float = size.y if size.y > 10.0  else 240.0

	# Centro do arco fica abaixo do container — cartas traçam um círculo
	var arc_cx := container_w / 2.0
	var arc_cy := container_h + ARC_R

	var spread_angle := minf(5.5, 38.0 / n)
	var start_angle  := -spread_angle * (n - 1) / 2.0
	var pivot        := Vector2(CARD_W / 2.0, CARD_H)

	for i in n:
		var view: CardView = CardViewScene.instantiate()
		add_child(view)
		view.bind(hand[i])
		view.set_sleeve(sleeve)

		var idx := i
		view.card_clicked.connect(func(c: Card) -> void: card_clicked.emit(c, idx))

		var angle     := start_angle + spread_angle * i
		var angle_rad := deg_to_rad(angle)
		# bottom-center da carta sobre o arco
		var bx := arc_cx + sin(angle_rad) * ARC_R
		var by := arc_cy - cos(angle_rad) * ARC_R
		var pos := Vector2(bx - CARD_W / 2.0, by - CARD_H)

		view.setup_fan(pos, angle, pivot, i + 1)

func get_card_views() -> Array:
	return get_children()
