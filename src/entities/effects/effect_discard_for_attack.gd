class_name EffectDiscardForAttack
extends CardEffect

var _bonus: int = 2

func setup(params: Dictionary) -> void:
	_bonus = params.get("bonus", 2)

func execute(ctx: CardEffectContext) -> void:
	var p := ctx.source_player
	if p.hand.is_empty():
		return
	p.pending_bonus_attack += _bonus
	var indices: Array[int] = []
	for i in p.hand.size():
		indices.append(i)
	GameState.begin_hand_discard(p.player_index, indices, 1, 0,
		"Descarte uma carta para ganhar +%d de ataque" % _bonus)
