class_name EffectPersistAttackIfNoDamage
extends CardEffect

var _bonus: int = 1

func setup(params: Dictionary) -> void:
	_bonus = params.get("bonus", 1)

func execute(ctx: CardEffectContext) -> void:
	# O bônus só é confirmado se o herói não tomar dano neste combate.
	# resolve_turn() converte pending_cross_turn_if_no_damage → next_turn_bonus_attack
	# após verificar o resultado do combate.
	ctx.source_player.pending_cross_turn_if_no_damage += _bonus
