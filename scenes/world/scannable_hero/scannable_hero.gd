class_name ScannableHero
extends Node2D
# NPC rastreável que CONCEDE UM HERÓI ao ser escaneado. Reutilizável para todo herói novo:
#   - solta uma instância no mundo com a config abaixo (creature_id, hero_*, dialogue_id);
#   - cria o diálogo data/dialogues/<dialogue_id>.json;
#   - adiciona o hero_key à allowlist do backend (ClaimScannedHeroUseCase.SCANNABLE_HERO_KEYS).
# Ao rastrear, o world_root dispara o diálogo e, no fim, concede a carta DIRETO
# (ApiClient.claim_scanned_hero(hero_key)) — sem quest. Fica no grupo "scannable".
#
# O sprite vem de um Npc (folha LPC em scenes/world/assets/npc/<creature_id>/).

@export var creature_id: String = ""   # pasta do sprite NPC (ex.: "nox")
@export var hero_name: String = ""      # nome exibido no popup (ex.: "Nox")
@export var hero_art: String = ""       # arte da carta (res://, ex.: res://assets/heros/hero_nox.png)
@export var hero_key: String = ""       # chave do herói no backend (ex.: "hero_nox") — o concedido
@export var dialogue_id: String = ""    # diálogo disparado ao rastrear (data/dialogues/<id>.json)
@export var facing: String = "down"     # direção que o NPC encara parado
# Gate de minigame (opcional). Vazio = herói "de graça" (concede direto após o diálogo).
@export var minigame_id: String = ""           # ex.: "memory_path" (ver MinigameLauncher.REGISTRY)
@export var minigame_config: Dictionary = {}    # dificuldade (ex.: { grid_size, path_length })
@export var fail_dialogue_id: String = ""       # diálogo ao falhar o gate (minigame/custo)
@export var cost: int = 0                        # custo em ouro para rastrear (0 = grátis)
@export var win_dialogue_id: String = ""        # diálogo extra ao VENCER o minigame (opcional)
@export var always_grant: bool = false          # true = perder o minigame NÃO bloqueia o scan
                                                  # (só troca a fala; ex.: Poppy admira a garra mesmo perdendo)
@export var already_dialogue_id: String = ""    # diálogo ao tentar rastrear de novo (já possui o herói)

@onready var _npc: Node2D = $Npc

func _ready() -> void:
	add_to_group("scannable")
	if creature_id != "":
		_npc.setup(creature_id)
		_npc.face(facing)
	# Já possui o herói → marca como rastreado (Scanner mostra "já rastreou"), sem reconceder.
	if hero_key != "" and Collection.owns_hero(hero_key):
		mark_scanned()

func mark_scanned() -> void:
	set_meta("scanned", true)
