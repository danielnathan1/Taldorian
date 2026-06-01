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
	# ── Coleção 0: efeito direto ───────────────────────────────────────────
	"direct_damage_if_first":        preload("res://src/entities/effects/effect_direct_damage_if_first.gd"),
	# ── Coleção 0: habilidade / skill ──────────────────────────────────────
	"skill_trigger_draw":            preload("res://src/entities/effects/effect_skill_trigger_draw.gd"),
}

static func create(id: String, params: Dictionary) -> CardEffect:
	if not _MAP.has(id):
		push_error("CardEffectRegistry: efeito desconhecido — '%s'" % id)
		return null
	var effect: CardEffect = _MAP[id].new()
	effect.setup(params)
	return effect
