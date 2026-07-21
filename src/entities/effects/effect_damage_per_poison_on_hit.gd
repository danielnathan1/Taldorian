# Caldeirão Fétido — on-hit: o alvo sofre 1 de dano por turno de *Veneno* acumulado nele
# (dano direto = poison_turns). Resolve após o combate, quando o dano já é conhecido.
class_name EffectDamagePerPoisonOnHit
extends CardEffect

func default_timing() -> int:
	return Timing.AFTER_TURN

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_dealt <= 0:
		return
	var h := ctx.opponent_player.active_hero
	if h == null or not h.is_alive():
		return
	var dmg := h.poison_turns
	if dmg <= 0:
		return
	var tctx := TurnContext.new()
	tctx.defender = h
	h.take_direct_damage(dmg, tctx)
