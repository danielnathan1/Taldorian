class_name EffectAttackIfHidden
extends CardEffect

var _bonus: int = 2

func setup(params: Dictionary) -> void:
	_bonus = params.get("bonus", 2)

func execute(ctx: CardEffectContext) -> void:
	var idx := ctx.source_player.player_index
	if not GameState.get_hero_revealed(idx):
		ctx.source_player.pending_bonus_attack += _bonus
