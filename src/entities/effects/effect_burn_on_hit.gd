# Queimadura on-hit (Brisa Ardente) — se o herói ativo inimigo sofrer dano neste turno,
# ele recebe Queimadura (perde vida no início dos próximos turnos). Resolve após o combate,
# quando o dano já é conhecido. A furtividade da carta (se houver) vem da flag is_stealth.
class_name EffectBurnOnHit
extends CardEffect

var _amount: int = 1
var _turns: int = 2

func default_timing() -> int:
	return Timing.AFTER_TURN

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)
	_turns  = params.get("turns", 2)

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_dealt <= 0:
		return
	var h := ctx.opponent_player.active_hero
	if h == null or not h.is_alive():
		return
	h.apply_burn(_amount, _turns)
