# scenes/minigames/minigame_launcher.gd
# Roda um minigame por id e devolve se o jogador VENCEU (await). Agnóstico ao gatilho.
# Uso:  var venceu := await MinigameLauncher.run(ui_layer, "memory_path", { ... })
# Registrar minigame novo = +1 linha em REGISTRY.
class_name MinigameLauncher
extends RefCounted

const REGISTRY := {
	"memory_path": "res://scenes/minigames/memory_path/memory_path.tscn",
	"mana_orb": "res://scenes/minigames/mana_orb/mana_orb.tscn",
	"arm_wrestle": "res://scenes/minigames/arm_wrestle/arm_wrestle.tscn",
	"target_shoot": "res://scenes/minigames/target_shoot/target_shoot.tscn",
}

## Instancia o minigame em p_parent, roda e aguarda o resultado. id desconhecido → true
## (não bloqueia: trata como "sem desafio"). Sempre libera a cena ao terminar.
static func run(p_parent: Node, p_id: String, p_config: Dictionary) -> bool:
	var path: String = REGISTRY.get(p_id, "")
	if path == "" or not ResourceLoader.exists(path):
		push_warning("MinigameLauncher: minigame desconhecido '%s'" % p_id)
		return true
	var mg: Node = load(path).instantiate()
	p_parent.add_child(mg)
	mg.start(p_config)
	var success: bool = await mg.finished
	mg.queue_free()
	return success
