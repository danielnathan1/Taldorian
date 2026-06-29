# Campo Condutor — se você controla pelo menos 1 token, +1 de defesa.
class_name EffectDefenseIfToken
extends CardEffect

var _bonus: int = 1

func setup(params: Dictionary) -> void:
	_bonus = params.get("bonus", 1)

func execute(ctx: CardEffectContext) -> void:
	if not ctx.source_player.tokens.is_empty():
		ctx.source_player.pending_bonus_defense += _bonus
		ctx.request_empower(0, _bonus)
