# src/world/world_server.gd
# Iniciado automaticamente quando o jogo é lançado com o argumento --world-server.
# Cria o servidor ENet na porta WORLD_PORT e ativa o WorldState como autoridade.
#
# Como usar (uma máquina):
#   Terminal: godot --headless -- --world-server
#   Editor:   Debug > Run Multiple Instances, add launch arg: -- --world-server
extends Node

const WORLD_PORT := 7001

## true quando esta instância foi lançada com --world-server (servidor dedicado).
## Lido por outras cenas (ex.: lobby) para não interferir no peer do servidor.
var is_dedicated: bool = false

func _ready() -> void:
	if not "--world-server" in OS.get_cmdline_user_args():
		return
	is_dedicated = true
	_start()

func _start() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err  := peer.create_server(WORLD_PORT)
	if err != OK:
		push_error("[WorldServer] Falha ao criar servidor na porta %d: %d" % [WORLD_PORT, err])
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	print("[WorldServer] Servidor do mundo rodando na porta %d" % WORLD_PORT)
	# Servidor dedicado não é um jogador — não se registra em _players.
	WorldState.activate({}, false)
	multiplayer.peer_connected.connect(func(id): print("[WorldServer] Jogador conectado: %d" % id))
	multiplayer.peer_disconnected.connect(func(id): print("[WorldServer] Jogador desconectado: %d" % id))
