class_name EffectDrawDiscardIfFullBlock
extends CardEffect

var _draw: int = 1
var _discard: int = 1

func setup(params: Dictionary) -> void:
	_draw    = params.get("draw",    1)
	_discard = params.get("discard", 1)

func execute(ctx: CardEffectContext) -> void:
	ctx.source_player.pending_on_full_block_draw           += _draw
	ctx.source_player.pending_on_full_block_discard_random += _discard
