# Iluminação (Nissin) — se você jogou uma AÇÃO e uma AÇÃO BÔNUS neste turno, o herói ativo
# NÃO exausta ao fim do turno (fica disponível para ser escolhido de novo). A flag é consumida
# no ponto de exaustão em GameState._run_combat_and_enter_end.
class_name EffectPreventExhaust
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	var has_action := false
	var has_bonus := false
	for c in ctx.source_player.cards_this_battle:
		if c.timing == Card.TimingType.ACTION:
			has_action = true
		elif c.timing == Card.TimingType.BONUS_ACTION:
			has_bonus = true
	if has_action and has_bonus:
		ctx.source_player.pending_prevent_exhaust = true
