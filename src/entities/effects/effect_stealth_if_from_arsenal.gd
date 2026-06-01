class_name EffectStealthIfFromArsenal
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	if ctx.played_from_arsenal:
		GameState.set_hero_stealth(ctx.source_player.player_index)
