# Queimadura sombria on-hit (Névoa Corrosiva) — se o herói ativo inimigo sofrer dano,
# recebe *Queimadura* sombria (não purificável). Ver Hero.apply_burn(dark = true).
class_name EffectDarkBurnOnHit
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
	h.apply_burn(_amount, _turns, true)
