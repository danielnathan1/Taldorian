# Veneno on-hit (Ecos) — se o herói ativo inimigo sofrer dano neste turno, fica *Envenenado*.
# Veneno reduz a defesa do alvo no combate (−1 por turno bancado). Ver Hero.apply_poison.
# param bonus_if_poisoned: turnos extras se o alvo JÁ estiver envenenado (Peçonha Persistente).
class_name EffectPoisonOnHit
extends CardEffect

var _turns: int = 2
var _bonus_if_poisoned: int = 0

func default_timing() -> int:
	return Timing.AFTER_TURN

func setup(params: Dictionary) -> void:
	_turns = params.get("turns", 2)
	_bonus_if_poisoned = params.get("bonus_if_poisoned", 0)

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_dealt <= 0:
		return
	var h := ctx.opponent_player.active_hero
	if h == null or not h.is_alive():
		return
	var t := _turns
	if _bonus_if_poisoned > 0 and h.poison_turns > 0:
		t += _bonus_if_poisoned
	h.apply_poison(t)
