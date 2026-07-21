# Ferida on-hit (Vapor Corrosivo) — se o herói ativo inimigo sofrer dano, fica *Ferido*:
# não pode ser curado por `turns` turnos. Ver Hero.apply_wound / heal.
class_name EffectWoundOnHit
extends CardEffect

var _turns: int = 1

func default_timing() -> int:
	return Timing.AFTER_TURN

func setup(params: Dictionary) -> void:
	_turns = params.get("turns", 1)

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_dealt <= 0:
		return
	var h := ctx.opponent_player.active_hero
	if h == null or not h.is_alive():
		return
	h.apply_wound(_turns)
