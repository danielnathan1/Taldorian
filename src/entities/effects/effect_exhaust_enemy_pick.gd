# Peso da Alma — exausta um herói inimigo da RETAGUARDA à sua escolha (não o ativo). Abre o
# pick de herói (side=inimigo, filtro=retaguarda) ao jogar; fizzle se não houver alvo válido.
class_name EffectExhaustEnemyPick
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	GameState.begin_ally_pick(ctx.source_player.player_index, "exhaust", 0, 1, "backline")
