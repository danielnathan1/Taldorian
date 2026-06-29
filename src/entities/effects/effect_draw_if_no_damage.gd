# Impacto Controlado — se não sofrer dano neste turno, compre 1 carta.
class_name EffectDrawIfNoDamage
extends CardEffect

var _amount: int = 1

func default_timing() -> int:
	return Timing.AFTER_TURN

func setup(params: Dictionary) -> void:
	_amount = params.get("draw", 1)

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_taken == 0:
		ctx.source_player.draw_cards(_amount)
		ctx.request_vfx("draw")
