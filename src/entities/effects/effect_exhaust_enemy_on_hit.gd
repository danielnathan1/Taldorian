# Exaurir — on-hit: escolha um herói inimigo da RETAGUARDA (não o ativo) para ficar exausto,
# negando a rotação dele. Abre o pick de herói (side=inimigo, filtro=retaguarda) durante o
# dreno pós-combate; fizzle se o oponente não tiver herói de retaguarda válido.
class_name EffectExhaustEnemyOnHit
extends CardEffect

func default_timing() -> int:
	return Timing.AFTER_TURN

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_dealt <= 0:
		return
	GameState.begin_ally_pick(ctx.source_player.player_index, "exhaust", 0, 1, "backline")
