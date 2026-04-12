# src/core/combat_resolver.gd
class_name CombatResolver
extends RefCounted

## Troca mútua: cada jogador contribui com ataques e defesas; resolve P0→P1 e P1→P0.
static func resolve_mutual(p0: Player, p1: Player) -> void:
	var dmg_to_p1_hero := _resolve_directed(p0, p1)
	var dmg_to_p0_hero := _resolve_directed(p1, p0)
	GameBus.combat_resolved.emit(dmg_to_p0_hero, dmg_to_p1_hero)


## Dano que `source` tenta causar ao herói ativo de `target` (ataques do source vs defesas do target).
static func _resolve_directed(source: Player, target: Player) -> int:
	var ctx := BattleContext.new()
	ctx.attacker_player = source
	ctx.defender_player = target
	ctx.attacker = source.active_hero
	ctx.defender = target.active_hero

	var chain: Array[String] = []
	for card in source.attacks_this_turn:
		for sym in card.get_symbol_ids():
			chain.append(sym)
	ctx.chain = chain

	if ctx.attacker == null or ctx.defender == null:
		return 0

	if SymbolChain.matches_chain(chain, ctx.attacker.symbols_required):
		ctx.attacker.on_skill_activated(ctx)

	var raw_attack := 0
	for card in source.attacks_this_turn:
		raw_attack += card.value
	var raw_defense := 0
	for card in target.defenses_this_turn:
		raw_defense += card.value
	var raw_dmg := (raw_attack + ctx.bonus_damage) - (raw_defense + ctx.bonus_block)

	var final_dmg: int = maxi(0, ctx.defender.on_before_damage_taken(maxi(0, raw_dmg), ctx))

	ctx.defender.take_damage(final_dmg, ctx)
	if final_dmg > 0:
		GameBus.hero_damaged.emit(ctx.defender, final_dmg)

	ctx.damage_dealt = final_dmg
	ctx.damage_taken = final_dmg

	if ctx.bonus_draw > 0:
		source.draw_cards(ctx.bonus_draw)

	return final_dmg
