# Execução (Execução Sombria) — +bonus de ataque se o herói ativo inimigo estiver
# abaixo de metade da vida.
class_name EffectAttackIfTargetLowHp
extends CardEffect

var _bonus: int = 3

func setup(params: Dictionary) -> void:
	_bonus = params.get("bonus", 3)

func execute(ctx: CardEffectContext) -> void:
	var enemy := ctx.opponent_player.active_hero
	if enemy == null:
		return
	if enemy.current_hp * 2 < enemy.max_hp:
		ctx.source_player.pending_bonus_attack += _bonus
		ctx.request_empower(_bonus, 0)
