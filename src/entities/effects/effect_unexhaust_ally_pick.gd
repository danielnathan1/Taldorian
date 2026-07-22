# Reanimar / Despertar Sombrio — escolha um herói SEU que esteja exausto para voltar ao
# estado ativo (disponível para a rotação). Abre o pick (side=próprio, filtro=exausto);
# fizzle se você não tiver herói exausto.
class_name EffectUnexhaustAllyPick
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	GameState.begin_ally_pick(ctx.source_player.player_index, "unexhaust", 0, 0, "exhausted")
