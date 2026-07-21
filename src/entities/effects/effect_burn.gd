# Queimadura direta (Erupção) — aplica *Queimadura* no herói ativo inimigo,
# incondicionalmente (não depende de causar dano). Ver Hero.apply_burn / _tick_burn.
class_name EffectBurn
extends CardEffect

var _amount: int = 1
var _turns: int = 2

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)
	_turns  = params.get("turns", 2)

func execute(ctx: CardEffectContext) -> void:
	var h := ctx.opponent_player.active_hero
	if h == null or not h.is_alive():
		return
	h.apply_burn(_amount, _turns)
