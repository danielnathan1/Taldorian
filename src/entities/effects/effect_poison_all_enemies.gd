# Veneno em área (Ecos) — envenena TODOS os heróis inimigos vivos (Terra Amaldiçoada,
# parte do Desespero). Ver Hero.apply_poison.
class_name EffectPoisonAllEnemies
extends CardEffect

var _turns: int = 1

func setup(params: Dictionary) -> void:
	_turns = params.get("turns", 1)

func execute(ctx: CardEffectContext) -> void:
	for h in ctx.opponent_player.heroes:
		if h.is_alive():
			h.apply_poison(_turns)
