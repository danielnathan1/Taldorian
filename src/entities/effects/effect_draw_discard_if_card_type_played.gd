class_name EffectDrawDiscardIfCardTypePlayed
extends CardEffect

var _timing_type: Card.TimingType = Card.TimingType.ACTION
var _scope: String = "combat"
var _draw: int = 1
var _discard: int = 1

func setup(params: Dictionary) -> void:
	var t: String = params.get("timing_type", "ACTION")
	_timing_type = Card.TimingType[t] if Card.TimingType.keys().has(t) else Card.TimingType.ACTION
	_scope   = params.get("scope",   "combat")
	_draw    = params.get("draw",    1)
	_discard = params.get("discard", 1)

func execute(ctx: CardEffectContext) -> void:
	var pool: Array[Card] = ctx.source_player.round_cards if _scope == "combat" \
		else ctx.source_player.cards_this_turn
	var found := false
	for card in pool:
		if card == ctx.source_card:
			continue
		if card.timing == _timing_type:
			found = true
			break
	if not found:
		return
	var p := ctx.source_player
	p.draw_cards(_draw)
	if p.hand.is_empty():
		return
	var indices: Array[int] = []
	for i in p.hand.size():
		indices.append(i)
	GameState.begin_hand_discard(p.player_index, indices, _discard, 0,
		"Descarte %d carta(s) para comprar %d nova(s)" % [_discard, _draw])
