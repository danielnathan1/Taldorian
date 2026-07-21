# src/entities/effects/effect_draw_discard.gd
# Compra M cartas e DEPOIS o jogador escolhe N cartas da mão para descartar.
# A ordem padrão é "compra primeiro, descarta depois": as cartas recém-compradas entram
# na mão antes do overlay, então podem ser descartadas também.
# Com "order": "discard_first" (Ajuste Fino) a ordem inverte: descarta às cegas primeiro,
# depois compra (usa o draw_after do overlay de descarte).
class_name EffectDrawDiscard
extends CardEffect

var _discard_count: int = 0
var _draw_count: int    = 0
var _order: String      = "draw_first"

func setup(params: Dictionary) -> void:
	_discard_count = params.get("discard", 0)
	_draw_count    = params.get("draw",    0)
	_order         = params.get("order",   "draw_first")

func execute(ctx: CardEffectContext) -> void:
	var p := ctx.source_player

	if _order == "discard_first":
		_discard_then_draw(ctx, p)
		return

	# Compra primeiro — as cartas novas já ficam disponíveis para o descarte.
	p.draw_cards(_draw_count)
	if _draw_count > 0:
		ctx.request_vfx("draw")

	if _discard_count <= 0 or p.hand.is_empty():
		return

	# Mão menor ou igual ao que precisa descartar: descarta tudo sem prompt
	# (o overlay exigiria mais seleções do que há cartas).
	if p.hand.size() <= _discard_count:
		var cards := p.hand.duplicate()
		p.hand.clear()
		for c in cards:
			p.send_to_discard(c)
		return

	# Abre o overlay de descarte sobre a mão completa (inclui as cartas compradas).
	var indices: Array[int] = []
	for i in p.hand.size():
		indices.append(i)

	GameState.begin_hand_discard(p.player_index, indices, _discard_count, 0,
		"Compre %d e descarte %d carta(s)" % [_draw_count, _discard_count])

# "Descarte primeiro, compre depois": o descarte às cegas resolve pelo overlay e o
# draw_after do pick compra as cartas em seguida (ver GameState begin_hand_discard).
func _discard_then_draw(ctx: CardEffectContext, p: Player) -> void:
	if _discard_count <= 0 or p.hand.is_empty():
		p.draw_cards(_draw_count)
		if _draw_count > 0:
			ctx.request_vfx("draw")
		return

	# Mão menor ou igual ao que precisa descartar: descarta tudo e compra, sem prompt.
	if p.hand.size() <= _discard_count:
		var cards := p.hand.duplicate()
		p.hand.clear()
		for c in cards:
			p.send_to_discard(c)
		p.draw_cards(_draw_count)
		if _draw_count > 0:
			ctx.request_vfx("draw")
		return

	var indices: Array[int] = []
	for i in p.hand.size():
		indices.append(i)

	GameState.begin_hand_discard(p.player_index, indices, _discard_count, _draw_count,
		"Descarte %d, depois compre %d carta(s)" % [_discard_count, _draw_count])
