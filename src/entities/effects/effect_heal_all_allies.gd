# "Florescer Eterno" — após o combate, cura todos os heróis aliados vivos.
class_name EffectHealAllAllies
extends CardEffect

var _amount: int = 1

func default_timing() -> int:
	return Timing.AFTER_COMBAT

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func resolve_after_combat(ctx: CardEffectContext) -> void:
	for h in ctx.source_player.heroes:
		if h.is_alive():
			h.heal(_amount)
