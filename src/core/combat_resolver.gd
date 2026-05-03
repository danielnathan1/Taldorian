# src/core/combat_resolver.gd
class_name CombatResolver
extends RefCounted

## Resolve o combate de uma rodada completa (ambas as direções).
## Usa round_cards para o dano e cards_this_turn para o chain.
static func resolve_round(p0: Player, p1: Player) -> void:
	var dmg_to_p1 := _resolve_directed_round(p0, p1)
	var dmg_to_p0 := _resolve_directed_round(p1, p0)
	GameBus.combat_resolved.emit(dmg_to_p0, dmg_to_p1)
	p0.reset_round_modifiers()
	p1.reset_round_modifiers()


## Dano de `source` → `target` usando as cartas da rodada corrente.
## source.round_cards contribuem com attack_value; target.round_cards com defense_value.
static func _resolve_directed_round(source: Player, target: Player) -> int:
	var ctx := BattleContext.new()
	ctx.attacker_player = source
	ctx.defender_player = target
	ctx.attacker = source.active_hero
	ctx.defender = target.active_hero

	if ctx.attacker == null or ctx.defender == null:
		return 0

	ctx.attacker.on_before_attack(ctx)

	# Ataque: base do herói + attack_value das cartas da rodada + pending de efeitos
	var raw_attack := ctx.attacker.base_attack
	for card in source.round_cards:
		raw_attack += card.attack_value
	raw_attack += source.pending_bonus_attack

	# Defesa: base do herói + defense_value das cartas da rodada + pending de efeitos
	var raw_defense := ctx.defender.base_defense
	for card in target.round_cards:
		raw_defense += card.defense_value
	raw_defense -= target.next_defense_penalty
	raw_defense += target.pending_bonus_defense

	var raw_dmg := (raw_attack + ctx.bonus_damage) - (raw_defense + ctx.bonus_block)
	var final_dmg: int = maxi(0, ctx.defender.on_before_damage_taken(maxi(0, raw_dmg), ctx))

	# All in — se atacou e causou 0 dano, atacante leva dano e compra carta
	if final_dmg == 0 and source.pending_on_zero_damage_self_damage > 0:
		if source.active_hero != null:
			source.active_hero.take_damage(source.pending_on_zero_damage_self_damage, ctx)
		source.draw_cards(source.pending_on_zero_damage_draw)

	# Contra Ataque — se defensor bloqueou tudo, causa dano direto ao atacante
	if final_dmg == 0 and target.pending_counter_damage > 0:
		if source.active_hero != null:
			source.active_hero.take_damage(target.pending_counter_damage, ctx)

	ctx.defender.take_damage(final_dmg, ctx)
	if final_dmg > 0:
		GameBus.hero_damaged.emit(ctx.defender, final_dmg)

	# Quebrando a Banca — se causou dano, destruir arsenal do oponente
	if final_dmg > 0 and source.pending_destroy_opponent_arsenal:
		target.arsenal.clear()

	ctx.damage_dealt = final_dmg
	ctx.damage_taken = final_dmg

	ctx.attacker.on_after_damage_dealt(final_dmg, ctx)

	if ctx.bonus_draw > 0:
		source.draw_cards(ctx.bonus_draw)

	# Coração da Fornalha — self-damage após combate
	if source.pending_self_damage > 0 and source.active_hero != null:
		source.active_hero.take_damage(source.pending_self_damage, ctx)

	return final_dmg


## Mantido para compatibilidade — não é mais chamado no fluxo principal.
static func resolve_mutual(p0: Player, p1: Player) -> void:
	var dmg_to_p1_hero := _resolve_directed_round(p0, p1)
	var dmg_to_p0_hero := _resolve_directed_round(p1, p0)
	GameBus.combat_resolved.emit(dmg_to_p0_hero, dmg_to_p1_hero)
