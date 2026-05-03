# src/world/encounter_manager.gd
# Gerencia encontros: jogador vs herói NPC ou jogador vs jogador.
# Fase 1 — stub; implementação completa na Fase 2.
class_name EncounterManager extends RefCounted

const BOARD_SCENE := "res://scenes/ui/board/Board.tscn"

static func start_encounter_vs_npc(hero_id: String) -> void:
	push_warning("EncounterManager: encontro vs '%s' — pendente para Fase 2" % hero_id)

static func start_encounter_vs_player(opponent_peer_id: int) -> void:
	push_warning("EncounterManager: PvP vs peer %d — pendente para Fase 2" % opponent_peer_id)
