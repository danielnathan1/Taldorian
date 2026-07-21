# Fluxo Interior (Nissin) — compre se jogou uma AÇÃO e uma AÇÃO BÔNUS neste turno.
class_name EffectDrawIfActionAndBonus
extends CardEffect

var _draw: int = 1

func setup(params: Dictionary) -> void:
	_draw = params.get("draw", 1)

func execute(ctx: CardEffectContext) -> void:
	var has_action := false
	var has_bonus := false
	for c in ctx.source_player.cards_this_battle:
		if c.timing == Card.TimingType.ACTION:
			has_action = true
		elif c.timing == Card.TimingType.BONUS_ACTION:
			has_bonus = true
	if has_action and has_bonus:
		ctx.source_player.draw_cards(_draw)
		ctx.request_vfx("draw")
