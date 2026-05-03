# src/entities/effects/effect_tutor_action.gd
# Permite ao jogador escolher qualquer carta do seu deck para colocar na mão.
class_name EffectTutorAction
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	var p := ctx.source_player
	if p.deck.is_empty():
		return

	# Monta lista com todos os índices do deck
	var indices: Array[int] = []
	for i in p.deck.size():
		indices.append(i)

	GameState.begin_card_pick(p.player_index, indices)
	# O estado de pick é sincronizado pelo GameState imediatamente após o efeito
	# (via _sync_state chamado pelo caller após execute_pending_effect).
