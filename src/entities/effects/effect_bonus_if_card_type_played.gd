class_name EffectBonusIfCardTypePlayed
extends CardEffect

var _timing_type: Card.TimingType = Card.TimingType.BONUS_ACTION
var _scope: String = "turn"  # "turn" (cards_this_battle) ou "combat" (turn_cards)
var _attack_bonus: int = 0
var _defense_bonus: int = 0

func setup(params: Dictionary) -> void:
	var t: String = params.get("timing_type", "BONUS_ACTION")
	_timing_type   = Card.TimingType[t] if Card.TimingType.keys().has(t) else Card.TimingType.BONUS_ACTION
	_scope         = params.get("scope", "turn")
	_attack_bonus  = params.get("attack_bonus",  0)
	_defense_bonus = params.get("defense_bonus", 0)

func execute(ctx: CardEffectContext) -> void:
	var pool: Array[Card] = ctx.source_player.cards_this_battle if _scope == "turn" \
		else ctx.source_player.turn_cards
	for card in pool:
		if card == ctx.source_card:
			continue
		if card.timing == _timing_type:
			ctx.source_player.pending_bonus_attack  += _attack_bonus
			ctx.source_player.pending_bonus_defense += _defense_bonus
			ctx.request_empower(_attack_bonus, _defense_bonus)
			return
