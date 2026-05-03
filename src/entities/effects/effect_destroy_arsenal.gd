# src/entities/effects/effect_destroy_arsenal.gd
class_name EffectDestroyArsenal
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	ctx.source_player.pending_destroy_opponent_arsenal = true
