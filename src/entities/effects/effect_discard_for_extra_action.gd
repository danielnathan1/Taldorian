# Preço da Ambição — descarte `count` cartas para ganhar `actions` ação(ões) extra(s).
# Abre o overlay de descarte (o jogador escolhe quais). A ação extra é concedida na hora.
class_name EffectDiscardForExtraAction
extends CardEffect

var _count: int = 2
var _actions: int = 1

func setup(params: Dictionary) -> void:
	_count   = params.get("count", 2)
	_actions = params.get("actions", 1)

func execute(ctx: CardEffectContext) -> void:
	var p := ctx.source_player
	if p.hand.size() < _count:
		return
	p.extra_actions += _actions
	var indices: Array[int] = []
	for i in p.hand.size():
		indices.append(i)
	GameState.begin_hand_discard(p.player_index, indices, _count, 0,
		"Descarte %d cartas para ganhar ação extra" % _count)
