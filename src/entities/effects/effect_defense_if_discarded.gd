# Descarga Residual — se esta carta for descartada (da mão), receba +N de defesa.
# Gatilho de descarte: disparado pelo GameState via Card.execute_discard_effects().
class_name EffectDefenseIfDiscarded
extends CardEffect

var _bonus: int = 3

func setup(params: Dictionary) -> void:
	_bonus = params.get("bonus", 3)

func on_discarded(player: Player) -> void:
	player.pending_bonus_defense += _bonus
