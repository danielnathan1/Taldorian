# Acúmulo Telúrico (parte 1) — trava o ataque neste combate: bônus positivos de ataque
# são ignorados pelo CombatResolver. O +5 do próximo turno é um efeito separado
# (next_turn_attack_bonus, AFTER_TURN). Resolve em AFTER_REACTION (antes do combate),
# para que a trava já esteja ativa quando o dano for calculado.
class_name EffectLockAttackThisTurn
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	ctx.source_player.pending_attack_locked = true
