# Prompt para Claude Code — DeckList.tscn (Godot 4)

Cole o conteúdo abaixo no Claude Code. Ele assume que o projeto Godot já existe em `res://` e tem as cenas anteriores do Taldorian TCG (Lobby, HeroPick, Card, Board, DeckBuilder).

---

## CONTEXTO

Estou desenvolvendo **Taldorian TCG**, um jogo de cartas colecionáveis em Godot 4.x. Já existem:

- `res://scenes/ui/lobby/Lobby.tscn`
- `res://scenes/ui/deckbuilder/DeckBuilder.tscn` (construtor de decks — já implementado)
- `res://scenes/ui/board/...` (cenas de mesa de jogo)
- Autoloads `Collection.gd` (heróis/cartas) e `DeckStore.gd` (decks em `user://decks.json`)
- Tema `res://themes/deckbuilder_theme.tres`

A referência visual completa em HTML/CSS está em **`Deck List.html`** na raiz do projeto (lê esse arquivo antes de começar — ele tem todas as cores OKLCH, tipografia, layout, hovers e estados que devem ser fielmente reproduzidos). Os dados de sleeves/playmats/decks estão em `deckbuilder-data.js` (raiz).

## OBJETIVO

Construa **`res://scenes/ui/decklist/DeckList.tscn`** — a tela de **listagem de decks** que aparece **antes** do DeckBuilder. É uma galeria onde o jogador vê todos os seus decks (nome, sleeve e playmat) e pode **selecionar para editar**, **selecionar para apagar**, **criar um novo deck** e **voltar** (canto superior esquerdo).

> **Fluxo de navegação:** Lobby/World HUD → **DeckList** → DeckBuilder.
> O botão "Decks" do World HUD e o botão "voltar" do DeckBuilder devem apontar para esta cena. O "voltar" desta cena vai para o Lobby.

---

## REQUISITOS FUNCIONAIS

1. **Galeria de decks**
   - Grid responsivo de "placas de deck" (`DeckPlate`), uma por deck salvo no `DeckStore`.
   - Cada placa mostra: **showcase** (fundo com a cor/gradiente do **playmat**) + **sleeve** (verso da carta, em leque de 3) + **nome do deck** + **3 heróis** (glyphs de classe) + contagem **Heróis (X/3)** e **Cartas (X/50)** + selo de status (**✦ Pronto** se 3 heróis e 50 cartas, senão **Rascunho**) + rodapé com **nome da sleeve** e **nome do playmat** (com swatches).
   - Última célula do grid é o **tile "Novo deck"** (tracejado, com `+`).

2. **Seleção**
   - Clique numa placa **seleciona** (moldura dourada + corner ticks nos 4 cantos).
   - Apenas um deck selecionado por vez. `Esc` limpa a seleção.
   - Duplo-clique numa placa abre direto o DeckBuilder naquele deck.
   - Ao passar o mouse (hover) sobre a placa, aparecem atalhos rápidos **Editar / Apagar** deslizando de baixo da placa (espelham as ações da barra).

3. **Barra de ação contextual (rodapé)**
   - Some quando nada está selecionado; **desliza de baixo** quando há seleção.
   - Mostra: mini-sleeve + "SELECIONADO" + nome do deck à esquerda; botões **Apagar** (danger) e **Editar deck** (primário dourado) à direita.

4. **Ações de deck**
   - **Editar** → troca de cena para `DeckBuilder.tscn` carregando o deck selecionado (passe o `deck_id`).
   - **Apagar** → abre modal de confirmação (`ConfirmDialog`); ao confirmar, remove do `DeckStore` e mostra toast.
   - **Novo deck** → cria deck novo via `DeckStore.create_new()` e abre o DeckBuilder nele. Há **dois** gatilhos: botão no header (primário) e o tile "Novo deck" do grid.
   - **Voltar** → `Lobby.tscn`.

5. **Header**
   - Esquerda: botão **← Voltar**, separador, eyebrow ("COLEÇÃO" / "Meus Decks").
   - Direita: contador "**N** decks" + botão primário **+ Novo deck**.

---

## DADOS

Reusa `HeroResource`, `CardResource`, `DeckResource`, `Collection` e `DeckStore` já existentes. **Estenda** o `DeckResource` e o `Collection` com sleeve/playmat:

### `DeckResource.gd` — adicionar campos
```gdscript
class_name DeckResource extends Resource
@export var id: String
@export var deck_name: String
@export var hero_ids: Array[String] = []
@export var card_counts: Dictionary = {}   # { "card_id": int_count }
@export var sleeve_id: String = "taldor"    # NOVO
@export var playmat_id: String = "dark"     # NOVO
```

### Sleeves — `res://data/cosmetics/sleeves.gd` (ou dentro de `Collection`)
Todas as sleeves derivam **da mesma arte** (`res://assets/card_back.png` — já existe, é a moldura de pergaminho com cristal dourado). As variantes são a **mesma textura tingida por cor** (igual a sleeves reais). `taldor` é a original (sem tint).

```gdscript
const SLEEVE_ART := preload("res://assets/card_back.png")
const SLEEVES := [
    { "id":"taldor",   "label":"Selo de Taldor",  "tint":Color(0,0,0,0), "swatch":Color("c89d4a") }, # sem tint
    { "id":"crimson",  "label":"Brasão Carmesim", "tint":Color("9b2f2a"), "swatch":Color("a83a32") }, # oklch(0.45 0.20 18)
    { "id":"azure",    "label":"Véu Arcano",      "tint":Color("2f4f9b"), "swatch":Color("3a59a8") }, # oklch(0.42 0.16 258)
    { "id":"verdant",  "label":"Folha Ancestral", "tint":Color("2f7a52"), "swatch":Color("368a5c") }, # oklch(0.42 0.14 150)
    { "id":"obsidian", "label":"Sigilo Sombrio",  "tint":Color("4a2f6a"), "swatch":Color("583a7a") }, # oklch(0.30 0.12 300)
]
```

> **Importante (recoloração da sleeve):** NÃO use `modulate` — ele só escurece, não recolore o dourado. Use um **shader de blend "color"** (igual ao `mix-blend-mode: color` do CSS): mantém a **luminância** da textura e aplica **matiz + saturação** do tint. Veja a seção SHADERS.

### Playmats — espelham os do tabuleiro (`board.html`)
```gdscript
const PLAYMATS := [
    { "id":"dark",     "label":"Sombra Etérea",    "stops":[Color("050215"),Color("0e0928"),Color("190736"),Color("070d28"),Color("020110")], "swatch":Color("190736") },
    { "id":"oriental", "label":"Jardim do Dragão", "stops":[Color("120802"),Color("391705"),Color("582908"),Color("284316"),Color("14280b")], "swatch":Color("391705") },
    { "id":"arcane",   "label":"Câmara Arcana",    "stops":[Color("020318"),Color("060e2c"),Color("0b052e"),Color("040216"),Color("010208")], "swatch":Color("0b052e") },
    { "id":"crimson",  "label":"Terra de Chamas",  "stops":[Color("160202"),Color("2c0505"),Color("160303"),Color("0a0101"),Color("040108")], "swatch":Color("2c0505") },
    { "id":"forest",   "label":"Floresta Élfica",  "stops":[Color("010f07"),Color("031608"),Color("071c0c"),Color("031208"),Color("010703")], "swatch":Color("071c0c") },
]
```
O fundo do showcase é um **gradiente diagonal a ~135°**. Use um `GradientTexture2D` (Gradient com esses stops, `fill = LINEAR`, `fill_from = (0,0)`, `fill_to = (1,1)`) num `TextureRect (stretch=COVER)`, **ou** carregue PNGs de `res://assets/playmats/<id>.png` se existirem (preferir a textura quando disponível, gradiente como fallback).

### Decks de exemplo
O `DeckStore` deve trazer ~5 decks de exemplo (espelhe `DEFAULT_DECKS` em `deckbuilder-data.js`), já com `sleeve_id`/`playmat_id`:
`Inferno Ardente` (crimson/crimson), `Marés Profundas` (azure/arcane), `Vigília de Pedra` (verdant/forest), `Sussurros nas Sombras` (obsidian/dark), `Deck sem nome` (taldor/dark, vazio).

---

## ÁRVORE DE CENAS

### `DeckList.tscn`
```
DeckList (Control, anchors=full_rect)  [script: DeckList.gd]
├─ Background (ColorRect, mouse_filter=IGNORE)            # var(--bg-deep)
├─ AtmosphereLayer (Control, mouse_filter=IGNORE)
│  └─ Vignette (ColorRect/TextureRect com gradient radial inferior)
├─ Root (VBoxContainer, anchors=full_rect)
│  ├─ TopHeader (PanelContainer, custom_minimum_size.y=66)
│  │  └─ HBoxContainer
│  │     ├─ HeaderLeft (HBoxContainer)
│  │     │  ├─ BackButton (Button "← Voltar")            # → Lobby.tscn
│  │     │  ├─ Separator (VSeparator)
│  │     │  └─ EyebrowBlock (VBoxContainer)
│  │     │     ├─ EyebrowLine (Label "COLEÇÃO")
│  │     │     └─ EyebrowTitle (Label "Meus Decks")
│  │     ├─ Spacer (Control, size_flags_horizontal=EXPAND_FILL)
│  │     └─ HeaderRight (HBoxContainer)
│  │        ├─ DeckTally (Label "N decks")
│  │        └─ NewDeckButton (Button primário "+ Novo deck")
│  └─ ListBody (ScrollContainer, size_flags_vertical=EXPAND_FILL)
│     └─ GalleryColumn (VBoxContainer, max width ~1500px centralizado via MarginContainer)
│        ├─ GalleryHead (HBoxContainer)
│        │  ├─ GhTitle (Label "Escolha um deck para jogar ou editar")
│        │  └─ GhHint  (Label "Clique para selecionar · duplo-clique para editar")
│        └─ DeckGrid (GridContainer — colunas recalculadas no resize)
│           ├─ [N x DeckPlate.tscn]
│           └─ NewDeckTile.tscn
├─ ActionBar.tscn (instância, anchor bottom, escondida fora da tela por padrão)
├─ ConfirmDialog.tscn (instância, hidden)
└─ Toast.tscn (instância)
```

### `DeckPlate.tscn` (placa de um deck — custom_minimum_size ≈ Vector2(330, 380))
```
DeckPlate (PanelContainer)  [script: DeckPlate.gd; expõe set_deck(deck) e signal selected/edit_requested/delete_requested]
├─ VBoxContainer
│  ├─ Showcase (Control, custom_minimum_size.y=188, clip_contents=true)
│  │  ├─ PlaymatBg (TextureRect, stretch=COVER)          # gradiente/textura do playmat
│  │  ├─ ShowcaseOverlay (ColorRect/TextureRect)         # vinheta escura p/ leitura
│  │  ├─ PlaymatNamePill (PanelContainer top-left → swatch + label)
│  │  ├─ StatusPill (PanelContainer top-right → "✦ Pronto" / "Rascunho")
│  │  └─ SleeveStack.tscn (instância, centralizado)
│  ├─ Body (MarginContainer → VBoxContainer)
│  │  ├─ NameLabel (Label, CinzelDecorative, dourado; itálico/apagado quando "Deck sem nome")
│  │  ├─ HeroChips (HBoxContainer com 3 HeroChip — glyph de classe ou "+" tracejado se vazio)
│  │  └─ Counts (HBoxContainer)
│  │     ├─ HeroesStat ("3/3 HERÓIS" — número fica verde ao completar)
│  │     └─ CardsStat  ("50/50 CARTAS")
│  └─ MetaFooter (PanelContainer → VBoxContainer)
│     ├─ SleeveRow (HBox: "SLEEVE" + swatch redondo + nome)
│     └─ PlaymatRow (HBox: "PLAYMAT" + swatch + nome)
├─ QuickActions (HBoxContainer, anchor bottom; alpha+offset animados; visível em hover/selecionado)
│  ├─ QuickEdit (Button "✎ Editar", expand)
│  └─ QuickDelete (Button "🗑", largura fixa ~52px)
└─ SelectionFrame (Control, mouse_filter=IGNORE; 4 corner ticks dourados; visível só quando selecionado)
```

### `SleeveStack.tscn` (verso em leque de 3 cartas)
```
SleeveStack (Control, custom_minimum_size=Vector2(108,158))  [script expõe set_sleeve(sleeve_id)]
├─ Back2 (TextureRect, textura = SLEEVE_ART, material = TintMaterial; rot ≈ -7°, offset (-13,7), alpha 0.78)
├─ Back1 (TextureRect, ... rot ≈ +7°, offset (13,7), alpha 0.78)
└─ Front (TextureRect, ... rot 0, alpha 1.0)
```
- Cada `TextureRect` usa um `ShaderMaterial` (TintShader) com `uniform tint_color` setado pelo sleeve. `taldor` → `tint_strength = 0` (mostra original).
- Cantos arredondados leves (≈6px) — pode ser via `clip_contents` + máscara, ou só borda dourada fina. Sombra projetada embaixo do stack (CanvasItem `material`/`StyleBox` drop shadow ou um `TextureRect` de sombra atrás).
- Em hover da placa, anime os ângulos/offsets das cartas de trás (abrindo o leque) via Tween.

### `NewDeckTile.tscn`
```
NewDeckTile (PanelContainer — StyleBox com borda TRACEJADA dourada)  [signal pressed]
└─ CenterContainer → VBoxContainer
   ├─ NewMark (Control redondo com "+"; gira 90° em hover)
   ├─ NewLabel (Label "NOVO DECK")
   └─ NewSub (Label "Forje uma nova trindade de heróis")
```

### `ActionBar.tscn`
```
ActionBar (PanelContainer, anchor bottom, full width)  [script: slide in/out via Tween; signals edit_pressed/delete_pressed]
└─ HBoxContainer
   ├─ MiniSleeve (TextureRect pequeno 30x42 com TintShader)
   ├─ TextBlock (VBox: "SELECIONADO" + nome do deck)
   ├─ Spacer (EXPAND_FILL)
   └─ Actions (HBox)
      ├─ DeleteButton (Button danger "🗑 Apagar")
      └─ EditButton (Button primário dourado "✎ Editar deck")
```

### `ConfirmDialog.tscn` e `Toast.tscn`
Reuse os componentes do DeckBuilder se já existirem (mesma estética: painel `BG_MID`, borda dourada, **2 corner ticks** no topo, título em CinzelDecorative com gradiente). O `ConfirmDialog` mostra "Apagar deck?" + nome em negrito + botões **Cancelar** / **Apagar definitivamente** (danger filled). O `Toast` sobe do rodapé com Tween (acima da ActionBar).

---

## SHADERS

### `TintShader` — recoloração estilo `mix-blend-mode: color` (essencial p/ as sleeves)
Mantém a luminância da textura e aplica matiz+saturação do tint. Sem isso, as sleeves coloridas não vão ficar certas.

```glsl
shader_type canvas_item;

uniform vec3 tint_color : source_color = vec3(1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 1.0; // 0 = original (taldor)

// RGB <-> HSL helpers
vec3 rgb2hsl(vec3 c){
    float mx = max(c.r, max(c.g, c.b));
    float mn = min(c.r, min(c.g, c.b));
    float l = (mx + mn) * 0.5;
    float h = 0.0, s = 0.0;
    float d = mx - mn;
    if (d > 0.00001){
        s = l > 0.5 ? d/(2.0 - mx - mn) : d/(mx + mn);
        if (mx == c.r) h = (c.g - c.b)/d + (c.g < c.b ? 6.0 : 0.0);
        else if (mx == c.g) h = (c.b - c.r)/d + 2.0;
        else h = (c.r - c.g)/d + 4.0;
        h /= 6.0;
    }
    return vec3(h, s, l);
}
float hue2rgb(float p, float q, float t){
    if (t < 0.0) t += 1.0; if (t > 1.0) t -= 1.0;
    if (t < 1.0/6.0) return p + (q - p) * 6.0 * t;
    if (t < 1.0/2.0) return q;
    if (t < 2.0/3.0) return p + (q - p) * (2.0/3.0 - t) * 6.0;
    return p;
}
vec3 hsl2rgb(vec3 hsl){
    float h = hsl.x, s = hsl.y, l = hsl.z;
    if (s == 0.0) return vec3(l);
    float q = l < 0.5 ? l*(1.0+s) : l+s-l*s;
    float p = 2.0*l - q;
    return vec3(hue2rgb(p,q,h+1.0/3.0), hue2rgb(p,q,h), hue2rgb(p,q,h-1.0/3.0));
}

void fragment(){
    vec4 base = texture(TEXTURE, UV);
    vec3 baseHsl = rgb2hsl(base.rgb);
    vec3 tintHsl = rgb2hsl(tint_color);
    // blend "color": matiz+sat do tint, luminância da base
    vec3 outRgb = hsl2rgb(vec3(tintHsl.x, tintHsl.y, baseHsl.z));
    outRgb = mix(base.rgb, outRgb, tint_strength);
    COLOR = vec4(outRgb, base.a);
}
```
Para `taldor`, `tint_strength = 0.0`. Para as demais, `tint_strength ≈ 0.88` e `tint_color = sleeve.tint`.

---

## STYLEBOXES E TEMA

Reuse `res://themes/deckbuilder_theme.tres` e seus tokens (GOLD, GOLD_DIM, GOLD_GLOW, GREEN, PARCHMENT, BG_DEEP, BG_MID, BORDER, BORDER_STRONG, etc.). Cantos **retos** (estética angular — sem corner_radius nos painéis; exceção: leve arredondamento só nas cartas-sleeve).

StyleBoxes específicos desta tela:
- **DeckPlate normal:** `bg = gradiente BG_SURFACE→BG_MID`, borda 1px `BORDER`.
- **DeckPlate hover:** borda `GOLD_SOFT`, sombra projetada `0 14px 34px` preta translúcida, `position.y -= 4` (Tween).
- **DeckPlate selecionado:** borda `GOLD` + glow interno sutil + os 4 corner ticks (Control com 4 ColorRects em L).
- **NewDeckTile:** StyleBox com **borda tracejada** dourada (Godot não tem dashed nativo — desenhe via `_draw()` com segmentos, ou use uma textura de borda tracejada em `NinePatchRect`).
- **PlaymatNamePill / StatusPill:** painéis pequenos translúcidos com `backdrop`-like (use `bg` escuro a ~0.6 alpha + borda clara fina).

**Fontes** (já em `res://fonts/`):
- CinzelDecorative-Bold — nome do deck, eyebrow title, título de modal
- Cinzel (Regular/SemiBold) — eyebrow line, pílulas, contadores, labels de meta, botões
- CrimsonPro (Regular/Italic) — hint da galeria, subtítulo do tile novo, corpo do modal

**Hierarquia tipográfica (mesma escala do HTML):**
- Eyebrow line: Cinzel 10px, letter_spacing 0.35em
- Eyebrow title: CinzelDecorative 18px, gradiente dourado
- Nome do deck (placa): CinzelDecorative 18px
- Pílula playmat / status: Cinzel 9px, letter_spacing 0.18–0.20em, uppercase
- Contadores: número Cinzel SemiBold 15px (verde quando completo) + label Cinzel 9px uppercase
- Meta (sleeve/playmat): chave Cinzel 8px uppercase dourado-dim + valor Cinzel 10px parchment
- Botões header/barra: Cinzel SemiBold 12px, letter_spacing 0.18em, uppercase

---

## INTERAÇÕES E SINAIS

`DeckList.gd` mantém `_selected_id` e escuta `DeckStore.decks_changed` para repopular o grid.

- `_on_plate_selected(deck_id)` → seta seleção, atualiza visual das placas, mostra ActionBar (slide-in) com dados do deck.
- `_on_plate_edit(deck_id)` / `_on_action_edit()` → `DeckStore.set_active(deck_id)` e troca de cena para `DeckBuilder.tscn` (passe o id, ex.: via autoload `DeckStore.active_deck_id` ou `get_tree().change_scene_to_file` + setar antes).
- `_on_plate_delete(deck_id)` / `_on_action_delete()` → abre `ConfirmDialog` com o nome; ao confirmar → `DeckStore.delete(deck_id)` + toast "Deck apagado".
- `_on_new_deck()` (header e tile) → `var d = DeckStore.create_new(); DeckStore.set_active(d.id);` → troca para DeckBuilder.
- `_on_back()` → `Lobby.tscn`.
- `ui_cancel` (Esc) → fecha modal se aberto; senão limpa seleção (esconde ActionBar).
- Duplo-clique numa placa → equivale a editar.

**Recalcular colunas do grid** no `_on_list_body_resized`: `DeckGrid.columns = max(1, floor(largura_util / 352))` (≈330 + gap 22). Mantenha o conteúdo centralizado com `max_width ≈ 1500`.

---

## ANIMAÇÕES

- **Hover na placa:** `position.y -= 4` + sombra, Tween 0.20s ease_out. As cartas de trás do leque abrem mais (rot ±11°, offset maior).
- **Seleção:** corner ticks fazem fade-in (0.2s); leve glow interno.
- **ActionBar:** slide do rodapé (`position.y` de +altura→0) + sem fade, 0.28s `cubic ease_out`. Sai ao desselecionar.
- **QuickActions:** deslizam de baixo da placa (offset 100%→0 + alpha) em 0.18s ao hover/seleção.
- **NewDeckTile:** o "+" gira 90° em hover (Tween 0.2s).
- **Toast:** slide-up + fade, vida útil ~2.2s (aparece acima da ActionBar).
- **ConfirmDialog:** véu fade-in + painel `scale .97→1` + `y -12→0`, 0.25s.

---

## ESCALA / RESPONSIVIDADE

Pensada para **1920×1080**, funcional a partir de **1280×720**:
- `Project Settings > Display > Window > Stretch Mode = canvas_items, Aspect = expand`
- Grid com colunas variáveis (ver fórmula acima); placas têm largura mínima ~330px.
- ListBody (ScrollContainer) rola verticalmente; reserve **padding inferior ≈ 130px** para a ActionBar não cobrir a última fileira.
- Header e ActionBar têm altura fixa; o corpo expande.

---

## ORDEM SUGERIDA DE IMPLEMENTAÇÃO

1. Estender `DeckResource` (sleeve_id/playmat_id) + tabelas SLEEVES/PLAYMATS no `Collection` (ou `cosmetics.gd`) + decks de exemplo no `DeckStore`.
2. `TintShader` (ShaderMaterial) + `SleeveStack.tscn` isolado (testar as 5 cores).
3. `DeckList.tscn` esqueleto (Background + Header + ListBody + GalleryHead).
4. `DeckPlate.tscn` (showcase + playmat bg + sleeve stack + body + meta footer) e populá-lo via `set_deck()`.
5. Grid + recálculo de colunas + `NewDeckTile.tscn`.
6. Seleção (corner ticks) + `ActionBar.tscn` (slide-in/out).
7. Editar/Novo → troca de cena para DeckBuilder passando o deck; Voltar → Lobby.
8. `ConfirmDialog` + `Toast` + apagar do `DeckStore`.
9. QuickActions em hover + animações (hover, leque, +giratório).
10. Polimento: estado vazio (sem decks), deck "sem nome" estilizado, edge cases, navegação do World HUD/DeckBuilder apontando p/ esta cena.

---

## REFERÊNCIA VISUAL

**Leia `Deck List.html` na raiz do projeto antes de começar.** Ele tem o layout exato, todas as cores OKLCH, espaçamentos, e a hierarquia visual completa. A arte de verso é `res://assets/card_back.png`. Não invente — espelhe.

Quando tiver dúvida sobre algum estilo, abra o HTML no navegador e olhe o elemento exato, ou me pergunte.

---

## ENTREGÁVEIS

Ao final, quero:
- [ ] `res://scenes/ui/decklist/DeckList.tscn` rodando
- [ ] Sub-cenas: `DeckPlate`, `SleeveStack`, `NewDeckTile`, `ActionBar` (+ reuso de `ConfirmDialog` e `Toast`)
- [ ] `TintShader` recolorindo a sleeve corretamente (5 cores distintas, taldor = original)
- [ ] Playmats como gradiente/textura no showcase (5 variações)
- [ ] `DeckResource` estendido (sleeve_id/playmat_id) + decks de exemplo no `DeckStore`
- [ ] Selecionar → ActionBar; Editar/duplo-clique → abre DeckBuilder no deck certo; Apagar → confirma e remove; Novo → cria e abre DeckBuilder; Voltar → Lobby
- [ ] World HUD ("Decks") e botão "voltar" do DeckBuilder apontando para `DeckList.tscn`
- [ ] Responsivo de 1280×720 a 1920×1080

Pode começar.
