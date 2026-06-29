# Solo Firme — se não sofrer dano neste turno, compre 1 carta e descarte 1.
class_name EffectDrawDiscardIfNoDamage
extends CardEffect

var _draw: int = 1
var _discard: int = 1

func default_timing() -> int:
	return Timing.AFTER_TURN

func setup(params: Dictionary) -> void:
	_draw = params.get("draw", 1)
	_discard = params.get("discard", 1)

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_taken != 0:
		return
	var p := ctx.source_player
	p.draw_cards(_draw)
	ctx.request_vfx("draw")
	if _discard <= 0 or p.hand.is_empty():
		return
	# Mão pequena: descarta tudo sem prompt (o overlay exigiria mais seleções que cartas).
	if p.hand.size() <= _discard:
		var cards := p.hand.duplicate()
		p.hand.clear()
		for c in cards:
			p.send_to_discard(c)
			ctx.request_card_move(c.art_key, "discard")
		return
	# Overlay: o jogador escolhe o que descartar (o corte dispara na resolução do pick).
	var indices: Array[int] = []
	for i in p.hand.size():
		indices.append(i)
	GameState.begin_hand_discard(p.player_index, indices, _discard, 0,
		"Descarte %d carta(s)" % _discard)
