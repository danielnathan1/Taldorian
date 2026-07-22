# Profanar Túmulo — bane a primeira carta de AÇÃO do cemitério do oponente (exílio) e ganha
# `attack` de ataque. Fizzle (sem bônus) se o oponente não tiver ação no cemitério.
class_name EffectBanishOpponentGraveyardAction
extends CardEffect

var _attack: int = 1

func setup(params: Dictionary) -> void:
	_attack = params.get("attack", 1)

func execute(ctx: CardEffectContext) -> void:
	var opp := ctx.opponent_player
	for c in opp.discard_pile:
		if c.timing == Card.TimingType.ACTION:
			opp.discard_pile.erase(c)
			opp.send_to_banish(c)
			ctx.source_player.pending_bonus_attack += _attack
			return
