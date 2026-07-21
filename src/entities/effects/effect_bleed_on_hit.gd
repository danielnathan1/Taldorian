# Sangramento on-hit (Ecos) — se o herói ativo inimigo sofrer dano neste turno, fica
# *Sangrando*: perde vida ao atacar/causar dano, por `turns` turnos. Ver Hero.apply_bleed.
class_name EffectBleedOnHit
extends CardEffect

var _amount: int = 1
var _turns: int = 1

func default_timing() -> int:
	return Timing.AFTER_TURN

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)
	_turns  = params.get("turns", 1)

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_dealt <= 0:
		return
	var h := ctx.opponent_player.active_hero
	if h == null or not h.is_alive():
		return
	h.apply_bleed(_amount, _turns)
