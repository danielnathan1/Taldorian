# Execução Silenciosa — se seu herói causar dano neste turno, o oponente descarta cartas.
# O OPONENTE escolhe quais cartas descartar, via modal (begin_hand_discard). Como resolve
# após o combate (AFTER_TURN), o pick pausa o pós-combate até a escolha — ver
# GameState._resolve_turn_combat / _continue_post_combat.
# A furtividade ("fica furtivo") é dada pela flag is_stealth=true da própria carta.
class_name EffectOpponentDiscardsOnHit
extends CardEffect

var _amount: int = 1

func default_timing() -> int:
	return Timing.AFTER_TURN

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_dealt <= 0:
		return
	var opp := ctx.opponent_player
	if opp.hand.is_empty():
		return
	var count: int = mini(_amount, opp.hand.size())
	var indices: Array[int] = []
	for i in opp.hand.size():
		indices.append(i)
	GameState.begin_hand_discard(opp.player_index, indices, count, 0,
		"Execução Silenciosa: descarte %d carta(s)" % count)
