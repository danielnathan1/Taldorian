# Sangue Quente — se a vida atual do herói ativo for menor que o total (máx), +N de ataque.
class_name EffectAttackIfHpBelowMax
extends CardEffect

var _bonus: int = 1

func setup(params: Dictionary) -> void:
	_bonus = params.get("bonus", 1)

func execute(ctx: CardEffectContext) -> void:
	var hero := ctx.source_player.active_hero
	if hero != null and hero.current_hp < hero.max_hp:
		ctx.source_player.pending_bonus_attack += _bonus
		ctx.request_empower(_bonus, 0)
