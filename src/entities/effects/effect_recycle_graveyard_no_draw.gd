class_name EffectRecycleGraveyardNoDraw
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	var p := ctx.source_player
	if p.discard_pile.is_empty():
		return
	var indices: Array[int] = []
	for i in p.discard_pile.size():
		indices.append(i)
	GameState.begin_graveyard_pick(p.player_index, indices, 0,
		"Escolha uma carta do cemitério para retornar ao baralho")
