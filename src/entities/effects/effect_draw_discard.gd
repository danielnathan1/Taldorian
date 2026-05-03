# src/entities/effects/effect_draw_discard.gd
# O jogador escolhe N cartas da mão para descartar; depois compra M cartas.
class_name EffectDrawDiscard
extends CardEffect

var _discard_count: int = 0
var _draw_count: int    = 0

func setup(params: Dictionary) -> void:
	_discard_count = params.get("discard", 0)
	_draw_count    = params.get("draw",    0)

func execute(ctx: CardEffectContext) -> void:
	var p := ctx.source_player

	# Se não há cartas suficientes na mão, descarta tudo sem prompt
	if p.hand.size() <= _discard_count:
		var cards := p.hand.duplicate()
		p.hand.clear()
		p.discard_pile.append_array(cards)
		p.draw_cards(_draw_count)
		return

	# Abre o overlay de descarte — jogador escolhe _discard_count cartas
	var indices: Array[int] = []
	for i in p.hand.size():
		indices.append(i)

	GameState.begin_hand_discard(p.player_index, indices, _discard_count, _draw_count)
