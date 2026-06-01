class_name EffectHealAllyPick
extends CardEffect

# Abre o overlay de seleção de herói aliado; o jogador escolhe qual curar.
var _amount: int = 1

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func execute(ctx: CardEffectContext) -> void:
	GameState.begin_ally_pick(ctx.source_player.player_index, "heal", _amount)
