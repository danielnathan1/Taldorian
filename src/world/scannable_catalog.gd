# src/world/scannable_catalog.gd
# Catálogo COMPARTILHADO dos heróis rastreáveis (config de scan: sprite, diálogos, minigame, custo).
# Fonte ÚNICA usada pelo mundo aberto (world_root, na cidade) e pela taverna do onboarding — assim o
# scan de um herói é IDÊNTICO nos dois lugares. Cada cena decide ONDE spawnar (a posição/tile é usada
# só pelo world_root; a taverna posiciona os 3 heróis manualmente na sua coreografia).
#
# Adicionar herói rastreável novo = +1 entrada aqui + o diálogo data/dialogues/<dialogue_id>.json
# + o hero_key na allowlist do backend (ClaimScannedHeroUseCase.SCANNABLE_HERO_KEYS).
class_name ScannableCatalog
extends RefCounted

const HEROES := [
	{ "creature_id": "nox", "hero_name": "Nox", "hero_art": "res://assets/heros/hero_nox.png",
	  "hero_key": "hero_nox", "dialogue_id": "scan_nox", "facing": "down", "tile": Vector2i(66, 34),
	  "minigame_id": "memory_path", "minigame_config": { "rounds": 3, "grid_size": 5, "path_length": 5, "path_increment": 4, "reveal_step": 0.5 },
	  "fail_dialogue_id": "scan_nox_fail", "already_dialogue_id": "scan_nox_already" },
	{ "creature_id": "hakai", "hero_name": "Hakai", "hero_art": "res://assets/heros/hero_hakai.png",
	  "hero_key": "hero_hakai", "dialogue_id": "scan_hakai", "facing": "down", "tile": Vector2i(58, 34),
	  "cost": 200, "fail_dialogue_id": "scan_hakai_fail", "already_dialogue_id": "scan_hakai_already" },
	{ "creature_id": "irena", "hero_name": "Irena", "hero_art": "res://assets/heros/hero_irena.png",
	  "hero_key": "hero_irena", "dialogue_id": "scan_irena", "facing": "down", "tile": Vector2i(62, 30),
	  "minigame_id": "mana_orb", "minigame_config": { "orb_speed": 130, "dir_change": 1.4, "dash_chance": 0.0, "zone_radius": 26, "fill_rate": 0.22, "drain_rate": 0.18, "start_progress": 0.4 },
	  "fail_dialogue_id": "scan_irena_fail", "already_dialogue_id": "scan_irena_already" },
	{ "creature_id": "poppy", "hero_name": "Poppy", "hero_art": "res://assets/heros/hero_poppy.png",
	  "hero_key": "hero_poppy", "dialogue_id": "scan_poppy", "facing": "down", "tile": Vector2i(62, 34),
	  "minigame_id": "arm_wrestle", "minigame_config": { "opponent_power": 0.6, "click_power": 0.14, "power_decay": 0.5, "max_power": 1.0, "start_pos": 0.5 },
	  "win_dialogue_id": "scan_poppy_win", "fail_dialogue_id": "scan_poppy_fail", "always_grant": true,
	  "already_dialogue_id": "scan_poppy_already" },
	{ "creature_id": "ieldor", "hero_name": "Ieldor", "hero_art": "res://assets/heros/hero_ieldor.png",
	  "hero_key": "hero_ieldor", "dialogue_id": "scan_ieldor", "facing": "down", "tile": Vector2i(58, 30),
	  "minigame_id": "target_shoot", "minigame_config": { "targets_per_round": [7, 8, 10], "hits_needed": [3, 5, 7], "target_lifetime": 1.0, "lifetime_decrease": 0.15, "target_radius": 28.0 },
	  "fail_dialogue_id": "scan_ieldor_fail", "already_dialogue_id": "scan_ieldor_already" },
]

## Retorna a config (dict) de um herói por hero_key, ou {} se não existir.
static func get_by_key(p_hero_key: String) -> Dictionary:
	for cfg in HEROES:
		if cfg.get("hero_key", "") == p_hero_key:
			return cfg
	return {}
