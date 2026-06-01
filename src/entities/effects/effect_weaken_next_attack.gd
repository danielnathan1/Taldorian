class_name EffectWeakenNextAttack
extends CardEffect

var _amount: int = 1

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func execute(ctx: CardEffectContext) -> void:
	ctx.opponent_player.next_attack_penalty += _amount
