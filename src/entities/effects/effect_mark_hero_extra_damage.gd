# Marca do Caçador — marca um herói inimigo; até o fim do turno, sempre que esse herói
# sofrer dano, recebe +N de dano extra.
# v1: marca automaticamente o herói ATIVO inimigo. TODO: seleção interativa de alvo
# (incluindo retaguarda) via overlay de pick de herói inimigo.
class_name EffectMarkHeroExtraDamage
extends CardEffect

var _bonus: int = 1

func setup(params: Dictionary) -> void:
	_bonus = params.get("bonus", 1)

func execute(ctx: CardEffectContext) -> void:
	var enemy := ctx.opponent_player.active_hero
	if enemy == null:
		return
	ctx.source_player.marked_target = enemy
	ctx.source_player.marked_bonus = _bonus
