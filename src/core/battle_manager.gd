# src/core/battle_manager.gd
class_name BattleManager
extends RefCounted

enum Phase {
	OPENING_MULLIGAN,
	DRAW,
	HERO_SELECTION,
	BACKLINE_ABILITY,   # fase entre hero selection e action: habilidades de retaguarda interativas
	ACTION,
	COMBAT,
	END,
}

var current_phase: Phase = Phase.OPENING_MULLIGAN
var current_player_index: int = 0
var players: Array[Player] = []

func phase_to_string(p: Phase) -> String:
	match p:
		Phase.OPENING_MULLIGAN:
			return "OPENING_MULLIGAN"
		Phase.DRAW:
			return "DRAW"
		Phase.HERO_SELECTION:
			return "HERO_SELECTION"
		Phase.BACKLINE_ABILITY:
			return "BACKLINE_ABILITY"
		Phase.ACTION:
			return "ACTION"
		Phase.COMBAT:
			return "COMBAT"
		Phase.END:
			return "END"
		_:
			return "UNKNOWN"

func emit_phase_changed() -> void:
	GameBus.phase_changed.emit(phase_to_string(current_phase))
