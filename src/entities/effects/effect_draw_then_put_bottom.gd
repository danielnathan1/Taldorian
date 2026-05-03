# src/entities/effects/effect_draw_then_put_bottom.gd
# Compra 1 carta, depois o jogador escolhe 1 carta da mão para colocar no fundo do deck.
class_name EffectDrawThenPutBottom
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	var p := ctx.source_player

	# 1. Compra a carta primeiro
	p.draw_cards(1)

	# 2. Se a mão estiver vazia não há nada para devolver
	if p.hand.is_empty():
		return

	# 3. Abre o pick da mão — o jogador escolhe qual carta vai ao fundo do deck
	var indices: Array[int] = []
	for i in p.hand.size():
		indices.append(i)

	GameState.begin_hand_pick(p.player_index, indices)
