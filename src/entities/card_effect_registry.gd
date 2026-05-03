# src/entities/card_effect_registry.gd
class_name CardEffectRegistry
extends RefCounted

const _MAP := {
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
}

static func create(id: String, params: Dictionary) -> CardEffect:
	if not _MAP.has(id):
		push_error("CardEffectRegistry: efeito desconhecido — '%s'" % id)
		return null
	var effect: CardEffect = _MAP[id].new()
	effect.setup(params)
	return effect
