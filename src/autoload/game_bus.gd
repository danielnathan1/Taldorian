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

# Fim de jogo
signal game_over(winner_index: int)

# src/autoloads/game_bus.gd
signal state_synced   # ← adiciona essa linha
