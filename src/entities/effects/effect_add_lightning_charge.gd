# Descarga Preparada — adiciona 1 símbolo de Raio (LIGHTNING) na sua chain.
class_name EffectAddLightningCharge
extends CardEffect

var _amount: int = 1

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func execute(ctx: CardEffectContext) -> void:
	for _i in _amount:
		ctx.source_player.add_chain_symbol(GameSymbols.RAIO)
