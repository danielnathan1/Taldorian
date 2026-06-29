# src/autoloads/network_state.gd
extends Node

## Índice do jogador local nesta instância (0 = host, 1 = cliente).
## Usado pela UI pra saber qual lado da tela controlar.
var local_player_index: int = 0

## Nome do jogador local — exibido no mundo e acima do personagem.
var player_name: String = "Jogador"

## Usuário da conta logada (login fake por enquanto; futura API real).
var account_name: String = ""

## ID do jogador no backend (UUID de /players/me). Usado em trocas e outras
## operações que precisam identificar o jogador para o serviço.
var player_id: String = ""

## Papel da conta logada (de /players/me): "PLAYER" ou "ADMIN".
## ADMIN libera ferramentas de teste (ex.: criar sala debug).
var role: String = "PLAYER"

## true quando a partida atual foi iniciada a partir do mundo aberto (Modelo A).
## Define se, ao terminar, o jogador volta ao mundo (true) ou ao lobby (false).
var match_origin_world: bool = false

## true logo após criar o personagem (primeira vez). O world_root usa isso para
## exibir o modal de boas-vindas UMA vez ao entrar no mundo e em seguida limpa o flag.
var just_created_character: bool = false

## Retorna true se a conta logada é ADMIN (libera ferramentas de teste).
func is_admin() -> bool:
	return role == "ADMIN"

## Retorna true se esta instância é o servidor.
func is_server() -> bool:
	return multiplayer.is_server()

## Retorna o peer_id local.
func local_peer_id() -> int:
	return multiplayer.get_unique_id()
