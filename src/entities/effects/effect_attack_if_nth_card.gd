class_name EffectAttackIfNthCard
extends CardEffect

var _n: int = 2
var _scope: String = "combat"
var _bonus: int = 1

func setup(params: Dictionary) -> void:
	_n     = params.get("n",     2)
	_scope = params.get("scope", "combat")
	_bonus = params.get("bonus", 1)

func execute(ctx: CardEffectContext) -> void:
	var count: int
	if _scope == "combat":
		count = ctx.source_player.turn_cards.size()
	else:
		count = ctx.source_player.cards_this_battle.size()
	if count >= _n:
		ctx.source_player.pending_bonus_attack += _bonus
