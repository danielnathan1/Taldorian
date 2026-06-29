# Sintonia Estática — olhe a carta do topo do deck; se tiver o símbolo indicado, compre-a;
# senão, mande-a ao cemitério. Resolve automaticamente (sem input do jogador).
class_name EffectPeekDrawIfSymbol
extends CardEffect

var _symbol: String = GameSymbols.RAIO

func setup(params: Dictionary) -> void:
	_symbol = params.get("symbol", GameSymbols.RAIO)

func execute(ctx: CardEffectContext) -> void:
	var p := ctx.source_player
	if p.deck.is_empty():
		return
	var top: Card = p.deck.pop_front()
	if _symbol in top.symbols:
		p.hand.append(top)
		GameBus.card_drawn.emit(p.player_index)
	else:
		p.send_to_discard(top)
