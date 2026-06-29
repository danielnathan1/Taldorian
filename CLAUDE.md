# Taldorian TCG — Contexto do Projeto

> **Manutenção deste arquivo:** descreva **arquitetura, regras e convenções** — coisas que mudam devagar.
> NÃO duplique aqui dados que vivem em arquivos-fonte (lista completa de cartas, ids de efeitos,
> stats exatos de cada herói linha a linha). Para esses, aponte para a fonte de verdade
> (`data/cards/taldorian_origins.json`, `card_effect_registry.gd`, os `_init()` dos heróis).
> Listas duplicadas envelhecem e foi exatamente isso que tornou versões antigas deste doc enganosas.

## Visão Geral

Card game tático (TCG-like) em **Godot 4.6** (GDScript), inspirado em Flesh and Blood.
O projeto tem **dois sistemas que rodam juntos** e compartilham a mesma conexão de rede:

1. **TCG** — a partida de cartas (tabuleiro `boardv2`).
2. **Mundo aberto** — cidade tile-based onde os jogadores andam, conversam, trocam cartas e
   entram em partidas (salas / fila rápida).

Há ainda um **backend HTTP** (`taldorian-service`, mockado em `localhost:8080`) para autenticação,
catálogo/loja, boosters, inventário, decks e trocas — acessado via `ApiClient`.

**Diferenciais do jogo:**
- 3 heróis ativos por jogador (de um time maior montado no deck)
- Sequência de símbolos elementais que ativa habilidades dos heróis
- Combate por turnos com herói ativo oculto (blefe — revelado ao jogar carta não-furtiva)
- Exaustão rotativa de heróis
- Timing estruturado: ACTION → janela de REACTION → BONUS_ACTION
- Habilidades de retaguarda interativas, habilidades ativadas e tokens

---

## ⚠️ Modelo de Rede — LEIA ANTES DE QUALQUER COISA SOBRE MULTIPLAYER

**NÃO existe mais host/join (peer que também é jogador).** O modelo atual ("Modelo A") é:

```
┌─────────────────────────┐
│  SERVIDOR DEDICADO      │  godot --headless -- --world-server   (porta ENet 7001)
│  (NÃO é jogador)        │  → autoridade ÚNICA de tudo: mundo, salas, trocas e PARTIDAS
└───────────┬─────────────┘
            │ ENetMultiplayerPeer
   ┌────────┴────────┐
┌──▼──┐           ┌──▼──┐
│ Cli │ Jogador 0 │ Cli │ Jogador 1    create_client("127.0.0.1", 7001)
└─────┘           └─────┘
```

- O servidor é lançado com o argumento `--world-server`. Ele é detectado pelo autoload
  `WorldServer` ([world_server.gd](src/world/world_server.gd)), que cria o `ENetMultiplayerPeer`
  servidor e ativa `WorldState` como autoridade. **O servidor não se registra como jogador.**
- Os **dois jogadores são clientes** comuns: `main.tscn` → tela de login → `create_client(...)`
  ([login.gd](scenes/ui/login/login.gd)). Não há mais "criar partida / entrar na partida" por IP.
- `multiplayer.is_server()` é `true` **somente no processo dedicado**. `NetworkState.is_server()`
  é um wrapper disso. `NetworkState.local_player_index` (0 ou 1) é definido pelo servidor ao
  iniciar a partida (`MatchService._rpc_begin_match`).

### Como rodar (uma máquina)

```
1. Servidor dedicado:
   - Terminal:  godot --headless -- --world-server
   - Editor:    Debug > Run Multiple Instances → add launch arg:  -- --world-server
2. Um ou mais clientes (instâncias normais do jogo) que se conectam a 127.0.0.1:7001.
```

### 🐛 Armadilha de depuração (a que já causou confusão)

**Toda a lógica autoritativa de partida roda SÓ no processo `--world-server`.** Ao iniciar a
partida, **cada cliente constrói o próprio `Player`/`Hero` localmente** para exibição
(`GameState._rpc_init_players` → `HeroFactory`/`_hero_from_name`, que instanciam as subclasses reais).

Consequência: **um cliente mostrando valores novos NÃO prova que o servidor tem o código novo.**
Se você mudar regra de jogo e testar, e o comportamento não mudar:
→ **reinicie o processo do servidor dedicado.** Reiniciar só as janelas dos jogadores não adianta.
Os prints de regras (`_fire_missiles`, `CombatResolver`, etc.) aparecem **no console do servidor**,
não no do cliente.

---

## Estrutura de Pastas

```
taldorian/
├── CLAUDE.md
├── project.godot                 # main scene = scenes/ui/main.tscn (embute o login)
│
├── src/
│   ├── autoload/
│   │   ├── game_bus.gd            # Signal bus central (sinais entre sistemas)
│   │   ├── network_state.gd       # local_player_index, player_id, is_server()
│   │   ├── collection.gd          # Catálogo de cartas + coleção do jogador
│   │   ├── deck_store.gd          # Decks do jogador (via backend / cache)
│   │   ├── cosmetics_store.gd     # Sleeves/playmats
│   │   ├── character_store.gd     # Personagem do mundo (aparência) do jogador
│   │   └── api_client.gd          # Camada HTTP REST p/ o taldorian-service
│   │
│   ├── core/
│   │   ├── game_state.gd          # Autoridade da partida + rede (multi-sala). Roda no servidor.
│   │   ├── match_state.gd         # MatchState: estado puro de UMA partida (container de dados)
│   │   ├── combat_resolver.gd     # Resolve dano bidirecional do turno
│   │   ├── battle_manager.gd      # Fase atual + jogador ativo (enum Phase)
│   │   ├── turn_context.gd        # Contexto passado ao resolver combate
│   │   ├── game_symbols.gd        # Constantes de símbolo (5) + de-para com a API
│   │   └── symbol_chain.gd        # Detecta subsequências contíguas (máx 3)
│   │
│   ├── entities/
│   │   ├── heros/                 # hero.gd é a BASE real (extends RefCounted). 7 heróis jogáveis.
│   │   ├── effects/               # ~90 implementações concretas de CardEffect
│   │   ├── tokens/                # Tokens de partida (magic_missile, arcane_fragment)
│   │   ├── hero.gd                # Modelo/base de herói (stats, estado, hooks virtuais)
│   │   ├── hero_factory.gd        # make_team() — instancia o pool de heróis
│   │   ├── card.gd                # Modelo de carta
│   │   ├── card_effect.gd         # Base CardEffect + enum Timing
│   │   ├── card_effect_context.gd # Contexto de CardEffect
│   │   ├── card_effect_registry.gd# effect_id → CardEffect (fonte de verdade dos efeitos)
│   │   ├── deck_loader.gd         # Carrega deck de JSON → Cards
│   │   ├── deck_data.gd           # Serialização de deck (heróis + cartas)
│   │   ├── token.gd / token_factory.gd  # Base de Token + factory por token_id
│   │   └── player.gd              # Heróis, deck, mão, arsenal, tokens, modificadores pendentes
│   │
│   └── world/                     # Servidor de mundo + serviços (autoridade no dedicado)
│       ├── world_server.gd        # Sobe o servidor dedicado quando há --world-server
│       ├── world_state.gd         # Estado do mundo (posições, chat) — autoridade
│       ├── world_trade.gd         # Sessões de troca entre jogadores
│       ├── room_service.gd        # Salas de batalha (criar/entrar/ranqueada)
│       ├── room_info.gd           # Struct de sala
│       ├── match_service.gd       # Fila rápida + begin_match_between → board
│       ├── map_loader.gd / encounter_manager.gd
│
├── scenes/
│   ├── ui/
│   │   ├── main.tscn              # Cena principal (embute login)
│   │   ├── login/                 # Login/cadastro → conecta ao servidor
│   │   ├── character_creator/     # Criação do personagem do mundo
│   │   ├── lobby/                 # (legado do fluxo antigo)
│   │   ├── room_lobby/            # Lista/seleção de salas
│   │   ├── match_room/            # Sala de espera (assentos + ready) antes da partida
│   │   ├── deck_builder/          # Construtor de deck (+ componentes)
│   │   ├── deck_list/             # Lista de decks do jogador
│   │   ├── booster_shop/          # Loja de boosters
│   │   ├── worldhud/ , pausemenu/ , token_view/ , card_view/ , hero_slot/ , card_popup/ , hero_popup/
│   │   └── boardv2/              # TABULEIRO da partida (ver abaixo)
│   │       ├── board.gd/.tscn , half_board.gd/.tscn , center_bar.gd/.tscn
│   │       ├── player_hand.gd , card_animator.gd , card_preview.gd
│   │       ├── hero_pick_screen , mulligan_screen , arsenal_screen
│   │       ├── pick_card/ , pick_symbol/ , pick_ally/ , discart_card/
│   │       ├── fragment_shop/    # Loja do Fragmento Arcano (Relicar)
│   │       ├── stealth_confirm/  # Confirma quebrar furtividade (passiva do Relicar)
│   │       ├── deck_reveal/ , graveyard_viewer/
│   │       ├── turn_transaction/ , combat_resolve/ , game_result/
│   │
│   ├── world/                     # Mundo aberto (separado do TCG)
│   │   ├── world_root.gd/.tscn , world_connect.gd
│   │   ├── player/ (player_character, remote_player)
│   │   ├── maps/ (map_base, taldorian_city, floresta_inicial)
│   │   └── ui/ (hud_world, player_context_menu, trade/, trade_request/)
│   │
│   └── vfx/                        # magic_missiles, arcane_fragments, arrow_rain, holy_heal,
│                                   # battle_fury, assassin_attack, combat_resolution, single_target_heal
│
├── assets/ , audio/
└── data/
    ├── cards/taldorian_origins.json   # SET BASE — fonte de verdade das cartas
    ├── cosmetics.json                 # Catálogo de sleeves/playmats
    └── player_cosmetics.json          # Cosméticos desbloqueados (persistido)
```

> Nota: `src/entities/heros/hero_base.gd` é **legado** e não é usado pelos heróis atuais —
> todos estendem `Hero` ([hero.gd](src/entities/hero.gd)).

---

## Autoloads Registrados (ordem de carregamento — respeitar)

```
GameBus          src/autoload/game_bus.gd          # signal bus
NetworkState     src/autoload/network_state.gd      # índice local, player_id, is_server()
GameState        src/core/game_state.gd             # autoridade da partida + rede
WorldState       src/world/world_state.gd           # estado do mundo (autoridade)
WorldServer      src/world/world_server.gd          # sobe o servidor dedicado (--world-server)
WorldTrade       src/world/world_trade.gd           # trocas entre jogadores
Collection       src/autoload/collection.gd
DeckStore        src/autoload/deck_store.gd
CosmeticsStore   src/autoload/cosmetics_store.gd
CharacterStore   src/autoload/character_store.gd    # personagem do mundo (backend /players/me/character; user:// é só cache)
RoomService      src/world/room_service.gd          # salas de batalha
MatchService     src/world/match_service.gd         # fila rápida → board
ApiClient        src/autoload/api_client.gd         # HTTP REST (taldorian-service)
```

Autoloads herdam de `Node` e **não** usam `class_name`.

---

## Arquitetura — Regras Fundamentais

### Separação de responsabilidades

```
src/core/      Lógica pura de jogo (RefCounted / estático). Sem nodes, sem UI.
src/entities/  Modelos de dados (RefCounted). Sem nodes, sem UI. Podem emitir via GameBus.
src/world/     Serviços de rede do mundo/salas/trocas (autoloads Node, autoridade no servidor).
scenes/        Só reagem — nunca decidem. Escutam GameBus e atualizam visual.
               Nunca contêm regra de jogo. Falam com o servidor via GameState.rpc_*(...).
```

**A cena não pensa, ela exibe.** Validação de jogada, cálculo de dano e verificação de fase
ficam em `src/core/` / `src/entities/`, nunca num `.gd` de cena.

### Comunicação

```
Ação do jogador  →  cena chama  GameState.<rpc>.rpc_id(1, ...)   (1 = servidor dedicado)
Servidor valida no MatchState autoritativo  →  _emit_sync()  →  snapshot p/ os 2 peers
Cliente recebe _sync_state  →  GameBus.state_synced  →  Board redesenha
```

Nunca referencie uma cena diretamente de outra. Estado de jogo viaja por snapshot; eventos
transientes (VFX, fim de jogo, preview) viajam por sinais direcionados do GameBus.

---

## GameState — Partida e Rede

`GameState` é autoload e concentra **lógica + rede**. O estado mutável de cada partida vive num
`MatchState` ([match_state.gd](src/core/match_state.gd)); o GameState expõe proxies
(`players`, `battle`, etc.) para que os corpos de método não mudem.

### Multi-sala (Modelo A)

- O servidor mantém **N partidas isoladas**: `_matches: match_id → MatchState`, com
  `_peer_to_match` e `MatchState._match_peer_to_idx` (peer → 0/1).
- Cada RPC roteia `_m` para a partida do remetente via `_peer_to_player_index(sender)`.
- `register_match(peerA, peerB)` cria a sala; `_emit_sync()` envia o snapshot **só** aos 2 peers
  da partida (e aplica no próprio servidor). Eventos visuais usam `_match_targets()`.
- Desconexão de um peer em partida → o oponente vence (`_on_peer_disconnected`).

### RPCs que o cliente chama (sempre `rpc_id(1, "<nome>", ...)`)

Métodos públicos com prefixo `rpc_` em [game_state.gd](src/core/game_state.gd) (`@rpc("any_peer","call_local","reliable")`,
guardados por `if not multiplayer.is_server(): return`):

```
rpc_submit_deck(deck_dict)                       # submete o deck escolhido
rpc_submit_mulligan(idx_a, idx_b)                # devolve 2 cartas ao fundo
rpc_submit_hero(hero_slot)                        # escolhe herói ativo (HERO_SELECTION)
rpc_respond_backline_ability(use)                # usa/passa habilidade de retaguarda
rpc_submit_backline_target(target_player, target_hero)
rpc_respond_stealth_passive(use)                 # confirma quebrar furtividade (Relicar)
rpc_submit_ally_pick(hero_idx)                    # escolhe herói aliado (ex.: cura)
rpc_ack_reveal()                                  # confirma "olhar topo do deck" (Fragmento)
rpc_play_card(hand_idx)                           # joga carta da mão
rpc_play_from_arsenal()                           # joga carta do arsenal
rpc_activate_ability(ability_id, targets)         # habilidade ativada (ex.: disparar mísseis)
rpc_buy_fragment_effect(effect_id)                # compra efeito na loja do Fragmento Arcano
rpc_pass()                                         # passa reação/segmento
rpc_submit_card_pick(pick_indices)                # resolve overlay de pick de carta
rpc_submit_symbol_pick(chosen_symbols)            # resolve overlay de pick de símbolo
rpc_finish_battle(arsenal_idx)                    # guarda carta no arsenal (-1 = não guardar)
rpc_forfeit()                                      # desiste da partida
```

---

## Backend HTTP (ApiClient)

[api_client.gd](src/autoload/api_client.gd) — `BASE_URL = http://localhost:8080` (mock). Toda chamada é
corrotina (`await`) e devolve `{ ok, status, data, error }`. Anexa `Authorization: Bearer` automaticamente.

```
/auth/register , /auth/login           # tokens em memória
/players/me                            # perfil (cacheia player_id em NetworkState)
/players/me/character                  # GET/PUT aparência do personagem (CharacterStore; 404 = sem personagem)
/players/me/inventory                  # heróis/cartas/playmats possuídos
/catalog/collections                   # loja
/boosters/open                         # abrir pacote
/decks , /decks/{id}                   # CRUD de decks
/trades                                # efetiva troca (chamado pelo servidor de mundo)
```

> Símbolos no backend usam nomes em inglês — ver `GameSymbols.TO_API/FROM_API`
> (fogo→FIRE, agua→WATER, terra→EARTH, ar→WIND, raio→LIGHTNING).

---

## Fases do Jogo (BattleManager.Phase)

```
OPENING_ROLL      →  cada jogador rola 2d6 (drag-arremesso); maior total escolhe quem começa
OPENING_MULLIGAN  →  cada jogador devolve 2 cartas ao fundo e compra até 6
DRAW              →  jogador ativo compra até o limite; excedente (>6) volta ao fundo
HERO_SELECTION    →  escolha simultânea de herói ativo (face-down)
BACKLINE_ABILITY  →  habilidades de retaguarda interativas resolvem (ex: Ieldor)
ACTION            →  rodadas de combate: ACTION → REACTION → BONUS_ACTION
COMBAT            →  resolução de dano ao fim de cada rodada
END               →  guardar carta no arsenal; comprar; exaustar herói ativo
```

Transição emitida via `GameBus.phase_changed.emit(phase_name: String)`.
Telas de fase começam com `visible = false` no editor.

### OPENING_ROLL — rolagem de dados de abertura

Primeira fase da partida. Cada jogador arremessa 2d6 (clicar-arrastar-soltar). O **valor é
autoritativo do servidor** (`rpc_submit_dice_throw` sorteia `randi_range(1,6)` ×2); a física é
uma **animação guiada** ([dice_roll.gd](scenes/ui/boardv2/dice_roll/dice_roll.gd), dados 3D num
`SubViewport`) que termina na face do valor — o vetor do arrasto é só cosmético (sincronizado para
o oponente animar). Maior total vence; **empate → re-roll**. O vencedor escolhe quem começa
(`rpc_choose_first_player`), o que define `current_player_index` ao iniciar a batalha (antes era
fixo em 0). Estado em `MatchState._dice_*` / `_first_player` (serializado no snapshot).

### Limites de mão (Player)

| Constante               | Valor | Descrição                                |
|-------------------------|-------|------------------------------------------|
| `HAND_CAP_START`        | 6     | Máximo de cartas na mão                  |
| `HAND_SIZE_REFILL_DRAW` | 4     | Cartas compradas ao final do turno (END) |

Deck embaralhado por Fisher-Yates em `_shuffle_deck()`. Limites de cópias/deck em `DeckLoader`.

---

## Timing — Rodada (fase ACTION)

Uma **rodada** tem dois **segmentos** (um por jogador). Após ambos, o combate resolve.

```
1. Jogador ativo joga uma carta ACTION (ou do arsenal)
   └─ Revela o herói se não-furtiva
   └─ Executa efeitos INSTANT (pré-janela)
   └─ Abre JANELA DE REAÇÃO ao oponente (a menos que reações estejam bloqueadas)
2. Oponente reage (REACTION fecha a janela) ou passa
3. Efeitos AFTER_REACTION da carta ACTION resolvem
4. Jogador ativo pode jogar uma BONUS_ACTION (sem abrir reação)
5. Segmento encerra — vez passa ao oponente
```

A fase ACTION encerra quando: 2 rodadas consecutivas sem ACTION (ambos passaram), **ou** ambos
sem cartas na mão. Habilidades ativadas (ver abaixo) também consomem ACTION/BONUS conforme o custo.

---

## Herói Face-Down e Furtividade

O herói ativo do oponente começa **oculto**. É **revelado** quando: joga uma carta ACTION
não-furtiva (mão ou arsenal); a fase COMBAT começa; ou a fase END começa. Estado rastreado em
`_hero_revealed[player_idx]` no GameState.

Cartas furtivas (`is_stealth = true`) não revelam o herói. Alguns heróis/efeitos ganham
furtividade cross-turn (`next_turn_stealth`, `pending_next_turn_stealth`).
Heróis com `starts_face_up = true` aparecem de cara para cima **mesmo na retaguarda** — ver isso
na tela não prova que o herói é o ativo. (Hoje nenhum herói usa `starts_face_up`.)

### Confirmação de passiva de frontline (Muro de Aço da Valkar)

Heróis com `wants_frontline_confirm() -> true` (Valkar) entram **furtivos como qualquer um**.
Depois que **ambos** escolhem o ativo (`submit_hero_pick`), o servidor abre — só para o dono,
reusando o `StealthConfirm` — a opção de **quebrar a furtividade e ativar a passiva**:
- **Sim** → revela o herói + liga `wall_active` + `skill_activated` (VFX/popup).
- **Não** → segue furtivo (sem proteção neste turno).

`wall_active` também liga sozinho se o herói se revelar durante a fase **ACTION** (jogar carta
não-furtiva) — ver `_activate_wall_on_reveal` (não dispara na revelação forçada de COMBAT/END).
Estado server-side em `_frontline_confirm_player/_hero_idx`, RPC `rpc_respond_frontline_passive`,
flag `wall_active` por herói (resetado a cada turno, serializado no snapshot).

---

## Arsenal

- Máximo **1 carta**. Guardar uma segunda manda a anterior ao fundo do deck.
- Visível para ambos (face-up).
- Jogável como ACTION, BONUS_ACTION ou REACTION (mesmas regras de timing).
- Efeitos podem checar `played_from_arsenal`.

---

## Combate — Resolução (CombatResolver.resolve_turn)

Resolve as duas direções do turno usando `turn_cards` (dano) e `cards_this_battle` (cadeia).

```
Ataque  = base_attack + Σ turn_cards.attack_value
          + (se NÃO pending_attack_locked: pending_bonus_attack + battle_bonus_attack
             + pending_stealth_hidden_bonus)
          − battle_attack_penalty   (debuff do turno — ex.: Finta; keyed no próprio atacante)
Defesa  = base_defense + Σ turn_cards.defense_value − next_defense_penalty + pending_bonus_defense
          (Fortaleza Inabalável: enquanto pending_defense_scales_attack está ativo, cada carta
           com defense_value>0 jogada dá +1 de ataque — aplicado em _on_card_added_to_play)

Dano    = max(0, (Ataque + ctx.bonus_damage) − (Defesa + ctx.bonus_block))
          − Σ get_team_damage_reduction (heróis de suporte, ex.: passivas de redução)
final   = max(0, defender.on_before_damage_taken(...))   ← hook do defensor
final   = absorb_shield(final)                            ← escudo (damage_shield)
se final>0 e marcado (marked_target): final += marked_bonus   ← Marca do Caçador
defender.take_damage(final)
```

### Efeitos condicionais ao RESULTADO migraram para AFTER_TURN

Contra-ataque, ricochete, destruir arsenal, cura pós-combate, compra por bloqueio total, etc.
**não** são tratados no CombatResolver. São efeitos com `Timing.AFTER_TURN`, enfileirados ao
jogar a carta e drenados (FIFO) pelo GameState após o combate, quando o dano já é conhecido
(`CardEffectContext.damage_dealt / damage_taken`). Ver `CardEffect.resolve_after_combat`.

---

## Símbolos e Cadeia

### Constantes (GameSymbols) — **5 elementos**

```gdscript
GameSymbols.FOGO   # "fogo"
GameSymbols.TERRA  # "terra"
GameSymbols.AGUA   # "agua"
GameSymbols.AR     # "wind"        (id local alinhado ao backend)
GameSymbols.RAIO   # "lightning"

GameSymbols.ALL    # [FOGO, TERRA, AGUA, AR, RAIO]
GameSymbols.display_chain(symbols)  # → "Fogo · Terra · Água"
```

Sempre usar as constantes — nunca strings literais.

### Cadeia

- Acumulada de `cards_this_battle` (+ `bonus_chain_symbols`, ex.: Fragmento Arcano injeta símbolos fora de carta).
- Verificada como **subsequência contígua** (`SymbolChain`, máx **3** símbolos).
- Quando o gatilho do herói ativo dispara: `on_skill_activated` roda e `GameBus.skill_activated` é emitido.
- O gatilho padrão é `symbols_required` contíguo; heróis podem sobrescrever `is_skill_triggered`
  (ex.: Relicar = "2 elementos distintos").

---

## Entidades

### Hero ([hero.gd](src/entities/hero.gd) — base real, `extends RefCounted`)

Campos: `hero_name, hero_class, max_hp/current_hp, base_attack/base_defense, state, symbols_required,
skill_name/skill_desc, passive_name/passive_desc, skill_animation, damage_shield, starts_face_up, ...`

Hooks virtuais (override só do necessário) — lista atual, abreviada:

```gdscript
# Habilidades
on_skill_activated(player)                 # cadeia completada
is_skill_triggered(chain) -> bool          # gatilho custom da skill
get_active_abilities(player, opp) -> Array[Dictionary]   # habilidades ativadas (ver abaixo)
activate_ability(id, player, opp, targets) -> String
has_backline_ability() / apply_backline_ability(...)     # retaguarda interativa (Ieldor)
on_support_battle_start(player, opp) -> String           # passiva de retaguarda
on_card_discarded(card, player) -> String                # gatilho de descarte (Relicar)
discard_passive_reveals() -> bool

# Combate / dano
on_before_attack(ctx) ; on_after_damage_dealt(dmg, ctx)
on_before_damage_taken(amount, ctx) -> int ; on_after_damage_taken(ctx)
get_team_damage_reduction(ctx) -> int      # reduz dano a aliado (suporte)
get_aoe_damage_reduction(ctx) -> int       # reduz dano de área por herói
protects_backline_from_targeting() -> bool # impede aliados de serem ALVO (Valkar frontline)
get_passive_attack_bonus() -> int

# Ciclo
on_battle_start(player) ; on_battle_end(player) -> String ; on_turn_reset() ; on_defeated(ctx)
```

Estados: `ACTIVE` / `EXHAUSTED` / `DEFEATED`. Quando todos os vivos ficam EXHAUSTED, todos
voltam a ACTIVE. Heróis são instanciados **apenas** via `HeroFactory` / `_hero_from_name`.

### Card ([card.gd](src/entities/card.gd))

`id, card_name, timing (ACTION/BONUS_ACTION/REACTION), attack_value, defense_value,
symbols: Array[String], is_stealth, art_key, rarity, is_foil, effects: Array[CardEffect]`.
Serialização via `Card.from_dict()`.

### CardEffect ([card_effect.gd](src/entities/card_effect.gd))

`enum Timing { INSTANT, AFTER_REACTION, AFTER_TURN }`. Hooks: `pre_window_execute`,
`execute`, `resolve_after_combat`, `on_discarded`. Efeitos vivem em `src/entities/effects/`
e são registrados em [card_effect_registry.gd](src/entities/card_effect_registry.gd)
(**fonte de verdade** — não duplicar a lista aqui).

#### VFX de carta é DATA-DRIVEN e tem DOIS momentos

A animação acompanha o **timing real** da carta, em dois pontos:

1. **Ao JOGAR** (`_on_card_played` → `_play_card_vfx`): a "default" — o feixe **empower** que representa
   o buff de ATK/DEF que quase toda carta dá. Dispara para qualquer carta com `attack_value > 0` ou
   `defense_value > 0`, independente de ter efeitos. Efeitos de **buff de atk/def** também disparam a
   empower **quando aplicam o buff**: o GameState detecta o aumento dos campos de bônus do Player
   (`_atk_buff_total`/`_def_buff_total`) antes/depois de cada efeito resolver e, se cresceu, notifica
   `GameBus.empower_anim` (cobre os ~34 efeitos de buff sem wiring por efeito; só anima se o buff de
   fato ocorreu — bom p/ condicionais).
2. **Quando o EFEITO RESOLVE**: o efeito **pede** seu visual via `ctx.request_vfx(key, target_hero_idx=-1)`
   **dentro do ramo que aplica o efeito** (efeito é `RefCounted`, não toca cena — só pede). Como o
   pedido é imperativo, **condicionais não animam à toa** (ex.: `heal_if_no_damage` só pede se não
   tomou dano). No momento da resolução (servidor: `_resolve_card_effects` para INSTANT/AFTER_REACTION;
   drain para AFTER_TURN) o GameState drena `ctx.requested_vfx` e notifica os clientes
   (`_notify_effect_vfx` → `GameBus.effect_vfx(player, key, target_hero_idx)`). O board (`_on_effect_vfx`)
   resolve a chave por um **registry data-driven** (`_vfx_registry()`: `chave → handler`, 1 linha por
   visual — sem `match`/if crescente). `target_hero_idx >= 0` mira um herói específico
   (ex.: `heal_ally_pick` cura o aliado escolhido, notificado de `rpc_submit_ally_pick`). Assim a
   animação do heal de uma ACTION só aparece **depois** da janela de reação, não no play.

Chaves atuais: `"draw"` (fly deck→mão, reusa o `CardAnimator.fly_draw`), `"heal"` (single-target;
alvo padrão = ativo), `"heal_all"` (área — reusa o HolyHeal da Irena), `"shield"` (Égide single no
ativo), `"team_shield"` (Égide em todos), `"stealth"` (fumaça). **Nova carta que reusa um visual = 0
código** (efeito chama `request_vfx` com a chave); **visual novo = 1 chave no registry + 1 handler**.

#### Movimento de carta específica (`card_move_anim`)

VFX que precisa da CARTA em si (não só do herói) usa outro canal: `ctx.request_card_move(art_key, kind)`
→ drenado pelo GameState → `GameBus.card_move_anim(player, art_key, kind)` → board anima via `CardAnimator`.
`kind`: `"discard"` (mão→centro→**corte**→cemitério) · `"to_deck"` (carta → baralho). Descartes por
overlay disparam de `rpc_submit_card_pick` (HAND_DISCARD); descartes automáticos/aleatórios e o
"colocar no fundo" usam `request_card_move` / o ponto de resolução do pick. Ex.: `team_damage_shield` → `"team_shield"`
([guardian_aegis.gd](scenes/vfx/guardian_aegis/guardian_aegis.gd),
`activate(source_slot, target_slots, mirror, auto_dismiss_after)`).
Nota: `hero.heal()`/`hero_healed` rodam só no servidor — o VFX de cura nos clientes vem do
`effect_vfx`, não do `hero_healed` (evita disparo duplicado).

### Token ([token.gd](src/entities/token.gd))

Entidade criada **durante** a partida, fora do deck (estado próprio: contadores, alvo, tempo de
vida). `destroy_at_combat_end` decide se some no fim do combate. Subclasses em
`src/entities/tokens/` (`TokenMagicMissile`, `TokenArcaneFragment`), reconstruídas no cliente via
`TokenFactory` a partir do snapshot. Player guarda `tokens: Array[Token]`.

### Player — Modificadores Pendentes ([player.gd](src/entities/player.gd))

Estado de combate por turno (acumulado por efeitos, consumido pelo CombatResolver, zerado em
`reset_turn_modifiers()` / `clear_combat_cards()`). **Confira a lista atual no arquivo** — inclui,
entre outros: `pending_bonus_attack/defense`, `pending_self_damage`, `next_defense_penalty`,
`pending_cancel_reaction`, `pending_heal`, `pending_next_card_attack/defense`,
`next_turn_bonus_attack` (cross-turn), `battle_bonus_attack` (turno inteiro — Frenesi),
`battle_attack_penalty` (debuff do turno — Finta), `pending_stealth_hidden_bonus`, `next_turn_stealth`/`pending_next_turn_stealth`,
`pending_defense_scales_attack`, `pending_skill_draw`, `pending_return_card`/`pending_heal_return_card`,
`extra_actions`, `marked_target`/`marked_bonus` (Marca do Caçador), `pending_attack_locked`.

> **Raio (Lightning):** não há contador de "carga". Cartas como Descarga Preparada / Acúmulo
> Estático injetam um símbolo LIGHTNING na chain via `Player.add_chain_symbol()` (em
> `bonus_chain_symbols`, como o Fragmento Arcano). A Ressonância Elétrica conta os símbolos de
> Raio na chain. O GameState anuncia o símbolo (VFX) e re-checa a skill em `_announce_chain_symbols_added`.

---

## Habilidades Ativadas e Tokens

Além da skill por cadeia, heróis podem expor **habilidades ativadas** via
`get_active_abilities()` → lista de descritores `{ id, label, cost, needs_target, ... }`.
O GameState faz o gating de fase/segmento e o timing; o herói só executa o efeito em
`activate_ability()`. Custos:

```
"ACTION" / "BONUS"  →  consomem o segmento (e abrem reação no caso de ACTION)
"FREE"              →  não consomem o segmento (ex.: disparar mísseis já criados)
```

Exemplos: **Nox** cria/dobra/dispara **Mísseis Mágicos** (dano direto, 1 por alvo);
**Relicar** gera **Fragmentos Arcanos** (loja de efeitos in-game — `fragment_shop`).

---

## Heróis (8 jogáveis)

Stats e descrições exatas vivem nos `_init()` de cada `src/entities/heros/hero_*.gd` (fonte de
verdade). Resumo de identidade:

| Herói   | Classe    | Identidade |
|---------|-----------|------------|
| Poppy   | Barbarian | Agressão; skill por cadeia que soma ATK |
| Irena   | Cleric    | Cura; passiva de cura de fim de turno |
| Hakai   | Rogue     | Furtividade; ganha ATK ao atacar oculto |
| Ieldor  | Ranger    | Dano de área (Chuva de Flechas) + **retaguarda interativa** (1 dano a alvo escolhido) |
| Nissin  | Monk      | Tempo/compra; bônus por ACTION+BONUS na rodada |
| Valkar  | Guardian  | **HP 11.** Passiva de **linha de frente** *Muro de Aço*: protege os **aliados de retaguarda** de dano direcionado/direto (Chuva de Flechas, Mísseis, alvo escolhido). **Não é automática** — Valkar entra furtiva como qualquer herói e só ativa o Muro (`wall_active`) se quebrar a furtividade: na confirmação pós-seleção ou ao se revelar durante a fase ACTION. A própria Valkar continua alvo válido. Skill por cadeia: *Escudo de Espinhos* (metade da defesa base vira ATK). |
| Nox     | Wizard    | Tokens **Mísseis Mágicos** (dano direto); cadeia dobra os mísseis controlados |
| Relicar | Sorcerer  | Tokens **Fragmentos Arcanos** (descarte/2 elementos distintos) → loja de efeitos |

> **Dano direcionado e a proteção da Valkar:** as fontes que miram heróis de retaguarda específicos
> são Ieldor (retaguarda + AoE) e Nox (mísseis). A checagem central é
> `Player.is_targeting_protected(hero)` — chamada antes de aplicar esses danos.
> `_deal_direct_damage` e contra-ataque atingem só o herói ATIVO, então não são afetados.

---

## Cartas do Set Base

Definidas em **`data/cards/taldorian_origins.json`** (fonte de verdade). Cada carta tem tipo
(timing), ataque/defesa, símbolos, raridade, `copies` e `effect_id`(s) resolvidos pelo
`CardEffectRegistry`. Raridades: Common, Rare, Legendary, Mystic.

> Não reproduza a lista completa de cartas aqui — ela muda com frequência (hoje há > 100 cartas,
> incluindo o elemento Raio para Nox/Relicar). Para inspecionar, leia o JSON e o registry.

---

## Sistema de Mundo Aberto

Separado do TCG (nunca misturar as duas lógicas). Autoridade no servidor dedicado.

- **WorldState** — posições em grid e chat; clientes enviam intenção via `rpc_id(1, ...)`,
  recebem `_sync_world`. Mapa principal: `taldorian_city`.
- **RoomService** — salas de batalha (criar/entrar/aleatória/ranqueada); senha fica só no servidor.
  Quando uma sala enche, o servidor inicia a partida via MatchService (reusa o GameState).
- **MatchService** — fila rápida; `begin_match_between(a, b)` → `register_match` → envia os 2 ao board.
- **WorldTrade** — sessões de troca entre jogadores (slots/ouro/aceite); efetivação no backend
  via `ApiClient.finalize_trade` (chamada server-to-server com credencial de serviço).

### Sala debug (ferramenta de teste do ADMIN)

`/players/me` retorna `role` (`PLAYER`/`ADMIN`; coluna já existe no backend — promover conta =
`UPDATE players SET role='ADMIN'`). O cliente cacheia em `NetworkState.role` / `is_admin()`.
Contas ADMIN veem um checkbox **"Sala debug"** ao criar sala (room_lobby). A flag viaja
`RoomInfo.debug` → `RoomService` → `MatchService.begin_match_between(...,p_debug)` →
`GameState.register_match(...,p_debug)` → `MatchState._debug` (serializado no snapshot, espelha o
padrão de `_ranked`). `GameState.is_debug_match()` lê isso no cliente. **Impacto zero no modo normal:** o board só
cria o botão **DEBUG** (e, sob o primeiro clique, o overlay `debug_card_picker` com a grade de
cartas) **quando `is_debug_match()` é true** — em partida normal nenhum desses nós é instanciado;
o único custo é uma checagem booleana por `state_synced`. O picker → `rpc_debug_give_card(card_id)`
dá a carta na mão (validado server-side por `_m._debug`, sem checar limite de mão — é teste).
**Limitação conhecida:** a flag `debug` é confiada do cliente (o servidor dedicado não conhece o
role dos peers); o gate real é o checkbox só aparecer para ADMIN.

---

## Convenções de Código

```gdscript
func _metodo_privado() -> void: pass          # privado: underscore
func rpc_play_card(hand_idx: int) -> void:     # RPC: prefixo rpc_
signal phase_changed(new_phase: String)        # sinais no GameBus: snake_case
@onready var name_label := $Path/HeroName      # nó: @onready com tipo inferido
func bind(p_hero: Hero) -> void: pass          # parâmetros de bind: prefixo p_
const BOARD_SCENE := "res://..."               # constantes de cena: SCREAMING_SNAKE_CASE
```

---

## GameBus — Sinais (ver [game_bus.gd](src/autoload/game_bus.gd) para a lista completa/atual)

Categorias: **turno/fase** (`battle_started/ended`, `phase_changed`), **herói** (`hero_chosen/
revealed/damaged/healed/defeated`), **carta** (`card_played/drawn/discarded`), **símbolo/skill**
(`symbol_added`, `skill_activated`), **combate** (`combat_resolved`, `combat_preview_ready`),
**reação** (`reaction_window_opened`), **VFX direcionados** (`backline_arrow_fired`,
`missiles_fired`, `fragment_used`, `fragment_symbol_added`), **rede** (`state_synced`,
`deck_shuffled`), **preview** (`card_hovered`, `card_hover_ended`), **mundo**
(`world_player_joined/left`, `world_state_synced`, `world_chat_received`), **salas**
(`match_room_synced`), **troca** (`trade_requested/started/state_synced/completed/cancelled/...`),
**fim** (`game_over`).

---

## O que NÃO fazer

- Nunca colocar lógica de jogo em script de cena.
- Nunca referenciar uma cena diretamente de outra.
- Nunca chamar `GameState` autoritativo do cliente sem RPC — sempre `rpc_id(1, ...)`.
- Nunca assumir host/join: a autoridade é o **servidor dedicado** (`--world-server`).
  Ao testar mudança de regra, **reinicie o servidor**, não só o cliente.
- Nunca usar strings literais de símbolo — sempre `GameSymbols.*`.
- Nunca criar heróis fora da `HeroFactory` / `_hero_from_name`, nem tokens fora da `TokenFactory`.
- Nunca deixar telas de fase com `visible = true` no editor.
- Nunca usar `class_name` em autoloads; autoloads herdam de `Node`.
- Nunca aplicar efeito de carta direto no `game_state.gd` — usar `CardEffect` + registry.
- Nunca revelar o herói do oponente sem passar por `_hero_revealed[player_idx]`.
- Nunca misturar lógica do mundo aberto com a do TCG.
- Nunca duplicar neste CLAUDE.md listas que vivem em arquivos-fonte (cartas, efeitos, stats).

---

## Estado Atual do Desenvolvimento

**Implementado:**
- Modelo de rede com **servidor dedicado** (mundo + salas + trocas + partidas) e clientes ENet.
- Backend HTTP (ApiClient) para auth/catálogo/boosters/inventário/decks/trocas (mock localhost:8080).
- Mundo aberto tile-based (cidade), chat, troca entre jogadores, menu social.
- Salas de batalha (RoomService) + fila rápida (MatchService) + sala de espera (match_room).
- Partida completa (GameState multi-sala): todas as fases, timing, símbolos (5 elementos), cadeia.
- 8 heróis (Poppy, Irena, Hakai, Ieldor, Nissin, Valkar, Nox, Relicar), incluindo tokens
  (Mísseis Mágicos, Fragmentos Arcanos) e habilidades ativadas.
- Sistema de efeitos via CardEffect/registry com timing INSTANT/AFTER_REACTION/AFTER_TURN.
- Set base com 100+ cartas em JSON; tabuleiro boardv2 com overlays dinâmicos.
- Deck builder, deck list, booster shop, criação de personagem.
- VFX: magic_missiles, arcane_fragments, arrow_rain, holy_heal, battle_fury, combat_resolution, etc.

**Pendente / Em andamento:**
- Backend real (hoje mockado); reconhecimento de `LIGHTNING` no serviço.
- Arte final de cartas/heróis; polimento de animações.
- Generalização multi-sala (fase 2.2) e balanceamento.
```