# Taldorian TCG — Contexto do Projeto

## Visão Geral

Card game tático (TCG-like) desenvolvido em Godot 4 com GDScript.
Inspirado em Flesh and Blood. Multiplayer via LAN usando ENetMultiplayerPeer.

**Diferenciais do jogo:**
- 3 heróis por jogador (em vez de 1)
- Sistema de sequência de símbolos que ativa habilidades
- Combate por turnos com escolha de herói face-down (blefe)
- Exaustão rotativa de heróis (força variedade)

---

## Estrutura de Pastas

```
taldorian/
├── CLAUDE.md
├── project.godot
│
├── src/
│   ├── autoloads/
│   │   ├── game_bus.gd          # Signal bus central — único canal de comunicação entre sistemas
│   │   └── network_state.gd     # Guarda local_player_index (0=host, 1=cliente)
│   │
│   ├── core/
│   │   ├── game_state.gd        # Autoridade do estado da partida — roda só no servidor
│   │   ├── turn_manager.gd      # Máquina de estados das fases do turno
│   │   ├── combat_resolver.gd   # Resolve dano, ativa hooks dos heróis
│   │   ├── symbol_chain.gd      # Detecta e valida sequências de símbolos
│   │   └── battle_context.gd    # Objeto temporário de comunicação durante combate
│   │
│   └── entities/
│       ├── hero_base.gd         # Classe base abstrata dos heróis
│       ├── heroes/
│       │   └── hero_poppy.gd    # Exemplo de herói concreto
│       ├── hero_factory.gd      # Instancia times de heróis
│       ├── card.gd              # Modelo de carta
│       ├── card_art.gd          # Resolve textura por art_key
│       ├── player.gd            # Gerencia heróis, deck, mão, arsenal
│       └── game_symbols.gd      # Constantes dos símbolos (FOGO, TERRA, AGUA, AR, DARK)
│
├── scenes/
│   └── ui/
│       ├── lobby/
│       │   ├── lobby.tscn
│       │   └── lobby.gd
│       ├── board/
│       │   ├── board.tscn
│       │   └── board.gd
│       ├── hero_slot/
│       │   ├── hero_slot.tscn
│       │   └── hero_slot.gd
│       └── card_view/
│           ├── card_view.tscn
│           └── card_view.gd
│
├── assets/
│   ├── heroes/                  # hero_poppy.png, placeholder.png, etc.
│   └── cards/                   # ataque_1.png, defesa_2.png, etc.
│
└── data/
    └── cards/
        └── base_set.json        # Definição do deck inicial em JSON
```

---

## Autoloads Registrados

Ordem de carregamento (respeitar — GameState depende dos anteriores):

```
GameBus       →  res://src/autoloads/game_bus.gd
NetworkState  →  res://src/autoloads/network_state.gd
GameState     →  res://src/core/game_state.gd
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
  → board.gd emite GameBus.card_play_requested(card)
    → board.gd chama GameState.rpc_id(1, "rpc_play_card", hand_idx)
      → servidor valida via action_play_card()
        → servidor chama _sync_state.rpc()
          → GameBus.state_synced emitido em todos
            → Board._on_state_synced() redesenha
```

### Métodos RPC no GameState

Todos os métodos públicos que clientes chamam têm prefixo `rpc_`:

```gdscript
rpc_submit_mulligan(idx_a, idx_b)
rpc_submit_hero(hero_slot)
rpc_play_card(hand_idx)
rpc_pass()
rpc_finish_turn(arsenal_idx)
```

### Identificação do jogador local

```gdscript
NetworkState.local_player_index  # 0 = host, 1 = cliente
```

Sempre usar isso pra decidir qual lado da tela é "você".

---

## Fases do Jogo

```
OPENING_MULLIGAN  →  cada jogador descarta 2 cartas da mão inicial
HERO_SELECTION    →  cada jogador escolhe 1 herói (simultâneo, face-down)
ACTION            →  jogadores alternam jogadas de carta
COMBAT            →  resolução automática de dano
END               →  guardar arsenal, comprar cartas, exaustar herói
```

Transição de fase é emitida via:
```gdscript
GameBus.phase_changed.emit(phase_name: String)
```

O `Board` escuta e mostra/esconde as telas correspondentes:
```gdscript
$PhaseOverlay/MulliganScreen.visible = (phase == "OPENING_MULLIGAN")
$PhaseOverlay/HeroPickScreen.visible = (phase == "HERO_SELECTION")
```

Todas as telas de fase começam com `visible = false` no editor.

---

## Entidades

### Hero

```gdscript
# Herança — cada herói é uma subclasse de HeroBase
class_name HeroBase extends RefCounted

# Hooks virtuais — subclasse faz override só do que precisa
func on_skill_activated(ctx: BattleContext) -> void: pass
func on_before_damage_taken(amount: int, ctx: BattleContext) -> int: return amount
func on_after_damage_taken(ctx: BattleContext) -> void: pass
func on_turn_start(ctx: BattleContext) -> void: pass
func on_defeated(ctx: BattleContext) -> void: pass
```

Cada herói concreto define no `_init()`:
- `hero_name`, `hero_class`, `max_hp`, `current_hp`
- `symbols_required` (Array[String] com IDs de GameSymbols)
- `art_key` (nome do arquivo em assets/heroes/ sem extensão)
- `skill_desc` (descrição legível da habilidade)

### Card

```gdscript
var card_name: String
var card_type: CardType     # ATTACK, DEFENSE, EFFECT
var value: int              # +1, +2, +3
var symbols: Array[String]  # IDs de GameSymbols
var is_stealth: bool        # carta furtiva não revela herói
var art_key: String         # nome do arquivo em assets/cards/
```

Textura carregada via:
```gdscript
card.get_texture()   # retorna Texture2D, usa placeholder se não achar
hero.get_texture()   # idem para heróis
```

### GameSymbols

Constantes de string para IDs de símbolo:
```gdscript
GameSymbols.FOGO   # "fogo"
GameSymbols.TERRA  # "terra"
GameSymbols.AGUA   # "agua"
GameSymbols.AR     # "ar"
GameSymbols.DARK   # "dark"
```

Sempre usar as constantes — nunca strings literais como "fogo" no código.

### Player

```gdscript
var player_index: int
var player_name: String
var heroes: Array[Hero]          # sempre 3
var deck: Array[Card]
var hand: Array[Card]
var arsenal: Card                # máx 1
var selected_hero: Hero
var active_hero: Hero
var attacks_this_turn: Array[Card]
var defenses_this_turn: Array[Card]
```

---

## Cenas de UI

### Board

Hierarquia principal:
```
Board (Node2D)
├── TableLayout (VBoxContainer)
│   ├── OpponentArea (HBoxContainer)
│   │   ├── OpponentHeroes (HBoxContainer)   ← HeroSlots instanciados via código
│   │   └── OpponentHand (HBoxContainer)     ← cartas face-down
│   ├── CombatZone (HBoxContainer)
│   └── PlayerArea (VBoxContainer)
│       ├── PlayerHeroes (HBoxContainer)     ← HeroSlots instanciados via código
│       └── PlayerHand (HBoxContainer)       ← CardViews instanciados via código
└── PhaseOverlay (CanvasLayer) layer=2
    ├── MulliganScreen (Control)   visible=false por padrão
    └── HeroPickScreen (Control)   visible=false por padrão
```

### HeroSlot

Componente reutilizável. Define próprio tamanho (Custom Minimum Size no PanelContainer).
API pública:
```gdscript
slot.bind(hero: Hero)   # popula todos os campos
slot.refresh()          # relê dados do hero já vinculado
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

# Sinais no GameBus — snake_case, passado participado
signal phase_changed(phase: String)
signal hero_damaged(hero: Hero, amount: int)
signal card_played(player_index: int, card: Card)

# Variáveis de nó — sempre @onready com tipo inferido
@onready var name_label := $VBoxContainer/HeroName

# Parâmetros de métodos bind — prefixo p_
func bind(p_hero: Hero) -> void: pass

# Constantes de cena — SCREAMING_SNAKE_CASE
const BOARD_SCENE := "res://scenes/ui/board/board.tscn"
```

---

## GameBus — Sinais Existentes

```gdscript
# Turno
signal turn_started(player_index: int)
signal turn_ended(player_index: int)
signal phase_changed(phase: String)

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

# Combate
signal combat_resolved(ctx: BattleContext)

# Rede
signal state_synced

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

---

## Estado Atual do Desenvolvimento

**Implementado:**
- Lobby com conexão LAN (host/join)
- Board com HeroSlots e CardViews instanciados dinamicamente
- GameState com lógica completa de fases
- Sistema de símbolos (GameSymbols)
- HeroBase com hooks virtuais
- HeroPoppy como primeiro herói concreto
- Carregamento de textura via art_key em heróis e cartas
- RPCs para todas as ações do jogador

**Em andamento:**
- MulliganScreen
- HeroPickScreen

**Pendente:**
- ActionScreen (jogar cartas durante fase ACTION)
- Feedback visual de combate
- Animações de carta
- Expansão de heróis e cartas
- Arte final
