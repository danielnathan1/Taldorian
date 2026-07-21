# scenes/minigames/minigame_base.gd
# Contrato REUTILIZÁVEL de minigame. Cada minigame estende isto, sobrescreve start() e, ao
# terminar, emite finished(success). Agnóstico ao gatilho (scan, baú, evento...): o
# MinigameLauncher instancia, chama start(config) e dá await em finished.
class_name Minigame
extends Control

signal finished(success: bool)

## Inicia o minigame com a configuração dada (dificuldade, etc.). Sobrescrever na subclasse.
func start(_config: Dictionary) -> void:
	pass
