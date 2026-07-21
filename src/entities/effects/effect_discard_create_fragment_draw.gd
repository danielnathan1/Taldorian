# Sacrifício Arcano (Relicar) — custo: descarte 1 carta. Cria 1 Fragmento Arcano e compra 1.
# O Fragmento é criado já no execute (a possibilidade de pagar o custo está garantida quando
# há carta na mão); o descarte (overlay) e a compra usam begin_hand_discard(count=1, draw_after=1).
class_name EffectDiscardCreateFragmentDraw
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	var p := ctx.source_player
	if p.hand.is_empty():
		return   # sem carta para pagar o custo do descarte
	p.tokens.append(TokenArcaneFragment.new())
	var indices: Array[int] = []
	for i in p.hand.size():
		indices.append(i)
	GameState.begin_hand_discard(p.player_index, indices, 1, 1, "Descarte 1 carta")
