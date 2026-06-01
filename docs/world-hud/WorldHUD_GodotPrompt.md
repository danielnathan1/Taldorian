# Prompt para Claude Code — `WorldHUD.tscn` (Godot 4)

Cole o conteúdo abaixo no Claude Code. Ele assume que o projeto Godot do **Taldorian TCCG** já existe em `res://`, que a cena de mundo aberto (`OverWorld.tscn` ou equivalente) já roda com o personagem e o sistema de chat, e que `Lobby.tscn` e `HeroPick.tscn` (seleção de heróis / entrada de partida) já existem.

---

## CONTEXTO

Estou desenvolvendo **Taldorian TCCG** em Godot 4.x. No **mundo aberto**, hoje só existem o personagem e o chat — sem nenhuma HUD. Quero uma **interface limpa, em estilo pixel art**, sobreposta ao mundo, dividida em três cantos:

1. **Superior esquerdo — Cartão do Jogador:** avatar com **moldura customizável** e **foto customizável**, nome, e — em tamanho menor — **ouro** e **rank**. Há também uma barra de XP fina abaixo.
2. **Inferior esquerdo — Chat:** painel com **abas** (Global, Privado, Guild), log de mensagens rolável e campo de digitação.
3. **Inferior direito — Barra de ícones:** **Batalha** (espadas cruzadas, em destaque), **Inventário** (mochila), **Decks** (pilha de cartas), **Amigos** (boneco, com contador de online) e **Sair** (botão de desligar).

A referência visual completa em HTML/CSS está em **`World HUD.html`** na raiz do projeto. **Leia esse arquivo antes de começar** — ele tem o layout exato, cores, fontes, espaçamentos, animações e todos os estados de hover/ativo/badge.

## OBJETIVO

Construa **`res://scenes/ui/worldhud/WorldHUD.tscn`** — uma HUD que:

1. É um **overlay** (`CanvasLayer`) desenhado por cima do mundo, **sem bloquear** o input do jogo nas áreas vazias (só os painéis capturam clique).
2. Mostra o **cartão do jogador** no topo-esquerda, o **chat** embaixo-esquerda e a **barra de ícones** embaixo-direita.
3. Usa **painéis pixel** translúcidos com borda de 2px e bevel (clarear no topo, escurecer na base), renderização nearest-neighbor.
4. É **autocontida** — expõe sinais públicos para a cena do mundo reagir (abrir batalha, inventário, decks, amigos, logout; enviar mensagem de chat), sem conhecer a lógica interna do jogo.
5. **Persiste** o avatar customizado (foto + moldura escolhida) em `user://profile.cfg`.

A cena nasce em **1280×720** e cobre o viewport inteiro, com os três blocos **ancorados nos cantos** (não centralizados) — eles devem grudar nos cantos em qualquer resolução.

---

## PALETA & TIPOGRAFIA (extraídos do HTML)

```
Fundo painel      rgba(21, 24, 31, 0.86)   # var --panel + --hud-alpha
Borda clara       #3a4150                   # --line-bright
Borda escura      #2a2e3a                   # --line
Texto             #e7e3da                   # --ink
Texto dim         #b7b6ad                   # --ink-dim
Muted             #8b8f9c / #6b6f7c
Acento (azul)     #87cee4                   # --accent  (customizável)
Acento profundo   #4f97ad                   # --accent-deep
Ouro              #e0b04a / #f5cf6a         # moeda, badge de nível
Sussurro (pv)     #b89cff                   # nomes no chat privado
Guild             #8fd99a                   # nomes no chat guild, online dot
Perigo            #e0795f                   # botão Sair
```

- **Números e rótulos** (ouro, rank, nível, abas, badges, ticks): fonte **pixel/bitmap** — use **Silkscreen** (Google Fonts) importada como `.ttf`, ou a fonte pixel já usada no jogo. Tamanhos pequenos: 8–11px, caps, `letter_spacing` ~0.08em.
- **Corpo** (nome do jogador, mensagens de chat, input): **monospace** — use a mono padrão do projeto (a mesma da tela de sprite). Nome 16px bold; mensagens 12.5px.
- Importe as fontes como recurso e aplique via `theme_override_fonts` / theme. **Não** escale fontes individualmente — escale o Control raiz.

> **Pixel-perfect:** todas as texturas (ícones, avatar, fill de barra) com `texture_filter = TEXTURE_FILTER_NEAREST`. O Control raiz e o subviewport (se usado) devem manter snapping de pixel.

---

## ÁRVORE DE CENAS

### `WorldHUD.tscn`
```
WorldHUD (CanvasLayer, layer=8)  [script: world_hud.gd]
└─ Root (Control, anchors=full_rect, mouse_filter=IGNORE)   # não bloqueia o mundo
   │
   ├─ PlayerCard (PanelContainer, anchor=top_left, offset=18/18, style=hud_panel)
   │  └─ VBox (VBoxContainer, separation=0)
   │     ├─ Top (HBoxContainer, separation=12, padding via Margin 11/12/10/12)
   │     │  ├─ AvatarFrame (Control, custom_minimum_size=Vector2(60,60))  [AvatarFrame.tscn]
   │     │  │   ├─ FrameBg   (NinePatchRect/ColorRect, moldura customizável)
   │     │  │   ├─ Photo     (TextureRect, foto do jogador, KEEP_ASPECT_COVERED, clipado)
   │     │  │   ├─ Corners   (4 ColorRect 7×7 nos cantos = enfeite pixel)
   │     │  │   └─ LevelBadge(Label "LV 24", style=level_badge, ancorado embaixo-centro)
   │     │  └─ Info (VBoxContainer, separation=7)
   │     │     ├─ Name (Label "Sagashii", mono 16 bold, --ink)
   │     │     └─ Stats (HBoxContainer, separation=10)
   │     │        ├─ Gold (HBox: Icon ic_coin.svg 14px + Label "1.250" pixel 11px ouro)
   │     │        ├─ Divider (ColorRect 1×13, --line-bright)
   │     │        └─ Rank (HBox: Icon ic_rank.svg 13px + Label "Prata II" pixel 11px dim)
   │     └─ XP (VBoxContainer, padding 0/12/11/12, separation=4)
   │        ├─ XpMeta (HBox justified: Label "EXPERIÊNCIA" pixel 8px muted | "3.4k / 5k")
   │        └─ XpTrack (ColorRect 7px alto, bg #11131a)
   │           └─ XpFill (ColorRect, width=68%, gradient accent→accent-deep, brilho topo)
   │
   ├─ Chat (PanelContainer, anchor=bottom_left, offset=18/-18, custom_minimum_size.x=376)
   │  └─ VBox (VBoxContainer, separation=0)                 [ChatPanel — chat_panel.gd]
   │     ├─ Tabs (HBoxContainer, separation=0)              # borda inferior 2px
   │     │  ├─ TabGlobal  (ChatTab "GLOBAL",  +badge unread)
   │     │  ├─ TabPrivado (ChatTab "PRIVADO", +badge unread)
   │     │  └─ TabGuild   (ChatTab "GUILD",   +badge unread)
   │     ├─ Log (ScrollContainer, custom_minimum_size.y=158)
   │     │  └─ Messages (VBoxContainer, separation=6, padding 9/11/9/11)
   │     │     └─ [MessageLine…] (RichTextLabel BBCode: hora dim + nome colorido + corpo)
   │     └─ Input (HBoxContainer, separation=0)             # borda superior 2px
   │        ├─ Prefix (Label do canal atual, pixel 8px accent, bg escuro)
   │        ├─ Field  (LineEdit "Pressione Enter para conversar…", mono 12.5px)
   │        └─ Send   (Button flat, icon ic_send.svg 15px, hover→accent)
   │
   └─ IconBar (PanelContainer, anchor=bottom_right, offset=-18/-18, style=hud_panel)
      └─ HBox (HBoxContainer, separation=8, padding 8/8/8/8)
         ├─ BtnBattle    (HudButton, icon ic_battle.svg,    variation=battle)   # destaque azul
         ├─ Sep          (ColorRect 2px largura, --line-bright)
         ├─ BtnInventory (HudButton, icon ic_inventory.svg, tooltip "Inventário")
         ├─ BtnDecks     (HudButton, icon ic_decks.svg,     tooltip "Decks")
         ├─ BtnFriends   (HudButton, icon ic_friends.svg,   tooltip "Amigos", +badge online)
         │   └─ FriendsPopover (PanelContainer, visible=false, ancorado acima-direita)
         │       ├─ Head (HBox: "AMIGOS" guild + "N online" muted)
         │       └─ List (VBox: [FriendRow: dot status + nome + status texto])
         └─ BtnLogout    (HudButton, icon ic_logout.svg, variation=danger, tooltip "Sair")
```

> Marque cada nó dinâmico com **Unique Name in Owner** (`%`): `%PlayerCard`, `%Photo`, `%FrameBg`, `%LevelBadge`, `%GoldLabel`, `%RankLabel`, `%XpFill`, `%Messages`, `%Field`, `%BtnFriends`, `%FriendsPopover`, abas e badges.

---

## CENAS FILHAS REUTILIZÁVEIS

### `HudButton.tscn` — botão quadrado da barra inferior direita
```
HudButton (Button, custom_minimum_size=Vector2(50,50),
           theme_type_variation=hud_button_default)  [hud_button.gd]
├─ Icon  (TextureRect, anchors=center, custom_minimum_size=Vector2(24,24),
│         stretch_mode=KEEP_ASPECT_CENTERED, modulate=--ink-dim, NEAREST)
├─ Badge (Label, ancorado canto sup-direito, pixel 8px, bg=guild, visible só se >0)
└─ Tooltip (Label/Panel acima do botão, pixel 8px caps, aparece no hover)
```
Variações de tema:
- `hud_button_default` — bg gradient `#232733→#1a1d26`, border `--line-bright`, color `--ink-dim`. Hover: color/border `accent`, sobe 2px, glow.
- `hud_button_battle`  — color/border já em `accent`, bg `#243642→#18222a`, glow leve permanente. Hover: brilho +15%.
- `hud_button_danger`  — hover: color `--danger`, border `#7a4035`.

### `ChatTab.tscn`
```
ChatTab (Button, flat, theme_type_variation=chat_tab)  # expand_h, fill
├─ Label (texto da aba, pixel 9px caps, color muted; ativo=accent)
├─ Badge (Label unread, pixel 8px, bg=accent, color escuro, visible se >0)
└─ Underline (ColorRect 2px, accent, visible só na aba ativa, com glow)
```

### `AvatarFrame.tscn` — moldura + foto customizáveis
```
AvatarFrame (Control, 60×60)  [avatar_frame.gd]
├─ FrameBg  (Panel/NinePatchRect — cor da moldura, ver MOLDURAS abaixo)
├─ PhotoClip(Control, clip_contents=true)
│   └─ Photo (TextureRect, KEEP_ASPECT_COVERED)   # foto do jogador
├─ Corner_TL / TR / BL / BR (ColorRect 7×7, cor de destaque da moldura)
└─ LevelBadge (Label "LV 24")
```
API: `set_photo(tex: Texture2D)`, `set_frame(id: String)`, `set_level(n: int)`.

### `FriendRow.tscn`
```
FriendRow (HBoxContainer, separation=9, padding 6/6)
├─ Dot   (ColorRect 8×8: on=guild+glow / idle=gold / off=#4a4e58)
├─ Name  (Label mono 12.5px, --ink-dim, expand_h)
└─ Status(Label pixel 8px, --muted-2)
```

---

## ASSETS ANEXADOS (já gerados — em `res://assets/ui/worldhud/`)

Importe estes SVGs no projeto (Godot importa SVG nativamente; defina `texture_filter = NEAREST` no uso). Todos são monocromáticos em branco e devem ser **tingidos via `modulate`** no nó, exceto a moeda e o rank que já vêm coloridos.

| Arquivo | Uso | Cor |
|---|---|---|
| `assets/ui/worldhud/ic_battle.svg`    | Botão **Batalha** (espadas cruzadas) | tingir com `accent` |
| `assets/ui/worldhud/ic_inventory.svg` | Botão **Inventário** (mochila)       | `--ink-dim` |
| `assets/ui/worldhud/ic_decks.svg`     | Botão **Decks** (pilha de cartas)    | `--ink-dim` |
| `assets/ui/worldhud/ic_friends.svg`   | Botão **Amigos** (boneco)            | `--ink-dim` |
| `assets/ui/worldhud/ic_logout.svg`    | Botão **Sair** (power)               | `--ink-dim` → hover `--danger` |
| `assets/ui/worldhud/ic_send.svg`      | Botão **Enviar** do chat (avião)     | `--muted` → hover `accent` |
| `assets/ui/worldhud/ic_coin.svg`      | Ícone de **ouro** no cartão          | já colorido (dourado) |
| `assets/ui/worldhud/ic_rank.svg`      | Ícone de **rank** (escudo+estrela)   | já colorido (prata) |

> A **foto do avatar** é fornecida pelo jogador em runtime (upload/seleção) — não há asset fixo. Use um placeholder `#181b22` quando não houver foto. No HTML isso é um slot arrastável; em Godot, exponha `set_photo()` e persista o caminho/bytes em `user://profile.cfg`.

---

## MOLDURAS DO AVATAR (customizável)

Quatro presets selecionáveis (mesmos valores do HTML). Cada moldura = cor base (`a`) + cor de destaque dos cantos (`b`) + glow opcional:

| ID | Base (a) | Destaque (b) | Glow |
|---|---|---|---|
| `iron`     | `#4a515f` | `#8b92a0` | nenhum |
| `ouro`     | `#8a6a1e` | `#f0c95f` | `rgba(240,201,95,0.55)` |
| `azure`    | `#3a6e80` | `#87cee4` | `rgba(135,206,228,0.55)` |
| `carmesim` | `#7a2f2a` | `#e0795f` | `rgba(224,121,95,0.50)` |

`set_frame(id)` aplica `a` no fundo da moldura, `b` nos 4 cantos 7×7, e o glow como sombra externa. Persistir o ID escolhido.

---

## ESTILOS DE PAINEL (theme `worldhud_theme.tres`)

`hud_panel` (StyleBoxFlat):
- `bg_color = Color(21/255, 24/255, 31/255, 0.86)`
- `border_width = 2` em todos os lados, `border_color = #3a4150`
- bevel: simular via `shadow`/`expand_margin` — clarão de 2px no topo (`rgba(255,255,255,0.05)`) e sombra de 2px na base (`rgba(0,0,0,0.35)`). Sombra externa: `0 8px 22px rgba(0,0,0,0.45)`.
- `corner_radius = 0` (cantos retos, pixel).
- Opcional: aplicar leve blur do fundo (no HTML é `backdrop-filter blur(6px)`) — em Godot isso exige um `BackBufferCopy` + shader; **é não-crítico**, pode pular e deixar só o painel translúcido.

`xp_track` bg `#11131a` com sombra interna; `xp_fill` gradient vertical `accent→accent-deep` com linha clara de 1px no topo e marcador branco 2px na ponta direita.

---

## DADOS DE EXEMPLO (seed do chat — replicar do HTML)

```
GLOBAL
  20:41  Thalwen: alguém pra dungeon do Pântano? falta 1
  20:42  [Sistema]: Evento "Lua de Sangue" começa em 10 min   (cor ouro, sem ":")
  20:43  Korrin: vendo booster lendário, chama no pv
  20:44  Mirae: gg na última, teu deque de relâmpago é insano
  20:45  Bromm: alguém sabe onde dropa o Selo de Tal'dorian?
PRIVADO  (prefixo → para enviadas)
  20:39  Bromm → você: bora um 1v1 rankeado?
  20:40  você → Bromm: já vou, só montar o deque
  20:44  Bromm → você: fechou, te mando o convite
GUILD
  20:30  Sayen: reunião da Ordem hoje 21h, presença vale ouro
  20:33  Dorne: subi pra Prata II, valeu pela ajuda no treino
  20:38  Vael: guild war sábado — confirmem no quadro
```
Cores de nome por canal: Global = `accent`; Privado = `#b89cff`; Guild = `#8fd99a`; Sistema = ouro. "você" em `--ink`.

Lista de **amigos** (popover):
```
Bromm   • No mundo    (on)
Sayen   • Em partida  (on)
Mirae   • No mundo    (on)
Korrin  • Loja        (on)
Thalwen • Ausente     (idle)
Dorne   • Offline·2h  (off)
Vael    • Offline·1d  (off)
```
Badge do botão Amigos = nº de `on` (=4).

---

## INTERAÇÃO / FLUXO

1. **Abas do chat** — clicar troca o log exibido e **zera o unread** daquela aba. Mensagens que chegam numa aba inativa incrementam o badge de unread dela.
2. **Enviar mensagem** — Enter no `Field` (ou clicar Enviar) adiciona a linha no canal atual (prefixo do canal aparece à esquerda do input). Em Privado, a linha enviada usa o formato `você → <alvo>:`.
3. **Mensagens ambiente** (opcional, fiel ao HTML) — um `Timer` injeta mensagens fake a cada ~9s em canais variados para dar vida ao mundo e exercitar os badges. Pode ser desligado por um export `ambient_chat := true`.
4. **Botão Batalha** — emite `battle_requested`. A cena do mundo decide (abrir matchmaking / `HeroPick.tscn`).
5. **Inventário / Decks** — emitem `inventory_requested` / `decks_requested` (ou navegam direto pra `DeckBuilder.tscn`, conforme o projeto).
6. **Amigos** — alterna o `FriendsPopover`; clique fora fecha (capturar via `_gui_input` no Root ou um `Popup`).
7. **Sair** — emite `logout_requested`; o host pode confirmar e voltar para `Lobby.tscn`.
8. **Avatar** — `AvatarFrame` aceita foto e moldura via API; mudanças persistem em `user://profile.cfg`.

---

## ANIMAÇÕES (replicar do HTML)

| Elemento | Gatilho | Propriedade | De → Até | Duração |
|---|---|---|---|---|
| HudButton    | hover  | `position:y`, glow         | base −2, sombra accent          | 0.10s |
| HudButton    | press  | `scale`                    | 0.95 (e volta)                  | 0.08s |
| ChatTab      | ativa  | underline + color          | aparece accent                  | 0.12s |
| FriendsPopover | abrir | `modulate:a`, `scale`     | 0→1, 0.96→1.0                   | 0.15s |
| Sprite (mundo) | loop | idle 2-frame               | alterna a cada 1.3s             | — (não-crítico, já é do mundo) |
| Toast        | abrir  | `modulate:a`, `position:y` | 0→1, +8→0                       | 0.22s |

**Toasts:** mensagens curtas centralizadas embaixo-centro (ex.: "Batalha — buscando partida…", "Saindo… voltando ao lobby"). Painel escuro com borda; somem em ~2.6s. Reutilize um nó `ToastLayer` simples.

---

## INTEGRAÇÃO COM A CENA DO MUNDO

No script do mundo aberto (`over_world.gd`):
```gdscript
const WORLD_HUD_SCENE := preload("res://scenes/ui/worldhud/WorldHUD.tscn")

@onready var hud: WorldHUD = WORLD_HUD_SCENE.instantiate()

func _ready() -> void:
    add_child(hud)
    hud.battle_requested.connect(_on_battle)
    hud.logout_requested.connect(_on_logout)
    hud.decks_requested.connect(func(): get_tree().change_scene_to_file("res://scenes/DeckBuilder.tscn"))
    hud.chat_message_sent.connect(_on_chat_sent)
    # alimentar dados reais:
    hud.set_player({ "name": "Sagashii", "level": 24, "gold": 1250, "rank": "Prata II", "xp": 0.68 })

func _on_battle() -> void:
    get_tree().change_scene_to_file("res://scenes/HeroPick.tscn")

func _on_logout() -> void:
    get_tree().change_scene_to_file("res://scenes/Lobby.tscn")
```

---

## SINAIS PÚBLICOS

A `WorldHUD` deve expor exatamente:
- `signal battle_requested`
- `signal inventory_requested`
- `signal decks_requested`
- `signal friends_toggled(open: bool)`
- `signal logout_requested`
- `signal chat_message_sent(channel: String, text: String)`

E os métodos de alimentação:
- `set_player(data: Dictionary)` — name, level, gold, rank, xp(0..1)
- `set_avatar_photo(tex: Texture2D)` / `set_avatar_frame(id: String)`
- `push_chat(channel: String, who: String, body: String, is_system := false)`
- `set_friends(list: Array)` — atualiza popover + badge de online

---

## ESCALA / RESPONSIVIDADE

- **Tamanho nativo:** 1280×720.
- O `CanvasLayer` cobre o viewport; o `Root` Control usa `anchors=full_rect` com `mouse_filter=IGNORE`.
- Os três blocos são **ancorados nos cantos** (não centralizados) com offset de 18px — assim grudam nos cantos em qualquer resolução.
- Se precisar escalar para telas muito pequenas, aplique `scale = min(viewport.x/1280, viewport.y/720)` no Root (mesmo padrão das outras cenas), mantendo o snapping de pixel.

---

## ENTREGÁVEIS

- [ ] `res://scenes/ui/worldhud/WorldHUD.tscn` + `world_hud.gd`
- [ ] `res://scenes/ui/worldhud/HudButton.tscn` + `hud_button.gd`
- [ ] `res://scenes/ui/worldhud/ChatTab.tscn`
- [ ] `res://scenes/ui/worldhud/AvatarFrame.tscn` + `avatar_frame.gd`
- [ ] `res://scenes/ui/worldhud/FriendRow.tscn`
- [ ] `res://scenes/ui/worldhud/ChatPanel` lógica em `chat_panel.gd`
- [ ] `res://themes/worldhud_theme.tres` (estilos de painel, botões, abas, slider XP)
- [ ] Ícones SVG (já anexados em `res://assets/ui/worldhud/`): `ic_battle`, `ic_inventory`, `ic_decks`, `ic_friends`, `ic_logout`, `ic_send`, `ic_coin`, `ic_rank`
- [ ] Fonte pixel (Silkscreen ou a do jogo) + mono importadas como recurso
- [ ] Persistência de avatar (foto + moldura) em `user://profile.cfg`
- [ ] Integração na cena do mundo (instanciar HUD + conectar sinais)

---

## CHECKLIST DE FIDELIDADE AO HTML

Abra `World HUD.html` lado a lado com a cena Godot e confirme:

- [ ] Três blocos ancorados nos cantos (sup-esq, inf-esq, inf-dir), nada no centro/topo-direita
- [ ] Cartão do jogador: avatar com moldura (cantos 7×7 em destaque), badge "LV 24" dourado embaixo
- [ ] Nome em mono bold; ouro (ícone moeda + nº dourado) e rank (escudo + texto dim) **menores**, lado a lado, separados por um traço
- [ ] Barra de XP fina abaixo, fill azul com marcador branco na ponta e rótulo "EXPERIÊNCIA / 3.4k / 5k"
- [ ] Chat com 3 abas; aba ativa em azul com sublinhado; badge de unread nas inativas
- [ ] Cores de nome por canal corretas (global azul, privado roxo, guild verde, sistema ouro)
- [ ] Privado mostra prefixo "→" nas mensagens enviadas
- [ ] Input com prefixo do canal à esquerda, placeholder e botão enviar (avião) que fica azul no hover
- [ ] Barra inferior direita: **Batalha** primeiro, em destaque azul, separado por um divisor dos demais
- [ ] Demais ícones: Inventário (mochila), Decks (pilha de cartas), Amigos (boneco), Sair (power)
- [ ] Botão Amigos com badge verde do nº de online; popover lista amigos com dot de status
- [ ] Botão Sair fica vermelho no hover
- [ ] Tooltips em caps aparecem acima dos botões no hover
- [ ] Painéis translúcidos com borda 2px e bevel (clarão no topo, sombra na base), cantos retos
- [ ] Render pixel: ícones e barras sem suavização (nearest)

---

## REFERÊNCIA VISUAL

**Leia `World HUD.html` na raiz do projeto antes de começar.** Não invente posições, fontes ou cores — espelhe. As proporções foram desenhadas para 1280×720; use-as como tamanho nativo da cena e ancore os blocos nos cantos.

Pode começar.
