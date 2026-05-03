# src/entities/effects/effect_redraw_both_hands.gd
class_name EffectRedrawBothHands
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	_log_hand("Antes", ctx.source_player, ctx.opponent_player)
	_redraw(ctx.source_player)
	_redraw(ctx.opponent_player)
	_log_hand("Depois", ctx.source_player, ctx.opponent_player)

func _log_hand(label: String, src: Player, opp: Player) -> void:
	var src_names := src.hand.map(func(c): return c.card_name)
	var opp_names := opp.hand.map(func(c): return c.card_name)
	print("[Redraw %s] P%d deck:%d mão:%s" % [label, src.player_index, src.deck.size(), str(src_names)])
	print("[Redraw %s] P%d deck:%d mão:%s" % [label, opp.player_index, opp.deck.size(), str(opp_names)])

func _redraw(p: Player) -> void:
	var amount := p.hand.size()
	if amount == 0:
		return
	var cards := p.hand.duplicate()
	p.hand.clear()
	for card in cards:
		p.deck.append(card)
	p.draw_cards(amount)
