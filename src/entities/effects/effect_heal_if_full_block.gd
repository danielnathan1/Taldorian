class_name EffectHealIfFullBlock
extends CardEffect

var _amount: int = 1

func default_timing() -> int:
	return Timing.AFTER_COMBAT

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_taken == 0 and ctx.source_player.active_hero != null:
		ctx.source_player.active_hero.heal(_amount)
