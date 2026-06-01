class_name EffectDrawDiscardIfFromArsenal
extends CardEffect

var _draw: int = 1
var _discard: int = 1

func setup(params: Dictionary) -> void:
	_draw    = params.get("draw",    1)
	_discard = params.get("discard", 1)

func execute(ctx: CardEffectContext) -> void:
	if not ctx.played_from_arsenal:
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
