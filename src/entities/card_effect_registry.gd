# src/entities/card_effect_registry.gd
class_name CardEffectRegistry
extends RefCounted

const _MAP := {
	# ── Efeitos originais ──────────────────────────────────────────────────
	"draw_discard":                  preload("res://src/entities/effects/effect_draw_discard.gd"),
	"draw_then_put_bottom":          preload("res://src/entities/effects/effect_draw_then_put_bottom.gd"),
	"escalating_attack":             preload("res://src/entities/effects/effect_escalating_attack.gd"),
	"fogo_chain_attack":             preload("res://src/entities/effects/effect_fogo_chain_attack.gd"),
	"all_in":                        preload("res://src/entities/effects/effect_all_in.gd"),
	"counter_attack_on_full_block":  preload("res://src/entities/effects/effect_counter_attack.gd"),
	"destroy_arsenal_on_damage":     preload("res://src/entities/effects/effect_destroy_arsenal.gd"),
	"weaken_next_defense":           preload("res://src/entities/effects/effect_weaken_defense.gd"),
	"tutor_action":                  preload("res://src/entities/effects/effect_tutor_action.gd"),
	"bonus_defense_from_arsenal":    preload("res://src/entities/effects/effect_bonus_arsenal.gd"),
	"surprise_strike":               preload("res://src/entities/effects/effect_surprise_strike.gd"),
	"add_symbols":                   preload("res://src/entities/effects/effect_add_symbols.gd"),
	"pick_symbols":                  preload("res://src/entities/effects/effect_pick_symbols.gd"),
	"recycle_graveyard_draw":        preload("res://src/entities/effects/effect_recycle_graveyard.gd"),
	"redraw_both_hands":             preload("res://src/entities/effects/effect_redraw_both_hands.gd"),
	# ── Coleção 0: cura ────────────────────────────────────────────────────
	"heal":                          preload("res://src/entities/effects/effect_heal.gd"),
	"heal_ally_pick":                preload("res://src/entities/effects/effect_heal_ally_pick.gd"),
	"heal_after_combat":             preload("res://src/entities/effects/effect_heal_after_combat.gd"),
	"heal_if_full_block":            preload("res://src/entities/effects/effect_heal_if_full_block.gd"),
	"heal_if_no_damage":             preload("res://src/entities/effects/effect_heal_if_no_damage.gd"),
	"heal_if_behind":                preload("res://src/entities/effects/effect_heal_if_behind.gd"),
	"heal_all_allies":               preload("res://src/entities/effects/effect_heal_all_allies.gd"),
	"heal_return_if_full":           preload("res://src/entities/effects/effect_heal_return_if_full.gd"),
	# ── Coleção 0: compra / descarte ───────────────────────────────────────
	"draw_one":                      preload("res://src/entities/effects/effect_draw_one.gd"),
	"draw_if_full_block":            preload("res://src/entities/effects/effect_draw_if_full_block.gd"),
	"draw_if_nth_card":              preload("res://src/entities/effects/effect_draw_if_nth_card.gd"),
	"draw_discard_if_from_arsenal":  preload("res://src/entities/effects/effect_draw_discard_if_from_arsenal.gd"),
	"draw_discard_if_card_type_played": preload("res://src/entities/effects/effect_draw_discard_if_card_type_played.gd"),
	"draw_discard_if_full_block":    preload("res://src/entities/effects/effect_draw_discard_if_full_block.gd"),
	"discard_for_attack":            preload("res://src/entities/effects/effect_discard_for_attack.gd"),
	"discard_if_dealt_damage":       preload("res://src/entities/effects/effect_discard_if_dealt_damage.gd"),
	# ── Coleção 0: bônus de ataque ─────────────────────────────────────────
	"attack_if_symbol_played":       preload("res://src/entities/effects/effect_attack_if_symbol_played.gd"),
	"attack_if_first_card":          preload("res://src/entities/effects/effect_attack_if_first_card.gd"),
	"attack_if_nth_card":            preload("res://src/entities/effects/effect_attack_if_nth_card.gd"),
	"attack_if_hidden":              preload("res://src/entities/effects/effect_attack_if_hidden.gd"),
	"attack_if_damaged_this_round":  preload("res://src/entities/effects/effect_attack_if_damaged_this_round.gd"),
	"attack_if_defense_low":         preload("res://src/entities/effects/effect_attack_if_defense_low.gd"),
	"attack_bonus_if_from_arsenal":  preload("res://src/entities/effects/effect_attack_bonus_if_from_arsenal.gd"),
	"next_card_attack_bonus":        preload("res://src/entities/effects/effect_next_card_attack_bonus.gd"),
	"next_card_both_bonus":          preload("res://src/entities/effects/effect_next_card_both_bonus.gd"),
	"fogo_symbol_count_attack":      preload("res://src/entities/effects/effect_fogo_symbol_count_attack.gd"),
	# ── Coleção 0: bônus de defesa ─────────────────────────────────────────
	"defense_if_first_card":         preload("res://src/entities/effects/effect_defense_if_first_card.gd"),
	"defense_if_behind":             preload("res://src/entities/effects/effect_defense_if_behind.gd"),
	"bonus_if_card_type_played":     preload("res://src/entities/effects/effect_bonus_if_card_type_played.gd"),
	"damage_shield":                 preload("res://src/entities/effects/effect_damage_shield.gd"),
	"defense_scales_attack":         preload("res://src/entities/effects/effect_defense_scales_attack.gd"),
	# ── Coleção 0: penalidade ao oponente ──────────────────────────────────
	"weaken_next_attack":            preload("res://src/entities/effects/effect_weaken_next_attack.gd"),
	# ── Coleção 0: arsenal / baralho ───────────────────────────────────────
	"store_in_arsenal":              preload("res://src/entities/effects/effect_store_in_arsenal.gd"),
	"put_bottom_then_draw":          preload("res://src/entities/effects/effect_put_bottom_then_draw.gd"),
	"recycle_graveyard_no_draw":     preload("res://src/entities/effects/effect_recycle_graveyard_no_draw.gd"),
	"optional_put_self_to_bottom":   preload("res://src/entities/effects/effect_optional_put_self_to_bottom.gd"),
	"scry":                          preload("res://src/entities/effects/effect_scry.gd"),
	"both_recycle_arsenal":          preload("res://src/entities/effects/effect_both_recycle_arsenal.gd"),
	# ── Coleção 0: bônus cross-round ───────────────────────────────────────
	"persist_attack_if_no_damage":   preload("res://src/entities/effects/effect_persist_attack_if_no_damage.gd"),
	"ricochet":                      preload("res://src/entities/effects/effect_ricochet.gd"),
	# ── Coleção 0: stealth / furtivo ───────────────────────────────────────
	"stealth_if_from_arsenal":       preload("res://src/entities/effects/effect_stealth_if_from_arsenal.gd"),
	"stealth_hidden_at_combat":      preload("res://src/entities/effects/effect_stealth_hidden_at_combat.gd"),
	"stealth_next_turn_on_damage":   preload("res://src/entities/effects/effect_stealth_next_turn_on_damage.gd"),
	# ── Coleção 0: efeito direto ───────────────────────────────────────────
	"direct_damage_if_first":        preload("res://src/entities/effects/effect_direct_damage_if_first.gd"),
	# ── Coleção 0: habilidade / skill ──────────────────────────────────────
	"skill_trigger_draw":            preload("res://src/entities/effects/effect_skill_trigger_draw.gd"),
	# ── Timing AFTER_TURN (resolvem após o combate, com resultado de dano) ─
	"on_hit_draw":                   preload("res://src/entities/effects/effect_on_hit_draw.gd"),
	# ── Coleção 0 (revisão): condicionais "sem dano" ───────────────────────
	"draw_if_no_damage":             preload("res://src/entities/effects/effect_draw_if_no_damage.gd"),
	"draw_discard_if_no_damage":     preload("res://src/entities/effects/effect_draw_discard_if_no_damage.gd"),
	# ── Coleção 0 (revisão): ataque / próximo turno ────────────────────────
	"next_turn_attack_bonus":        preload("res://src/entities/effects/effect_next_turn_attack_bonus.gd"),
	"double_attack":                 preload("res://src/entities/effects/effect_double_attack.gd"),
	"defense_to_attack":             preload("res://src/entities/effects/effect_defense_to_attack.gd"),
	"attack_if_hp_below_max":        preload("res://src/entities/effects/effect_attack_if_hp_below_max.gd"),
	"lock_attack_this_turn":         preload("res://src/entities/effects/effect_lock_attack_next_turn_bonus.gd"),
	# ── Coleção 0 (revisão): cura / escudo em área ─────────────────────────
	"heal_backline":                 preload("res://src/entities/effects/effect_heal_backline.gd"),
	"team_damage_shield":            preload("res://src/entities/effects/effect_team_damage_shield.gd"),
	"heal_all_allies_reflect":       preload("res://src/entities/effects/effect_heal_all_allies_reflect.gd"),
	# ── Coleção 0 (revisão): furtivo / descarte / marca ────────────────────
	"opponent_discards_on_hit":      preload("res://src/entities/effects/effect_opponent_discards_on_hit.gd"),
	"both_discard_random":           preload("res://src/entities/effects/effect_both_discard_random.gd"),
	"mark_hero_extra_damage":        preload("res://src/entities/effects/effect_mark_hero_extra_damage.gd"),
	"defense_if_discarded":          preload("res://src/entities/effects/effect_defense_if_discarded.gd"),
	"mark_discard_on_damage_next_combat": preload("res://src/entities/effects/effect_mark_discard_on_damage_next_combat.gd"),
	"no_reactions_this_turn":        preload("res://src/entities/effects/effect_no_reactions_this_turn.gd"),
	"discard_fire_for_attack":       preload("res://src/entities/effects/effect_discard_fire_for_attack.gd"),
	"peek_draw_if_symbol":           preload("res://src/entities/effects/effect_peek_draw_if_symbol.gd"),
	# ── Raio / Lightning (tokens, carga de raio, ações extras) ─────────────
	"attack_per_token":              preload("res://src/entities/effects/effect_attack_per_token.gd"),
	"defense_per_token":             preload("res://src/entities/effects/effect_defense_per_token.gd"),
	"defense_if_token":              preload("res://src/entities/effects/effect_defense_if_token.gd"),
	"attack_if_below_enemy":         preload("res://src/entities/effects/effect_attack_if_below_enemy.gd"),
	"attack_per_lightning_charge":   preload("res://src/entities/effects/effect_attack_per_lightning_charge.gd"),
	"add_lightning_charge":          preload("res://src/entities/effects/effect_add_lightning_charge.gd"),
	"add_lightning_charge_if_no_damage": preload("res://src/entities/effects/effect_add_lightning_charge_if_no_damage.gd"),
	"create_missiles":               preload("res://src/entities/effects/effect_create_missiles.gd"),
	"consume_tokens_for_bonus":      preload("res://src/entities/effects/effect_consume_tokens_for_bonus.gd"),
	"extra_action":                  preload("res://src/entities/effects/effect_extra_action.gd"),
	"extra_action_if_from_arsenal":  preload("res://src/entities/effects/effect_extra_action_if_from_arsenal.gd"),
}

static func create(id: String, params: Dictionary) -> CardEffect:
	if not _MAP.has(id):
		push_error("CardEffectRegistry: efeito desconhecido — '%s'" % id)
		return null
	var effect: CardEffect = _MAP[id].new()
	# Guarda o spec de origem (id + params) para permitir reserializar a carta com seus
	# efeitos no snapshot de rede — ver GameState._serialize_cards.
	var spec := params.duplicate(true)
	spec["id"] = id
	effect.spec = spec
	# Timing: começa do padrão do efeito; carta pode sobrescrever via "timing" no JSON.
	effect.timing = effect.default_timing()
	if params.has("timing"):
		effect.timing = _parse_timing(params["timing"])
	effect.setup(params)
	return effect

static func _parse_timing(value) -> int:
	match str(value).to_lower():
		"instant":
			return CardEffect.Timing.INSTANT
		"after_reaction", "afterreaction":
			return CardEffect.Timing.AFTER_REACTION
		"after_combat", "aftercombat", "after_turn", "afterturn":
			return CardEffect.Timing.AFTER_TURN
	push_error("CardEffectRegistry: timing desconhecido — '%s' (usando AFTER_REACTION)" % value)
	return CardEffect.Timing.AFTER_REACTION
