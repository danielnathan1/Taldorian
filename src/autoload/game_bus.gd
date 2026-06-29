# src/autoload/game_bus.gd
extends Node

# Turno
signal battle_started(player_index: int)
signal battle_ended(player_index: int)
signal phase_changed(new_phase: String)

# Herói
signal hero_chosen(player_index: int, hero: Hero)
signal hero_revealed(player_index: int, hero: Hero)
signal hero_damaged(hero: Hero, amount: int)
signal hero_healed(hero: Hero, amount: int)
signal hero_defeated(hero: Hero)

# Carta
signal card_played(player_index: int, card: Card)
signal card_drawn(player_index: int)
## Carta descartada da mão pelo jogador (NÃO inclui cartas jogadas indo ao
## cemitério no fim do turno). Gatilho da passiva do Relicar (Fragmento Arcano).
signal card_discarded(player_index: int, card: Card)

# Símbolo
signal symbol_added(symbol: String, chain: Array)
signal skill_activated(hero: Hero, skill_name: String)

## VFX de um efeito de carta no momento em que ele REALMENTE resolve (ex.: heal
## resolvendo após a janela de reação de uma ACTION). vfx_key/target vêm de
## CardEffectContext.request_vfx(). Disparado pelo servidor (notify) — a "default" de
## play continua em card_played. target_hero_idx: herói alvo no player (-1 = ativo).
signal effect_vfx(player_index: int, vfx_key: String, target_hero_idx: int)

## Movimento animado de uma carta específica. kind: "discard" (mão→centro→corte→
## cemitério) · "to_deck" (carta → baralho). art_key reconstrói a textura no cliente.
signal card_move_anim(player_index: int, art_key: String, kind: String)

## Buff de ataque/defesa aplicado por um EFEITO (feixe "empower" no herói ativo).
## Disparado quando o efeito realmente aumenta atk/def. symbols → cor do feixe.
signal empower_anim(player_index: int, atk: int, def: int, symbols: Array)

# Combate — dano recebido pelo herói ativo de cada índice (mútuo)
signal combat_resolved(damage_to_player_0_hero: int, damage_to_player_1_hero: int)
# Preview de combate — dispara antes do dano ser aplicado, com os valores calculados
signal combat_preview_ready(data: Dictionary)

# Janela de reação aberta — UI do jogador deve exibir opção de reagir
signal reaction_window_opened(player_index: int)

# Retaguarda de Ieldor disparou flecha contra um herói inimigo
signal backline_arrow_fired(source_player_idx: int, source_hero_idx: int, target_player_idx: int, target_hero_idx: int)

# Token de Mísseis Mágicos disparado — VFX dos feixes (ambos os clientes).
# targets: Array de [player_idx, hero_idx] (um por míssil).
signal missiles_fired(caster_player_idx: int, targets: Array)

# Loja do Fragmento Arcano — efeito comprado (toast pros dois jogadores).
signal fragment_used(player_index: int, effect_id: String, cost: int)
# Símbolo escolhido via Fragmento entrou na chain — exibe na combat zone (ambos).
signal fragment_symbol_added(player_index: int, symbol: String)

# Fim de jogo
signal game_over(winner_index: int)

## Recompensas da partida (rankeada) para o jogador local: tier, pontos, delta e ouro ganho.
## Chega via RPC direcionado um pouco DEPOIS de game_over (corrotina HTTP ao backend); a tela
## de resultado mostra o card no game_over e anima o módulo de rank/ouro quando isto chega.
## data = { result, tier_enum, points, points_delta, gold, apex }
signal match_rewards(data: Dictionary)

# Rede
signal state_synced

# Deck embaralhado (ex: após Planos Futuros)
signal deck_shuffled(player_index: int)

# Preview de carta/herói
signal card_hovered(data: Dictionary)
signal card_hover_ended

# Mundo aberto
signal world_player_joined(peer_id: int, data: Dictionary)
signal world_player_left(peer_id: int)
signal world_state_synced(players: Dictionary)
signal world_chat_received(peer_id: int, message: String)

# ── Diálogo (onboarding / NPCs do mundo) ─────────────────────────────────────────
# Caixa de diálogo estilo Stardew. Transientes — o sistema de missão (quest) escuta
# 'dialogue_finished' para avançar objetivos sem segurar referência à caixa.
signal dialogue_started(dialogue_id: String)
signal dialogue_advanced(line_index: int)
signal dialogue_finished(dialogue_id: String)

# Sala de espera (Match Room) — detalhe da sala do jogador local (assentos + ready)
signal match_room_synced(detail: Dictionary)

# ── Troca entre jogadores (mundo aberto) ────────────────────────────────────────
# Convite recebido: outro jogador quer trocar com você.
signal trade_requested(from_peer: int, from_name: String)
# Convite recusado pelo alvo (notifica quem solicitou).
signal trade_request_declined(by_peer: int, by_name: String)
# Sessão de troca iniciada — ambos abrem a TradeWindow.
signal trade_started(other_peer: int, other_name: String, state: Dictionary)
# Estado da sessão atualizado (slots/ouro/aceite) — a janela redesenha.
signal trade_state_synced(state: Dictionary)
# Reconfirmação bloqueada por N segundos após mudança em lado já aceito.
signal trade_reset(seconds: float)
# Troca concluída — itens transferidos (efetivação no backend).
signal trade_completed(state: Dictionary)
# Troca cancelada/encerrada por um dos lados ou desconexão.
signal trade_cancelled(by_peer: int)
