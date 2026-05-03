# src/entities/effects/effect_surprise_strike.gd
class_name EffectSurpriseStrike
extends CardEffect

# Precisa rodar antes da janela abrir para poder cancelá-la.
func pre_window_execute(ctx: CardEffectContext) -> void:
	var is_first := ctx.source_player.cards_this_turn.size() == 1
	if is_first and ctx.played_from_arsenal:
		ctx.source_player.pending_cancel_reaction = true
