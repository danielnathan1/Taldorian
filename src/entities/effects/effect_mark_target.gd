# Marca (status) — marca o herói ativo inimigo: +`bonus` de dano recebido por `turns` turnos.
# param direct_if_marked: dano direto se o alvo JÁ estava marcado (Alvo Amaldiçoado, checado
# ANTES de reaplicar a Marca). Ver Hero.apply_mark / incoming_mark_bonus.
class_name EffectMarkTarget
extends CardEffect

var _bonus: int = 1
var _turns: int = 2
var _direct_if_marked: int = 0

func setup(params: Dictionary) -> void:
	_bonus = params.get("bonus", 1)
	_turns = params.get("turns", 2)
	_direct_if_marked = params.get("direct_if_marked", 0)

func execute(ctx: CardEffectContext) -> void:
	var h := ctx.opponent_player.active_hero
	if h == null or not h.is_alive():
		return
	if _direct_if_marked > 0 and h.is_marked():
		var tctx := TurnContext.new()
		tctx.defender = h
		h.take_direct_damage(_direct_if_marked, tctx)
	h.apply_mark(_bonus, _turns)
