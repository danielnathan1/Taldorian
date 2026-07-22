# Prompt para Claude Code — DeckBuilder.tscn (Godot 4)

Cole o conteúdo abaixo no Claude Code. Ele assume que o projeto Godot já existe em `res://` e tem as cenas anteriores do Taldorian TCG (Lobby, HeroPick, Card, Board).

---

## CONTEXTO

Estou desenvolvendo **Taldorian TCG**, um jogo de cartas colecionáveis em Godot 4.x. Já existem:

- `res://scenes/ui/lobby/Lobby.tscn`
- `res://scenes/ui/card/Card.tscn` (já implementada com frame + arte + campos de texto)
- `res://scenes/ui/board/...` (cenas de mesa de jogo)

A referência visual completa em HTML/CSS está em `Deck Builder.html` na raiz do projeto (lê esse arquivo antes de começar — ele tem todas as cores OKLCH, tipografia, layout, hovers e estados que devem ser fielmente reproduzidos).

## OBJETIVO

Construa **`res://scenes/ui/deckbuilder/DeckBuilder.tscn`** — a tela onde o jogador cria, edita e apaga decks. Cada deck tem **3 heróis + até 50 cartas** (máx **4 cópias** por carta).

---

## REQUISITOS FUNCIONAIS

1. **Gerenciamento de decks**
   - Criar novo deck
   - Selecionar deck existente (dropdown com lista)
   - Renomear deck (clique inline no nome)
   - Salvar deck (persistir em `user://decks.json`)
   - Descartar alterações (volta para último estado salvo)
   - Apagar deck (com modal de confirmação)
   - Estado "dirty" deve ser visível (botão Salvar destacado quando há mudanças)

2. **Seleção de Heróis (aba "Heróis")**
   - Filtros: busca por **nome** (LineEdit) + chips por **classe** (multi-seleção, chip "Todas" limpa o grupo)
   - Botão "Limpar (N)" quando há classes selecionadas
   - Grid com cards de herói (mostra HP, ataque, defesa, classe, símbolos da skill)
   - Indicação visual clara se herói já está no deck (ribbon verde "✓ No deck")
   - Clique adiciona ao deck; clique no slot do deck remove

3. **Seleção de Cartas (aba "Cartas")** — painel de filtros reformulado, todos os grupos de chip são **multi-seleção** (pode ativar vários valores ao mesmo tempo dentro do mesmo grupo):
   - Busca por **nome** + toggle "Só no deck"
   - Grupo **ELEMENTO** (Fogo/Terra/Água/Ar/Trevas, multi-seleção, chip "Todos" limpa o grupo)
   - Grupo **RARIDADE** (Comum/Incomum/Raro/Épico/Lendário, multi-seleção, cor do chip = cor da raridade)
   - Grupo **TIPO** (Ação/Reação/Ação Bônus, multi-seleção)
   - Grupo **EFEITOS** (multi-seleção; categorias placeholder "Dano/Cura/Buff/Debuff/Controle/Recurso" — a categorização real de cada carta ainda será definida, hoje é inferida por palavra-chave no texto do efeito)
   - Dois **sliders numéricos**: "Ataque mínimo" (0–7) e "Custo máximo" (0–6) — filtram por limiar
   - Botão "Limpar filtros (N)" que aparece só quando há filtros ativos e reseta tudo
   - Barra de **pills de filtros ativos** abaixo dos grupos, cada uma removível com "×" (um pill por valor selecionado, incluindo busca e sliders fora do padrão)
   - Grid com mini-cards mostrando custo, elemento, nome, tipo, raridade, efeito
   - Badge verde "×N" no canto superior direito de cartas que já estão no deck
   - Clique adiciona uma cópia; clique no badge ×N remove uma cópia

4. **Painel direito sticky (composição do deck)**
   - Nome do deck + status (salvo/dirty)
   - Duas barras de progresso: **Heróis (X/3)** e **Cartas (X/50)** — ficam verdes ao completar
   - **Curva de custo** (histograma simples 0–6+)
   - 3 slots de herói (tracejados quando vazios; mostram nome + classe + stats quando preenchidos)
   - Lista de cartas no deck (ordenada por custo) com controles `−` `×N` `+`

---

## DADOS

### HeroResource.gd (Resource)
```gdscript
class_name HeroResource extends Resource
@export var id: String
@export var hero_name: String
@export var hero_class: String  # BARBARIAN/MAGE/ARCHER/KNIGHT/ASSASSIN/HEALER/DRUID
@export var hp: int
@export var attack: int
@export var defense: int
@export var passive_text: String
@export var skill_symbols: Array[String]  # ["fogo","terra","fogo"]
@export var skill_desc: String
@export var portrait: Texture2D  # opcional
```

### CardResource.gd (Resource)
```gdscript
class_name CardResource extends Resource
@export var id: String
@export var card_name: String
@export var element: String  # fogo/terra/agua/ar/dark
@export var rarity: String   # Comum/Incomum/Raro/Épico/Lendário
@export var type: String     # "Ação"/"Reação"/"Ação Bônus"
@export var cost: int
@export var attack: int
@export var effect_text: String
@export var effect_tags: Array[String] = []  # placeholder: subconjunto de EFFECT_TAGS, ver Collection.gd
@export var art: Texture2D   # opcional
```

Constante global de categorias de efeito (placeholder, ainda a validar):
```gdscript
const EFFECT_TAGS := ["Dano", "Cura", "Buff", "Debuff", "Controle", "Recurso"]
```

### DeckResource.gd (Resource — serializável em JSON)
```gdscript
class_name DeckResource extends Resource
@export var id: String
@export var deck_name: String
@export var hero_ids: Array[String] = []
@export var card_counts: Dictionary = {}  # { "card_id": int_count }
```

### Singleton/Autoload `Collection.gd`
- Carrega todos os HeroResource e CardResource de `res://data/heroes/*.tres` e `res://data/cards/*.tres`
- Expõe: `Collection.heroes`, `Collection.cards`, `Collection.get_hero(id)`, `Collection.get_card(id)`
- Crie ~14 heróis e ~28 cartas de exemplo seguindo os dados em `deckbuilder-data.js` (raiz do projeto)

### Singleton/Autoload `DeckStore.gd`
- Carrega/salva decks em `user://decks.json`
- API: `DeckStore.decks: Array[DeckResource]`, `DeckStore.save()`, `DeckStore.create_new() -> DeckResource`, `DeckStore.delete(deck_id)`
- Emite signal `decks_changed`

---

## ÁRVORE DE CENAS

### `DeckBuilder.tscn`
```
DeckBuilder (Control, anchors=full_rect)  [script: DeckBuilder.gd]
├─ Background (ColorRect, mouse_filter=IGNORE)  # var(--bg-deep)
├─ AtmosphereLayer (Control, mouse_filter=IGNORE)
│  └─ Vignette (TextureRect ou ColorRect com gradient)
├─ Root (VBoxContainer, anchors=full_rect)
│  ├─ TopHeader (PanelContainer, custom_minimum_size.y=64)
│  │  └─ HBoxContainer
│  │     ├─ HeaderLeft (HBoxContainer)
│  │     │  ├─ BackButton (Button "← Lobby")
│  │     │  ├─ Separator (VSeparator)
│  │     │  └─ EyebrowBlock (VBoxContainer)
│  │     │     ├─ EyebrowLine (Label "FORJA DE DECKS")
│  │     │     └─ EyebrowTitle (Label "Construa sua trindade")
│  │     ├─ HeaderCenter (CenterContainer, size_flags_horizontal=EXPAND_FILL)
│  │     │  └─ DeckSwitcher.tscn (instância)
│  │     └─ HeaderRight (HBoxContainer)
│  │        ├─ DiscardButton (Button "Descartar", hidden quando !dirty)
│  │        ├─ DeleteButton (Button "Apagar")
│  │        └─ SaveButton (Button "Salvar")
│  └─ BodyGrid (HBoxContainer, size_flags_vertical=EXPAND_FILL)
│     ├─ PickerPane (VBoxContainer, size_flags_horizontal=EXPAND_FILL)
│     │  ├─ PickerTabs (HBoxContainer)
│     │  │  ├─ HeroesTab (Button toggle, "♛ Heróis  X/3")
│     │  │  ├─ CardsTab  (Button toggle, "❖ Cartas  X/50")
│     │  │  └─ HintLabel (Label "Clique numa carta para adicionar")
│     │  ├─ FiltersContainer (PanelContainer, com moldura de cantos dourados nas quinas)
│     │  │  └─ [conteúdo trocado por GDScript ao mudar de aba]
│     │  │     • aba Cartas: FiltersTopRow (busca + toggle "Só no deck" + ClearFiltersButton) →
│     │  │       FilterGroupsGrid (4x FilterGroup: Elemento/Raridade/Tipo/Efeitos, chips multi-seleção) →
│     │  │       FilterStatsRow (2x StatSlider: Ataque mínimo, Custo máximo) → ActiveFiltersBar (HFlowContainer de ActivePill)
│     │  │     • aba Heróis: FiltersTopRow (busca + ClearFiltersButton) → FilterGroup Classe (chips multi-seleção)
│     │  └─ GridScroll (ScrollContainer, size_flags_vertical=EXPAND_FILL)
│     │     └─ GridContainer (GridContainer, columns=auto via _resize)
│     └─ DeckRail.tscn (instância, custom_minimum_size.x=380)
```

### `DeckSwitcher.tscn` (componente)
```
DeckSwitcher (HBoxContainer)
├─ TriggerButton (Button "▼ DECK ATIVO")
├─ NameButton (Button — mostra nome do deck) / NameEdit (LineEdit oculto)
└─ PickerPopup (PopupPanel)
   └─ VBoxContainer
      ├─ HeaderLabel ("Meus decks")
      ├─ DeckList (VBoxContainer — preenchido em runtime)
      └─ NewDeckButton (Button "+ Novo deck")
```

### `HeroPickerCard.tscn` (item da grade de heróis)
```
HeroPickerCard (PanelContainer, custom_minimum_size=Vector2(200, 230))
├─ MarginContainer
│  └─ VBoxContainer
│     ├─ ArtArea (Control, custom_minimum_size.y=130)
│     │  ├─ Background (ColorRect, com cor da classe)
│     │  ├─ ClassGlyph (TextureRect, centralizado)
│     │  ├─ HPBadge (PanelContainer top-left, "♥20")
│     │  └─ ClassPill (PanelContainer bottom-right)
│     ├─ NameLabel
│     ├─ StatsRow (HBoxContainer) → "⚔ 2"  "🛡 1"
│     └─ SymbolsRow (HBoxContainer com ElementPip instances)
├─ InDeckRibbon (Label, top-right corner, hidden por padrão)
└─ HoverOverlay (Control com "+ Adicionar", alpha animado)
```

### `CardPickerCard.tscn` (item da grade de cartas)
```
CardPickerCard (PanelContainer, custom_minimum_size=Vector2(190, 240))
├─ MarginContainer
│  └─ VBoxContainer
│     ├─ ArtArea (Control, custom_minimum_size.y=120)
│     │  ├─ Background (ColorRect com cor do elemento)
│     │  ├─ ArtGlyph (TextureRect baseado no tipo)
│     │  ├─ CostBadge (PanelContainer redondo top-left)
│     │  └─ ElementPip (bottom-left)
│     ├─ NameLabel
│     ├─ MetaRow (HBoxContainer) → "AÇÃO"  "◆ RARO"
│     └─ EffectLabel (Label com autowrap)
├─ CountBadge (Button, top-right, "×N", hidden quando count=0)
└─ HoverOverlay
```

### `DeckRail.tscn`
```
DeckRail (PanelContainer)
└─ MarginContainer
   └─ VBoxContainer
      ├─ HeaderSection (VBoxContainer)
      │  ├─ TitleRow (HBoxContainer)
      │  │  ├─ DeckTitle (Label)
      │  │  └─ StatusLabel (Label "● não salvo" / "✓ salvo")
      │  ├─ ProgressSection (VBoxContainer)
      │  │  ├─ HeroesProgress (ProgressTrack.tscn)
      │  │  └─ CardsProgress  (ProgressTrack.tscn)
      │  └─ ManaCurve (Control, custom_minimum_size.y=80)
      │     ├─ Label "CURVA DE CUSTO"
      │     └─ BarsContainer (HBoxContainer com 7 ColorRect colunas)
      ├─ HeroesSection (VBoxContainer)
      │  ├─ SectionHeader (HBoxContainer "HERÓIS" + count)
      │  └─ HeroSlots (HBoxContainer com 3x DeckHeroSlot.tscn)
      └─ CardsSection (VBoxContainer, size_flags_vertical=EXPAND_FILL)
         ├─ SectionHeader
         └─ CardListScroll (ScrollContainer)
            └─ CardList (VBoxContainer — preenchido em runtime com DeckCardRow.tscn)
```

### `ProgressTrack.tscn`, `DeckHeroSlot.tscn`, `DeckCardRow.tscn`
Componentes pequenos:
- **ProgressTrack** — Label + Label valor + ProgressBar customizada
- **DeckHeroSlot** — caixa com glyph da classe + nome + classe + stats + botão remover (×). Tem `state: empty | filled` que troca a aparência.
- **DeckCardRow** — Custo (round badge) + ElementPip + Nome + sub + 3 botões `[−] [×N] [+]`

### `FilterChip.tscn` / `FilterGroup.tscn` / `StatSlider.tscn` / `ActivePill.tscn` (componentes de filtro, reutilizados nas duas abas)
- **FilterChip** — Button toggle; estado `active` mostra um `✓` à esquerda do label (exceto chips de elemento, que já têm o ElementPip como indicador visual) e muda borda/cor para dourado. Suporta `color` opcional (usado pelos chips de raridade).
- **FilterGroup** — Label do grupo (Cinzel 9px, letter-spacing largo) + HFlowContainer de FilterChip.
- **StatSlider** — Label do rótulo + Label do valor atual + `HSlider` estilizado (trilho fino, thumb dourado com glow). Usado para "Ataque mínimo" e "Custo máximo".
- **ActivePill** — pequeno botão-tag dourado translúcido com label + "×"; clicar remove aquele filtro específico. Populado dinamicamente a partir de todos os filtros ativos (busca, cada valor de cada grupo, sliders fora do padrão, toggle "só no deck").

---

## STYLEBOXES E TEMA

Crie `res://themes/deckbuilder_theme.tres` com tokens espelhando o CSS:

```gdscript
# Cores OKLCH convertidas para Color (use o equivalente sRGB aproximado)
const GOLD         := Color("c89d4a")  # oklch(0.73 0.13 78)
const GOLD_DIM     := Color("9a7434")
const GOLD_GLOW    := Color("e6b455")
const GOLD_SOFT_A  := Color(0.78, 0.62, 0.29, 0.25)
const CRIMSON      := Color("8a2a2a")
const GREEN        := Color("3aa055")
const PARCHMENT    := Color("e8dccb")
const PARCHMENT_D  := Color("b6a78f")
const BG_DEEP      := Color("0a0a18")
const BG_MID       := Color("12121f")
const BG_SURFACE   := Color("171724")
const BORDER       := Color(0.78, 0.62, 0.29, 0.18)
const BORDER_STRONG:= Color(0.78, 0.62, 0.29, 0.35)
```

StyleBoxFlat padrão para painéis: `bg_color = BG_MID`, `border_width_all = 1`, `border_color = BORDER`, cantos retos (sem `corner_radius` — a estética é angular, não arredondada).

**Fontes** (carregue de `res://fonts/`):
- `CinzelDecorative-Bold.ttf` — títulos
- `Cinzel-Regular.ttf`, `Cinzel-SemiBold.ttf` — labels, botões, números
- `CrimsonPro-Regular.ttf`, `CrimsonPro-Italic.ttf` — corpo, descrições

**Hierarquia tipográfica:**
- Header eyebrow: Cinzel 10px letter_spacing 0.35em
- Eyebrow title: CinzelDecorative 15px gradient gold
- Nome do deck: CinzelDecorative 18px
- Tab: Cinzel 14px letter_spacing 0.22em
- Label de filtro: Cinzel 9px letter_spacing 0.28em
- Nome do card/herói: Cinzel 15px / Cinzel 13px
- Efeito da carta: CrimsonPro Italic 12px

---

## INTERAÇÕES E SINAIS

`DeckBuilder.gd` mantém referência ao deck ativo e emite/escuta:
- `_on_hero_picker_card_clicked(hero_id)` → tenta adicionar via `_active_deck.add_hero(hero_id)`
- `_on_card_picker_card_clicked(card_id)` → idem cartas
- `_on_count_badge_clicked(card_id)` → remove uma cópia
- `_on_filter_changed()` → re-popula GridContainer (filtros de elemento/raridade/tipo/efeitos e classe são `Array[String]`, valor vazio = "todos"; sliders de ataque/custo são inteiros de limiar)
- `_on_clear_filters_pressed()` → reseta todos os filtros da aba atual
- `_on_tab_changed(tab)` → troca conteúdo do FiltersContainer e do GridContainer
- `_on_save_pressed()` → `DeckStore.save()`, atualiza snapshot
- `_on_delete_pressed()` → abre `ConfirmDialog.tscn`
- `_on_new_deck_pressed()` → cria deck novo via DeckStore e seleciona
- `_on_name_edited(new_name)` → atualiza `_active_deck.deck_name`

**Toast** — cena pequena `Toast.tscn` que sobe do bottom com Tween (mostra "Deck salvo", "Limite de 4 cópias", "Deck cheio", etc.)

**Validações:**
- Adicionar 4º herói → toast warn
- Adicionar 5ª cópia da carta → toast warn
- Adicionar carta com deck em 50 → toast warn
- Apagar último deck → toast warn "Mantenha ao menos um deck"

---

## ANIMAÇÕES

- Hover no card: `scale → 1.02` + `position.y -= 3` via Tween 0.18s ease_out
- Aparição do PickerPopup: `modulate.a 0→1` + `position.y -=6→0` em 0.18s
- Toast: slide-up do bottom + fade, vida útil 2.4s
- Barra de progresso ficando verde: lerp da cor `width` ao completar

---

## ESCALA / RESPONSIVIDADE

A cena foi pensada para **1920×1080** mas precisa funcionar a partir de **1280×720**:
- `Project Settings > Display > Window > Stretch Mode = canvas_items, Aspect = expand`
- O painel direito tem largura fixa (380px); o picker pane expande
- GridContainer usa colunas variáveis: recalcule `columns` no `_on_resized` do ScrollContainer (`columns = max(2, floor(width / 210))`)

---

## ORDEM SUGERIDA DE IMPLEMENTAÇÃO

1. Resources (HeroResource, CardResource, DeckResource) + Autoloads (Collection, DeckStore) + dados de exemplo
2. Tema (deckbuilder_theme.tres) + StyleBoxes + carregar fontes
3. `DeckBuilder.tscn` esqueleto (header + body grid vazio)
4. `DeckRail.tscn` + sub-componentes (DeckHeroSlot, DeckCardRow, ProgressTrack)
5. `HeroPickerCard.tscn` + grid de heróis + filtros de classe e busca
6. `CardPickerCard.tscn` + grid de cartas + filtros de elemento/raridade/tipo
7. `DeckSwitcher.tscn` + persistência (DeckStore.save/load)
8. Modal de confirmação de delete + Toast
9. Curva de mana + estados "dirty/salvo" + Discard
10. Polimento: hovers, animações, edge cases (deck vazio, deck cheio, último deck)

---

## REFERÊNCIA VISUAL

**Leia `Deck Builder.html` na raiz do projeto antes de começar.** Ele tem o layout exato, todas as cores OKLCH, espaçamentos, e a hierarquia visual completa. Não invente — espelhe.

Quando tiver dúvida sobre algum estilo, abra o HTML no navegador e olhe o elemento exato, ou me pergunte.

---

## ENTREGÁVEIS

Ao final, quero:
- [ ] `res://scenes/ui/deckbuilder/DeckBuilder.tscn` rodando
- [ ] Todas as sub-cenas (`DeckSwitcher`, `DeckRail`, `HeroPickerCard`, `CardPickerCard`, `DeckHeroSlot`, `DeckCardRow`, `ProgressTrack`, `FilterChip`, `FilterGroup`, `StatSlider`, `ActivePill`, `Toast`, `ConfirmDialog`)
- [ ] Resources de exemplo em `res://data/heroes/` e `res://data/cards/`
- [ ] Autoloads `Collection` e `DeckStore` registrados em `project.godot`
- [ ] Tema `deckbuilder_theme.tres`
- [ ] Persistência funcionando (criar deck → salvar → fechar Godot → reabrir → deck ainda lá)

Pode começar.
