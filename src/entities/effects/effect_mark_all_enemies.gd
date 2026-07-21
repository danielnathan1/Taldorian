# Olhar do Abismo — *Marca* os 3 heróis inimigos vivos por `turns` turnos. Ver Hero.apply_mark.
class_name EffectMarkAllEnemies
extends CardEffect

var _bonus: int = 1
var _turns: int = 1

func setup(params: Dictionary) -> void:
	_bonus = params.get("bonus", 1)
	_turns = params.get("turns", 1)

func execute(ctx: CardEffectContext) -> void:
	for h in ctx.opponent_player.heroes:
		if h.is_alive():
			h.apply_mark(_bonus, _turns)
