# Incinerar Tudo — descarte cartas da mão à sua escolha; para cada carta de Fogo
# descartada, +2 de ataque. Abre o overlay de descarte de quantidade VARIÁVEL (0..mão);
# o bônus por carta de Fogo é aplicado ao resolver o pick (ver rpc_submit_card_pick).
class_name EffectDiscardFireForAttack
extends CardEffect

var _bonus: int = 2

func setup(params: Dictionary) -> void:
	_bonus = params.get("bonus", 2)

func execute(ctx: CardEffectContext) -> void:
	var p := ctx.source_player
	if p.hand.is_empty():
		return
	var indices: Array[int] = []
	for i in p.hand.size():
		indices.append(i)
	GameState.begin_hand_discard_variable(p.player_index, indices, GameSymbols.FOGO, _bonus,
		"Descarte cartas da mão (opcional) — +%d de ataque por carta de Fogo descartada" % _bonus)
