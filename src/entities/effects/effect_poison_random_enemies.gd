# Veneno em N inimigos aleatórios (Miasma) — envenena `count` heróis inimigos vivos
# escolhidos ao acaso. Ver Hero.apply_poison.
class_name EffectPoisonRandomEnemies
extends CardEffect

var _turns: int = 2
var _count: int = 2

func setup(params: Dictionary) -> void:
	_turns = params.get("turns", 2)
	_count = params.get("count", 2)

func execute(ctx: CardEffectContext) -> void:
	var alive: Array[Hero] = []
	for h in ctx.opponent_player.heroes:
		if h.is_alive():
			alive.append(h)
	alive.shuffle()
	for i in mini(_count, alive.size()):
		alive[i].apply_poison(_turns)
