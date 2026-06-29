# Broto Vital — cura N de vida de todos os heróis da retaguarda (aliados não-ativos vivos).
class_name EffectHealBackline
extends CardEffect

var _amount: int = 1

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func execute(ctx: CardEffectContext) -> void:
	var p := ctx.source_player
	for h in p.heroes:
		if h != p.active_hero and h.is_alive():
			h.heal(_amount)
	ctx.request_vfx("heal_all")
