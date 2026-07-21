# Queimadura sombria direta (Chama Negra, Maldição Persistente) — aplica *Queimadura*
# sombria (não purificável) no herói ativo inimigo, sem depender de causar dano.
class_name EffectDarkBurnDirect
extends CardEffect

var _amount: int = 1
var _turns: int = 3

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)
	_turns  = params.get("turns", 3)

func execute(ctx: CardEffectContext) -> void:
	var h := ctx.opponent_player.active_hero
	if h == null or not h.is_alive():
		return
	h.apply_burn(_amount, _turns, true)
