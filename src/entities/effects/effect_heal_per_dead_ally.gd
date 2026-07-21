# Comunhão Vampírica — o herói ativo cura `amount` por herói aliado DERROTADO. Imediato.
class_name EffectHealPerDeadAlly
extends CardEffect

var _amount: int = 1

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func execute(ctx: CardEffectContext) -> void:
	var dead := 0
	for h in ctx.source_player.heroes:
		if h.state == Hero.State.DEFEATED:
			dead += 1
	if dead <= 0:
		return
	var hero := ctx.source_player.active_hero
	if hero == null:
		return
	hero.heal(dead * _amount)
	ctx.request_vfx("heal")
