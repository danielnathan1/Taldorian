# Ressurgir — cada jogador recupera 1 carta do cemitério para a mão (você escolhe primeiro,
# depois o oponente) e VOCÊ ganha 1 ação extra. Abre o pick do cemitério para você com
# followup para o oponente. Se seu cemitério estiver vazio, ainda concede a ação e tenta o
# followup do oponente.
class_name EffectResurrectGraveyard
extends CardEffect

var _actions: int = 1

func setup(params: Dictionary) -> void:
	_actions = params.get("actions", 1)

func execute(ctx: CardEffectContext) -> void:
	var p := ctx.source_player
	var opp := ctx.opponent_player
	if _actions > 0:
		p.extra_actions += _actions
	if not p.discard_pile.is_empty():
		var idxs: Array[int] = []
		for i in p.discard_pile.size():
			idxs.append(i)
		var followup := opp.player_index if not opp.discard_pile.is_empty() else -1
		GameState.begin_graveyard_to_hand_pick(p.player_index, idxs, followup, "Recupere 1 carta do cemitério para a mão")
	elif not opp.discard_pile.is_empty():
		var idxs2: Array[int] = []
		for i in opp.discard_pile.size():
			idxs2.append(i)
		GameState.begin_graveyard_to_hand_pick(opp.player_index, idxs2, -1, "Recupere 1 carta do cemitério para a mão")
