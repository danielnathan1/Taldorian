# Baluarte Eterno (Valkar) — concede *Escudo* persistente (`amount` por `turns` turnos) a
# TODOS os heróis aliados vivos. Ver Hero.grant_persistent_shield / GameState._tick_persistent_shields.
class_name EffectTeamPersistentShield
extends CardEffect

var _amount: int = 1
var _turns: int = 1

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)
	_turns  = params.get("turns", 1)

func execute(ctx: CardEffectContext) -> void:
	for h in ctx.source_player.heroes:
		if h.is_alive():
			h.grant_persistent_shield(_amount, _turns)
	ctx.request_vfx("team_shield")
