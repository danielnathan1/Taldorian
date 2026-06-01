class_name EffectSkillTriggerDraw
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	ctx.source_player.pending_skill_draw = true
