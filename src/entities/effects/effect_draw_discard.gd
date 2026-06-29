# src/entities/effects/effect_draw_discard.gd
# Compra M cartas e DEPOIS o jogador escolhe N cartas da mão para descartar.
# A ordem é "compra primeiro, descarta depois": as cartas recém-compradas entram
# na mão antes do overlay, então podem ser descartadas também.
class_name EffectDrawDiscard
extends CardEffect

var _discard_count: int = 0
var _draw_count: int    = 0

func setup(params: Dictionary) -> void:
	_discard_count = params.get("discard", 0)
	_draw_count    = params.get("draw",    0)

func execute(ctx: CardEffectContext) -> void:
	var p := ctx.source_player

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
