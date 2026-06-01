# src/autoloads/network_state.gd
extends Node

## Índice do jogador local nesta instância (0 = host, 1 = cliente).
## Usado pela UI pra saber qual lado da tela controlar.
var local_player_index: int = 0

## Nome do jogador local — exibido no mundo e acima do personagem.
var player_name: String = "Jogador"

## true quando a partida atual foi iniciada a partir do mundo aberto (Modelo A).
## Define se, ao terminar, o jogador volta ao mundo (true) ou ao lobby (false).
var match_origin_world: bool = false

## Retorna true se esta instância é o servidor.
func is_server() -> bool:
	return multiplayer.is_server()

## Retorna o peer_id local.
func local_peer_id() -> int:
	return multiplayer.get_unique_id()
