# src/entities/effects/effect_recycle_graveyard.gd
# O jogador escolhe uma carta do cemitério:
#   → a carta escolhida vai ao fundo do deck
#   → o jogador compra a carta do topo do deck
class_name EffectRecycleGraveyard
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	var p := ctx.source_player
	if p.discard_pile.is_empty():
		# Cemitério vazio — compra diretamente se houver deck
		p.draw_cards(1)
		return

	# Monta lista com todos os índices do cemitério
	var indices: Array[int] = []
	for i in p.discard_pile.size():
		indices.append(i)

	GameState.begin_graveyard_pick(p.player_index, indices)
