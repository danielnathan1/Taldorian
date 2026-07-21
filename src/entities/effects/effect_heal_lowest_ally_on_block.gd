# Elo Sanguíneo — on-block (não sofreu dano neste combate): cura `amount` no herói aliado
# vivo com menos vida. Resolve após o combate, quando o dano sofrido é conhecido.
class_name EffectHealLowestAllyOnBlock
extends CardEffect

var _amount: int = 1

func default_timing() -> int:
	return Timing.AFTER_TURN

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_taken > 0:
		return
	var lowest: Hero = null
	for h in ctx.source_player.heroes:
		if not h.is_alive():
			continue
		if lowest == null or h.current_hp < lowest.current_hp:
			lowest = h
	if lowest == null:
		return
	var idx := ctx.source_player.heroes.find(lowest)
	lowest.heal(_amount)
	ctx.request_vfx("heal", idx)
