# Impulso Ofensivo / Linha de Ferro — inicia o próximo combate com +N de ataque.
# Resolve em AFTER_TURN (depois que o combate deste turno já consumiu next_turn_bonus_attack),
# garantindo que o bônus se aplique apenas ao PRÓXIMO combate.
class_name EffectNextTurnAttackBonus
extends CardEffect

var _bonus: int = 1

func default_timing() -> int:
	return Timing.AFTER_TURN

func setup(params: Dictionary) -> void:
	_bonus = params.get("bonus", 1)

func resolve_after_combat(ctx: CardEffectContext) -> void:
	ctx.source_player.next_turn_bonus_attack += _bonus
