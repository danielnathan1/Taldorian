# src/entities/effects/effect_escalating_attack.gd
class_name EffectEscalatingAttack
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	# cards_this_battle já inclui a carta atual — size()-1 = cartas jogadas antes desta
	ctx.source_player.pending_bonus_attack += ctx.source_player.cards_this_battle.size() - 1
