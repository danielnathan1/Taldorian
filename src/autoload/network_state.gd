# src/autoloads/network_state.gd
extends Node

## Índice do jogador local nesta instância (0 = host, 1 = cliente).
## Usado pela UI pra saber qual lado da tela controlar.
var local_player_index: int = 0

## Retorna true se esta instância é o servidor.
func is_server() -> bool:
	return multiplayer.is_server()

## Retorna o peer_id local.
func local_peer_id() -> int:
	return multiplayer.get_unique_id()
