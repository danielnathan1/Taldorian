class_name EffectBothRecycleArsenal
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	var p    := ctx.source_player
	var opp  := ctx.opponent_player
	var p_idx   := p.player_index
	var opp_idx := opp.player_index

	if p.discard_pile.is_empty() and opp.discard_pile.is_empty():
		return

	if not p.discard_pile.is_empty():
		var indices: Array[int] = []
		for i in p.discard_pile.size():
			indices.append(i)
		var followup := opp_idx if not opp.discard_pile.is_empty() else -1
		GameState.begin_graveyard_arsenal_pick(p_idx, indices, followup,
			"Escolha uma carta do cemitério para colocar no seu arsenal")
	elif not opp.discard_pile.is_empty():
		var indices: Array[int] = []
		for i in opp.discard_pile.size():
			indices.append(i)
		GameState.begin_graveyard_arsenal_pick(opp_idx, indices, -1,
			"Escolha uma carta do cemitério para colocar no seu arsenal")
