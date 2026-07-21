# Sangramento direto (Maldição Escarlate) — aplica *Sangramento* no herói ativo inimigo
# incondicionalmente. Ver Hero.apply_bleed.
class_name EffectBleedDirect
extends CardEffect

var _amount: int = 1
var _turns: int = 1

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)
	_turns  = params.get("turns", 1)

func execute(ctx: CardEffectContext) -> void:
	var h := ctx.opponent_player.active_hero
	if h == null or not h.is_alive():
		return
	h.apply_bleed(_amount, _turns)
