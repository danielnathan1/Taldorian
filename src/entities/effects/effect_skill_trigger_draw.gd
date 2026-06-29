class_name EffectSkillTriggerDraw
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	# Só marca; a compra (e o fly de draw) acontece quando a skill dispara, no GameState.
	# TODO: trocar o fly de draw por uma animação específica de "compra por skill".
	ctx.source_player.pending_skill_draw = true
