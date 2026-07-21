# Ferida em área (Desespero) — todos os heróis inimigos vivos ficam *Feridos* (não podem
# ser curados) por `turns` turnos. Ver Hero.apply_wound.
class_name EffectWoundAllEnemies
extends CardEffect

var _turns: int = 2

func setup(params: Dictionary) -> void:
	_turns = params.get("turns", 2)

func execute(ctx: CardEffectContext) -> void:
	for h in ctx.opponent_player.heroes:
		if h.is_alive():
			h.apply_wound(_turns)
