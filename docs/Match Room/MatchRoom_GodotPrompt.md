# Prompt para Claude Code — `MatchRoom.tscn` (Godot 4)

Cole o conteúdo abaixo no Claude Code. Ele assume que o projeto Godot do **Taldorian TCCG** já existe em `res://` com os autoloads (`GameBus`, `NetworkState`, `GameState`) e as cenas anteriores (lobby de conexão, `RoomLobby.tscn`, `DeckBuilder.tscn`, `Board.tscn`).

---

## CONTEXTO

Estou desenvolvendo **Taldorian TCCG**, card game tático em Godot 4.x, multiplayer LAN via `ENetMultiplayerPeer`. Já existem:

- `res://scenes/ui/lobby/RoomLobby.tscn` — navegador de salas (cria/entra em salas)
- `res://scenes/ui/board/Board.tscn` — mesa de jogo
- `res://scenes/ui/deckbuilder/DeckBuilder.tscn` — forja de decks
- Autoloads: `GameBus` (signal bus), `NetworkState` (`local_player_index`, `is_host`), `GameState`, e (do prompt anterior) `RoomService`.

A referência visual completa em HTML/CSS está em **`Match Room.html`** na raiz do projeto, com os componentes em `match-room-app.jsx`. **Leia os dois arquivos antes de começar — espelhe cores OKLCH, layout, estados e animações. Não invente.**

## OBJETIVO

Construir **`res://scenes/ui/match/MatchRoom.tscn`** — a **sala de partida** (lobby pré-jogo de 1v1). É a tela que aparece **logo após criar ou entrar numa sala**, antes do `Board`. Mostra os dois jogadores como pódios circulares no chão com um sigilo **"VS"** no meio; cada jogador confirma "Pronto"; quando ambos confirmam, dispara uma contagem regressiva e troca para o `Board`.

> **Layout (1920×1080, funcional a partir de 1280×720):** topbar com nome/chip/ID da sala + status de rede · arena central com 2 círculos + VS · footer com **Sair da Sala** (carmesim) e **Pronto** (verde, alterna).

---

## REQUISITOS FUNCIONAIS

1. **Topbar**
   - Nome da sala (CinzelDecorative, gradient gold), chip do modo (`Clássico`/`Flash`) e `Sala #id`
   - Status de rede à direita (bolinha verde + "Rede Local · sincronizado")

2. **Arena — dois pódios circulares + VS**
   - **Dois círculos no "chão"** (lado a lado), com sombra elíptica embaixo, **dois anéis de runas girando** (um lento horário, um rápido anti-horário) e leve sensação de piso (elipses faint atrás, via perspectiva/escala).
   - **Sigilo VS** no centro: losango (lozenge) carmesim + losango interno dourado + texto "VS" (CinzelDecorative gradient gold→crimson), com linhas verticais finas acima e abaixo.
   - **Estados do círculo:**
     - **vazio** (slot sem jogador): borda **tracejada** esmaecida, conteúdo "?" + "à espera"; nameplate "Aguardando oponente…"
     - **presente / aguardando** (jogador entrou, não confirmou): borda dourada sólida, avatar (inicial do nome) + tag "⌂ Anfitrião" se host; badge **"aguardando…"** (com reticências animadas) acima
     - **pronto** (confirmou): círculo fica **verde** (borda verde, fill esverdeado, **glow pulsante**), avatar fica verde, e badge **"● PRONTO"** verde aparece acima
   - Abaixo de cada círculo: **nameplate** (nome em Cinzel + deck em CrimsonPro italic + tag "Você" no jogador local).

3. **Footer (barra de ações)**
   - Texto de status à esquerda (ex.: "Confirme quando estiver pronto" / "Aguardando o oponente confirmar…" / "Aguardando um oponente entrar na sala…" / "Ambos prontos — iniciando…")
   - **Sair da Sala** (carmesim) → desconecta e volta ao `RoomLobby.tscn`
   - **Pronto** (verde): ao clicar, **o círculo do jogador local fica verde + badge "PRONTO" aparece** e o botão vira **dourado "✓ Pronto — Cancelar"**. Clicar de novo **volta ao estado de espera** (círculo perde a cor, badge some, botão volta a verde "Pronto").

4. **Início da partida**
   - Quando **ambos** os jogadores estão prontos: overlay de **contagem regressiva** ("A BATALHA COMEÇA EM" + número 3→2→1, CinzelDecorative gigante com glow) e ao fim **troca de cena para `Board.tscn`**.
   - Se alguém cancelar o "pronto" durante a contagem, **aborta** e volta ao estado de espera.

---

## ⭐ PARTÍCULAS DE FUNDO (IMPORTANTE — não esquecer)

O cliente gostou muito das partículas do fundo. Replique fielmente o efeito do HTML (faíscas/cinzas subindo lentamente, douradas e carmesim, com leve drift horizontal e fade-in/out).

Implemente um **`AtmosphereLayer.tscn` reutilizável** (também usado no `RoomLobby`) com:

```
AtmosphereLayer (CanvasLayer, layer = -1, follow_viewport_enabled = false)  [script: atmosphere.gd]
├─ BgGradient (ColorRect, anchors=full_rect, material = bg_gradient.tres)   # gradiente radial/linear do --bg-deep
├─ Fog (ColorRect, anchors=full_rect, material = fog_radial.tres)           # alpha pulsando 0.5↔0.85 em ~22s (Tween loop)
└─ Embers (GPUParticles2D)                                                  # as faíscas
```

**Configuração das `Embers` (GPUParticles2D + ParticleProcessMaterial):**
- `amount = 90`, `lifetime = 11.0`, `preprocess = 8.0` (pré-popula a tela ao abrir), `local_coords = false`
- **Emissão na base, largura toda da tela:** `emission_shape = BOX`, `emission_box_extents = Vector3(960, 8, 1)`, e posicione o nó em `Vector2(960, 1080)` (base inferior, coords 1920×1080)
- **Subir devagar:** `gravity = Vector3(0, -22, 0)`; `direction = Vector3(0, -1, 0)`; `initial_velocity_min = 8`, `initial_velocity_max = 26`
- **Drift horizontal:** `spread = 18`, `linear_accel`/`tangential` leves, ou habilite `turbulence` com `turbulence_noise_strength ≈ 6`, `turbulence_noise_scale ≈ 1.2` para um vaivém orgânico (equivalente ao `--drift` do CSS)
- **Tamanho:** `scale_min = 0.4`, `scale_max = 1.1` (partícula base ~3px); pontos redondos → use uma textura `ember_dot.png` (disco branco 8×8 com leve glow) **ou** um `GradientTexture2D` radial gerado em código
- **Cor variada (dourado/carmesim/índigo) + fade-in/out:** `color_ramp` (GradientTexture1D) começando em alpha 0 → sobe a ~0.6 → cai a 0; e **randomize a cor por partícula** com `color_initial_ramp` contendo as 4 cores do HTML:
  - `#e6b455` (gold-glow), `#c89d4a` (gold), `#b34141` (crimson-bright), `#7d7fc0` (índigo)
- `emission` aditiva: no `CanvasItemMaterial` das partículas use `blend_mode = BLEND_MODE_ADD` para o brilho das faíscas

> **Alternativa sem shader/material custom:** se preferir, use **`CPUParticles2D`** com os mesmos números (`amount=90`, `gravity=(0,-22)`, `emission_rect_extents=(960,8)`, `color_ramp` com fade alpha, `color_initial_ramp` com as 4 cores, `scale_amount_min/max=0.4/1.1`). Visualmente idêntico, e dispensa o `ParticleProcessMaterial`. **Prefira esta opção se quiser zero assets de imagem** (CPUParticles2D desenha pontos sem textura).

A `AtmosphereLayer` deve ficar **atrás de tudo** (layer negativa) e com `mouse_filter = IGNORE` em qualquer Control sobreposto.

---

## DADOS

### Estado do jogador na sala
```gdscript
class_name SeatState extends RefCounted
var present: bool = false
var player_name: String = ""
var initial: String = ""      # 1ª letra do nome (avatar)
var deck_name: String = ""
var is_host: bool = false
var ready: bool = false
```

`MatchRoom.gd` mantém dois seats: `_local` (jogador local, sempre present) e `_remote` (oponente). Popule-os a partir de `NetworkState` / `RoomService` (qual sala, quem é host) e do `DeckStore` (deck ativo, lido do prompt anterior).

### Sincronização em rede (RPC)
A confirmação de "pronto" precisa propagar entre os peers. Use RPCs simples sobre o multiplayer já existente:

```gdscript
@rpc("any_peer", "call_local", "reliable")
func _rpc_set_ready(peer_id: int, value: bool) -> void
    # atualiza o seat correspondente, re-renderiza, e se ambos ready -> _start_countdown()

# ao entrar na sala, troca de presença/identidade:
@rpc("any_peer", "call_local", "reliable")
func _rpc_seat_info(peer_id: int, name: String, deck: String, is_host: bool) -> void
```

> **Autoridade:** o host decide quando a contagem inicia (quando `both_ready`). Use `multiplayer.is_server()` para gatear `_start_countdown()` e propague o tick da contagem por RPC, **ou** rode a contagem local em ambos assim que `both_ready` for verdadeiro (mais simples; aceitável para LAN). Marque `# TODO: revisar autoridade` se for pelo caminho simples.
>
> Por enquanto, se a malha de rede ainda não estiver pronta, **simule o oponente** com dois toggles de debug (espelhe os Tweaks do HTML: "Oponente na sala" / "Oponente pronto") para validar todos os estados visualmente. Marque `# TODO: remover simulação`.

---

## ÁRVORE DE CENAS

### `MatchRoom.tscn`
```
MatchRoom (Control, anchors=full_rect)  [script: match_room.gd]
├─ AtmosphereLayer.tscn (instância — partículas/fog/gradiente, ver seção ⭐)
├─ Root (MarginContainer, anchors=full_rect, padding ~1.2rem/2.6rem)
│  └─ Shell (VBoxContainer)
│     ├─ TopBar (HBoxContainer)
│     │  ├─ RoomHead (HBox → RoomTitle(CinzelDecorative gold) + Chip(modo) + "Sala #id")
│     │  ├─ Spacer (EXPAND)
│     │  └─ NetStatus (HBox → NetDot(Panel circular) + Label "Rede Local · sincronizado")
│     ├─ Divider (HSeparator)
│     ├─ Arena (CenterContainer, size_flags_vertical=EXPAND_FILL)
│     │  ├─ StageFloor (Control — 2 elipses faint, mouse_filter=IGNORE, atrás)
│     │  └─ Matchup (HBoxContainer, separation grande)
│     │     ├─ PlayerSlot.tscn (LEFT — jogador local)
│     │     ├─ VsSigil (VBox → VLine + Vs(Control, _draw losangos + Label "VS") + VLine)
│     │     └─ PlayerSlot.tscn (RIGHT — oponente)
│     └─ Footer (HBoxContainer)
│        ├─ FooterStatus (Label, à esquerda — texto de estado)
│        ├─ Spacer (EXPAND)
│        ├─ LeaveButton (Button carmesim "⬅ Sair da Sala")
│        └─ ReadyButton (Button verde "⚔ Pronto", alterna estado)
├─ CountdownLayer (CanvasLayer, layer=2)
│  └─ Countdown (Control, hidden → Overlay blur + "A BATALHA COMEÇA EM" + NumLabel gigante)
└─ ToastLayer (CanvasLayer, layer=3)
   └─ Toast.tscn (reuso do RoomLobby)
```

### `PlayerSlot.tscn`
```
PlayerSlot (VBoxContainer)  [script: player_slot.gd]
├─ StatusBanner (Control, altura fixa ~2.2rem)
│  ├─ ReadyBadge (HBox → Tick(Panel verde) + Label "PRONTO", hidden)   # animação badgePop ao aparecer
│  └─ WaitingBadge (Label "aguardando" com reticências animadas / "vazio")
├─ CircleStage (Control, ~210px)
│  ├─ CircleShadow (TextureRect/_draw elipse borrada)
│  ├─ Circle (Control, _draw OU Panel circular)  [estados: empty | waiting | ready]
│  │  ├─ RuneRing (Control/Sprite anel, gira lento, _process rotation)
│  │  ├─ RuneRingFast (Control/Sprite anel, gira rápido invertido)
│  │  └─ Content:
│  │     ├─ Occupant (VBox → Avatar(Panel circular + Label inicial) + HostTag "⌂ Anfitrião")
│  │     └─ EmptyMark (VBox → "?" + "à espera")  (um ou outro visível)
└─ NamePlate (VBox → PlayerName(Cinzel) + PlayerDeck(CrimsonPro italic) + YouTag "Você")

func bind(seat: SeatState, is_you: bool) -> void
func set_state(state: String) -> void     # "empty" | "waiting" | "ready" — anima a transição (Tween)
```

> **Transição para "ready":** Tween de 0.5s na cor da borda/fill do círculo (dourado→verde) + cor do avatar; o glow pulsante do estado ready é um Tween em loop no `box-shadow`-equivalente (use um `Panel`/`_draw` com um halo cuja modulate.a pulsa 2.4s). O badge "PRONTO" entra com `scale 0.85→1` + fade (cubic, 0.35s).

---

## ÍCONES / GLYPHS / SHAPES

Tudo desenhável — **nenhuma imagem nova é estritamente necessária**:
- **Círculos, anéis de runa, sombra, losangos do VS, sigilos** → `_draw()` (`draw_circle`, `draw_arc`, `draw_polygon`, `draw_dashed_line`) ou `Panel` com `StyleBoxFlat` (`corner_radius` = metade para virar círculo; bordas `dashed` não existem em StyleBox → use `_draw` para o anel tracejado).
- **Avatar** = `Panel` circular + `Label` com a inicial (CinzelDecorative).
- **Glyphs Unicode** já usados: `⚔ ⬅ ✓ ● ⌂ ? ✦ · VS`.
- **Bolinha de rede / tick / pulse** = `Panel` circular pequeno (`corner_radius` alto) com `StyleBox` colorido + glow via segundo Panel borrado.

---

## ASSETS

A v1 é **toda desenhável + glyphs Unicode + partículas via CPUParticles2D** → **não preciso de nenhuma imagem nova**.

Opcionais (se você preferir textura a `_draw()`) — **crie a pasta e me avise que eu te mando os arquivos**, OU gere proceduralmente:
- `res://assets/vfx/ember_dot.png` — disco branco 8×8 com glow suave (textura das partículas, se usar `GPUParticles2D`). *Pode ser gerado por código com `GradientTexture2D` radial — então nem precisa.*
- `res://assets/ui/rune_ring.png` — anel de runas decorativo (substitui o anel tracejado desenhado).
- `res://assets/ui/icons/lock.png` — (compartilhado com o RoomLobby, se aquele caminho foi escolhido).

**Fontes** (necessárias, em `res://fonts/` — as mesmas do DeckBuilder/RoomLobby): `CinzelDecorative-Bold/Black.ttf`, `Cinzel-Regular/SemiBold/Bold.ttf`, `CrimsonPro-Regular/Italic.ttf`. Se ainda não estiverem no projeto, me avisa que eu te passo os `.ttf`.

> Sugestão de pastas a criar caso vá pelo caminho com assets: `res://assets/vfx/` e `res://assets/ui/` (provavelmente já existem). Coloque materiais `.tres` (gradiente, fog, partículas) em `res://scenes/ui/match/materials/`.

---

## TEMA / TOKENS (sRGB ≈ OKLCH, espelhando `Match Room.html`)

```gdscript
const BG_DEEP      := Color("0a0a16")   # oklch(0.07 0.055 268)
const GOLD         := Color("c89d4a")   # oklch(0.73 0.13 78)
const GOLD_DIM     := Color("8f6f37")
const GOLD_GLOW    := Color("e6b455")
const CRIMSON      := Color("8a2a2a")   # oklch(0.42 0.20 15)
const CRIMSON_BR   := Color("b34141")
const READY        := Color("33b87a")   # oklch(0.68 0.17 150) — verde "pronto"
const READY_GLOW   := Color("4fd693")   # oklch(0.78 0.19 150)
const READY_DEEP   := Color("1c5a3e")   # oklch(0.30 0.10 150)
const INDIGO       := Color("7d7fc0")   # rune-color / partícula índigo
const PARCHMENT    := Color("e8dccb")
const PARCHMENT_D  := Color("b6a78f")
const GREEN_NET    := Color("3fbf7f")
const LINE         := Color(0.78, 0.62, 0.29, 0.15)
```

- Painéis/bordas: **cantos retos**, borda dourada fina (estética angular do projeto).
- **Círculo waiting:** borda `GOLD` a~0.4, fill radial escuro. **ready:** borda `READY` a~0.9, fill esverdeado, halo pulsante `READY_GLOW`. **empty:** borda `GOLD` a~0.22 **tracejada**.
- **VS:** lozenge externo borda `CRIMSON` a0.55; interno borda `GOLD` a0.5; texto gradient gold→crimson.
- Botões: **Pronto** = gradient verde, texto escuro; ao confirmar vira **dourado** ("Cancelar"). **Sair** = gradient carmesim.

**Tipografia:**
- RoomTitle: CinzelDecorative ~24px gradient gold
- Chip/IDs/badges/botões: Cinzel 11–14px, uppercase, letter_spacing 0.18–0.24em
- Avatar: CinzelDecorative ~30px
- PlayerName: Cinzel ~18px · PlayerDeck/status: CrimsonPro italic ~13px
- Countdown num: CinzelDecorative ~120px gold_glow + glow

---

## SINAIS / FLUXO

`match_room.gd`:
- ao abrir: lê sala/host de `RoomService`/`NetworkState`, popula `_local` (com deck ativo do `DeckStore`); `_remote` fica vazio até o peer entrar.
- `ReadyButton.pressed` → alterna `_local.ready`, atualiza `PlayerSlot` esquerdo + botão + footer, e **emite RPC** `_rpc_set_ready(my_id, value)`.
- recebe `_rpc_set_ready` do oponente → atualiza `PlayerSlot` direito; se `both_ready` → `_start_countdown()`.
- `_start_countdown()` → mostra overlay, Tween/Timer 3→2→1 (1s cada), ao fim `get_tree().change_scene_to_file("res://scenes/ui/board/Board.tscn")`. Se `ready` mudar para falso durante → `_abort_countdown()`.
- `LeaveButton.pressed` → desconecta peer (se conectado), `RoomService` libera a sala, e `change_scene_to_file("res://scenes/ui/lobby/RoomLobby.tscn")`. Emita `GameBus.left_room` se útil.
- peer connect/disconnect (`multiplayer.peer_connected/disconnected`) → preencher/limpar `_remote`, toasts ("✦ Vesper entrou na sala" / "✦ O oponente saiu").

**Edge cases:** oponente sai durante a contagem → aborta + toast; ambos host (não deveria) → log; deck ativo ausente → usar "Sem deck" e impedir "Pronto" (toast pedindo escolher deck no RoomLobby).

---

## ANIMAÇÕES (espelhe o HTML)

- **Partículas Embers** (ver ⭐) — faíscas subindo, drift, fade, cores variadas. *Prioridade do cliente.*
- **Fog** — alpha 0.5↔0.85, ~22s, Tween loop.
- **Anéis de runa** — `_process`: ring lento `rotation += dt*TAU/38`; ring rápido `-= dt*TAU/24`.
- **occupantIn** — avatar entra com `scale 0.8→1` + fade 0.5s quando o jogador aparece.
- **ready glow** — halo do círculo pulsa (modulate.a + escala leve) 2.4s loop.
- **badgePop** — badge "PRONTO" `scale 0.85→1` + fade, cubic 0.35s.
- **waiting dots** — reticências "·/··/···" animadas (Timer 1.4s ciclando o texto).
- **countdown** — número com pop por tick (scale 0.7→1→1.1 + fade), overlay fade-in 0.3s.
- **toast** — slide-up do bottom + fade, vida ~2.4s.
- **hover botões** — translateY -2px + brilho (Tween 0.16s).

---

## ESCALA / RESPONSIVIDADE

- `Project Settings > Display > Window > Stretch = canvas_items`, `Aspect = expand`, base 1920×1080.
- Arena central via `CenterContainer`; `Matchup` em `HBoxContainer` com `separation` grande; círculos com `custom_minimum_size` (~190px) e os pódios encolhendo com graça até 1280×720.
- `AtmosphereLayer` cobre o viewport inteiro independente da resolução.

---

## ORDEM SUGERIDA DE IMPLEMENTAÇÃO

1. `AtmosphereLayer.tscn` (⭐ partículas + fog + gradiente) — valide o look primeiro, é a prioridade do cliente.
2. Tema/StyleBoxes + fontes (reuso).
3. `MatchRoom.tscn` esqueleto: topbar + arena + footer sobre a AtmosphereLayer.
4. `PlayerSlot.tscn` + `_draw` do círculo/anéis/sombra + estados (empty/waiting/ready) + nameplate.
5. `VsSigil` (`_draw` losangos + label).
6. Botão Pronto alternando estado local (sem rede ainda) + badges + footer status. Use os 2 toggles de debug pra testar todos os estados.
7. Contagem regressiva + troca para `Board.tscn`; Sair → `RoomLobby.tscn`.
8. Rede: RPCs `_rpc_set_ready`/`_rpc_seat_info` + peer connect/disconnect + toasts; remover simulação.
9. Polimento: animações (occupantIn, ready glow, badgePop, countdown), edge cases.

---

## REFERÊNCIA VISUAL

**Leia `Match Room.html` + `match-room-app.jsx` na raiz do projeto antes de começar.** Têm o layout exato, cores OKLCH, estados dos círculos, o VS, os botões e as animações (incluindo o `spawnParticles()` que inspirou as Embers). Em dúvida, abra o HTML e inspecione, ou me pergunte.

---

## ENTREGÁVEIS

- [ ] `res://scenes/ui/match/MatchRoom.tscn` rodando
- [ ] `res://scenes/ui/common/AtmosphereLayer.tscn` reutilizável (⭐ partículas + fog + gradiente)
- [ ] Sub-cenas: `PlayerSlot.tscn` (+ `Toast.tscn` reusado do RoomLobby)
- [ ] Dois círculos + VS; estados empty/waiting/ready com transições animadas
- [ ] Botão **Pronto** alterna (verde→dourado) e pinta o círculo de verde + badge "PRONTO"; **Sair da Sala** volta ao `RoomLobby`
- [ ] Contagem regressiva quando ambos prontos → troca para `Board.tscn`
- [ ] RPCs de sincronização de "pronto" + presença (mock/simulação removível atrás de `# TODO`)
- [ ] Partículas de fundo idênticas ao HTML (prioridade do cliente)

Pode começar.
