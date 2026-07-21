# Veneno direto (Ecos) — envenena o herói ativo inimigo incondicionalmente (não depende de
# causar dano). param bonus_if_poisoned: turnos extras se o alvo já estiver envenenado.
class_name EffectPoisonDirect
extends CardEffect

var _turns: int = 1
var _bonus_if_poisoned: int = 0

func setup(params: Dictionary) -> void:
	_turns = params.get("turns", 1)
	_bonus_if_poisoned = params.get("bonus_if_poisoned", 0)

func execute(ctx: CardEffectContext) -> void:
	var h := ctx.opponent_player.active_hero
	if h == null or not h.is_alive():
		return
	var t := _turns
	if _bonus_if_poisoned > 0 and h.poison_turns > 0:
		t += _bonus_if_poisoned
	h.apply_poison(t)
