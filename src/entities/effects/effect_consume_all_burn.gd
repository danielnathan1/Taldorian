# Pira Profana — consome a *Queimadura* de TODOS os heróis inimigos: cada um sofre de uma
# vez o total de dano de queimadura acumulado (burn_amount), e a queimadura é removida.
class_name EffectConsumeAllBurn
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	for h in ctx.opponent_player.heroes:
		if not h.is_alive():
			continue
		if h.burn_turns <= 0 or h.burn_amount <= 0:
			continue
		var dmg := h.burn_amount
		h.burn_amount = 0
		h.burn_turns = 0
		h.burn_is_dark = false
		var tctx := TurnContext.new()
		tctx.defender = h
		h.take_direct_damage(dmg, tctx)
