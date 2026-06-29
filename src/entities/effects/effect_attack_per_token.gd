# Condutor Arcano — +1 de ataque para cada token que o jogador controla.
class_name EffectAttackPerToken
extends CardEffect

var _bonus: int = 1

func setup(params: Dictionary) -> void:
	_bonus = params.get("bonus", 1)

func execute(ctx: CardEffectContext) -> void:
	ctx.source_player.pending_bonus_attack += ctx.source_player.tokens.size() * _bonus
