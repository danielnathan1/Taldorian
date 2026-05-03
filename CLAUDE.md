# Taldorian TCG — Contexto do Projeto

## Visão Geral

Card game tático (TCG-like) desenvolvido em Godot 4 com GDScript.
Inspirado em Flesh and Blood. Multiplayer via LAN usando ENetMultiplayerPeer.

**Diferenciais do jogo:**
- 3 heróis por jogador (em vez de 1)
- Sistema de sequência de símbolos que ativa habilidades passivas
- Combate por turnos com herói ativo oculto (blefe — revelado ao jogar carta não-furtiva)
- Exaustão rotativa de heróis (força variedade de uso)
- Timing estruturado: ACTION → janela de REACTION → BONUS_ACTION

---

## Estrutura de Pastas

```
taldorian/
├── CLAUDE.md
├── project.godot
│
├── src/
│   ├── autoload/
│   │   ├── game_bus.gd          # Signal bus central — único canal de comunicação entre sistemas
│   │   └── network_state.gd     # Guarda local_player_index (0=host, 1=cliente)
│   │
│   ├── core/
│   │   ├── game_state.gd        # Autoridade do estado da partida — roda só no servidor
│   │   ├── combat_resolver.gd   # Resolve dano, ativa hooks dos heróis e efeitos pendentes
│   │   └── symbol_chain.gd      # Detecta e valida sequências de símbolos (máx 3)
│   │
│   └── entities/
│       ├── heros/
│       │   ├── hero_base.gd     # Classe base abstrata dos heróis
│       │   ├── hero_poppy.gd    # Herói concreto — Poppy, Martelo do Destino
│       │   └── hero_grok.gd     # Herói concreto — Grok
│       ├── effects/             # Implementações de CardEffect por carta
│       ├── hero_factory.gd      # Instancia times de heróis
│       ├── hero.gd              # Modelo de herói (stats, estado, símbolos)
│       ├── card.gd              # Modelo de carta (tipo, valor, símbolos, efeitos)
│       ├── card_effect.gd       # Classe base CardEffect — hook apply()
│       ├── card_effect_context.gd  # Contexto passado para CardEffect.apply()
│       ├── card_effect_registry.gd # Mapeia card_id → lista de CardEffects
│       ├── deck_loader.gd       # Carrega deck de JSON e instancia Cards
│       └── player.gd            # Gerencia heróis, deck, mão, arsenal, modificadores
│
├── scenes/
│   └── ui/
│       ├── lobby/
│       │   ├── lobby.tscn
│       │   └── lobby.gd
│       ├── board/
│       │   ├── board.tscn
│       │   ├── board.gd
│       │   ├── mulligan_screen.gd
│       │   ├── hero_pick_screen.gd
│       │   └── card_preview.gd
│       ├── card_preview/        # Cena de preview de carta
│       ├── hero_slot/
│       │   ├── hero_slot.tscn
│       │   └── hero_slot.gd
│       └── card_view/
│           ├── card_view.tscn
│           └── card_view.gd
│
├── assets/
│   ├── heros/                   # hero_poppy.png, hero_grok.png, etc.
│   ├── playmats/
│   └── sleve/                   # Arte do verso das cartas
│
└── data/
    └── cards/
        └── base_set.json        # Definição do deck base em JSON (nome, tipo, valor, símbolos, cópias)
```

---

## Autoloads Registrados

Ordem de carregamento (respeitar — GameState depende dos anteriores):

```
GameBus       →  res://src/autoload/game_bus.gd
NetworkState  →  res://src/autoload/network_state.gd
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
  → board.gd chama GameState.rpc_id(1, "rpc_play_card", hand_idx)
    → servidor valida via action_play_card()
      → servidor chama _sync_state.rpc()
        → GameBus.state_synced emitido em todos
          → Board._on_state_synced() redesenha
```

### Métodos RPC no GameState

Todos os métodos públicos que clientes chamam têm prefixo `rpc_`:

```gdscript
rpc_submit_mulligan(kept_indices: Array)   # índices das cartas que o jogador MANTÉM
rpc_submit_hero(hero_slot: int)            # escolha de herói na HERO_SELECTION
rpc_play_card(hand_idx: int)               # jogar carta da mão
rpc_play_from_arsenal()                    # jogar carta do arsenal
rpc_pass()                                 # passar janela de reação ou segmento
rpc_finish_turn(arsenal_idx: int)          # encerrar turno guardando carta no arsenal (-1 = não guardar)
```

### Identificação do jogador local

```gdscript
NetworkState.local_player_index  # 0 = host, 1 = cliente
```

Sempre usar isso pra decidir qual lado da tela é "você".

---

## Fases do Jogo

```
OPENING_MULLIGAN  →  cada jogador escolhe quais cartas manter da mão inicial
DRAW              →  jogador ativo compra até o limite (6); excesso vai ao fundo do deck
HERO_SELECTION    →  jogadores escolhem herói ativo simultaneamente (face-down)
ACTION            →  rodadas de combate: ACTION → REACTION → BONUS_ACTION
COMBAT            →  resolução de dano ao fim de cada rodada
END               →  guardar carta no arsenal; comprar 4; exaustar herói ativo
```

Transição de fase emitida via:
```gdscript
GameBus.phase_changed.emit(phase_name: String)
```

O `Board` escuta e mostra/esconde as telas correspondentes:
```gdscript
$PhaseOverlay/MulliganScreen.visible  = (phase == "OPENING_MULLIGAN")
$PhaseOverlay/HeroPickScreen.visible  = (phase == "HERO_SELECTION")
```

Todas as telas de fase começam com `visible = false` no editor.

---

## Regras de Deck e Mão

### Limites de mão

| Constante            | Valor | Descrição                               |
|----------------------|-------|-----------------------------------------|
| `HAND_CAP_START`     | 6     | Limite máximo de cartas na mão          |
| `HAND_SIZE_REFILL_DRAW` | 4 | Cartas compradas ao final do turno (END)|

Na fase DRAW, o jogador compra até atingir 6. Se já tiver ≥ 6, não compra nada. Cartas excedentes vão ao fundo do deck.

### Limite de cópias por deck

Definido no campo `"copies"` de cada carta em `data/cards/base_set.json`. Exemplos do set base:

- **3 cópias:** Golpe Bruto, Perfeito Equilíbrio, Golpe Furtivo, Escalada Brutal, Contra Ataque, Finta, Ajuste Fino
- **2 cópias:** All In, Quebrando a Banca, Planos Futuros, Defesa Oculta, Golpe Surpresa, Coração da Fornalha, Descarte Estratégico
- **1 cópia:** Manipulando Elementos

O deck é embaralhado no início da partida via Fisher-Yates em `_shuffle_deck()`.

---

## Timing — Fases da Rodada (ACTION)

Uma **rodada** tem dois **segmentos** (um por jogador). Após ambos completarem seus segmentos, o combate resolve.

### Sequência de um segmento

```
1. Jogador ativo pode jogar uma carta ACTION (ou do arsenal)
   └─ Revela o herói se a carta não for furtiva
   └─ Abre JANELA DE REAÇÃO para o oponente

2. Janela de reação (oponente)
   └─ Oponente pode jogar carta REACTION (fecha a janela imediatamente)
   └─ Oponente pode passar (fecha a janela)
   └─ Se pending_cancel_reaction == true: janela não abre

3. Jogador ativo pode jogar uma carta BONUS_ACTION
   └─ Não abre janela de reação

4. Segmento encerra — jogador ativo passa para o oponente
```

### Condição de fim de rodada

Após ambos os segmentos, o combate da rodada resolve. Uma nova rodada começa se nenhum herói for derrotado. A fase ACTION encerra quando:
- 2 rodadas consecutivas sem ACTION jogada (ambos passaram), **ou**
- Ambos os jogadores sem cartas na mão

---

## Lógica de Herói Face-Down

### Visibilidade do herói ativo do oponente

O herói ativo do oponente começa **oculto** (exibido como verso de carta). Ele é **revelado** quando:

1. O oponente joga uma carta ACTION **não-furtiva** (`is_stealth == false`)
2. O oponente joga uma carta ACTION do arsenal **não-furtiva**
3. A fase COMBAT começa (todos os heróis não revelados são forçadamente revelados)
4. A fase END começa

Estado rastreado em `_hero_revealed[player_idx]: bool` no GameState.

### Cartas furtivas (`is_stealth = true`)

- Não revelam o herói ao serem jogadas
- Permitem manter o blefe por mais um segmento
- Exemplo: Golpe Furtivo

---

## Arsenal

- **Máximo 1 carta.** Se o jogador guardar uma segunda carta, a anterior vai ao fundo do deck.
- A carta do arsenal é visível para ambos os jogadores (face-up).
- Pode ser jogada como ACTION, BONUS_ACTION ou REACTION seguindo as mesmas regras de timing.
- Alguns efeitos se ativam apenas quando a carta foi jogada do arsenal (`played_from_arsenal == true`).

---

## Combate — Resolução de Dano

### Fórmula

```
Ataque bruto   = base_attack do herói
               + soma dos valores de ataque das cartas da rodada
               + pending_bonus_attack

Defesa bruta   = base_defense do herói
               - next_defense_penalty (aplicado e zerado)
               + soma dos valores de defesa das cartas da rodada
               + pending_bonus_defense

Dano bruto     = Ataque bruto + pending_bonus_damage - (Defesa bruta + pending_bonus_block)
Dano final     = max(0, on_before_damage_taken(Dano bruto))   ← hook do herói defensor
```

### Efeitos condicionais pós-dano

| Condição                          | Efeito                                                    |
|-----------------------------------|-----------------------------------------------------------|
| Dano final == 0 e `pending_on_zero_damage_self_damage` > 0 | Atacante sofre esse dano e compra cartas equivalentes |
| Dano final == 0 e `pending_counter_damage` > 0             | Atacante sofre dano de contra-ataque                 |
| Dano final > 0 e `pending_destroy_opponent_arsenal`        | Arsenal do oponente é destruído                      |
| `pending_self_damage` > 0                                  | Aplicado ao atacante após o combate                  |

Todos os `pending_*` são zerados em `reset_round_modifiers()` após cada resolução.

---

## Sistema de Símbolos e Habilidades

### Constantes (GameSymbols)

```gdscript
GameSymbols.FOGO   # "fogo"
GameSymbols.TERRA  # "terra"
GameSymbols.AGUA   # "agua"
GameSymbols.AR     # "ar"
GameSymbols.DARK   # "dark"
```

Sempre usar as constantes — nunca strings literais.

### Cadeia de símbolos

- Acumulada de `cards_this_turn` (todas as cartas jogadas no turno atual).
- Cada carta contribui com todos os seus símbolos.
- Verificada como subsequência contígua dentro da cadeia acumulada.
- **Tamanho máximo da cadeia:** 3 símbolos (`SymbolChain.MAX_CHAIN`).
- Quando os `symbols_required` do herói são encontrados: habilidade ativa, GameBus emite `skill_activated`.

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
func on_passive_check(ctx: BattleContext) -> void: pass   # verificações antes do combate
func on_defeated(ctx: BattleContext) -> void: pass
```

Cada herói concreto define no `_init()`:
- `hero_name`, `hero_class`, `max_hp`, `base_attack`, `base_defense`
- `symbols_required` (Array[String] com IDs de GameSymbols — subsequência necessária)
- `art_key` (nome do arquivo em `assets/heros/` sem extensão)
- `skill_name`, `skill_desc` (nome e descrição legível da habilidade ativa)

### Estados do herói

```
ACTIVE     →  disponível para seleção
EXHAUSTED  →  já atuou neste turno (não selecionável até todos exaustos)
DEFEATED   →  eliminado (hp == 0)
```

Quando todos os heróis vivos estão EXHAUSTED, todos são restaurados para ACTIVE.

### Card

```gdscript
var card_name: String
var card_type: CardType     # ACTION, BONUS_ACTION, REACTION
var attack_value: int       # contribuição de ataque
var defense_value: int      # contribuição de defesa
var symbols: Array[String]  # IDs de GameSymbols
var is_stealth: bool        # carta furtiva — não revela o herói
var art_key: String         # nome do arquivo em assets/cards/
var effects: Array          # lista de CardEffect aplicados ao ser jogada
```

Textura carregada via:
```gdscript
card.get_texture()   # retorna Texture2D, usa placeholder se não achar
hero.get_texture()   # idem para heróis
```

### CardEffect

```gdscript
class_name CardEffect extends RefCounted

func apply(ctx: CardEffectContext) -> void: pass  # override em cada efeito concreto
```

`CardEffectContext` carrega: `game_state`, `player_idx`, `card`, `played_from_arsenal`.

Efeitos ficam em `src/entities/effects/` e são registrados via `CardEffectRegistry`.

### Player — Modificadores Pendentes

```gdscript
var cards_this_turn: Array[Card]         # todas as cartas do turno (cadeia de símbolos)
var round_cards: Array[Card]             # cartas da rodada atual (combate)
var pending_bonus_attack: int
var pending_bonus_defense: int
var pending_bonus_damage: int
var pending_bonus_block: int
var pending_self_damage: int
var pending_destroy_opponent_arsenal: bool
var pending_counter_damage: int
var next_defense_penalty: int            # penalty de defesa aplicado na PRÓXIMA rodada
var pending_cancel_reaction: bool        # suprime a janela de reação do oponente
var pending_on_zero_damage_self_damage: int
var pending_on_zero_damage_draw: int
```

---

## Cartas do Set Base

| Carta                  | Tipo         | Atk | Def | Efeito resumido                                              |
|------------------------|--------------|-----|-----|--------------------------------------------------------------|
| Golpe Bruto            | ACTION       | 3   | 0   | Se dano == 0: recebe 1 dano e compra 1                       |
| Perfeito Equilíbrio    | ACTION       | 1   | 2   | —                                                            |
| Golpe Furtivo          | ACTION       | 2   | 0   | Furtivo — não revela herói                                   |
| Escalada Brutal        | ACTION       | 1   | 0   | +1 ataque por carta já jogada no turno                       |
| All In                 | ACTION       | 4   | 0   | Se dano == 0: recebe 1 dano e compra 1                       |
| Quebrando a Banca      | ACTION       | 2   | 0   | Se dano > 0: destrói arsenal do oponente                     |
| Planos Futuros         | ACTION       | 0   | 0   | Busca a primeira ACTION do deck para a mão                   |
| Coração da Fornalha    | ACTION       | 0   | 0   | +1 ataque por símbolo FOGO jogado; recebe 2 de dano          |
| Golpe Surpresa         | ACTION       | 2   | 0   | Se primeira carta do turno e veio do arsenal: cancela reação  |
| Defesa Oculta          | BONUS_ACTION | 0   | 3   | Se veio do arsenal: +2 de defesa extra                       |
| Descarte Estratégico   | BONUS_ACTION | 0   | 0   | Descarta 2 aleatórias, compra 1                              |
| Ajuste Fino            | BONUS_ACTION | 0   | 0   | Compra 1, coloca carta ao fundo do deck                      |
| Contra Ataque (Bônus)  | BONUS_ACTION | 0   | 0   | Recicla primeiro descarte, compra 1                          |
| Contra Ataque          | REACTION     | 0   | 0   | Se dano == 0: atacante sofre 1 de dano                       |
| Finta                  | REACTION     | 0   | 0   | Próxima rodada: -1 de defesa no oponente                     |
| Manipulando Elementos  | REACTION     | 0   | 0   | Adiciona símbolos FOGO + TERRA à cadeia desta carta          |

---

## Heróis Implementados

### Poppy, Martelo do Destino

- **Classe:** BARBARIAN
- **HP:** 20 | **Atk base:** 2 | **Def base:** 1
- **Habilidade ativa** — *Impacto Sísmico*: requer cadeia [TERRA, TERRA, FOGO] → +3 de dano bônus
- **Habilidade passiva** — *Ataque Descuidado*: se nenhuma carta de defesa (defense_value > 0) foi jogada na rodada → +1 de ataque

### Grok

- Em desenvolvimento — arquivo presente mas habilidades pendentes

---

## Cenas de UI

### Board

Hierarquia principal:
```
Board (Node2D)
├── TableLayout (VBoxContainer)
│   ├── OpponentArea (HBoxContainer)
│   │   ├── OpponentHeroes (HBoxContainer)   ← HeroSlots instanciados via código
│   │   └── OpponentHand (HBoxContainer)     ← cartas face-down (só contagem visível)
│   ├── CombatZone (HBoxContainer)
│   └── PlayerArea (VBoxContainer)
│       ├── PlayerHeroes (HBoxContainer)     ← HeroSlots instanciados via código
│       └── PlayerHand (HBoxContainer)       ← CardViews instanciados via código
└── PhaseOverlay (CanvasLayer) layer=2
    ├── MulliganScreen (Control)   visible=false por padrão
    └── HeroPickScreen (Control)   visible=false por padrão
```

### HeroSlot

Componente reutilizável. API pública:
```gdscript
slot.bind(hero: Hero)        # popula todos os campos
slot.set_face_down(value: bool)  # oculta/revela herói do oponente
slot.refresh()               # relê dados do hero já vinculado
signal slot_clicked(hero: Hero)
```

### CardView

Componente reutilizável. API pública:
```gdscript
view.bind(card: Card)
view.set_selected(value: bool)
view.set_face_down(value: bool)   # false = face-up (padrão na mão do jogador local)
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
const BOARD_SCENE := "res://scenes/ui/board/board.tscn"
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
signal hero_defeated(hero: Hero)

# Carta
signal card_played(player_index: int, card: Card)
signal card_drawn(player_index: int)

# Símbolo / Habilidade
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
- Nunca aplicar efeito de carta diretamente em `game_state.gd` — usar `CardEffect` + registry
- Nunca revelar o herói do oponente sem passar por `_hero_revealed[player_idx]` no GameState

---

## Estado Atual do Desenvolvimento

**Implementado:**
- Lobby com conexão LAN (host/join)
- Board com HeroSlots e CardViews instanciados dinamicamente
- GameState com lógica completa de fases e timing (ACTION → REACTION → BONUS_ACTION)
- Sistema de símbolos e cadeia (SymbolChain, máx 3)
- HeroBase com hooks virtuais + HeroPoppy + HeroGrok (em andamento)
- Lógica de herói face-down com revelação condicional
- Arsenal (1 carta, efeitos especiais ao jogar do arsenal)
- Sistema de efeitos via CardEffect / CardEffectRegistry
- Carregamento de deck via DeckLoader (JSON)
- Limites de mão: cap 6, refill 4
- Todas as RPCs de ação do jogador

**Em andamento:**
- MulliganScreen
- HeroPickScreen
- HeroGrok (habilidades)

**Pendente:**
- ActionScreen (jogar cartas durante fase ACTION)
- Feedback visual de combate e animações
- Expansão de heróis e cartas
- Arte final
