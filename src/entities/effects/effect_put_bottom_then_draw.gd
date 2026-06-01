class_name EffectPutBottomThenDraw
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	var p := ctx.source_player
	if p.hand.is_empty():
		return
	var indices: Array[int] = []
	for i in p.hand.size():
		indices.append(i)
	GameState.begin_hand_pick(p.player_index, indices, 1,
		"Escolha uma carta da mão para colocar no fundo do baralho e comprar uma nova")
