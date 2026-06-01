class_name EffectScry
extends CardEffect

# Dois Passos à Frente — mostra a carta do topo do deck SEM sacá-la.
# O jogador decide: manter no topo (confirmar sem selecionar) ou
# mover ao fundo (selecionar a carta e confirmar).
func execute(ctx: CardEffectContext) -> void:
	var p := ctx.source_player
	if p.deck.is_empty():
		return
	GameState.begin_deck_peek(p.player_index,
		"Veja a carta do topo do baralho — mantenha no topo ou envie ao fundo")
