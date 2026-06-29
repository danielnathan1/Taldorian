# Véu Transitório — carta com is_stealth=true (não revela ao jogar). Resolve no MOMENTO de
# jogar (pre-window), ANTES de abrir a janela de reação:
#   • do arsenal → o herói fica furtivo (set_hero_stealth);
#   • da mão     → revela o herói normalmente (como uma carta comum).
# Sem isso, a flag is_stealth deixaria o herói oculto mesmo jogando da mão.
class_name EffectStealthIfFromArsenal
extends CardEffect

func pre_window_execute(ctx: CardEffectContext) -> void:
	if ctx.played_from_arsenal:
		GameState.set_hero_stealth(ctx.source_player.player_index)
	else:
		GameState.reveal_active_hero(ctx.source_player.player_index)
