# Acúmulo Estático — se não sofrer dano neste turno, adiciona 1 símbolo de Raio na chain.
class_name EffectAddLightningChargeIfNoDamage
extends CardEffect

var _amount: int = 1

func default_timing() -> int:
	return Timing.AFTER_TURN

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_taken == 0:
		for _i in _amount:
			ctx.source_player.add_chain_symbol(GameSymbols.RAIO)
