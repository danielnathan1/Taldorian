class_name EffectAttackIfFirstCard
extends CardEffect

var _bonus: int = 1
var _scope: String = "combat"  # "turn" ou "combat"

func setup(params: Dictionary) -> void:
	_bonus = params.get("bonus", 1)
	_scope = params.get("scope", "combat")

func execute(ctx: CardEffectContext) -> void:
	var count: int
	if _scope == "combat":
		count = ctx.source_player.turn_cards.size()
	else:
		count = ctx.source_player.cards_this_battle.size()
	if count == 1:
		ctx.source_player.pending_bonus_attack += _bonus
		ctx.request_empower(_bonus, 0)
