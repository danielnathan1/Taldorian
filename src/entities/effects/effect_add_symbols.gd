# src/entities/effects/effect_add_symbols.gd
class_name EffectAddSymbols
extends CardEffect

var _symbols_to_add: Array = []

func setup(params: Dictionary) -> void:
	_symbols_to_add = params.get("symbols_to_add", [])

func execute(ctx: CardEffectContext) -> void:
	for sym in _symbols_to_add:
		var sid := str(sym)
		if GameSymbols.ALL.has(sid):
			ctx.source_card.symbols.append(sid)
