# Ascensão Profana — +`per` de ataque por herói aliado DERROTADO.
class_name EffectAttackPerDeadAlly
extends CardEffect

var _per: int = 3

func setup(params: Dictionary) -> void:
	_per = params.get("per", 3)

func execute(ctx: CardEffectContext) -> void:
	var dead := 0
	for h in ctx.source_player.heroes:
		if h.state == Hero.State.DEFEATED:
			dead += 1
	if dead > 0:
		ctx.source_player.pending_bonus_attack += dead * _per
