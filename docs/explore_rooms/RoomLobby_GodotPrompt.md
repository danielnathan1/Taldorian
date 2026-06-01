# Prompt para Claude Code — RoomLobby.tscn (Godot 4)

Cole o conteúdo abaixo no Claude Code. Ele assume que o projeto Godot do Taldorian TCG já existe em `res://` com os autoloads (`GameBus`, `NetworkState`, `GameState`) e as cenas anteriores (Lobby de conexão, HeroPick, Card, Board, DeckBuilder).

---

## CONTEXTO

Estou desenvolvendo **Taldorian TCG**, um card game tático em Godot 4.x (multiplayer LAN via `ENetMultiplayerPeer`). Já existem:

- `res://scenes/ui/lobby/lobby.tscn` — **tela de conexão** atual (host/join por IP)
- `res://scenes/ui/deckbuilder/DeckBuilder.tscn` — forja de decks
- `res://scenes/ui/board/...` — mesa de jogo
- Autoloads: `GameBus` (signal bus), `NetworkState` (`local_player_index`), `GameState`

A referência visual completa em HTML/CSS está em **`Room Lobby.html`** na raiz do projeto (leia esse arquivo antes de começar — tem todas as cores OKLCH, tipografia, layout em 2 colunas, hovers, estados e o modal). Os componentes React estão em `room-lobby-app.jsx`.

## OBJETIVO

Construa **`res://scenes/ui/lobby/RoomLobby.tscn`** — a tela de **navegação de salas**. É a tela que aparece *depois* de conectar à rede (ou que substitui o lobby de conexão atual, se você optar por unificar). Lista todas as salas abertas, deixa o jogador filtrar, criar uma sala, conectar a uma sala (com senha quando privada) ou entrar numa fila rankeada, e escolher o deck ativo.

> **Layout:** 2 colunas. A da esquerda ocupa **3/4** da largura (lista de salas + filtros + barra de ações), a da direita **1/4** (deck ativo + fila rankeada + deck builder). Botão de fechar o lobby no canto superior direito.

---

## REQUISITOS FUNCIONAIS

1. **Topbar**
   - Marca "TALDORIAN" (gradient gold) + tag "SALAS DE BATALHA"
   - Status de rede (bolinha verde + "Rede Local · N jogadores online")
   - **Botão fechar (✕)** no canto superior direito (sai do lobby → volta ao menu/desconecta)

2. **Coluna esquerda — Lista de salas (3/4)**
   - Cabeçalho: rótulo "SALAS ABERTAS" + contador "X de Y" (filtradas/total)
   - **Filtros** (lado a lado): por **número** (LineEdit numérico, só dígitos) e por **nome** (LineEdit texto). Filtragem reativa enquanto digita.
   - Cabeçalho de colunas: `ID · SALA · MODO · JOGADORES`
   - **Lista de salas** (ScrollContainer) — cada linha (`RoomRow`) mostra:
     - `#id` (ex.: `#1042`)
     - **Ícone de cadeado ANTES do nome** quando a sala é privada (`locked`)
     - Nome da sala
     - Chip de **modo de jogo** (`Clássico` dourado / `Flash` índigo)
     - Contador de jogadores **`0/2`** (fica vermelho quando cheio)
   - Salas **cheias** (`players >= cap`): linha esmaecida (`modulate.a ≈ 0.5`) e **não selecionável**
   - Selecionar uma linha → destaque dourado (borda + glow)
   - Estado vazio: "Nenhuma sala encontrada com esse filtro"

3. **Barra de ações (rodapé da coluna esquerda)**
   - **Conectar** — botão primário (dourado). Começa **desabilitado**; **acende ao selecionar uma sala** e passa a mostrar `⚔ Conectar · #id`. Se a sala for privada, abre o `PasswordModal` antes de conectar.
   - **Aleatório** ("Conectar aleatoriamente") — escolhe uma sala aleatória **não-cheia**, seleciona e conecta
   - **Criar Sala** — abre o `CreateRoomModal`

4. **Modal Criar Sala (`CreateRoomModal`)**
   - Campo **Nome da Sala** (LineEdit, máx 32, autofocus)
   - **Tipo de Jogo** — toggle segmentado de 2 opções: **Clássico** ("partida completa") / **Flash** ("ritmo acelerado")
   - Checkbox **"Sala privada"** ("— exige senha para entrar"). Ao marcar, **revela** (animado) o campo **Senha** (LineEdit `secret`)
   - Ações: **Cancelar** / **Criar Sala**. "Criar Sala" só habilita com nome preenchido (e senha, se privada).
   - Criar → adiciona a sala no topo da lista, seleciona-a, fecha o modal e emite toast.

5. **Coluna direita (1/4)**
   - **Deck Ativo** — card clicável que abre dropdown com a lista de decks (lê do `DeckStore`/`Collection` do DeckBuilder). Mostra nome do deck + "N heróis · N cartas". Trocar deck emite toast e persiste a escolha.
   - **Partida Rankeada** — emblema de tier (losango com "IV"), tier ("Prata IV"), elo ("1 248 pontos · 7 vitórias seguidas"), e botão **Entrar na Fila Rankeada** (carmesim). Ao entrar: vira "Cancelar Fila" (ghost), mostra "Na fila · 00:0X" com bolinha pulsante.
   - **Deck Builder** — botão no rodapé que troca a cena para `DeckBuilder.tscn`.

---

## DADOS

### RoomInfo (RefCounted ou Dictionary)
```gdscript
class_name RoomInfo extends RefCounted
var id: int
var room_name: String
var game_type: String   # "classico" | "flash"
var players: int
var capacity: int = 2
var locked: bool        # tem senha
# senha NUNCA trafega no browser — só validada no host ao conectar
```

### Autoload `RoomService.gd` (Node)
Abstrai a origem das salas. Por enquanto serve **dados mock** (espelhe `INITIAL_ROOMS` de `room-lobby-app.jsx`); depois pluga em LAN discovery (broadcast UDP) ou num list-server.

```gdscript
extends Node
signal rooms_updated(rooms: Array)        # Array[RoomInfo]
signal room_created(room: RoomInfo)
signal join_result(success: bool, msg: String)

var rooms: Array = []                      # Array[RoomInfo]

func refresh() -> void                      # repopula `rooms` e emite rooms_updated
func create_room(p_name: String, p_type: String, p_locked: bool, p_password: String) -> RoomInfo
func join_room(p_id: int, p_password: String = "") -> void   # valida senha, conecta via ENet, emite join_result
func join_random() -> void                  # escolhe sala não-cheia aleatória e chama join_room
func enter_ranked_queue() -> void
func leave_ranked_queue() -> void
```

> **Integração de rede:** `join_room()` deve, no fim, usar o fluxo já existente do projeto (criar/conectar `ENetMultiplayerPeer`, setar `NetworkState.local_player_index`) e, ao concluir, trocar para `board.tscn`. Reaproveite o que já existe em `lobby.gd`. Salas e fila rankeada começam **mock**; deixe `# TODO: wire LAN discovery` marcado.

### Decks (reuso)
Leia os decks já existentes do DeckBuilder via o autoload `DeckStore` (ou `Collection`). Não duplique dados — exiba `deck_name`, nº de heróis e nº de cartas. Persista o deck ativo em `user://settings.cfg` (chave `active_deck_id`).

---

## ÁRVORE DE CENAS

### `RoomLobby.tscn`
```
RoomLobby (Control, anchors=full_rect)  [script: RoomLobby.gd]
├─ Background (ColorRect, mouse_filter=IGNORE)              # var(--bg-deep), gradient via shader/StyleBox
├─ AtmosphereLayer (Control, mouse_filter=IGNORE)
│  ├─ Fog (TextureRect/ColorRect com gradient radial, alpha animado)
│  └─ Particles (CPUParticles2D ou GPUParticles2D — faíscas douradas subindo)
├─ Root (MarginContainer, anchors=full_rect)               # padding clamp ~1.2rem/2.6rem
│  └─ Shell (VBoxContainer)
│     ├─ TopBar (HBoxContainer, custom_minimum_size.y=56)
│     │  ├─ Brand (HBoxContainer)
│     │  │  ├─ BrandMark (Label "TALDORIAN" — CinzelDecorative gradient gold)
│     │  │  └─ BrandTag (Label "SALAS DE BATALHA")
│     │  ├─ Spacer (Control, size_flags_horizontal=EXPAND_FILL)
│     │  ├─ NetStatus (HBoxContainer → NetDot(Panel circular) + Label)
│     │  └─ CloseButton (Button "✕", redondo, borda carmesim)
│     ├─ Divider (HSeparator)
│     └─ Columns (HBoxContainer, size_flags_vertical=EXPAND_FILL)
│        ├─ LeftCol (PanelContainer, size_flags_horizontal=EXPAND_FILL, stretch_ratio=3.0)
│        │  └─ VBoxContainer
│        │     ├─ LeftHead (HBoxContainer)
│        │     │  ├─ TitleBlock (HBox → "SALAS ABERTAS" + RoomCount "X de Y")
│        │     │  ├─ Spacer (EXPAND)
│        │     │  └─ Filters (HBoxContainer)
│        │     │     ├─ NumFilter  (LineEdit, prefixo "#", largura ~130)
│        │     │     └─ NameFilter (LineEdit, prefixo "⌕", largura ~210)
│        │     ├─ ListCols (HBoxContainer — cabeçalhos ID/SALA/MODO/JOGADORES)
│        │     ├─ RoomListScroll (ScrollContainer, size_flags_vertical=EXPAND_FILL)
│        │     │  └─ RoomList (VBoxContainer — preenchido em runtime com RoomRow.tscn)
│        │     └─ ActionBar (HBoxContainer)
│        │        ├─ ConnectButton (Button primário, disabled por padrão, stretch_ratio=1.4)
│        │        ├─ RandomButton  (Button ghost "⚄ Aleatório")
│        │        └─ CreateButton  (Button ghost "✚ Criar Sala")
│        └─ RightCol (VBoxContainer, stretch_ratio=1.0)
│           ├─ DeckPanel (PanelContainer)
│           │  └─ VBox → SectionLabel "DECK ATIVO" + DeckSelector.tscn
│           └─ RankedPanel (PanelContainer, size_flags_vertical=EXPAND_FILL)
│              └─ VBox
│                 ├─ SectionLabel "PARTIDA RANKEADA"
│                 ├─ RankedEmblem (Control → 2 Panels losango rotacionados + Label "IV")
│                 ├─ TierLabel ("Prata IV")
│                 ├─ EloLabel ("1 248 pontos · 7 vitórias seguidas")
│                 ├─ QueueingRow (HBox → PulseDot + "Na fila · 00:0X", hidden por padrão)
│                 ├─ RankedButton (Button carmesim "⚔ Entrar na Fila Rankeada")
│                 └─ BuilderButton (Button, "⚒ Deck Builder", size_flags_vertical=END)
├─ ModalLayer (CanvasLayer, layer=2)
│  ├─ CreateRoomModal.tscn (instância, visible=false)
│  └─ PasswordModal.tscn   (instância, visible=false)
└─ ToastLayer (CanvasLayer, layer=3)
   └─ Toast.tscn (instância)
```

### `RoomRow.tscn` (item da lista)
```
RoomRow (PanelContainer, custom_minimum_size.y=54)  [script: RoomRow.gd]
└─ MarginContainer
   └─ Grid (HBoxContainer com larguras fixas/expand)
      ├─ IdLabel (Label "#1042", largura ~64)
      ├─ NameCell (HBoxContainer, EXPAND_FILL)
      │  ├─ LockIcon (ver “ÍCONE DE CADEADO” abaixo, hidden quando !locked)
      │  └─ NameLabel (Label, clip_text)
      ├─ GameChip (PanelContainer + Label, largura ~130, alinhado à esquerda)
      └─ PlayersCell (HBoxContainer, alinhado à direita)
         ├─ SeatDot (Panel circular)
         └─ PlayersLabel (Label "0/2")

Estados (trocados por GDScript):  normal | hover | selected | full
signal row_selected(id: int)
func bind(p_room: RoomInfo) -> void
func set_selected(v: bool) -> void
```

### `CreateRoomModal.tscn`
```
CreateRoomModal (Control, anchors=full_rect)  [script: CreateRoomModal.gd]
├─ Overlay (ColorRect escuro semi-transparente, clica fora = fechar)
└─ Box (PanelContainer, centralizado, ~440px)
   └─ VBoxContainer
      ├─ Title (Label "⚒ CRIAR SALA")
      ├─ NameField (VBox → label "NOME DA SALA" + LineEdit)
      ├─ TypeField (VBox → label "TIPO DE JOGO" + TypeToggle HBox de 2 botões)
      ├─ PrivateRow (HBox → CheckBox custom + "Sala privada" + hint)
      ├─ PasswordReveal (VBox, hidden/animado → label "SENHA" + LineEdit secret)
      └─ Actions (HBox → CancelButton + CreateButton[disabled até válido])
signal create_requested(data: Dictionary)   # {name, type, locked, password}
signal cancelled
```

### `PasswordModal.tscn` (ao conectar em sala privada)
```
PasswordModal (Control)  →  Overlay + Box(VBox → "SALA PROTEGIDA" + LineEdit secret + [Cancelar][Entrar])
signal submitted(password: String)
signal cancelled
```

### `DeckSelector.tscn`
```
DeckSelector (VBoxContainer)  [script: DeckSelector.gd]
├─ DeckCard (Button/PanelContainer → "SELECIONADO" + DeckName(CinzelDecorative gold) + Meta "N heróis · N cartas" + Chevron ▼/▲)
└─ Options (VBoxContainer, hidden → DeckOption por deck: nome + "✓ ativo"/"N cartas")
signal deck_changed(deck_id: String)
```

### `Toast.tscn`
Pequena cena que sobe do bottom com Tween (fade+slide), vida ~2.6s. API: `Toast.show_msg("✦ ...")`.

---

## ÍCONE DE CADEADO

No HTML o cadeado é desenhado em CSS (corpo + arco). Em Godot há **duas opções** — escolha uma:

- **(A) Sem asset (preferido):** componente `LockIcon.tscn` = um `Control` 13×13 com `_draw()`:
  - corpo: `draw_rect(Rect2(0, 5, 13, 8), GOLD)` com cantos levemente arredondados
  - arco (shackle): `draw_arc(Vector2(6.5, 5), 4, PI, TAU, 16, GOLD, 2.0)`
  - (ou dois `Panel` com StyleBox: um retângulo + um com `border` só no topo e `corner_radius` superior)
- **(B) Com asset:** um ícone `lock.svg`/`lock.png` 16×16 dourado. **Se preferir esse caminho, me avisa que eu te mando o arquivo** — coloque em `res://assets/ui/icons/lock.png` (ou `.svg`).

Mesma lógica para o ícone de **assento** (`SeatDot`) e a **bolinha pulsante** da fila: são só `Panel` circulares (StyleBox `corner_radius` = metade), sem asset.

---

## STYLEBOXES E TEMA

Reaproveite/estenda o tema do projeto. Tokens (OKLCH → sRGB aproximado, espelhando `Room Lobby.html`):

```gdscript
const BG_DEEP      := Color("0a0a16")  # oklch(0.07 0.055 268)
const BG_MID       := Color("11111d")
const BG_SURFACE   := Color("161622")
const PANEL_BG     := Color(0.10, 0.10, 0.18, 0.88)
const GOLD         := Color("c89d4a")  # oklch(0.73 0.13 78)
const GOLD_DIM     := Color("8f6f37")
const GOLD_GLOW    := Color("e6b455")
const CRIMSON      := Color("8a2a2a")  # oklch(0.42 0.20 15)
const CRIMSON_BR   := Color("b34141")
const INDIGO       := Color("5a5fb0")  # rune-color, oklch(0.50 0.14 262) → chip "Flash"
const PARCHMENT    := Color("e8dccb")
const PARCHMENT_D  := Color("b6a78f")
const GREEN_NET    := Color("3fbf7f")  # bolinha de status online
const LINE         := Color(0.78, 0.62, 0.29, 0.15)   # bordas douradas suaves
const LINE_SOFT    := Color(0.78, 0.62, 0.29, 0.10)
```

- **Painéis** (`PanelContainer`): StyleBoxFlat `bg_color = PANEL_BG`, `border_width_all = 1`, `border_color = LINE`, **cantos retos** (sem `corner_radius` — estética angular). Cantos ornamentados (os "L" dourados nos cantos) podem ser 2 `NinePatchRect`/`_draw()` ou ignorados na v1.
- **RoomRow selected**: `border_color = GOLD (a≈0.75)` + leve sombra/glow.
- **GameChip Clássico**: texto GOLD, borda GOLD a0.4, bg GOLD a0.06. **Flash**: texto/borda INDIGO, bg INDIGO a0.10.
- **Botões**:
  - *primário (Conectar/Criar Sala)*: gradient dourado, texto escuro; estado `disabled` = cinza-azulado + texto esmaecido.
  - *ghost (Aleatório/Criar Sala/Cancelar Fila)*: bg azul-escuro, texto/borda gold.
  - *carmesim (Entrar na Fila)*: gradient carmesim, texto claro.
  - *builder*: borda índigo.

**Fontes** (de `res://fonts/` — já usadas no DeckBuilder):
- `CinzelDecorative-Bold.ttf` — marca, nome do deck, emblema "IV"
- `Cinzel-Regular/SemiBold.ttf` — rótulos, botões, IDs, contadores, chips
- `CrimsonPro-Regular/Italic.ttf` — nomes de sala, hints, status, elo

**Hierarquia tipográfica (espelhe o HTML):**
- BrandMark: CinzelDecorative ~28px, gradient gold
- BrandTag / SectionLabel: Cinzel ~11px, letter_spacing 0.28–0.42em, uppercase, gold_dim
- ID / chip / contador jogadores: Cinzel 13–14px
- Nome da sala: CrimsonPro 16px
- Nome do deck: CinzelDecorative 18px gold_glow
- Status/elo/hint: CrimsonPro Italic 13px parchment_dim

---

## INTERAÇÕES E SINAIS

`RoomLobby.gd` mantém `_rooms`, `_selected_id`, `_active_deck_id`, `_queueing` e liga:
- `RoomService.rooms_updated` → re-popula `RoomList` (aplicando filtros) e atualiza contador
- `NumFilter.text_changed` / `NameFilter.text_changed` → `_apply_filters()` (número = `str(id).contains(q)`; nome = case-insensitive `contains`)
- `RoomRow.row_selected(id)` → `_select(id)`: marca a linha, habilita Connect, atualiza texto `⚔ Conectar · #id`
- `ConnectButton.pressed` → se sala `locked` abre `PasswordModal`; senão `RoomService.join_room(id)`
- `RandomButton.pressed` → `RoomService.join_random()` (toast se não houver sala livre)
- `CreateButton.pressed` → abre `CreateRoomModal`
- `CreateRoomModal.create_requested(data)` → `RoomService.create_room(...)`, seleciona nova sala, toast
- `DeckSelector.deck_changed(id)` → salva `active_deck_id`, toast
- `RankedButton.pressed` → alterna fila (`enter/leave_ranked_queue`), troca rótulo do botão + mostra/esconde `QueueingRow`
- `BuilderButton.pressed` → `get_tree().change_scene_to_file("res://scenes/ui/deckbuilder/DeckBuilder.tscn")`
- `CloseButton.pressed` → desconecta (se conectado) e volta ao menu/conexão; emite `GameBus` se fizer sentido
- `RoomService.join_result(ok, msg)` → ok: troca para `board.tscn`; senão: toast de erro

**Validações + toasts:** sala cheia não selecionável; "Nenhuma sala disponível" no aleatório vazio; "Criar Sala" exige nome (e senha se privada); senha incorreta → toast e mantém modal.

---

## ANIMAÇÕES

- **Partículas**: faíscas douradas/carmesim subindo lentamente (CPUParticles2D, ~22, gravidade negativa, alpha curve fade-in/out).
- **Fog**: alpha pulsando 0.5↔0.85 em ~22s (Tween loop).
- **RoomRow hover**: `position.x += 2` + leve clareada do bg (Tween 0.12–0.2s).
- **Seleção**: borda gold aparece com Tween rápido.
- **PasswordReveal** (modal): expandir altura 0→auto + `modulate.a 0→1` em 0.3s.
- **Modal**: surge com `scale 0.94→1` + fade em 0.28s.
- **Toast**: slide-up do bottom + fade, vida 2.6s.
- **PulseDot** (fila): `scale 0.8↔1.2` + alpha 0.3↔1 em loop 1.1s.

---

## ESCALA / RESPONSIVIDADE

Pensada para **1920×1080**, funcional a partir de **1280×720**:
- `Project Settings > Display > Window > Stretch Mode = canvas_items, Aspect = expand`
- Colunas via `size_flags_stretch_ratio` (esquerda **3** / direita **1**); a coluna direita pode ter `custom_minimum_size.x` (~360) para não espremer.
- A lista usa `ScrollContainer` com `RoomList` em `VBoxContainer` (uma linha por sala — sem grid de colunas variáveis).

---

## ORDEM SUGERIDA DE IMPLEMENTAÇÃO

1. Autoload `RoomService.gd` com dados mock (espelhe `INITIAL_ROOMS`) + tipos (`RoomInfo`)
2. Tema/StyleBoxes + carregar fontes (reuso do DeckBuilder)
3. `RoomLobby.tscn` esqueleto (topbar + 2 colunas vazias + background/atmosfera)
4. `RoomRow.tscn` + popular lista + estados (normal/hover/selected/full) + `LockIcon`
5. Filtros (número + nome) + contador + estado vazio
6. ActionBar: seleção habilita Conectar; Aleatório; Criar
7. `CreateRoomModal.tscn` (tipo toggle + checkbox privada + reveal senha + validação)
8. Coluna direita: `DeckSelector.tscn` (lê DeckStore) + `RankedPanel` (emblema + fila) + Builder
9. `PasswordModal.tscn` + `Toast.tscn` + integração de rede no `RoomService.join_room`
10. Polimento: partículas, fog, hovers, animações, edge cases (lista vazia, todas cheias, sem decks)

---

## REFERÊNCIA VISUAL

**Leia `Room Lobby.html` (e `room-lobby-app.jsx`) na raiz do projeto antes de começar.** Têm o layout exato, todas as cores OKLCH, espaçamentos, chips, estados de botão e o modal. Não invente — espelhe. Em dúvida sobre um estilo, abra o HTML no navegador e inspecione o elemento, ou me pergunte.

---

## ASSETS

A tela é **toda desenhável** (cores, fontes, glyphs Unicode `✕ ⚔ ⚒ ⚄ ✚ ✦ ▼ ✓` e shapes via `_draw()`/`StyleBox`). **Não preciso de nenhuma imagem nova** para a v1.

Opcionais (se você preferir não desenhar via código) — **me avise e eu te mando**:
- `res://assets/ui/icons/lock.png` (ou `.svg`) — ícone de cadeado 16×16 dourado
- `res://assets/ui/icons/rank_silver.png` — emblema de tier rankeado (substitui o losango desenhado)
- `res://fonts/` — **necessário** que as fontes Cinzel Decorative / Cinzel / Crimson Pro já estejam lá (as mesmas do DeckBuilder). Se ainda não estiverem, me avisa que eu te passo os `.ttf`.

---

## ENTREGÁVEIS

Ao final, quero:
- [ ] `res://scenes/ui/lobby/RoomLobby.tscn` rodando
- [ ] Sub-cenas: `RoomRow`, `CreateRoomModal`, `PasswordModal`, `DeckSelector`, `Toast` (+ `LockIcon` se via cena)
- [ ] Autoload `RoomService` registrado em `project.godot` (mock agora, com `# TODO: LAN discovery`)
- [ ] Filtros (número/nome), seleção, criar sala, conectar, aleatório e fila rankeada funcionando com os mocks
- [ ] Troca de cena para `DeckBuilder.tscn` pelo botão Deck Builder
- [ ] Deck ativo lido do `DeckStore` e persistido em `user://settings.cfg`

Pode começar.
