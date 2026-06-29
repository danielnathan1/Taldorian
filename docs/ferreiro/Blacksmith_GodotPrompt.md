# Prompt para Claude Code — `Blacksmith.tscn` / O Ferreiro (Godot 4)

Cole o conteúdo abaixo no Claude Code. Ele assume que o projeto Godot do **Taldorian TCCG** já existe em `res://`, que `Card.tscn` (`res://scenes/ui/card/Card.tscn`) já foi criada conforme `Card_GodotPrompt.md`, que o autoload `Collection` já carrega os `CardResource` do jogo e que o autoload `Player` (ouro + `card_counts`) já existe conforme `BoosterShop_GodotPrompt.md`.

---

## CONTEXTO

Estou desenvolvendo **Taldorian TCCG** em Godot 4.x. Já existem (ou serão criadas):

- `res://scenes/ui/lobby/Lobby.tscn`
- `res://scenes/ui/card/Card.tscn` (carta data-driven em 600×900 — usa `bind(card_resource)`)
- `res://scenes/ui/booster_shop/BoosterShop.tscn` (loja de pacotes)
- Autoload `Collection` com `CardResource`s carregadas de `res://data/cards/*.tres`
- Autoload `Player` com `gold`, `card_counts: {card_id: int}`, `spend_gold()`, `add_gold()`, `add_card()` e persistência em `user://player.json`

A referência visual completa em HTML/CSS está em **`Ferreiro.html`** na raiz do projeto, com os módulos:
- `ferreiro-data.js` — raridades da forja, pesos, cálculo de chances, custo, sorteio
- `ferreiro-shared.jsx` — `CardFace`, emblema-diamante, marca do martelo, card de inventário
- `ferreiro-hub.jsx` — tela-hub com as 3 opções
- `ferreiro-forge-random.jsx` — pedra-runa + encaixes + chances + animação de cataclismo
- `ferreiro-forge-targeted.jsx` — altar + 10 slots em círculo + ritual

**Leia esses arquivos antes de começar** — eles têm a paleta OKLCH exata, a coreografia das animações, a lógica de chances/sorteio e todos os textos. Não invente: espelhe.

## OBJETIVO

Construir **`res://scenes/ui/blacksmith/Blacksmith.tscn`** — a oficina do Ferreiro, onde o jogador transmuta cartas. A cena tem 3 modos, navegados a partir de uma **tela-hub**:

1. **Forjar Carta Aleatória** — o jogador encaixa cartas do inventário numa **pedra-runa** (5 encaixes por padrão). Labels mostram a **chance** de cada raridade de forja (Comum / Rara / Lendária / Mística), que **reagem** à quantidade e raridade das cartas encaixadas. Há um **custo em ouro**. O botão vermelho **FORJAR** dispara um **cataclismo** (tela tremendo, raios, rachaduras, cartas se espalhando e convergindo numa **luz central** colorida) que revela uma carta sorteada.
2. **Forjar Carta** — ritual dirigido: um **altar central** onde o jogador escolhe a carta que almeja, cercado por **10 slots em círculo**. Preenchidos os 10 e pago o custo, um **ritual** canaliza energia das oferendas para o centro e materializa a carta-alvo.
3. **Encantar Carta** — **bloqueada** ("Em breve"). Só o card do hub, sem tela.

Tudo é **data-driven**: as raridades da forja, pesos, pools e custos vêm de constantes/Resources. O ouro e o inventário usam o autoload `Player`.

---

## MODELO DE RARIDADES DA FORJA

> Espelha `FORGE_TIERS` em `ferreiro-data.js`. **Atenção:** as raridades **da forja** (4 níveis, definem a **cor da luz** final) são diferentes das raridades **das cartas** (5 níveis: Comum, Incomum, Raro, Épico, Lendário). Cada tier de forja sorteia de um **pool** de raridades de carta.

| Tier forja | Luz       | Cor da luz (sRGB) | Cromática? | Pool de cartas        |
|------------|-----------|-------------------|------------|-----------------------|
| `comum`    | Branca    | `#eae7df`         | não        | Comum                 |
| `rara`     | Azul      | `#3f8fe0`         | não        | Incomum, Raro         |
| `lendaria` | Âmbar     | `#e8b84a`         | não        | Épico                 |
| `mistica`  | Cromática | arco-íris (conic) | **sim**    | Lendário              |

Ordem dos tiers: `["comum", "rara", "lendaria", "mistica"]`.

Pesos de "poder de forja" por raridade da **carta** encaixada (`FE_RARITY_WEIGHT`):
`Comum=1, Incomum=2, Raro=4, Épico=7, Lendário=12`.

Custo em ouro por carta encaixada (`FE_RARITY_COST`):
`Comum=12, Incomum=24, Raro=55, Épico=110, Lendário=240`.

---

## REQUISITOS FUNCIONAIS

### 0. Tela-Hub
- **Header** padrão: botão "← Voltar ao Saguão", eyebrow "OFICINA" + título "O Ferreiro", bolsa de ouro (ícone moeda + valor pt-BR).
- **Fundo da fornalha**: brasas (`ember`) subindo continuamente do rodapé + um glow quente que "respira" (escala vertical em loop). Use `CPUParticles2D` para as brasas.
- **Intro central**: marca do martelo & bigorna, eyebrow "A FORNALHA ETERNA", título grande "Forje o seu destino", subtítulo itálico, e um ornamento (linha — diamante — linha).
- **3 cards de opção** lado a lado (`ForgeOptionCard`):
  1. `01 · SORTE DO METAL` → "Forjar Carta Aleatória" (acento **vermelho**)
  2. `02 · RITUAL DIRIGIDO` → "Forjar Carta" (acento **dourado**)
  3. `03 · EM DESENVOLVIMENTO` → "Encantar Carta" (acento roxo, **locked** com selo "🔒 Em breve")
- Hover nos cards não-locked: sobe 6px, borda assume o acento, glow radial no topo, seta "→" desliza.
- Clicar 1 ou 2 transiciona para o modo correspondente (fade + leve slide). Locked não responde.

### 1. Forjar Carta Aleatória

**Layout** — grade horizontal: palco da forja à esquerda (expand), painel de inventário à direita (largura fixa ~380px).

**Palco da forja:**
- **Pedra-runa**: bloco de pedra escura com runas circulares decorativas, rachaduras sutis e uma base. Dentro dela, os **encaixes** (sockets) em flex-wrap.
- Nº de encaixes = `stone_slots` (padrão **5**, ajustável 3–9). Encaixe vazio mostra o emblema-diamante esmaecido pulsando; encaixe cheio mostra a carta (via `Card.tscn` escalada) com glow dourado e um "✕" no hover para remover.
- **Caption** sob a pedra: "Encaixe cartas da coleção nas runas da pedra" ou "N / M runas seladas" + link "limpar".
- **Barra de chances** (`OddsBar`): 4 células (Comum/Rara/Lendária/Mística), cada uma com: ponto colorido (tier), nome + "Luz <cor>", valor em **%** com 1 casa decimal, e uma trilha de progresso preenchida pelo %. A célula **Mística** tem tratamento **cromático** (gradiente cônico animado no ponto e na trilha).
- **Rodapé**: caixa de **custo** ("CUSTO DA FORJA" + valor com moeda; vermelho se `gold < cost`) + botão grande **FORJAR** vermelho.
- O botão FORJAR:
  - Desabilitado se 0 cartas encaixadas (label "Encaixe ao menos 1 carta") ou `gold < cost` (label "Ouro insuficiente").
  - Habilitado: label "FORJAR", com pulso de glow vermelho em loop e shimmer diagonal no hover.

**Painel de inventário:**
- Eyebrow "SUA COLEÇÃO" + título "Inventário".
- Filtro por elemento (Tudo + 🔥⛰💧💨🌙).
- Grid de cards mini (`InvCard`): arte do elemento, pip de raridade, nome, "×N" (quantidade **disponível** = possuída − já encaixada). Card com 0 disponível fica esmaecido/desabilitado. Clicar adiciona no primeiro encaixe livre.

**Lógica de chances** — `fe_compute_odds(placed, max_slots)` (espelhar `ferreiro-data.js`, sempre soma 100):
```
power   = soma dos FE_RARITY_WEIGHT das cartas encaixadas
maxPow  = max_slots * 12   (todos os slots com lendárias)
p       = clamp(power / maxPow, 0, 1)
q       = n_cartas / max_slots

mistica  = pow(p, 1.7) * 42 * (0.4 + 0.6*q)
lendaria = pow(p, 1.1) * 34 + q*6
rara     = 14 + p*30 + q*16
comum    = max(2, 96 - (mistica+lendaria+rara))
→ normalizar para somar 100 (1 casa decimal; comum absorve o resto)
```
Com 0 cartas: `{comum:100, rara:0, lendaria:0, mistica:0}`.

**Custo** — `fe_compute_cost(placed)`: `0` se vazio; senão `60 + Σ FE_RARITY_COST[rarity]`.

**Sorteio** — `fe_roll_result(placed, max_slots)`: rola um tier segundo as chances; escolhe uma carta aleatória do `Collection.cards` filtrado pelo pool do tier; retorna `{tier, card}`.

**Ao FORJAR** (descrito na seção ANIMAÇÕES). Ao final, mostra a carta. O jogador confirma "✓ Adicionar à Coleção":
- `Player.spend_gold(cost)`
- consome as cartas encaixadas: `Player.add_card(id, -1)` para cada (ou um método `remove_card`)
- `Player.add_card(result.card.id, +1)`
- limpa a pedra, volta ao estado IDLE.

### 2. Forjar Carta (ritual)

**Layout** — grade horizontal: palco do círculo à esquerda (expand), painel lateral à direita (~390px) com a caixa do alvo + inventário.

**Círculo ritual:**
- Dois anéis concêntricos (externo sólido dourado, interno tracejado), 12 glifos "✦" distribuídos na borda.
- **Altar central** clicável (carta ~150px). Vazio: emblema-diamante + "Escolher carta almejada". Definido: mostra a carta-alvo via `Card.tscn` + hint "trocar" no hover.
- **10 slots** distribuídos em círculo (raio = `ritual_radius`, padrão **215px**, ajustável 170–260). Slot vazio mostra o número (1–10); cheio mostra a carta + "✕" no hover.
- **Linhas de energia** (`Line2D` ou desenho) do altar até cada slot; a linha "acende" (dourada, pulsando) quando o slot está preenchido.
- **Caption**: "Toque o altar central e escolha a carta que deseja forjar" / "N / 10 oferendas no círculo" + link "limpar círculo".

**Painel lateral:**
- Caixa "ALVO DA FORJA": nome do alvo, pip+raridade+tipo, **custo** (`120 + FE_RARITY_WEIGHT[rarity] * 70`), nota "+ 10 cartas em oferenda", e botão **CANALIZAR** (vermelho, mesma família do FORJAR; labels: "Escolha um alvo" / "Faltam N oferendas" / "Ouro insuficiente" / "CANALIZAR").
- Abaixo, o mesmo painel de **Inventário** (filtro + grid de `InvCard`).

**Seletor de carta-alvo** (`CardPicker`): modal sobre a tela, com filtro por elemento e grid de **todas** as `Collection.cards` (full `Card.tscn`). Clicar escolhe o alvo e fecha.

**Ao CANALIZAR** (ver ANIMAÇÕES). Ao final materializa a **carta-alvo** (não é sorteio — é a carta escolhida). Confirma "✓ Adicionar à Coleção":
- `Player.spend_gold(cost)`, consome as 10 oferendas, `Player.add_card(target.id, +1)`, reseta alvo + círculo.

### 3. Encantar Carta
- Apenas o terceiro card do hub, **locked**, selo "🔒 Em breve". Sem cena/tela.

---

## DADOS

### `ForgeService.gd` (RefCounted ou autoload utilitário)
Porte fiel de `ferreiro-data.js`. Sem estado de UI — só cálculo.

```gdscript
class_name ForgeService extends RefCounted

const TIER_ORDER := ["comum", "rara", "lendaria", "mistica"]

const TIERS := {
    "comum":    { "name": "Comum",    "light": "Branca",
                  "color": Color("eae7df"), "glow": Color("f3f1ea"), "deep": Color("c5c2b8"),
                  "chromatic": false, "pool": ["Comum"] },
    "rara":     { "name": "Rara",     "light": "Azul",
                  "color": Color("3f8fe0"), "glow": Color("5aa3ec"), "deep": Color("2c5fb0"),
                  "chromatic": false, "pool": ["Incomum", "Raro"] },
    "lendaria": { "name": "Lendária", "light": "Âmbar",
                  "color": Color("e8b84a"), "glow": Color("f3cc5e"), "deep": Color("b88f30"),
                  "chromatic": false, "pool": ["Épico"] },
    "mistica":  { "name": "Mística",  "light": "Cromática",
                  "color": Color("c060d8"), "glow": Color("d97fe8"), "deep": Color("9040b0"),
                  "chromatic": true,  "pool": ["Lendário"] },
}

const RARITY_WEIGHT := { "Comum": 1, "Incomum": 2, "Raro": 4, "Épico": 7, "Lendário": 12 }
const RARITY_COST   := { "Comum": 12, "Incomum": 24, "Raro": 55, "Épico": 110, "Lendário": 240 }

# placed: Array[CardResource]
static func compute_odds(placed: Array, max_slots: int) -> Dictionary:
    var n := placed.size()
    if n == 0:
        return { "comum": 100.0, "rara": 0.0, "lendaria": 0.0, "mistica": 0.0 }
    var power := 0
    for c in placed:
        power += RARITY_WEIGHT.get(c.rarity, 1)
    var max_power := max_slots * RARITY_WEIGHT["Lendário"]
    var p: float = clampf(float(power) / float(max_power), 0.0, 1.0)
    var q: float = float(n) / float(max_slots)

    var mistica  := pow(p, 1.7) * 42.0 * (0.4 + 0.6 * q)
    var lendaria := pow(p, 1.1) * 34.0 + q * 6.0
    var rara     := 14.0 + p * 30.0 + q * 16.0
    var comum: float = maxf(2.0, 96.0 - (mistica + lendaria + rara))

    var total := mistica + lendaria + rara + comum
    var out := {
        "comum":    snappedf(comum    / total * 100.0, 0.1),
        "rara":     snappedf(rara     / total * 100.0, 0.1),
        "lendaria": snappedf(lendaria / total * 100.0, 0.1),
        "mistica":  snappedf(mistica  / total * 100.0, 0.1),
    }
    var sum: float = out.comum + out.rara + out.lendaria + out.mistica
    out.comum = snappedf(out.comum + (100.0 - sum), 0.1)   # absorve o resto
    return out

static func compute_cost(placed: Array) -> int:
    if placed.is_empty(): return 0
    var cards := 0
    for c in placed:
        cards += RARITY_COST.get(c.rarity, 10)
    return 60 + cards

static func roll_result(placed: Array, max_slots: int) -> Dictionary:
    var odds := compute_odds(placed, max_slots)
    var r := randf() * 100.0
    var acc := 0.0
    var tier_key := "comum"
    for k in TIER_ORDER:
        acc += odds[k]
        if r < acc:
            tier_key = k
            break
    var tier: Dictionary = TIERS[tier_key]
    var pool := Collection.cards.filter(func(c): return c.rarity in tier.pool)
    var card: CardResource = pool[randi() % pool.size()] if not pool.is_empty() else Collection.cards[0]
    return { "tier_key": tier_key, "tier": tier, "card": card }

# Custo do ritual dirigido
static func targeted_cost(target: CardResource) -> int:
    return 120 + RARITY_WEIGHT.get(target.rarity, 1) * 70
```

### `Player.gd` — extensão necessária
`add_card(id, qty)` já existe. Garanta que aceita **qty negativo** para consumo, ou adicione:
```gdscript
func remove_card(card_id: String, qty: int = 1) -> void:
    var cur: int = card_counts.get(card_id, 0)
    card_counts[card_id] = max(0, cur - qty)
    cards_changed.emit(card_id, card_counts[card_id])
    _save()
```
O inventário do Ferreiro lê de `Player.card_counts` cruzado com `Collection.cards` (só mostra cartas com `count > 0`).

> **QA isolado:** se o `card_counts` estiver vazio (jogador novo), semeie um inventário de teste — mais cópias de comuns, poucas de lendárias — atrás de um botão na cena de teste, espelhando `fe_build_inventory()`.

---

## ÁRVORE DE CENAS

### `Blacksmith.tscn`
```
Blacksmith (Control, anchors=full_rect)  [script: blacksmith.gd]
├─ Background (ColorRect — BG_DEEP) + ForgeAtmosphere (CPUParticles2D brasas + glow)
├─ TopHeader (PanelContainer, custom_minimum_size.y=64)
│  └─ HBoxContainer: HeaderLeft (Back + Separator + Eyebrow/Title) | HeaderRight (GoldPurse)
└─ ViewStack (Control, full_rect)              # troca de modo (hub / random / targeted)
   ├─ HubView.tscn        (instância)
   ├─ RandomForgeView.tscn(instância, hidden)
   └─ TargetedForgeView.tscn (instância, hidden)
```
`blacksmith.gd` controla a navegação (`show_view("hub"|"random"|"targeted")`), o header (título/eyebrow muda por modo) e ouve `Player.gold_changed` para atualizar a bolsa (com flash). Cada view emite `back_requested` e o random/targeted emitem `forge_committed(...)`.

### `HubView.tscn`
```
HubView (Control)  [script: hub_view.gd]   signal option_picked(mode: String)
└─ CenterColumn (VBoxContainer, centralizado)
   ├─ Intro (VBox): HammerMark + Eyebrow + Title + Sub + Ornament
   └─ Options (HBoxContainer)
      ├─ ForgeOptionCard (random)   # acento vermelho
      ├─ ForgeOptionCard (targeted) # acento dourado
      └─ ForgeOptionCard (enchant, locked) # acento roxo + selo
```

### `ForgeOptionCard.tscn`
```
ForgeOptionCard (PanelContainer, custom_minimum_size=Vector2(320, 260))
└─ MarginContainer > VBoxContainer
   ├─ IndexLabel ("01")
   ├─ IconLabel  (glyph grande, modulate = acento)
   ├─ EyebrowLabel
   ├─ TitleLabel
   ├─ DescLabel (autowrap)
   └─ ArrowLabel ("→" / "🔒", align right)
+ LockRibbon (Label "Em breve", canto, hidden quando !locked)
+ 4 CornerOrnament (acento)
```
Estados: `idle`, `hover` (translateY -6, borda acento, glow), `locked` (alpha 0.5, dessaturado, sem hover).

### `RandomForgeView.tscn`
```
RandomForgeView (Control)  [script: random_forge_view.gd]
└─ HSplit (HBoxContainer)
   ├─ ForgeMain (VBoxContainer, expand)
   │  ├─ StageWrap (CenterContainer, expand)
   │  │  └─ Runestone (PanelContainer custom desenhada)
   │  │     ├─ RuneDecor (runas + rachaduras — Sprite2D/desenho)
   │  │     ├─ Sockets (HFlowContainer)
   │  │     │  └─ [N x Socket]   # Socket = Panel + (Card.tscn | DiamondEmblem esmaecido) + RemoveX
   │  │     └─ StoneBase
   │  ├─ StageCaption (HBox: Label + ClearLink)
   │  ├─ OddsBar (HBoxContainer com 4 x OddsCell)
   │  └─ ForgeFooter (HBox: CostBox + ForgeButton)
   └─ InvPanel.tscn (instância — inventário com filtro + grid)
+ CataclysmStage.tscn (instanciada on-demand sobre tudo, hidden)
```

### `TargetedForgeView.tscn`
```
TargetedForgeView (Control)  [script: targeted_forge_view.gd]
└─ HSplit (HBoxContainer)
   ├─ RitualStage (CenterContainer, expand)
   │  └─ RitualCircle (Control, tamanho = ritual_radius*2 + margem)
   │     ├─ RingOuter / RingInner (desenho de círculo)
   │     ├─ Glyphs (12 x Label "✦" posicionados radialmente)
   │     ├─ EnergyLines (Node2D com 10 x Line2D altar→slot)
   │     ├─ Altar (Button central + Card.tscn | placeholder)
   │     └─ RingSlots (10 x RingSlot posicionados em círculo)
   │  + RitualCaption (Label + ClearLink)
   └─ RitualSide (VBoxContainer, ~390px)
      ├─ TargetBox (PanelContainer): nome/meta/custo/req + CanalizeButton
      └─ InvPanel.tscn (instância)
+ CardPicker.tscn (modal on-demand)
+ RitualStage.tscn (overlay on-demand, hidden)  # reaproveita CataclysmStage se preferir
```

### Sub-cenas reutilizáveis
- **`InvPanel.tscn`** — Eyebrow/Título + filtro de elemento + `GridContainer`/`HFlowContainer` de `InvCard`. Emite `card_added(card_resource)`. Recebe `set_inventory(array)` e `set_available_counts(dict)` para esmaecer/desabilitar.
- **`InvCard.tscn`** — `Button` com arte do elemento (gradiente), pip de raridade, nome, "×N".
- **`Socket.tscn`** / **`RingSlot.tscn`** — encaixe vazio/cheio (cheio instancia `Card.tscn` escalada + área de clique para remover).
- **`OddsCell.tscn`** — célula da barra de chances (com variante cromática).
- **`CardPicker.tscn`** — modal de seleção de carta-alvo.

Marque os filhos relevantes com **Unique Name in Owner** (`%`).

---

## SCRIPT — `random_forge_view.gd` (esqueleto)

```gdscript
class_name RandomForgeView extends Control

signal back_requested
signal forge_committed(result: Dictionary, consumed_ids: Array, cost: int)

@export var stone_slots: int = 5
@export var shake_amp: String = "forte"   # "sutil" | "forte" | "caotico"
@export var lightning: bool = true

var _placed: Array = []          # Array[CardResource] (size == stone_slots, null = vazio)
var _phase: String = "idle"

func _ready() -> void:
    _placed.resize(stone_slots)
    _refresh_inventory()
    _rebuild_sockets()
    _recompute()

func _refresh_inventory() -> void:
    var inv := Collection.cards.filter(func(c): return Player.card_counts.get(c.id, 0) > 0)
    %InvPanel.set_inventory(inv)
    _update_available()

func _update_available() -> void:
    # disponível = possuída - já encaixada
    var placed_count := {}
    for c in _placed:
        if c != null: placed_count[c.id] = placed_count.get(c.id, 0) + 1
    var avail := {}
    for c in %InvPanel.inventory:
        avail[c.id] = Player.card_counts.get(c.id, 0) - placed_count.get(c.id, 0)
    %InvPanel.set_available_counts(avail)

func _on_inv_card_added(card: CardResource) -> void:
    if _phase != "idle": return
    var slot := _placed.find(null)
    if slot == -1: return
    _placed[slot] = card
    _rebuild_sockets()
    _update_available()
    _recompute()

func _on_socket_removed(i: int) -> void:
    if _phase != "idle" or _placed[i] == null: return
    _placed[i] = null
    _rebuild_sockets()
    _update_available()
    _recompute()

func _placed_cards() -> Array:
    return _placed.filter(func(c): return c != null)

func _recompute() -> void:
    var placed := _placed_cards()
    var odds := ForgeService.compute_odds(placed, stone_slots)
    %OddsBar.set_odds(odds)
    var cost := ForgeService.compute_cost(placed)
    %CostValue.text = _fmt(cost)
    %CostValue.modulate = RED_INSUFF if Player.gold < cost else GOLD_GLOW
    var can := placed.size() > 0 and Player.gold >= cost and _phase == "idle"
    %ForgeButton.disabled = not can
    %ForgeButton.text = ("FORJAR" if can
        else ("Encaixe ao menos 1 carta" if placed.is_empty()
        else "Ouro insuficiente"))

func _on_forge_pressed() -> void:
    var placed := _placed_cards()
    var cost := ForgeService.compute_cost(placed)
    if placed.is_empty() or Player.gold < cost: return
    var result := ForgeService.roll_result(placed, stone_slots)
    _phase = "forging"
    var consumed := placed.map(func(c): return c.id)
    %CataclysmStage.play(result, placed, lightning, shake_amp)
    # CataclysmStage emite "kept" quando o jogador confirma
    await %CataclysmStage.kept
    forge_committed.emit(result, consumed, cost)
    _commit(result, consumed, cost)

func _commit(result: Dictionary, consumed: Array, cost: int) -> void:
    Player.spend_gold(cost)
    for id in consumed:
        Player.remove_card(id, 1)
    Player.add_card(result.card.id, 1)
    for i in _placed.size(): _placed[i] = null
    _phase = "idle"
    _refresh_inventory()
    _rebuild_sockets()
    _recompute()
```

> `_rebuild_sockets()` recria os filhos de `%Sockets`: para cada índice, instancia `Socket.tscn`; se `_placed[i]` existe, chama `socket.set_card(card)` (que instancia `Card.tscn` escalada dentro) e conecta o botão de remover a `_on_socket_removed.bind(i)`.

---

## SCRIPT — `CataclysmStage.gd` (esqueleto, o "estrafagante")

Coreografia (segundos), espelhando os timers de `ferreiro-forge-random.jsx`:

| Fase      | t (s)      | O que acontece                                                                 |
|-----------|------------|--------------------------------------------------------------------------------|
| SHAKE     | 0.0–1.25   | Véu escurece; a tela **treme** (amplitude por `shake_amp`); **rachaduras** radiais crescem do centro; **raios** caem (se `lightning`) com flashes. |
| SCATTER   | 1.25–2.15  | As cartas encaixadas **explodem** para fora em arco, com rotação aleatória.    |
| CONVERGE  | 2.15–3.25  | As cartas **convergem** ao centro encolhendo até sumir; a **luz central** começa a crescer (cor do tier). |
| FLASH     | 3.25–3.65  | **Flash branco** de tela no pico da luz.                                        |
| REVEAL    | 3.65+      | Fundo escuro reaparece; a **carta sorteada** surge no centro com halo da cor do tier; eyebrow "Forja <tier> · Luz <cor>"; título com o nome (mística = texto cromático); botão "✓ Adicionar à Coleção". |

```gdscript
class_name CataclysmStage extends Control

signal kept

const T_SCATTER := 1.25
const T_CONVERGE := 2.15
const T_FLASH := 3.25
const T_REVEAL := 3.65

var _cam_origin: Vector2

func play(result: Dictionary, cards: Array, lightning: bool, shake_amp: String) -> void:
    show()
    _spawn_scattering_backs(cards)        # instancia Card.tscn de cada carta no centro
    _start_shake(shake_amp)               # tremor na ViewStack/câmera até T_FLASH
    if lightning: _start_bolts()          # raios caindo durante SHAKE/SCATTER
    _grow_cracks()                        # rachaduras radiais
    var tier: Dictionary = result.tier

    get_tree().create_timer(T_SCATTER, false).timeout.connect(_scatter_out)
    get_tree().create_timer(T_CONVERGE, false).timeout.connect(func():
        _converge_in()
        _grow_central_light(tier)         # luz cresce (radial p/ sólido, conic p/ cromático)
    )
    get_tree().create_timer(T_FLASH, false).timeout.connect(_screen_flash)
    get_tree().create_timer(T_REVEAL, false).timeout.connect(func():
        _stop_shake()
        _stop_bolts()
        _show_reveal(result)
    )
```

Notas de implementação:
- **Tremor**: aplique offset+rotação numa `Camera2D` (com `make_current`) ou translade `ViewStack` por um `Tween` em loop curto. Amplitudes: `sutil` ≈ ±2px; `forte` ≈ ±5px/±0.3°; `caotico` ≈ ±10px/±0.6°.
- **Rachaduras**: 7 `Line2D`/Sprite2D radiais com `transform.origin` no centro da tela, ângulos espaçados ~51° (+jitter), crescendo via tween de `scale.y`/comprimento. Glow quente (`#d9883c` → transparente).
- **Raios**: 5 `bolt` (Sprite2D `lightning_bolt.png` ou polígono em zig-zag), posições X aleatórias no topo, piscando rápido (alpha steps); um `bolt_flash` (ColorRect azulado) pulsando.
- **Cartas**: instancie `Card.tscn` por carta no centro. SCATTER → tween para `Vector2(cos*dist, sin*dist*0.78)` + rotação aleatória (TRANS_CUBIC EASE_OUT). CONVERGE → tween para o centro com `scale → 0.05` e `modulate:a → 0` (TRANS_CUBIC EASE_IN).
- **Luz central**: um Sprite2D radial (`forge_light.png`) com `modulate` = `tier.glow`, `scale` 0 → grande, `blend_mode = ADD`. Para o tier **cromático**, sobreponha `forge_light_chromatic.png` (gradiente cônico arco-íris) com rotação em loop (`hue` shift ou rotação). Acrescente god-rays opcionais (`light_rays.png`, `blend ADD`, alpha ~0.4, girando lento) que **somem/atenuam** no REVEAL.
- **Flash**: ColorRect branco full_rect, alpha 0 → 1 → 0 em ~0.4s.
- **Reveal**: ColorRect escuro semi-opaco (NÃO use blend dependente — garanta que a carta fique legível); `Card.tscn` da carta sorteada com `drop-shadow`/glow na cor do tier (use um Sprite2D de halo atrás); eyebrow/título; botão "✓ Adicionar à Coleção" → `emit_signal("kept")` e `hide()`.

> **Importante** (lição do protótipo HTML): no REVEAL, **não confie em blend aditivo** para a luz residual sobre a carta — ela "estoura" em branco. Coloque um fundo escuro sólido/semi-opaco **acima** da luz e a carta acima dele, para a carta sempre ler nítida com seu halo colorido.

---

## SCRIPT — `RitualStage.gd` (ritual dirigido, esqueleto)

Coreografia (segundos), espelhando `ferreiro-forge-targeted.jsx`:

| Fase    | t (s)     | O que acontece                                                            |
|---------|-----------|---------------------------------------------------------------------------|
| CHANNEL | 0.0–1.3   | Anéis giram (externo e interno em sentidos opostos); glifos acendem; núcleo de luz dourada começa a pulsar. |
| DRAW    | 1.3–2.35  | As 10 oferendas **são sugadas** das posições do anel para o centro, encolhendo. |
| BURST   | 2.35–2.75 | **Flash dourado** no centro.                                              |
| REVEAL  | 2.75+     | A **carta-alvo** (escolhida, não sorteada) surge no centro com halo dourado; eyebrow "Ritual completo · Carta materializada"; botão "✓ Adicionar à Coleção". |

```gdscript
class_name RitualStage extends Control
signal kept

const T_DRAW := 1.3
const T_BURST := 2.35
const T_REVEAL := 2.75

func play(target: CardResource, offerings: Array, radius: float) -> void:
    show()
    _spawn_offerings(offerings, radius)    # Card.tscn nas 10 posições do círculo
    _spin_rings()                          # anéis girando (CHANNEL)
    _grow_core()                           # núcleo dourado pulsando
    get_tree().create_timer(T_DRAW, false).timeout.connect(_draw_to_center)
    get_tree().create_timer(T_BURST, false).timeout.connect(_gold_flash)
    get_tree().create_timer(T_REVEAL, false).timeout.connect(func(): _show_reveal(target))
```

Posições do anel: `ring_pos(i, R)` → `Vector2(cos(a)*R, sin(a)*R)` com `a = (i/10)*TAU - PI/2` (começa no topo).

---

## TEMA / TIPOGRAFIA

Reaproveite o tema gold/navy das outras cenas. Constantes (sRGB):

```gdscript
const BG_DEEP      := Color("0a0a18")
const BG_MID       := Color("12121f")
const BG_SURFACE   := Color("171724")
const GOLD         := Color("c89d4a")
const GOLD_DIM     := Color("9a7434")
const GOLD_GLOW    := Color("e6b455")
const GOLD_SOFT_A  := Color(0.78, 0.62, 0.29, 0.25)
const PARCHMENT    := Color("e8dccb")
const PARCHMENT_D  := Color("b6a78f")
const CRIMSON      := Color("8a2d22")   # base do botão FORJAR
const CRIMSON_BR   := Color("c0432e")   # topo do gradiente
const CRIMSON_GLOW := Color("e0552a")   # borda/glow
const RED_INSUFF   := Color("e36a3a")
const EMBER        := Color("e09a3a")   # brasas da fornalha

# Raridades de CARTA (pips) — iguais à BoosterShop
const RAR_COMUM    := Color("b3b3a8")
const RAR_INCOMUM  := Color("4ec877")
const RAR_RARO     := Color("5aa3ec")
const RAR_EPICO    := Color("b376e8")
const RAR_LENDARIO := Color("e6b94a")

# Tiers de FORJA (luz) — ver ForgeService.TIERS
# comum #eae7df · rara #3f8fe0 · lendaria #e8b84a · mistica cromático
```

**Fontes:**
- `CinzelDecorative-Bold.ttf` — títulos, "Forje o seu destino", nomes, valores, % das chances
- `Cinzel-SemiBold.ttf` — botões (FORJAR/CANALIZAR), labels com letter_spacing wide
- `Cinzel-Regular.ttf` — eyebrows, captions, "Luz <cor>"
- `CrimsonPro-Regular.ttf` / `CrimsonPro-Italic.ttf` — subtítulos e descrições

**Tamanhos chave** (1920×1080):
- Eyebrow "OFICINA" — Cinzel 10px letter_spacing 0.35em
- "O Ferreiro" (header) — CinzelDecorative 16px gradient gold
- "Forje o seu destino" (hub) — CinzelDecorative ~48px gradient gold
- Título do card de opção — CinzelDecorative ~21px
- Nome do tier na OddsBar — CinzelDecorative ~15px; valor % — CinzelDecorative ~22px
- Botão FORJAR — Cinzel ~17px uppercase letter_spacing 0.32em
- Valor do custo — CinzelDecorative ~22px
- Reveal título — CinzelDecorative ~38px

StyleBoxFlat padrão: cantos retos, `bg_color = BG_MID com alpha ~0.7`, `border_width_all = 1`, `border_color = GOLD_SOFT_A`. Painéis/encaixes ativos: `border_color = GOLD` + glow. Botão FORJAR: gradiente `CRIMSON_BR → CRIMSON`, borda `CRIMSON_GLOW`, com pulso de glow em loop.

---

## ASSETS — A GERAR

A maior parte é desenhável com `StyleBoxFlat`/`Gradient`/`Line2D`, mas estes PNGs ajudam a fidelidade. Coloque em `res://assets/blacksmith/` (e copie `card_back.png` de `res://assets/` se precisar do emblema):

| Arquivo                       | Tamanho   | Uso                                                                |
|-------------------------------|-----------|--------------------------------------------------------------------|
| `runestone.png`               | 760×420   | Corpo da pedra-runa (textura escura com runas gravadas) — opcional, pode ser StyleBox |
| `diamond_emblem.png`          | 128×160   | Emblema-diamante dourado (encaixe vazio / altar vazio)             |
| `hammer_mark.png`             | 96×96     | Marca martelo & bigorna (intro do hub + ícone do botão)            |
| `forge_light.png`             | 512×512   | Glow radial branco (luz central — recolorida via `modulate`)       |
| `forge_light_chromatic.png`   | 512×512   | Gradiente cônico arco-íris (luz mística)                           |
| `light_rays.png`              | 1024×1024 | God-rays (raios cônicos repetidos) p/ cataclismo e ritual          |
| `crack.png`                   | 24×512    | Rachadura radial (fade no topo, base larga)                        |
| `lightning_bolt.png`          | 80×440    | Raio em zig-zag (azulado, glow)                                    |
| `gold_particle.png`           | 64×64     | Brasas da fornalha (reaproveita o da BoosterShop)                  |
| `ritual_glyph.png`            | 48×48     | Glifo "✦" do círculo (ou use Label com a fonte)                    |
| `coin_icon.png`               | 64×64     | Ícone da moeda no header (reaproveita)                             |

### Import flags
- `filter = true`, `mipmaps = true`, `compress/mode = 0` (Lossless), `process/fix_alpha_border = true`
- `forge_light*`, `light_rays`, `lightning_bolt`, `crack` serão usados com **blend ADD** → no material/CanvasItem use `blend_mode = ADD` (na luz/raios) e cor base preferencialmente clara para recolorir via `modulate`.

---

## INTERAÇÕES E SINAIS

`blacksmith.gd`:
- Back no hub → `get_tree().change_scene_to_file("res://scenes/ui/lobby/Lobby.tscn")`
- Back em random/targeted → `show_view("hub")`
- `HubView.option_picked(mode)` → `show_view(mode)` com fade
- `RandomForgeView.forge_committed` / `TargetedForgeView.forge_committed` → toast "Forjado: <nome>" + bolsa de ouro atualiza
- `Player.gold_changed` → atualiza bolsa com **flash** (`RED_INSUFF` por 0.6s quando diminui)

**Toasts** (reaproveite `Toast.tscn`):
- "Forjado: <nome>" (good) ao confirmar
- "Ouro insuficiente" (warn) — opcional, já refletido no botão
- "Retornando ao saguão..." (info) ao sair

**Bloqueio durante animação:** enquanto `_phase != "idle"`, desabilite back, inventário e remoção de encaixes.

---

## ESCALA / RESPONSIVIDADE

Pensada para **1920×1080**; funciona a partir de **1366×768**:
- `Project Settings > Display > Window > Stretch = canvas_items, Aspect = expand`
- `HSplit` divide o palco/inventário; em telas < ~1280px, empilhe (palco em cima, inventário embaixo) — espelha o `@media (max-width: 820px)` do HTML.
- O círculo ritual usa `ritual_radius`; garanta que `radius*2 + 130` cabe na metade esquerda — reduza `ritual_radius` se necessário em telas pequenas.
- Os overlays (`CataclysmStage`/`RitualStage`) são `full_rect` e centram tudo em `viewport_size / 2`.

---

## CHECKLIST DE FIDELIDADE AO HTML

Abra `Ferreiro.html` no navegador e compare:

- [ ] **Hub** — header, ouro, fornalha com brasas subindo, intro centralizada, 3 cards (2 ativos + 1 locked "Em breve")
- [ ] Hover nos cards ativos: sobe, borda acende no acento, seta desliza; locked não responde
- [ ] **Forja Aleatória** — pedra-runa com 5 encaixes, inventário com filtro por elemento, clique adiciona ao 1º encaixe livre, "✕" remove
- [ ] OddsBar reage: mais cartas + mais raras desloca chance p/ tiers altos; soma sempre 100; célula Mística cromática
- [ ] Custo = `60 + Σ custo das cartas`; vermelho quando `gold < cost`; botão muda de label conforme estado
- [ ] FORJAR → **0.0–1.25** tremor + rachaduras + raios; **1.25** cartas explodem em arco; **2.15** convergem ao centro + luz cresce na cor do tier; **3.25** flash branco; **3.65** revela carta com halo da cor (mística = cromática)
- [ ] Confirmar → desconta ouro, consome encaixadas, adiciona a forjada, limpa a pedra
- [ ] **Forjar Carta** — altar central abre o picker (grid de todas as cartas), 10 slots em círculo, linhas de energia acendem ao preencher
- [ ] CANALIZAR só habilita com alvo + 10 oferendas + ouro suficiente; custo = `120 + peso*70`
- [ ] CANALIZAR → anéis giram, oferendas sugadas ao centro, flash dourado, materializa a **carta-alvo**
- [ ] Reveal sempre legível (carta nítida com halo — sem "estourar" em branco)
- [ ] **Encantar** — card locked "Em breve", sem tela
- [ ] Persistência: forjar → ouro decrementado, cartas consumidas e a nova carta no inventário sobrevivem ao reiniciar

---

## ORDEM SUGERIDA DE IMPLEMENTAÇÃO

1. `ForgeService.gd` + teste isolado (print de `compute_odds`/`compute_cost`/`roll_result` para validar distribuição e soma 100)
2. `Player.remove_card` (se ainda não aceita qty negativo)
3. `Blacksmith.tscn` esqueleto + `blacksmith.gd` (header, ViewStack, navegação)
4. `HubView.tscn` + `ForgeOptionCard.tscn` (com fornalha/brasas)
5. `InvPanel.tscn` + `InvCard.tscn` (lendo de `Player.card_counts` × `Collection.cards`)
6. `RandomForgeView.tscn`: pedra + `Socket.tscn` + OddsBar + custo + botão (sem animação — só lógica)
7. `CataclysmStage.tscn` fase a fase: SHAKE (tremor+rachaduras+raios) → SCATTER → CONVERGE+luz → FLASH → REVEAL
8. `commit` da forja aleatória (ouro/inventário) + toast
9. `TargetedForgeView.tscn`: círculo + altar + `RingSlot.tscn` + linhas + `CardPicker.tscn` + custo/botão
10. `RitualStage.tscn`: CHANNEL → DRAW → BURST → REVEAL + commit
11. Tweaks finais de tema/animação + responsividade
12. Cena de teste `BlacksmithTest.tscn` com botão "Semear inventário de teste" e "Forjar sem custo"

---

## REFERÊNCIA VISUAL

**Leia `Ferreiro.html`, `ferreiro-data.js`, `ferreiro-shared.jsx`, `ferreiro-hub.jsx`, `ferreiro-forge-random.jsx` e `ferreiro-forge-targeted.jsx` na raiz do projeto antes de começar.** Toda a coreografia, pesos/chances, layout e textos estão lá. Não invente — espelhe. Em caso de dúvida visual, abra o HTML no navegador e inspecione o elemento exato.

---

## ENTREGÁVEIS

- [ ] `res://scenes/ui/blacksmith/Blacksmith.tscn` + `blacksmith.gd`
- [ ] Views: `HubView.tscn`, `RandomForgeView.tscn`, `TargetedForgeView.tscn` (+ scripts)
- [ ] Overlays: `CataclysmStage.tscn` + `cataclysm_stage.gd`, `RitualStage.tscn` + `ritual_stage.gd`
- [ ] Sub-cenas: `ForgeOptionCard.tscn`, `InvPanel.tscn`, `InvCard.tscn`, `Socket.tscn`, `RingSlot.tscn`, `OddsCell.tscn`, `CardPicker.tscn`
- [ ] `res://scripts/utils/ForgeService.gd`
- [ ] `Player.remove_card` (ou suporte a qty negativo em `add_card`)
- [ ] Pasta `res://assets/blacksmith/` com os PNGs listados
- [ ] Entrada no Lobby para abrir `Blacksmith.tscn` (botão "O Ferreiro")
- [ ] Cena de teste `res://scenes/ui/blacksmith/BlacksmithTest.tscn` com semeador de inventário e forja sem custo
- [ ] Persistência: forjar → fechar Godot → reabrir → ouro/inventário consistentes

Pode começar.
