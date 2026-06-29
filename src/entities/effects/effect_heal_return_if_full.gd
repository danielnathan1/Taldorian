# Ciclo Vital — cura o herói ativo. Marca a carta como candidata a retornar à mão; a
# condição "terminar o combate com vida cheia" é avaliada no FIM do combate (END phase),
# com o HP final — ver GameState._run_combat_and_enter_end. Antes, checava o HP no play
# (antes do dano do combate), então retornava mesmo terminando sem vida cheia.
class_name EffectHealReturnIfFull
extends CardEffect

var _amount: int = 2

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 2)

func execute(ctx: CardEffectContext) -> void:
	var hero := ctx.source_player.active_hero
	if hero == null:
		return
	hero.heal(_amount)
	ctx.request_vfx("heal")
	ctx.source_player.pending_heal_return_card = ctx.source_card
