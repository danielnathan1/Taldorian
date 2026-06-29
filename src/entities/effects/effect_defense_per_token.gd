# Barreira Condutora — +1 de defesa para cada token que o jogador controla.
class_name EffectDefensePerToken
extends CardEffect

var _bonus: int = 1

func setup(params: Dictionary) -> void:
	_bonus = params.get("bonus", 1)

func execute(ctx: CardEffectContext) -> void:
	var amount := ctx.source_player.tokens.size() * _bonus
	if amount <= 0:
		return
	ctx.source_player.pending_bonus_defense += amount
	ctx.request_empower(0, amount)
