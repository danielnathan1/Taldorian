# Taldorian TCG — Contexto do Projeto

## Visão Geral

Card game tático (TCG-like) desenvolvido em Godot 4 com GDScript.
Inspirado em Flesh and Blood. Multiplayer via LAN usando ENetMultiplayerPeer.

**Diferenciais do jogo:**
- 3 heróis por jogador (em vez de 1)
- Sistema de sequência de símbolos que ativa habilidades ativas dos heróis
- Combate por turnos com herói ativo oculto (blefe — revelado ao jogar carta não-furtiva)
- Exaustão rotativa de heróis (força variedade de uso)
- Timing estruturado: ACTION → janela de REACTION → BONUS_ACTION
- Habilidades de retaguarda interativas (ex: Ieldor escolhe alvo por rodada)

---

## Estrutura de Pastas

```
taldorian/
├── CLAUDE.md
├── project.godot
│
├── src/
│   ├── autoload/
│   │   ├── game_bus.gd           # Signal bus central — único canal de comunicação entre sistemas
│   │   ├── network_state.gd      # Guarda local_player_index (0=host, 1=cliente), is_server()
│   │   ├── collection.gd         # Catálogo de cartas disponíveis + coleção do jogador
│   │   ├── deck_store.gd         # Persiste decks do jogador em user://
│   │   └── cosmetics_store.gd    # Catálogo de sleeves/playmats + posse do jogador
│   │
│   ├── core/
│   │   ├── game_state.gd         # Autoridade do estado da partida — roda só no servidor
│   │   ├── combat_resolver.gd    # Resolve dano bidirecional, aplica hooks dos heróis
│   │   ├── turn_manager.gd       # Rastreia fase atual e jogador ativo (enum Phase)
│   │   ├── battle_context.gd     # Contexto bidirecional passado ao resolver combate
│   │   ├── game_symbols.gd       # Constantes de símbolo + display_chain()
│   │   └── symbol_chain.gd       # Detecta e valida subsequências contíguas (máx 3)
│   │
│   └── entities/
│       ├── heros/
│       │   ├── hero_base.gd      # Classe base abstrata dos heróis (hooks virtuais)
│       │   ├── hero_poppy.gd     # Poppy — Barbarian
│       │   ├── hero_irena.gd     # Irena — Cleric
│       │   ├── hero_hakai.gd     # Hakai — Rogue
│       │   ├── hero_ieldor.gd    # Ieldor — Ranger (habilidade de retaguarda interativa)
│       │   ├── hero_nissin.gd    # Nissin — Monk
│       │   └── hero_valkar.gd    # Valkar — Guardian
│       ├── effects/              # 60+ implementações concretas de CardEffect
│       ├── hero_factory.gd       # Instancia o time padrão de 6 heróis
│       ├── hero.gd               # Modelo de herói (stats, estado, hooks, símbolos)
│       ├── card.gd               # Modelo de carta (tipo, valor, símbolos, raridade, efeitos)
│       ├── card_effect.gd        # Classe base CardEffect — hook apply()
│       ├── card_effect_context.gd   # Contexto passado para CardEffect.apply()
│       ├── card_effect_registry.gd  # Mapeia effect_id → CardEffect para todas as 84 cartas
│       ├── deck_loader.gd        # Carrega deck de JSON e instancia Cards (máx 3 cópias, 300 cartas)
│       ├── deck_data.gd          # Struct para serializar deck (heróis + lista de cartas)
│       └── player.gd             # Gerencia heróis, deck, mão, arsenal, modificadores pendentes
│
├── scenes/
│   ├── ui/
│   │   ├── boardv2/              # Tabuleiro principal (substitui board/)
│   │   │   ├── board.gd / board.tscn         # Controlador principal do tabuleiro
│   │   │   ├── half_board.gd / .tscn         # Metade do tabuleiro (cada jogador)
│   │   │   ├── center_bar.gd / .tscn         # Barra central com heróis ativos e preview de dano
│   │   │   ├── player_hand.gd                # Mão do jogador (drag/drop)
│   │   │   ├── hero_pick_screen.gd           # Seleção de herói (HERO_SELECTION)
│   │   │   ├── mulligan_screen.gd            # Opening mulligan (OPENING_MULLIGAN)
│   │   │   ├── card_preview.gd               # Preview ao passar mouse sobre carta
│   │   │   ├── card_animator.gd              # Animações de carta (jogar, comprar)
│   │   │   ├── arsenal_screen.gd             # Visual do arsenal
│   │   │   ├── game_result/                  # Tela de vitória/derrota
│   │   │   ├── turn_transaction/             # Animação de transição de turno
│   │   │   ├── combat_resolve/               # Animação de resolução de dano
│   │   │   ├── pick_card/                    # Overlay de escolha de carta (tutor/scry)
│   │   │   ├── pick_symbol/                  # Overlay de escolha de símbolo
│   │   │   ├── discart_card/                 # Overlay de descarte
│   │   │   └── backline_ability/             # Overlay de habilidade de retaguarda interativa
│   │   ├── lobby/
│   │   │   ├── lobby.tscn
│   │   │   └── lobby.gd
│   │   ├── card_view/
│   │   │   ├── card_view.tscn
│   │   │   └── card_view.gd
│   │   ├── hero_slot/
│   │   │   ├── hero_slot.tscn
│   │   │   └── hero_slot.gd
│   │   ├── card_popup/
│   │   │   ├── card_popup.tscn
│   │   │   └── card_popup.gd
│   │   ├── hero_popup/
│   │   │   ├── hero_popup.tscn
│   │   │   └── hero_popup.gd
│   │   ├── card_preview/         # Cena reutilizável de preview de carta
│   │   ├── pick_hero/            # Seleção de herói para deck
│   │   ├── deck_shuffle/         # Animação de embaralhamento
│   │   └── skill_animations/     # Animações de habilidades ativas
│   │
│   └── world/                    # Sistema de mundo aberto multiplayer (separado do TCG)
│       ├── player/
│       │   ├── player_character.gd / .tscn
│       │   └── remote_player.gd
│       ├── maps/
│       │   ├── map_base.gd
│       │   └── floresta_inicial.gd
│       ├── ui/
│       │   └── hud_world.gd
│       ├── world_root.gd / .tscn
│       └── world_connect.gd
│
├── assets/
│   ├── card/                     # Arte das cartas
│   ├── fonts/                    # Cinzel_Decorative
│   ├── heros/                    # hero_poppy.png, hero_hakai.png, etc.
│   ├── icons/
│   ├── images/
│   ├── playmats/                 # Tapetes customizáveis
│   └── sleve/                    # Arte do verso das cartas (sleeves)
│
├── audio/
│   └── theme/                    # Música temática de batalha
│
└── data/
    ├── cards/
    │   └── base_set.json         # 84 cartas definidas em JSON
    ├── cosmetics.json            # Catálogo de sleeves e playmats disponíveis
    ├── player_cards.json         # Coleção de cartas do jogador (persistida)
    └── player_cosmetics.json     # Cosméticos desbloqueados (persistido)
```

---

## Autoloads Registrados

Ordem de carregamento (respeitar — GameState depende dos anteriores):

```
GameBus          →  res://src/autoload/game_bus.gd
NetworkState     →  res://src/autoload/network_state.gd
GameState        →  res://src/core/game_state.gd
WorldState       →  res://src/world/world_state.gd
WorldServer      →  res://src/world/world_server.gd
Collection       →  res://src/autoload/collection.gd
DeckStore        →  res://src/autoload/deck_store.gd
CosmeticsStore   →  res://src/autoload/cosmetics_store.gd
```

---

## Arquitetura — Regras Fundamentais

### Separação de responsabilidades

```
src/core/       Lógica pura de jogo. Sem nodes, sem UI.
                Herda de RefCounted ou é classe estática.
                Não conhece nada de scenes/.

src/entities/   Modelos de dados. Sem nodes, sem UI.
                Herda de RefCounted.
                Pode usar GameBus para emitir sinais.

scenes/         Só reage — nunca decide.
                Escuta GameBus e atualiza visual.
                Nunca contém regras de jogo.
                Nunca chama GameState diretamente (só via RPC).
```

### A cena não pensa, ela exibe

Se encontrar lógica de jogo dentro de um `.gd` de cena (validação de jogada, cálculo de dano, verificação de fase), mover para `src/core/`.

### Comunicação entre sistemas

```
Ação do jogador  →  emit via GameBus  →  GameState processa
GameState        →  emit via GameBus  →  Board reage e atualiza UI
```

Nunca referência direta entre cenas. Sempre via GameBus.

---

## Sistema de Rede (Multiplayer LAN)

### Papéis

```
Servidor (host, peer_id = 1)  →  autoridade única do GameState
Cliente  (peer_id != 1)       →  envia intenções, recebe estado
```

### Fluxo de uma ação

```
Cliente clica em jogar carta
  → board.gd chama GameState.rpc_id(1, "rpc_play_card", hand_idx)
    → servidor valida via action_play_card()
      → servidor chama _sync_state.rpc()
        → GameBus.state_synced emitido em todos
          → Board._on_state_synced() redesenha
```

### Métodos RPC no GameState

Todos os métodos públicos que clientes chamam têm prefixo `rpc_`:

```gdscript
rpc_submit_opening_mulligan(idx_a: int, idx_b: int)  # devolve 2 cartas ao fundo do deck
rpc_submit_hero(hero_slot: int)                       # escolha de herói na HERO_SELECTION
rpc_submit_backline_ability(use: bool, target: int)   # usa ou passa habilidade de retaguarda
rpc_play_card(hand_idx: int)                          # jogar carta da mão
rpc_play_from_arsenal()                               # jogar carta do arsenal
rpc_pass()                                            # passar janela de reação ou segmento
rpc_finish_turn(arsenal_idx: int)                     # encerrar turno guardando carta no arsenal (-1 = não guardar)
rpc_submit_card_pick(index: int)                      # resolve overlay de pick_card
rpc_submit_symbol_pick(symbols: Array)                # resolve overlay de pick_symbol
```

### Identificação do jogador local

```gdscript
NetworkState.local_player_index  # 0 = host, 1 = cliente
NetworkState.is_server()         # true se este peer é o servidor
```

Sempre usar isso pra decidir qual lado da tela é "você".

---

## Fases do Jogo

```
OPENING_MULLIGAN  →  cada jogador devolve 2 cartas ao fundo e compra novas até 6
DRAW              →  jogador ativo compra cartas até o limite (4); se > 6, devolve excedente
HERO_SELECTION    →  jogadores escolhem herói ativo simultaneamente (face-down)
BACKLINE_ABILITY  →  habilidades de retaguarda interativas resolvem (ex: Ieldor)
ACTION            →  rodadas de combate: ACTION → REACTION → BONUS_ACTION
COMBAT            →  resolução de dano ao fim de cada rodada
END               →  guardar carta no arsenal; comprar 4; exaustar herói ativo
```

Transição de fase emitida via:
```gdscript
GameBus.phase_changed.emit(phase_name: String)
```

Todas as telas de fase começam com `visible = false` no editor.

---

## Regras de Deck e Mão

### Limites de mão

| Constante               | Valor | Descrição                               |
|-------------------------|-------|-----------------------------------------|
| `HAND_CAP_START`        | 6     | Limite máximo de cartas na mão          |
| `HAND_SIZE_REFILL_DRAW` | 4     | Cartas compradas ao final do turno (END)|

Na fase DRAW, o jogador compra cartas. Se já tiver ≥ 6, não compra nada. Cartas excedentes vão ao fundo do deck.

### Limite de cópias por deck

- Máximo de cópias definido no campo `"copies"` de cada carta em `data/cards/base_set.json`
- Limite global: `MAX_COPIES = 3`, `MAX_DECK_SIZE = 300` (validado em `DeckLoader`)

O deck é embaralhado no início da partida via Fisher-Yates em `_shuffle_deck()`.

---

## Timing — Fases da Rodada (ACTION)

Uma **rodada** tem dois **segmentos** (um por jogador). Após ambos completarem seus segmentos, o combate resolve.

### Sequência de um segmento

```
1. Jogador ativo pode jogar uma carta ACTION (ou do arsenal)
   └─ Revela o herói se a carta não for furtiva
   └─ Executa efeitos pre_window (antes de abrir reação)
   └─ Abre JANELA DE REAÇÃO para o oponente

2. Janela de reação (oponente)
   └─ Oponente pode jogar carta REACTION (fecha a janela imediatamente)
   └─ Oponente pode passar (fecha a janela)
   └─ Se pending_cancel_reaction == true: janela não abre

3. Efeitos pós-reação da carta ACTION são executados

4. Jogador ativo pode jogar uma carta BONUS_ACTION
   └─ Não abre janela de reação

5. Segmento encerra — vez passa para o oponente
```

### Condição de fim de rodada

Após ambos os segmentos, o combate da rodada resolve. Uma nova rodada começa se nenhum herói for derrotado. A fase ACTION encerra quando:
- 2 rodadas consecutivas sem ACTION jogada (ambos passaram), **ou**
- Ambos os jogadores sem cartas na mão

---

## Lógica de Herói Face-Down

### Visibilidade do herói ativo do oponente

O herói ativo do oponente começa **oculto**. Ele é **revelado** quando:

1. O oponente joga uma carta ACTION **não-furtiva** (`is_stealth == false`)
2. O oponente joga uma carta ACTION do arsenal **não-furtiva**
3. A fase COMBAT começa (todos os heróis não revelados são forçadamente revelados)
4. A fase END começa

Estado rastreado em `_hero_revealed[player_idx]: bool` no GameState.

### Cartas furtivas (`is_stealth = true`)

- Não revelam o herói ao serem jogadas
- Permitem manter o blefe por mais um segmento
- Alguns heróis podem ganhar `pending_next_round_stealth` para ficar furtivos na próxima rodada

---

## Arsenal

- **Máximo 1 carta.** Se o jogador guardar uma segunda carta, a anterior vai ao fundo do deck.
- A carta do arsenal é visível para ambos os jogadores (face-up).
- Pode ser jogada como ACTION, BONUS_ACTION ou REACTION seguindo as mesmas regras de timing.
- Alguns efeitos se ativam apenas quando a carta foi jogada do arsenal (`played_from_arsenal == true`).

---

## Combate — Resolução de Dano

### Fórmula (CombatResolver.resolve_round)

```
Ataque bruto   = hero.base_attack
               + soma de attack_value das round_cards
               + pending_bonus_attack
               + next_round_bonus_attack (cross-round, ex: Guarda Inabalável)
               - next_attack_penalty (Finta do oponente)

Defesa bruta   = hero.base_defense
               + soma de defense_value das round_cards
               + pending_bonus_defense
               (se pending_defense_scales_attack: defesa = ataque total)

Dano bruto     = max(0, Ataque bruto - Defesa bruta)
               - pending_damage_shield (Fluxo Reativo)

Dano final     = max(0, on_before_damage_taken(Dano bruto))   ← hook do herói defensor
```

### Efeitos condicionais pós-dano

| Condição | Efeito |
|----------|--------|
| Dano final == 0 e `pending_on_zero_damage_self_damage` > 0 | Atacante sofre esse dano e compra cartas |
| Dano final == 0 e `pending_counter_damage` > 0 | Atacante sofre dano de contra-ataque |
| Dano final > 0 e `pending_destroy_opponent_arsenal` | Arsenal do oponente é destruído |
| `pending_ricochet` == true | Dano é refletido de volta ao atacante |
| `pending_heal_after_combat` > 0 | Defensor cura após receber dano |
| `pending_on_full_block_draw` > 0 (dano == 0) | Defensor compra cartas |
| `pending_on_full_block_heal` > 0 (dano == 0) | Defensor cura |

Todos os `pending_*` são zerados em `reset_round_modifiers()` após cada resolução.

---

## Sistema de Símbolos e Habilidades

### Constantes (GameSymbols)

```gdscript
GameSymbols.FOGO   # "fogo"
GameSymbols.TERRA  # "terra"
GameSymbols.AGUA   # "agua"
GameSymbols.AR     # "ar"

GameSymbols.ALL    # [FOGO, TERRA, AGUA, AR]
GameSymbols.display_chain(symbols)  # → "Fogo · Terra · Água"
```

Sempre usar as constantes — nunca strings literais.

### Cadeia de símbolos

- Acumulada de `cards_this_turn` (todas as cartas jogadas no turno atual).
- Cada carta contribui com todos os seus símbolos.
- Verificada como **subsequência contígua** dentro da cadeia acumulada.
- **Tamanho máximo da cadeia:** 3 símbolos (`SymbolChain.MAX_CHAIN`).
- Quando os `symbols_required` do herói são encontrados: habilidade ativa dispara, GameBus emite `skill_activated`.

---

## Entidades

### Hero (src/entities/heros/hero_base.gd)

```gdscript
class_name HeroBase extends RefCounted

# Definidos no _init() de cada subclasse
var hero_name: String
var hero_class: HeroClass
var max_hp, current_hp: int
var base_attack, base_defense: int
var state: State  # ACTIVE, EXHAUSTED, DEFEATED
var symbols_required: Array[String]
var skill_name, skill_desc: String
var passive_name, passive_desc: String
var art_key: String
var is_backline_revealed: bool

# Hooks virtuais — override só do necessário
func on_skill_activated(player: Player) -> void: pass
func on_support_turn_start(player: Player, opponent: Player) -> void: pass  # passiva de retaguarda
func on_turn_start(player: Player) -> void: pass
func on_card_played(card: Card, player: Player) -> void: pass
func on_before_attack(ctx: BattleContext) -> void: pass
func on_after_damage_dealt(damage: int, ctx: BattleContext) -> void: pass
func on_before_damage_taken(amount: int, ctx: BattleContext) -> int: return amount
func on_after_damage_taken(ctx: BattleContext) -> void: pass
func on_turn_end(player: Player) -> void: pass
func on_round_reset() -> void: pass
func has_backline_ability() -> bool: return false
func apply_backline_ability(player: Player, opponent: Player, target: int) -> void: pass
func get_team_damage_reduction(ctx: BattleContext) -> int: return 0
func get_passive_attack_bonus() -> int: return 0
```

### Estados do herói

```
ACTIVE     →  disponível para seleção
EXHAUSTED  →  já atuou neste turno (não selecionável até todos exaustos)
DEFEATED   →  eliminado (hp == 0)
```

Quando todos os heróis vivos estão EXHAUSTED, todos são restaurados para ACTIVE.

### Card (src/entities/card.gd)

```gdscript
var id: int
var card_name: String
var timing: TimingType      # ACTION, BONUS_ACTION, REACTION
var attack_value: int
var defense_value: int
var symbols: Array[String]  # IDs de GameSymbols
var is_stealth: bool
var art_key: String
var rarity: Rarity          # COMMON, RARE, LEGENDARY, MYSTIC
var effects: Array[CardEffect]

func execute_pre_window_effects(ctx: CardEffectContext) -> void  # antes de abrir reação
func execute_effects(ctx: CardEffectContext) -> void             # após reação
func get_texture() -> Texture2D                                  # usa placeholder se não achar
```

### CardEffect (src/entities/card_effect.gd)

```gdscript
class_name CardEffect extends RefCounted
func apply(ctx: CardEffectContext) -> void: pass
```

`CardEffectContext` contém: `source_player`, `opponent_player`, `source_card`, `played_from_arsenal`, `hero_was_hidden`.

Efeitos ficam em `src/entities/effects/` e são registrados via `CardEffectRegistry`.

### Player — Modificadores Pendentes (src/entities/player.gd)

```gdscript
var cards_this_turn: Array[Card]          # cadeia de símbolos do turno
var round_cards: Array[Card]              # cartas desta rodada (combate)
var pending_bonus_attack: int
var pending_bonus_defense: int
var pending_heal: int
var pending_heal_after_combat: int
var pending_counter_damage: int
var next_round_bonus_attack: int          # cross-round (Guarda Inabalável)
var pending_damage_shield: int            # Fluxo Reativo
var pending_on_full_block_draw: int
var pending_on_full_block_heal: int
var pending_on_zero_damage_self_damage: int
var pending_on_zero_damage_draw: int      # All In
var pending_destroy_opponent_arsenal: bool
var pending_ricochet: bool                # Ricochetear
var pending_discard_if_attacked: bool     # Fúria Instável
var pending_next_round_stealth: bool      # Execução Silenciosa
var pending_defense_scales_attack: bool   # Fortaleza Inabalável
var pending_skill_draw: bool              # Sintonia Primordial
var next_attack_penalty: int              # Finta
var pending_next_card_attack: int
var pending_next_card_defense: int
var pending_cancel_reaction: bool
```

---

## Heróis Implementados

### Poppy — Barbarian
- **HP:** 10 | **Atk base:** 2 | **Def base:** 1
- **Habilidade ativa** — *Impacto Sísmico*: cadeia [TERRA, FOGO, FOGO] → +3 ATK
- **Passiva** — *Ataque Descuidado*: se nenhuma carta de defesa jogada na rodada → +1 ATK

### Irena — Cleric
- **HP:** 9 | **Atk base:** 0 | **Def base:** 2
- **Habilidade ativa** — *Toque Revigorante*: cadeia [AGUA, AGUA, TERRA] → curas ganham +1 até fim do turno
- **Passiva** — *Crescimento Natural*: fim de turno cura todos os aliados em 1

### Hakai — Rogue
- **HP:** 10 | **Atk base:** 1 | **Def base:** 0
- **Habilidade ativa** — *Instinto de Caça*: cadeia [AR, AR, AR] → torna-se furtivo
- **Passiva** — *Golpe das Sombras*: +1 ATK permanente ao causar dano enquanto furtivo

### Ieldor — Ranger
- **HP:** 9 | **Atk base:** 1 | **Def base:** -1
- **Habilidade ativa** — *Chuva de Flechas*: cadeia [FOGO, AR, AR] → 1 dano a todos heróis inimigos
- **Habilidade de retaguarda interativa** — *Retaguarda Precisa*: escolhe 1 herói inimigo por rodada e causa 1 dano direto (fase BACKLINE_ABILITY)

### Nissin — Monk
- **HP:** 10 | **Atk base:** 1 | **Def base:** 2
- **Habilidade ativa** — *Passos Ágeis*: cadeia [AR, AR, AGUA] → compra 1 carta (1x por turno)
- **Passiva** — *Fluxo Suave*: jogou ACTION + BONUS_ACTION na mesma rodada → +1 ATK

### Valkar — Guardian
- **HP:** 10 | **Atk base:** 0 | **Def base:** 3
- **Habilidade ativa** — *Escudo de Espinhos*: cadeia [TERRA, TERRA, AGUA] → ganha metade da defesa base como bônus ATK
- **Passiva de retaguarda** — *Muro de Aço*: primeiro dano a aliado por turno reduzido em 1

---

## Cartas do Set Base (84 cartas)

### ACTION — Comuns

| Carta | Atk | Def | Efeito resumido |
|-------|-----|-----|----------------|
| Golpe Bruto | 3 | 0 | Se dano == 0: recebe 1 dano e compra 1 |
| Perfeito Equilíbrio | 1 | 2 | — |
| Corte Preciso | 2 | 0 | — |
| Postura Firme | 0 | 3 | — |
| Avanço Imprudente | 4 | 0 | — |
| Investida Selvagem | 3 | 0 | — |
| Exposição Tática | 2 | 1 | — |
| Defesa Implacável | 0 | 4 | — |
| Impacto Controlado | 1 | 1 | — |
| Chama Crescente | 2 | 0 | +1 ATK por símbolo FOGO já jogado |
| Pressão Inicial | 2 | 0 | +1 ATK se for a 1ª carta do turno |
| Encadeamento | 1 | 0 | +1 ATK por carta já jogada no turno |
| Impulso Ofensivo | 1 | 0 | — |
| Pequenos Riscos | 1 | 0 | — |
| Brisa Cortante | 2 | 0 | — |
| Fluxo Sereno | 1 | 1 | — |
| Corrente Restauradora | 1 | 0 | — |
| Onda Reversa | 0 | 2 | — |
| Reflexo Líquido | 1 | 1 | — |
| Renovação | 0 | 0 | Compra 1 carta |
| Passo Fantasma | 1 | 0 | Furtivo |
| Resistência Natural | 0 | 2 | — |
| Fúria Instável | 3 | 0 | Se atacado: descarta 1 carta aleatória |
| Linha de Ferro | 0 | 3 | — |

### ACTION — Raras e Lendárias

| Carta | Tipo | Efeito resumido |
|-------|------|----------------|
| Golpe Furtivo | ACTION Rara | Furtivo — não revela herói |
| Coração da Fornalha | ACTION Rara | +1 ATK por símbolo FOGO jogado; recebe 2 de dano |
| Quebrando a Banca | ACTION Rara | Se dano > 0: destrói arsenal do oponente |
| Golpe Surpresa | ACTION Rara | Se 1ª carta do turno e veio do arsenal: cancela reação |
| Tiro de Oportunidade | ACTION Rara | +1 ATK se herói estava oculto |
| Sombra Oculta | ACTION Rara | Furtivo + compra 1 se causar dano |
| Broto Vital | ACTION Rara | Cura 2 se bloqueio total |
| Sacrifício | ACTION Rara | Descarta para ganhar +3 ATK |
| Sintonia Primordial | ACTION Lendária | Após habilidade ativa: compra 1 carta |
| Frenesi | ACTION Lendária | — |
| Execução Silenciosa | ACTION Lendária | Torna-se furtivo na próxima rodada |
| Florescer Eterno | ACTION Lendária | — |

### BONUS_ACTION — Comuns e Raras

| Carta | Def | Efeito resumido |
|-------|-----|----------------|
| Passo Leve | 1 | — |
| Ajuste Fino | 0 | Compra 1, coloca carta ao fundo do deck |
| Ajuste de Guarda | 2 | — |
| Impulso Rápido | 0 | Compra 1 |
| Respiração Serena | 0 | Cura 1 |
| Brasa | 0 | — |
| Defesa Oculta | 3 | Se veio do arsenal: +2 defesa extra |
| Descarte Estratégico | 0 | Descarta 2 aleatórias, compra 1 |
| Contra Ataque (Bônus) | 0 | Recicla primeiro descarte, compra 1 |
| Preparando o Arsenal | 0 | Guarda carta no arsenal |
| Planos Futuros | 0 | Busca a primeira ACTION do deck para a mão |
| Ricochetear | 0 | Reflete dano de volta ao atacante |
| Fortaleza Inabalável | 0 | Defesa espelha valor de ataque total |

### REACTION — Comuns e Raras

| Carta | Def | Efeito resumido |
|-------|-----|----------------|
| Bloqueio Instintivo | 3 | — |
| Desvio Rápido | 2 | — |
| Guarda Emergencial | 4 | — |
| Reflexivo Ofensivo | 1 | — |
| Passo Nebuloso | 0 | Furtivo até fim da rodada |
| Recuperação Breve | 0 | Cura 1 |
| Maré Suave | 2 | — |
| Instinto Violento | 0 | Se dano == 0: compra 1 |
| Contra Ataque | 0 | Se dano == 0: atacante sofre 1 de dano |
| Finta | 0 | Próxima rodada: -1 defesa no oponente |
| Sangue Quente | 0 | Compra 1 se sofreu dano |
| Guarda Inabalável | 2 | Guarda bônus de defesa para a próxima rodada |
| Fluxo Reativo | 0 | Absorve 1 de dano como escudo |
| Manipulando Elementos | 0 | Adiciona símbolos FOGO + TERRA à cadeia |
| Ecos do Passado | 0 | Recicla arsenal; compra 1 |
| Ciclo Vital | 0 | Cura 2; compra 1 |

---

## Cenas de UI

### Board (boardv2)

O tabuleiro é gerenciado por `board.gd` e usa dois componentes principais:
- **HalfBoard**: representa o campo de um jogador (herói ativo, arsenal, deck, discard)
- **CenterBar**: barra central com heróis ativos de ambos, ataque/defesa calculado e preview de dano

Overlays dinâmicos carregados sob demanda:
- `MulliganScreen` — visível apenas na fase OPENING_MULLIGAN
- `HeroPickScreen` — visível apenas na fase HERO_SELECTION
- `BacklineAbility` — visível apenas na fase BACKLINE_ABILITY
- `PickCard` — overlay para efeitos tutor/scry
- `PickSymbol` — overlay para escolha de símbolo (Manipulando Elementos)
- `DiscartCard` — overlay para descarte seletivo

Todas as telas de fase começam com `visible = false` no editor.

### HeroSlot

Componente reutilizável. API pública:
```gdscript
slot.bind(hero: Hero)
slot.set_face_down(value: bool)
slot.refresh()
signal slot_clicked(hero: Hero)
```

### CardView

Componente reutilizável. API pública:
```gdscript
view.bind(card: Card)
view.set_selected(value: bool)
view.set_face_down(value: bool)
signal card_clicked(card: Card)
signal card_double_clicked(card: Card)
```

---

## Convenções de Código

```gdscript
# Métodos privados — underscore no início
func _metodo_privado() -> void: pass

# RPCs — prefixo rpc_
func rpc_play_card(hand_idx: int) -> void: pass

# Sinais no GameBus — snake_case
signal phase_changed(phase: String)
signal hero_damaged(hero: Hero, amount: int)
signal card_played(player_index: int, card: Card)

# Variáveis de nó — sempre @onready com tipo inferido
@onready var name_label := $VBoxContainer/HeroName

# Parâmetros de métodos bind — prefixo p_
func bind(p_hero: Hero) -> void: pass

# Constantes de cena — SCREAMING_SNAKE_CASE
const BOARD_SCENE := "res://scenes/ui/boardv2/board.tscn"
```

---

## GameBus — Sinais Existentes

```gdscript
# Turno / Fase
signal turn_started(player_index: int)
signal turn_ended(player_index: int)
signal phase_changed(phase: String)

# Herói
signal hero_chosen(player_index: int, hero: Hero)
signal hero_revealed(player_index: int, hero: Hero)
signal hero_damaged(hero: Hero, amount: int)
signal hero_healed(hero: Hero, amount: int)
signal hero_defeated(hero: Hero)

# Carta
signal card_played(player_index: int, card: Card)
signal card_drawn(player_index: int)

# Símbolo / Habilidade
signal symbol_added(symbol: String, chain: Array)
signal skill_activated(hero: Hero, skill_name: String)

# Combate
signal combat_resolved(ctx: BattleContext)
signal combat_preview_ready(atk: int, def: int, damage: int)

# Reação
signal reaction_window_opened(player_index: int)

# Rede (TCG)
signal state_synced

# Mundo aberto
signal world_player_joined(peer_id: int)
signal world_player_left(peer_id: int)
signal world_state_synced
signal world_chat_received(sender: String, message: String)

# Fim de jogo
signal game_over(winner_index: int)
```

---

## O que NÃO fazer

- Nunca colocar lógica de jogo dentro de scripts de cena
- Nunca referenciar uma cena diretamente de outra cena
- Nunca chamar `GameState` diretamente do cliente — sempre via `rpc_id(1, ...)`
- Nunca usar strings literais de símbolo — sempre `GameSymbols.FOGO`
- Nunca criar heróis fora da `HeroFactory`
- Nunca deixar telas de fase com `visible = true` no editor
- Nunca usar `class_name` em autoloads
- Nunca fazer autoload herdar de `RefCounted` — sempre `Node`
- Nunca aplicar efeito de carta diretamente em `game_state.gd` — usar `CardEffect` + registry
- Nunca revelar o herói do oponente sem passar por `_hero_revealed[player_idx]` no GameState
- Nunca misturar lógica do mundo aberto com lógica do TCG — são sistemas separados

---

## Estado Atual do Desenvolvimento

**Implementado:**
- Lobby com conexão LAN (host/join)
- Tabuleiro boardv2 com HalfBoard + CenterBar + overlays dinâmicos
- GameState com lógica completa de todas as fases e timing
- Sistema de símbolos e cadeia (SymbolChain, máx 3)
- 6 heróis completos: Poppy, Irena, Hakai, Ieldor, Nissin, Valkar
- Habilidades de retaguarda interativas (Ieldor — fase BACKLINE_ABILITY)
- Sistema de efeitos via CardEffect / CardEffectRegistry (60+ efeitos)
- 84 cartas no set base com raridades (Common, Rare, Legendary, Mystic)
- Lógica de herói face-down com revelação condicional
- Arsenal (1 carta, efeitos especiais ao jogar do arsenal)
- Combate bidirecional com todos os modificadores cross-round
- Animações: card_animator, turn_transaction, combat_resolve, vfx (arrow_rain, holy_heal)
- Persistência: DeckStore, Collection, CosmeticsStore
- Sistema de mundo aberto multiplayer tile-based (separado do TCG)

**Pendente / Em andamento:**
- Arte final das cartas e heróis
- Tela de deck builder (scenes/ui/deck_builder/)
- Expansão de heróis e cartas além do set base
- Polimento de animações e VFX
