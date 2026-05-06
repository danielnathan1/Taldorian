# src/autoload/game_bus.gd
extends Node

# Turno
signal turn_started(player_index: int)
signal turn_ended(player_index: int)
signal phase_changed(new_phase: String)

# Herói
signal hero_chosen(player_index: int, hero: Hero)
signal hero_revealed(player_index: int, hero: Hero)
signal hero_damaged(hero: Hero, amount: int)
signal hero_defeated(hero: Hero)

# Carta
signal card_played(player_index: int, card: Card)
signal card_drawn(player_index: int)

# Símbolo
signal symbol_added(symbol: String, chain: Array)
signal skill_activated(hero: Hero, skill_name: String)

# Combate — dano recebido pelo herói ativo de cada índice (mútuo)
signal combat_resolved(damage_to_player_0_hero: int, damage_to_player_1_hero: int)
# Preview de combate — dispara antes do dano ser aplicado, com os valores calculados
signal combat_preview_ready(data: Dictionary)

# Janela de reação aberta — UI do jogador deve exibir opção de reagir
signal reaction_window_opened(player_index: int)

# Fim de jogo
signal game_over(winner_index: int)

# Rede
signal state_synced

# Preview de carta/herói
signal card_hovered(data: Dictionary)
signal card_hover_ended

# Mundo aberto
signal world_player_joined(peer_id: int, data: Dictionary)
signal world_player_left(peer_id: int)
signal world_state_synced(players: Dictionary)
signal world_chat_received(peer_id: int, message: String)
