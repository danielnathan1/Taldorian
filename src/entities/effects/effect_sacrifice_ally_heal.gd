# Banquete de Sombras — sacrifique `amount` de HP de um aliado da RETAGUARDA à sua escolha;
# o herói ativo cura `amount`. Abre o pick (side=próprio, filtro=retaguarda); fizzle se você
# não tiver aliado de retaguarda vivo.
class_name EffectSacrificeAllyHeal
extends CardEffect

var _amount: int = 3

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 3)

func execute(ctx: CardEffectContext) -> void:
	GameState.begin_ally_pick(ctx.source_player.player_index, "sacrifice_heal", _amount, 0, "backline")
