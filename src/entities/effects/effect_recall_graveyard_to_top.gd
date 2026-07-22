# Recordar — devolve 1 carta escolhida do seu cemitério ao TOPO do deck. Abre o pick do
# cemitério; fizzle se o cemitério estiver vazio.
class_name EffectRecallGraveyardToTop
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	var p := ctx.source_player
	if p.discard_pile.is_empty():
		return
	var idxs: Array[int] = []
	for i in p.discard_pile.size():
		idxs.append(i)
	GameState.begin_graveyard_to_top_pick(p.player_index, idxs, "Escolha uma carta do cemitério para o topo do deck")
