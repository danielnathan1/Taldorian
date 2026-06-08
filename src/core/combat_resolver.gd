# src/core/combat_resolver.gd
class_name CombatResolver
extends RefCounted

## Resolve o combate de um turno completo (ambas as direções).
## Usa turn_cards para o dano e cards_this_battle para o chain.
static func resolve_turn(p0: Player, p1: Player) -> void:
	# Aplica bônus cross-turn ganho no combate anterior (ex: Guarda Inabalável confirmado)
	p0.pending_bonus_attack += p0.next_turn_bonus_attack
	p1.pending_bonus_attack += p1.next_turn_bonus_attack
	p0.next_turn_bonus_attack = 0
	p1.next_turn_bonus_attack = 0
	print("[TCG] ─── Resolução de turno ───────────────────────")
	var dmg_to_p1 := _resolve_directed_turn(p0, p1)
	var dmg_to_p0 := _resolve_directed_turn(p1, p0)
	print("[TCG] Resultado: J0→J1 %d dano | J1→J0 %d dano" % [dmg_to_p1, dmg_to_p0])
	GameBus.combat_resolved.emit(dmg_to_p0, dmg_to_p1)
	# Cura "após combate" agora é efeito AFTER_COMBAT (effect_heal_after_combat),
	# resolvido pela fila do GameState após esta função retornar.
	# Florescer Eterno — cura todos os heróis aliados vivos
	if p0.pending_heal_all_amount > 0:
		for h in p0.heroes:
			if h.is_alive():
				h.heal(p0.pending_heal_all_amount)
	if p1.pending_heal_all_amount > 0:
		for h in p1.heroes:
			if h.is_alive():
				h.heal(p1.pending_heal_all_amount)
	# Guarda Inabalável: confirma bônus cross-turn SOMENTE se o herói não tomou dano
	if p0.pending_cross_turn_if_no_damage > 0:
		if dmg_to_p0 == 0:
			p0.next_turn_bonus_attack += p0.pending_cross_turn_if_no_damage
			print("[TCG]   ★ Guarda Inabalável (J0): bloqueio total → +%d ATK na próxima rodada" % p0.pending_cross_turn_if_no_damage)
	if p1.pending_cross_turn_if_no_damage > 0:
		if dmg_to_p1 == 0:
			p1.next_turn_bonus_attack += p1.pending_cross_turn_if_no_damage
			print("[TCG]   ★ Guarda Inabalável (J1): bloqueio total → +%d ATK na próxima rodada" % p1.pending_cross_turn_if_no_damage)
	p0.reset_turn_modifiers()
	p1.reset_turn_modifiers()


## Dano de `source` → `target` usando as cartas da rodada corrente.
## source.turn_cards contribuem com attack_value; target.turn_cards com defense_value.
static func _resolve_directed_turn(source: Player, target: Player) -> int:
	var ctx := TurnContext.new()
	ctx.attacker_player = source
	ctx.defender_player = target
	ctx.attacker = source.active_hero
	ctx.defender = target.active_hero

	if ctx.attacker == null or ctx.defender == null:
		return 0

	ctx.attacker.on_before_attack(ctx)

	# Fortaleza Inabalável: bônus de defesa espelha como bônus de ataque
	if target.pending_defense_scales_attack:
		target.pending_bonus_attack += target.pending_bonus_defense

	# Ataque: base do herói + attack_value das cartas da rodada + pending de efeitos
	var raw_attack := ctx.attacker.base_attack
	for card in source.turn_cards:
		raw_attack += card.attack_value
	raw_attack += source.pending_bonus_attack
	raw_attack += source.battle_bonus_attack         # Frenesi: bônus que dura o turno inteiro
	raw_attack += source.pending_stealth_hidden_bonus  # Execução Silenciosa: oculto ao jogar
	raw_attack -= target.next_attack_penalty  # Finta rara — penaliza próxima carta adversária

	# Defesa: base do herói + defense_value das cartas da rodada + pending de efeitos
	var raw_defense := ctx.defender.base_defense
	for card in target.turn_cards:
		raw_defense += card.defense_value
	raw_defense -= target.next_defense_penalty
	raw_defense += target.pending_bonus_defense

	var raw_dmg := (raw_attack + ctx.bonus_damage) - (raw_defense + ctx.bonus_block)
	var pre_dmg := maxi(0, raw_dmg)
	# Redução de dano de heróis de suporte (ex: Muro de Aço de Valkar)
	if pre_dmg > 0:
		for h in target.heroes:
			if h != ctx.defender:
				pre_dmg = maxi(0, pre_dmg - h.get_team_damage_reduction(ctx))
	var final_dmg: int = maxi(0, ctx.defender.on_before_damage_taken(pre_dmg, ctx))
	# Escudo de dano (Fluxo Reativo) — absorve antes das verificações de dano
	final_dmg = ctx.defender.absorb_shield(final_dmg)

	# All in — se atacou e causou 0 dano, atacante leva dano e compra carta
	if final_dmg == 0 and source.pending_on_zero_damage_self_damage > 0:
		if source.active_hero != null:
			source.active_hero.take_damage(source.pending_on_zero_damage_self_damage, ctx)
		source.draw_cards(source.pending_on_zero_damage_draw)

	# Contra Ataque — se defensor bloqueou tudo, causa dano direto ao atacante
	if final_dmg == 0 and target.pending_counter_damage > 0:
		if source.active_hero != null:
			var counter_dmg := source.active_hero.absorb_shield(target.pending_counter_damage)
			if counter_dmg > 0:
				source.active_hero.take_damage(counter_dmg, ctx)

	ctx.defender.take_damage(final_dmg, ctx)
	if final_dmg > 0:
		GameBus.hero_damaged.emit(ctx.defender, final_dmg)
		target.took_damage_this_turn = true

	# Bloqueio completo (dano == 0): reações de defesa perfeita
	if final_dmg == 0:
		if target.pending_on_full_block_draw > 0:
			target.draw_cards(target.pending_on_full_block_draw)
		if target.pending_on_full_block_discard_random > 0:
			target.discard_random_from_hand(target.pending_on_full_block_discard_random)
		if target.pending_on_full_block_heal > 0 and target.active_hero != null:
			target.active_hero.heal(target.pending_on_full_block_heal)
		if target.pending_on_no_damage_heal > 0 and target.active_hero != null:
			target.active_hero.heal(target.pending_on_no_damage_heal)

	# Quebrando a Banca — se causou dano, destruir arsenal do oponente
	if final_dmg > 0 and source.pending_destroy_opponent_arsenal:
		target.arsenal.clear()

	# Ricochetear — se causou dano, causa 1 dano direto de volta ao herói do atacante
	if final_dmg > 0 and target.pending_ricochet and source.active_hero != null:
		var ricochet_dmg := source.active_hero.absorb_shield(1)
		if ricochet_dmg > 0:
			source.active_hero.take_damage(ricochet_dmg, ctx)
			GameBus.hero_damaged.emit(source.active_hero, ricochet_dmg)
		print("[TCG]   ↩ Ricochetear: %s (J%d) sofre %d de dano (HP restante: %d)" % [
			source.active_hero.hero_name, source.player_index, ricochet_dmg, source.active_hero.current_hp
		])

	# Fúria Instável — se causou dano, atacante descarta 1 carta aleatória
	if final_dmg > 0 and source.pending_discard_if_attacked:
		source.discard_random_from_hand(1)

	# Execução Silenciosa — se causou dano, marca herói para começar oculto no próximo combate
	if final_dmg > 0 and source.pending_next_turn_stealth:
		source.next_turn_stealth = true

	print("[TCG]   %s (J%d) → %s (J%d): atk=%d def=%d → %d dano (HP restante: %d)" % [
		ctx.attacker.hero_name, source.player_index,
		ctx.defender.hero_name, target.player_index,
		raw_attack, raw_defense, final_dmg, ctx.defender.current_hp
	])
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
	var dmg_to_p1_hero := _resolve_directed_turn(p0, p1)
	var dmg_to_p0_hero := _resolve_directed_turn(p1, p0)
	GameBus.combat_resolved.emit(dmg_to_p0_hero, dmg_to_p1_hero)
