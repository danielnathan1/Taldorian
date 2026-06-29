class_name EffectWeakenNextAttack
extends CardEffect

var _amount: int = 1

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func execute(ctx: CardEffectContext) -> void:
	# Finta: o oponente perde _amount de ataque até o fim do turno. battle_attack_penalty
	# fica no próprio jogador debuffado (o oponente) e reduz o ataque dele em todos os
	# pontos de cálculo (combate, preview, display). Zera em clear_combat_cards (fim do turno).
	ctx.opponent_player.battle_attack_penalty += _amount
