# Carne Podre — +`per` de defesa por herói aliado DERROTADO.
class_name EffectDefensePerDeadAlly
extends CardEffect

var _per: int = 1

func setup(params: Dictionary) -> void:
	_per = params.get("per", 1)

func execute(ctx: CardEffectContext) -> void:
	var dead := 0
	for h in ctx.source_player.heroes:
		if h.state == Hero.State.DEFEATED:
			dead += 1
	if dead > 0:
		ctx.source_player.pending_bonus_defense += dead * _per
