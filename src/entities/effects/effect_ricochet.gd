# "Ricochetear" — se o herói defensor sofreu dano, causa 1 de dano direto
# de volta ao herói ativo do atacante (mitigado por escudo).
class_name EffectRicochet
extends CardEffect

func default_timing() -> int:
	return Timing.AFTER_COMBAT

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_taken <= 0:
		return
	var foe := ctx.opponent_player.active_hero
	if foe == null:
		return
	var dmg := foe.absorb_shield(1)
	if dmg > 0:
		foe.take_damage(dmg, TurnContext.new())
		GameBus.hero_damaged.emit(foe, dmg)
	print("[TCG]   ↩ Ricochetear: %s (J%d) sofre %d de dano (HP restante: %d)" % [
		foe.hero_name, ctx.opponent_player.player_index, dmg, foe.current_hp
	])
