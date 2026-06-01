class_name EffectStealthHiddenAtCombat
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	if ctx.hero_was_hidden:
		ctx.source_player.pending_stealth_hidden_bonus += 1
	ctx.source_player.pending_next_round_stealth = true
