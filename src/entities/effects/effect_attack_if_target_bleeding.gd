# Mordida Profana — +`bonus` de ataque se o herói ativo inimigo estiver *Sangrando*.
class_name EffectAttackIfTargetBleeding
extends CardEffect

var _bonus: int = 2

func setup(params: Dictionary) -> void:
	_bonus = params.get("bonus", 2)

func execute(ctx: CardEffectContext) -> void:
	var h := ctx.opponent_player.active_hero
	if h != null and h.bleed_turns > 0:
		ctx.source_player.pending_bonus_attack += _bonus
