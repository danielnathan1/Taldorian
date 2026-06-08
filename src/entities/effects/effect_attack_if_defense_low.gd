class_name EffectAttackIfDefenseLow
extends CardEffect

var _bonus: int = 1

func setup(params: Dictionary) -> void:
	_bonus = params.get("bonus", 1)

func execute(ctx: CardEffectContext) -> void:
	var p := ctx.source_player
	var net_defense := p.pending_bonus_defense
	for card in p.turn_cards:
		net_defense += card.defense_value
	if net_defense <= 0:
		p.battle_bonus_attack += _bonus
