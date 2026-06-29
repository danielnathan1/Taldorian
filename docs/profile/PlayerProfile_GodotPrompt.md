# Prompt para Claude Code — `PlayerProfile.tscn` (Godot 4)

Cole o conteúdo abaixo no Claude Code. Ele assume que o projeto Godot do **Taldorian TCCG** já existe em `res://`, que a **HUD do mundo aberto** (`WorldHUD.tscn`) já roda com o **cartão do jogador** no topo-esquerda (avatar + nome + ouro + rank), e que `Lobby.tscn`, `HeroPick.tscn` e `DeckBuilder.tscn` já existem. A carta `golpe_bruto.png` já está em `res://assets/`.

---

## CONTEXTO

Estou desenvolvendo **Taldorian TCCG** em Godot 4.x. Quero o **perfil do jogador**: um **modal/popover** que abre **por cima da HUD do mundo** quando o jogador **clica no próprio avatar** (o `AvatarFrame` do cartão no topo-esquerda da `WorldHUD`). É um **cartão de identidade** com tudo que define o jogador.

O modal é o **estilo aprovado “Dossiê de Campo” (opção A)**: um painel **horizontal**, nativo da HUD (pixel art, painel slate, rótulos em fonte pixel), com toques cerimoniais de fantasia (nome em serifa, anel dourado no avatar, escudos de rank). Ele mostra:

1. **Coluna de identidade (esquerda):** **avatar redondo** com **anel dourado customizável** e **miolo cinza** quando sem foto, **badge de nível** embaixo, **nome (nick)**, **chip da guild** (brasão + nome) e o **cargo na guild**.
2. **Coluna de detalhe (centro):** **Rank atual em destaque** (escudo grande + tier + pontos) e, ao lado, o **Maior rank** como **selo secundário** menor; abaixo, um bloco de estatísticas com **Vitórias/Derrotas (winrate)**, **Membro desde** e **Aproveitamento**.
3. **Coluna da carta (direita):** **Carta preferida** — uma miniatura da carta favorita do jogador (imagem real da carta), levemente inclinada, com **+ataque** e **elemento**, e o **nome** embaixo.

> Existe também uma **opção B (“Selo da Guilda”)** — um cartão **vertical/cerimonial** com os mesmos dados (avatar em medalhão dourado, escudo grande centralizado, brasão, winrate e carta preferida embaixo). **Construa a opção A como a cena principal.** A opção B é **opcional**, como um *layout/skin alternativo* que reaproveita exatamente as mesmas cenas filhas (escudo de rank, selo, carta preferida, brasão) — descrita no fim deste prompt.

A referência visual completa em HTML/CSS está em **`profile/Player Profile.html`** na raiz do projeto. **Leia esse arquivo antes de começar** — ele tem o layout exato, cores, fontes, espaçamentos, os escudos de rank, a borda dourada do avatar e a carta preferida. (Os componentes ficam em `profile/profile-cards.jsx`.)

## OBJETIVO

Construa **`res://scenes/ui/profile/PlayerProfile.tscn`** — um modal de perfil que:

1. É um **overlay** (`CanvasLayer`, layer acima da HUD) com um **scrim escuro** atrás (escurece + leve blur o mundo/HUD) e o **cartão centralizado**.
2. Mostra **identidade / ranks / estatísticas / carta preferida** conforme o layout “Dossiê de Campo”.
3. Usa **painel pixel** translúcido com borda de 2px e bevel (clarear no topo, escurecer na base), render nearest-neighbor.
4. **Fecha** ao clicar no **X**, ao clicar **fora** do cartão (no scrim) ou ao apertar **Esc**.
5. É **autocontido** — recebe os dados via `set_profile(data)` e expõe sinais públicos (carta preferida clicada, abrir guild, fechar), sem conhecer a lógica do jogo.
6. **Persiste** a customização do avatar (foto + cor do anel) em `user://profile.cfg` — compartilhada com a `WorldHUD`.

A cena nasce em **1280×720** (mesmo nativo da HUD); o cartão tem **largura fixa ~600px** e fica **centralizado**.

---

## PALETA & TIPOGRAFIA (extraídos do HTML)

```
Fundo painel      rgba(21, 24, 31, 0.94)    # --panel
Painel interno    rgba(10, 12, 17, 0.55)    # .panel-inset
Borda clara       #3a4150                    # --line-bright
Borda escura      #2a2e3a                    # --line
Texto             #e7e3da                    # --ink
Texto dim         #b7b6ad                    # --ink-dim
Muted             #8b8f9c / #6b6f7c
Ouro              #e0b04a / #f5cf6a          # anel do avatar, badge, rótulos de rank
Guild             #8fd99a                    # brasão, chip da guild
Vitória           #8fd99a (verde)            # winrate, nº de vitórias
Derrota / Perigo  #e0795f                    # nº de derrotas, hover do X
Acento (azul)     #87cee4                    # selo Platina, detalhes
Miolo do avatar   #2c313c                    # cinza neutro quando sem foto
```

- **Rótulos e números pixel** (RANK ATUAL, MAIOR RANK, CARTA PREFERIDA, PTS, LV, +ataque, %): fonte **pixel/bitmap** — use **Silkscreen** (Google Fonts) `.ttf`, ou a fonte pixel já usada no jogo. Tamanhos 7–11px, caps, `letter_spacing` ~0.08em.
- **Títulos display** (nick, nome do tier de rank): **serifa** — use **Cinzel** (`.ttf`). Nick 19px bold; tier de rank 21px bold (ouro).
- **Corpo / serifa de leitura** (nome da carta, valores de stat, “Membro desde”): **Crimson Pro** (ou a serifa de leitura do projeto), 12–14px.
- Importe as fontes como recurso e aplique via theme. **Não** escale fontes individualmente — escale o Control raiz.

> **Pixel-perfect:** escudos, selos, ícones e a arte da carta com `texture_filter = TEXTURE_FILTER_NEAREST` quando aplicável. O Control raiz mantém snapping de pixel.

---

## ÁRVORE DE CENAS

### `PlayerProfile.tscn`
```
PlayerProfile (CanvasLayer, layer=9)  [script: player_profile.gd]
└─ Root (Control, anchors=full_rect)
   ├─ Scrim (ColorRect, full_rect, color=rgba(8,9,13,0.62), mouse_filter=STOP)  # clique fecha
   │                                                # (blur opcional via BackBufferCopy+shader — não-crítico)
   └─ Card (PanelContainer, anchor=center, custom_minimum_size=Vector2(600,0), style=hud_panel)
      └─ VBox (VBoxContainer, separation=0)
         │
         ├─ TitleBar (HBoxContainer)               # borda inferior 2px, padding 9/12
         │  ├─ Title  (Label "PERFIL DO JOGADOR", pixel 10px, ouro #f5cf6a)
         │  ├─ Spacer (Control, expand_h)
         │  └─ BtnClose (Button 24×24, X, border --line-bright; hover→--danger)   [%BtnClose]
         │
         └─ Body (HBoxContainer, separation=0)      # 3 colunas: 152 | expand | 132
            │
            ├─ Identity (VBoxContainer, separation=9, padding 20/14/16/14)  # borda direita --line
            │  ├─ Avatar (AvatarMedallion.tscn, 104×104)   [%Avatar]   # anel ouro + miolo cinza + LV
            │  ├─ Nick   (Label "Sagashii", Cinzel 19 bold, --ink)      [%Nick]
            │  ├─ GuildChip (HBoxContainer, bg rgba(143,217,154,0.08), borda guild, padding 4/8)
            │  │  ├─ Crest (GuildCrest.tscn 15px, modulate=guild)
            │  │  └─ GName (Label "Ordem de Tal'dorian", Crimson 12, guild, ellipsis)  [%GuildName]
            │  └─ Role   (Label "OFICIAL", pixel 8px, --muted-2)        [%Role]
            │
            ├─ Detail (VBoxContainer, separation=14, padding 16/16)
            │  ├─ Ranks (HBoxContainer, separation=14)
            │  │  ├─ RankMain (HBoxContainer, separation=12, expand_h)
            │  │  │  ├─ Shield (RankShield.tscn, 78px)                  [%CurrentShield]
            │  │  │  └─ RankText (VBoxContainer, separation=3)
            │  │  │     ├─ (Label "RANK ATUAL", pixel 8px, --muted)
            │  │  │     ├─ (Label "Ouro II", Cinzel 21 bold, ouro)      [%CurrentRank]
            │  │  │     └─ (Label "1480 PTS", pixel 9px, --ink-dim)     [%CurrentPts]
            │  │  └─ RankPeak (HBoxContainer, separation=9)             # borda esquerda --line, pad-left 14
            │  │     ├─ Seal (PeakSeal.tscn, 42px)                      [%PeakSeal]
            │  │     └─ PeakText (VBoxContainer, separation=2)
            │  │        ├─ (Label "MAIOR RANK", pixel 8px, --muted)
            │  │        ├─ (Label "Platina I", Cinzel 14, --ink-dim)    [%PeakRank]
            │  │        └─ (Label "TEMP. 3", pixel 7px, --muted-2)      [%PeakSeason]
            │  │
            │  └─ Stats (PanelContainer, style=panel_inset, padding 12/13)
            │     └─ VBox (separation=11)
            │        ├─ WinBlock (VBoxContainer, separation=6)
            │        │  ├─ (Label "VITÓRIAS / DERROTAS", pixel 8px, --muted)
            │        │  └─ WinBar (WinBar.tscn)                         [%WinBar]
            │        └─ Grid (HBoxContainer, separation=22, borda superior --line, pad-top 9)
            │           ├─ StatRow("MEMBRO DESDE", "Mar 2024")          [%SinceRow]
            │           └─ StatRow("APROVEIT.", "65%")                  [%WinrateRow]
            │
            └─ Fav (VBoxContainer, separation=9, padding 18/14/16/14)   # borda esquerda --line
               ├─ (Label "CARTA PREFERIDA", pixel 8px, ouro #e0b04a)
               ├─ FavCard (FavCard.tscn, largura 104, inclinação −5°)   [%FavCard]
               └─ FavName (Label "Golpe Bruto", Cinzel 12, --ink-dim)   [%FavName]
```

> Marque cada nó dinâmico com **Unique Name in Owner** (`%`): `%Avatar`, `%Nick`, `%GuildName`, `%Role`, `%CurrentShield`, `%CurrentRank`, `%CurrentPts`, `%PeakSeal`, `%PeakRank`, `%PeakSeason`, `%WinBar`, `%SinceRow`, `%WinrateRow`, `%FavCard`, `%FavName`, `%BtnClose`.

---

## CENAS FILHAS REUTILIZÁVEIS

### `AvatarMedallion.tscn` — avatar redondo, anel dourado, miolo cinza
```
AvatarMedallion (Control, 104×104)  [avatar_medallion.gd]
├─ Ring   (Panel/TextureRect circular — anel metálico, cor base = --frame-main/ouro,
│          desenhado como gradiente cônico; espessura 5px)            # ver ANEL abaixo
├─ PhotoClip (Control, clip_contents=true, círculo)
│   ├─ Filler (ColorRect #2c313c)               # miolo cinza quando sem foto
│   └─ Photo  (TextureRect, KEEP_ASPECT_COVERED, visible só com foto)
├─ InnerShadow (sombra interna 1px rgba(0,0,0,0.5))
└─ LevelBadge (Label "LV 24", pixel 9px, texto #1a1205, bg gradient ouro, pad 2/7,
               ancorado embaixo-centro, sombra/contorno escuro)
```
API: `set_photo(tex)`, `set_ring_color(c: Color)` (default **#e0b04a / ouro**), `set_level(n)`, `set_glow(on: bool)`.
- **Anel:** gradiente cônico metálico — claro no topo-esquerda → cor base → escuro embaixo → cor base; usar um `GradientTexture2D` cônico ou um shader simples no `Ring`. Borda externa 2px `#14161c` + 3px da cor base escurecida. Glow opcional (sombra externa da cor base).
- **Miolo:** sempre `#2c313c` por trás da foto; com foto, a foto cobre (círculo via `clip_contents`).

### `RankShield.tscn` — escudo de rank (heráldico)
```
RankShield (Control, tamanho param.)  [rank_shield.gd]
├─ Body  (Polygon2D/TextureRect com forma de escudo, preenchimento = gradiente do tier)
│         # clip-path do HTML: polygon(50% 0, 100% 13%, 100% 56%, 50% 100%, 0 56%, 0 13%)
├─ Shine (faixa de brilho no topo, ~46% altura, branco translúcido, blend add)
├─ Star  (ícone estrela 5 pontas, ~46% do escudo, cor = tier escuro)
└─ Div   (Label divisão "II", pixel ~16% do tamanho, branco #faf6ea, embaixo-centro)
```
API: `set_rank(tier: String, div: String)`. O tier define as cores (ver **TIERS DE RANK**).
- Render: forma de escudo via `Polygon2D` (6 vértices, proporção do HTML) com gradiente vertical `clara→base→escura`, contorno 2px `#14161c`, sombra externa suave. Estrela e divisão por cima.

### `PeakSeal.tscn` — selo circular do maior rank
```
PeakSeal (Control, tamanho param.)  [peak_seal.gd]
├─ Disc (círculo, gradiente radial do tier: claro→base→escuro)
├─ Ring (borda 2px #14161c + 3px tier-escuro + glow do tier)
├─ Star (estrela 64%, tier-escuro, opacidade .85)
└─ Div  (Label "I", pixel 10px, texto escuro #1c1304)
```
API: `set_rank(tier, div)`.

### `FavCard.tscn` — miniatura da carta preferida
```
FavCard (Control, largura param., proporção 912:1328)  [fav_card.gd]
├─ Frame (Panel, raio 6px, borda 2px #0c0d11 + contorno 2px ouro)  # clip_contents
│   ├─ Art   (TextureRect, KEEP_ASPECT_COVERED = arte da carta)    # res://assets/golpe_bruto.png
│   └─ Gloss (brilho diagonal canto sup-esq, blend add)
└─ Foot (HBoxContainer, justify)                                   # margin-top 4
   ├─ Atk (Label "+3", pixel 11px, --danger)
   └─ El  (Label "FOGO", pixel 8px, ouro #f5cf6a, caps)
```
API: `set_card(data)` — `name, element, atk, art(Texture2D)`. Inclinação aplicada via `rotation` do nó (−5° na opção A; 0° na opção B). Sombra projetada (drop shadow).
- **Hover (opcional):** leve `scale` 1.03 + sombra; clique emite `pressed` → host abre a carta.

### `GuildCrest.tscn` — brasão (escudo + estrela)
```
GuildCrest (TextureRect/Control, tamanho param.)
└─ desenho: escudo com estrela central; tingir via modulate = cor da guild (#8fd99a)
```
> Pode ser um SVG (`ic_guild_crest.svg`) ou desenho `Polygon2D`. Monocromático, tingível.

### `WinBar.tscn` — barra de vitórias/derrotas
```
WinBar (VBoxContainer)  [win_bar.gd]
├─ Meta (HBoxContainer, justify)            # opcional (mostrar na opção A)
│  ├─ W    (Label "342" verde + "V" pequeno)
│  ├─ Rate (Label "65%", --ink, pixel 11px)
│  └─ L    (Label "188" vermelho + "D" pequeno)
└─ Track (ColorRect 8px, bg #11131a, sombra interna)
   └─ Fill (ColorRect, width = winrate%, gradient verde guild→verde escuro, brilho topo 1px)
```
API: `set_record(w: int, l: int)` → calcula `winrate = round(w/(w+l)*100)` e ajusta o fill. `show_meta(bool)`.

### `StatRow` (inline, não precisa de cena)
```
StatRow (VBoxContainer ou HBox)
├─ K (Label rótulo, pixel 8px caps, --muted)
└─ V (Label valor, Crimson 14 semibold, --ink-dim)
```

---

## TIERS DE RANK (cores — replicar do HTML `TIERS`)

Cada tier = cor base (`c`) + cor escura (`d`) + glow (`g`). O escudo usa gradiente `clara(base+branco)→base→escura`; estrela e divisão derivam de `d`.

| Tier | Base `c` | Escura `d` | Glow `g` |
|---|---|---|---|
| `Bronze`   | `#c89058` | `#6f4a26` | `rgba(200,144,88,0.55)` |
| `Prata`    | `#cdd2dd` | `#828998` | `rgba(205,210,221,0.55)` |
| `Ouro`     | `#f1c659` | `#a87d1e` | `rgba(241,198,89,0.60)` |
| `Platina`  | `#86e6da` | `#3c969c` | `rgba(134,230,218,0.55)` |
| `Diamante` | `#a4d2ff` | `#4f8ad0` | `rgba(164,210,255,0.60)` |
| `Mestre`   | `#ec8ba0` | `#a3486a` | `rgba(236,139,160,0.60)` |
| `Lenda`    | `#f7e7a6` | `#c9a23e` | `rgba(247,231,166,0.65)` |

---

## ASSETS

| Arquivo | Uso | Observação |
|---|---|---|
| `res://assets/golpe_bruto.png` | Arte da **carta preferida** (já existe) | 912×1328; `KEEP_ASPECT_COVERED`, NEAREST |
| `res://assets/ui/worldhud/ic_rank.svg` | (opcional) ícone de rank reaproveitado | já colorido |
| `ic_guild_crest.svg` (gerar, opcional) | Brasão da guild | branco monocromático, tingir com guild |
| Foto do avatar | fornecida em runtime | placeholder miolo `#2c313c` quando sem foto |

> A **carta preferida** é definida pelo jogador (a carta favorita dele). Para o protótipo, use `golpe_bruto.png` (Fogo · Ação · Comum · +3) como seed. Exponha `set_favorite_card(data)`.

---

## ESTILOS DE PAINEL (theme `profile_theme.tres` — pode estender `worldhud_theme.tres`)

`hud_panel` (StyleBoxFlat): `bg = rgba(21,24,31,0.94)`, borda 2px `#3a4150`, bevel (clarão 2px topo `rgba(255,255,255,0.05)`, sombra 2px base `rgba(0,0,0,0.35)`), sombra externa `0 18px 44px rgba(0,0,0,0.55)`, cantos retos.

`panel_inset` (StyleBoxFlat): `bg = rgba(10,12,17,0.55)`, borda 1px `#2a2e3a`, sombra interna sutil.

`level_badge`: bg gradient `#f5cf6a→#e0b04a`, texto `#1a1205`, contorno escuro `#14161c`, cantos retos.

`close_btn`: transparente, borda 1px `#3a4150`, ícone `--muted`; hover → `--danger`, borda `#7a4035`.

---

## DADOS DE EXEMPLO (seed — replicar do HTML `PLAYER`)

```gdscript
{
  "nick": "Sagashii",
  "level": 24,
  "current": { "tier": "Ouro",    "div": "II", "pts": 1480 },
  "peak":    { "tier": "Platina", "div": "I",  "season": "Temp. 3" },
  "guild":   { "name": "Ordem de Tal'dorian", "tag": "ORD", "role": "Oficial", "color": Color("#8fd99a") },
  "record":  { "w": 342, "l": 188 },               # winrate = 65%
  "since":   "Mar 2024",
  "fav":     { "name": "Golpe Bruto", "type": "Ação", "element": "Fogo", "rarity": "Comum", "atk": 3,
               "art": "res://assets/golpe_bruto.png" }
}
```

---

## INTERAÇÃO / FLUXO

1. **Abrir** — chamado pela `WorldHUD` quando o jogador clica no próprio `AvatarFrame`. O modal entra com fade + leve scale (ver ANIMAÇÕES).
2. **Fechar** — **X**, clique no **scrim** (fora do cartão) ou **Esc** → fade-out e `queue_free()`/oculta; emite `closed`.
3. **Rank atual em destaque** — escudo grande + nome do tier em ouro + pontos. **Maior rank** ao lado, menor, como **selo** + texto (“Platina I · Temp. 3”).
4. **Winrate** — barra verde proporcional a `w/(w+l)`; números de V (verde) e D (vermelho) e o `%`.
5. **Carta preferida** — clique emite `favorite_card_pressed(card_id)`; o host pode abrir a carta em foco/inspeção.
6. **Chip da guild** — clique (opcional) emite `guild_pressed` para abrir a tela da guild.
7. **Customização do avatar** — `set_avatar_photo()` / `set_ring_color()`; persiste em `user://profile.cfg` (mesmo arquivo da HUD). A cor padrão do anel é **ouro `#e0b04a`**.

---

## ANIMAÇÕES (replicar do HTML)

| Elemento | Gatilho | Propriedade | De → Até | Duração |
|---|---|---|---|---|
| Card    | abrir  | `modulate:a`, `scale`   | 0→1, 0.98→1.0   | 0.20s (ease-out) |
| Card    | fechar | `modulate:a`, `scale`   | 1→0, 1.0→0.98   | 0.15s |
| Scrim   | abrir  | `modulate:a`            | 0→1             | 0.18s |
| BtnClose| hover  | `color`/`border`        | → --danger      | 0.12s |
| FavCard | hover  | `scale`, sombra         | 1.0→1.03        | 0.12s (opcional) |

> Em **reduced-motion** / export, o estado final (visível) deve aparecer sem depender da animação — nasça em opacity 1 e anime só na abertura.

---

## INTEGRAÇÃO COM A `WorldHUD`

No `world_hud.gd`, ao clicar no avatar do cartão:
```gdscript
const PROFILE_SCENE := preload("res://scenes/ui/profile/PlayerProfile.tscn")

func _on_avatar_pressed() -> void:
    var profile := PROFILE_SCENE.instantiate()
    add_child(profile)
    profile.set_profile(_player_profile_data)       # mesmo dict de exemplo
    profile.favorite_card_pressed.connect(_on_fav_card)
    profile.guild_pressed.connect(_on_open_guild)
```
> O `AvatarFrame` da HUD deve virar clicável (um `Button`/`TextureButton` transparente por cima) e emitir `avatar_pressed`. A foto e a cor do anel vêm de `user://profile.cfg`, então HUD e perfil ficam sincronizados.

---

## SINAIS PÚBLICOS

A `PlayerProfile` deve expor:
- `signal closed`
- `signal favorite_card_pressed(card_id: String)`
- `signal guild_pressed`

E os métodos de alimentação:
- `set_profile(data: Dictionary)` — preenche tudo (nick, level, current, peak, guild, record, since, fav)
- `set_avatar_photo(tex: Texture2D)` / `set_ring_color(c: Color)`
- `set_favorite_card(data: Dictionary)`

---

## ESCALA / RESPONSIVIDADE

- **Tamanho nativo:** 1280×720 (mesmo da HUD).
- O `CanvasLayer` cobre o viewport; o `Scrim` usa `full_rect`; o `Card` fica **centralizado** com largura fixa ~600px (altura pelo conteúdo).
- Para telas pequenas, aplique `scale = min(viewport.x/1280, viewport.y/720)` no `Root` (mesmo padrão das outras cenas), mantendo snapping de pixel.

---

## OPÇÃO B (alternativa) — `PlayerProfileSeal.tscn` (cerimonial, vertical)

Mesmos dados e **mesmas cenas filhas** (`RankShield`, `PeakSeal`, `FavCard`, `GuildCrest`, `WinBar`, `AvatarMedallion`), reorganizados num cartão **retrato ~440px** com moldura dourada:

```
Card (PanelContainer, 440 wide, bg dark + glow ouro no topo, borda 2px ouro, filigrana interna)
└─ VBox (center, separation grande)
   ├─ Head:   "✦ PERFIL DO JOGADOR ✦" (Cinzel 9 caps ouro) + Nick (Cinzel Decorative 33 ouro) +
   │           Guild (brasão + nome guild + "· Oficial")
   ├─ Medallion: AvatarMedallion num anel cônico dourado maior (116px) + LV badge
   ├─ Rank:   RankShield 92px centralizado + "Ouro II" (Cinzel 24 ouro) + "1480 pontos…" +
   │           caixinha "Auge: Platina I · Temp. 3" (PeakSeal 34px)
   ├─ Régua:  divisória ornamental "⟡"
   ├─ Stats:  linha "342 VITÓRIAS · 65% · DERROTAS 188" (Cinzel grandes) + WinBar (sem meta) +
   │           "Membro desde Mar 2024"
   └─ Fav:    faixa com FavCard (92px, 0°) + "CARTA PREFERIDA / Golpe Bruto / Fogo · Ação · Comum"
   + BtnClose (X) no canto sup-direito (borda ouro)
```
Use **Cinzel Decorative** no nick; o resto da tipografia segue a paleta acima. Construa **só se** quiser oferecer o skin alternativo — não é obrigatório para entregar o perfil.

---

## ENTREGÁVEIS

- [ ] `res://scenes/ui/profile/PlayerProfile.tscn` + `player_profile.gd`  (opção A)
- [ ] `res://scenes/ui/profile/AvatarMedallion.tscn` + `avatar_medallion.gd`
- [ ] `res://scenes/ui/profile/RankShield.tscn` + `rank_shield.gd`
- [ ] `res://scenes/ui/profile/PeakSeal.tscn` + `peak_seal.gd`
- [ ] `res://scenes/ui/profile/FavCard.tscn` + `fav_card.gd`
- [ ] `res://scenes/ui/profile/WinBar.tscn` + `win_bar.gd`
- [ ] `res://scenes/ui/profile/GuildCrest.tscn` (ou SVG `ic_guild_crest.svg`)
- [ ] `res://themes/profile_theme.tres` (painel, painel interno, badge, botão fechar)
- [ ] Fontes: pixel (Silkscreen) + Cinzel + serifa de leitura (Crimson Pro) importadas como recurso
- [ ] Persistência do avatar (foto + cor do anel) em `user://profile.cfg` (compartilhada com a HUD)
- [ ] Gatilho na `WorldHUD`: avatar clicável → abre `PlayerProfile`
- [ ] (Opcional) `PlayerProfileSeal.tscn` — skin cerimonial vertical (opção B)

---

## CHECKLIST DE FIDELIDADE AO HTML

Abra `profile/Player Profile.html` (opção A “Dossiê de Campo”) lado a lado com a cena Godot e confirme:

- [ ] Modal centralizado, horizontal (~600px), painel slate com borda 2px e bevel; scrim escuro atrás
- [ ] Barra de título "PERFIL DO JOGADOR" (pixel, ouro) + botão **X** que fica vermelho no hover
- [ ] Três colunas: **identidade** | **detalhe** | **carta**, com divisórias finas entre elas
- [ ] **Avatar redondo** com **anel dourado** e **miolo cinza** (sem foto); **badge "LV 24"** dourado embaixo
- [ ] Nick em **serifa (Cinzel) bold**; chip da guild com **brasão verde** + nome; cargo "OFICIAL" em pixel abaixo
- [ ] **Rank atual em destaque:** escudo grande do tier + "Ouro II" em ouro + "1480 PTS"
- [ ] **Maior rank** como **selo menor** ao lado: "MAIOR RANK / Platina I / TEMP. 3"
- [ ] Bloco de stats interno: **VITÓRIAS/DERROTAS** com barra verde (winrate), e linha "MEMBRO DESDE Mar 2024" + "APROVEIT. 65%"
- [ ] Números de vitória em **verde**, derrota em **vermelho**, winrate destacado
- [ ] **Carta preferida** (golpe_bruto) como miniatura **inclinada (−5°)**, com contorno dourado, "+3" e "FOGO" no rodapé, e nome "Golpe Bruto" embaixo
- [ ] Escudos de rank com gradiente do tier, estrela central e divisão (II / I)
- [ ] Render pixel: escudos, selos e arte da carta sem suavização (nearest)
- [ ] Fecha no X, no clique fora (scrim) e no Esc

---

## REFERÊNCIA VISUAL

**Leia `profile/Player Profile.html` na raiz do projeto antes de começar** (componentes em `profile/profile-cards.jsx`). Construa a **opção A (“Dossiê de Campo”)** como a cena principal; a **opção B** é o skin alternativo opcional. Não invente posições, fontes ou cores — espelhe. As proporções foram desenhadas para 1280×720; ancore o cartão no centro.

Pode começar.
