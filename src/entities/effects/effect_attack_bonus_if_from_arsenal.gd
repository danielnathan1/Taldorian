class_name EffectAttackBonusIfFromArsenal
extends CardEffect

var _bonus: int = 1

func setup(params: Dictionary) -> void:
	_bonus = params.get("bonus", 1)

func execute(ctx: CardEffectContext) -> void:
	if ctx.played_from_arsenal:
		ctx.source_player.pending_bonus_attack += _bonus
		ctx.request_empower(_bonus, 0)
