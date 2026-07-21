# Ferida direta (Ferida Amaldiçoada) — o herói ativo inimigo não pode ser curado por
# `turns` turnos, incondicionalmente. Ver Hero.apply_wound.
class_name EffectWoundDirect
extends CardEffect

var _turns: int = 2

func setup(params: Dictionary) -> void:
	_turns = params.get("turns", 2)

func execute(ctx: CardEffectContext) -> void:
	var h := ctx.opponent_player.active_hero
	if h == null or not h.is_alive():
		return
	h.apply_wound(_turns)
