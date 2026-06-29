# Prompt para Claude Code — `TradeWindow.tscn` (Godot 4)

Cole o conteúdo abaixo no Claude Code. Ele assume que o projeto Godot do **Taldorian TCG** já existe em `res://`, que `Card.tscn` já foi criada e que `Collection` / `Player` (inventário + ouro) já existem como autoloads, conforme os outros prompts do projeto.

---

## CONTEXTO

Estou desenvolvendo **Taldorian TCG** em Godot 4.x (multiplayer LAN via `ENetMultiplayerPeer`, ver `CLAUDE.md`). Já existem (ou serão criadas):

- `res://scenes/ui/card/Card.tscn` (carta data-driven)
- Autoload `Player` (ouro + `card_counts` do inventário) — ver `BoosterShop_GodotPrompt.md`
- Autoload `Collection` com as `CardResource`s
- `GameBus` / `NetworkState` (canais de sinal e `local_player_index`)

A referência visual completa em HTML/CSS está em **`Trade Window.html`** + **`trade-app.jsx`** na raiz do projeto. **Leia esses arquivos antes de começar** — eles têm a paleta OKLCH exata, o layout dos slots, a coreografia do reset e todos os textos.

## OBJETIVO

Construir **`res://scenes/ui/trade/TradeWindow.tscn`** — a janela modal de troca entre dois jogadores. Cada jogador tem:

1. Uma **grade de slots** (padrão 4×4 = 16) onde coloca cartas do próprio inventário para ofertar.
2. Um **campo numérico de ouro** ofertado (limitado pela bolsa do jogador).
3. Um **botão "Aceitar Troca"**.

Regras de negociação (o coração desta tela — espelhar `trade-app.jsx`):

- Quando um jogador clica **Aceitar Troca**, **o lado dele inteiro fica cinza** (dessaturado/escurecido, sensação de "finalizado") e recebe um **carimbo "Aceito"** girado. O botão vira **"✓ Aceito — Cancelar"**.
- **Se um lado já aceitou e o OUTRO faz qualquer alteração** (adicionar/remover carta ou mudar o ouro), a aceitação é **revogada automaticamente** e entra um **bloqueio de reconfirmação de 3 segundos** (`reset_seconds`, configurável). Durante esse período:
  - Os **dois** botões "Aceitar Troca" ficam **desabilitados** mostrando a contagem regressiva `3 → 2 → 1`.
  - Um **aviso** aparece: "A oferta mudou — reconfirmem a troca".
- Quando **ambos** aceitam (sem nenhuma alteração pendente), a troca **conclui**: overlay "Troca Concluída", itens transferidos.

> ⚠️ **Detalhe crítico de timing** (já tratado no `.jsx`): a verificação de "o outro lado tinha aceitado?" precisa ser feita de forma **síncrona**, com base num espelho do estado de aceitação, não esperando o próximo frame. Em GDScript isso é trivial (variáveis `_accepted[0/1]` lidas direto), mas registre: **toda mutação consulta `_accepted[other]` ANTES de limpar as aceitações.**

---

## REQUISITOS FUNCIONAIS

### 1. Cabeçalho de cada lado
- **Avatar** (retrato do herói/jogador, fallback monograma da inicial) + **crest** (pequeno brasão de classe).
- **Nome** + **Nível** + ícones de status (amigo/online — opcional, decorativo).
- O lado local ganha o selo **"Você"**. O lado local fica à **esquerda**; o oponente à **direita** (cabeçalho espelhado).

### 2. Grade de slots
- `slot_count` slots (padrão 16), sempre em **4 colunas** (8 = 4×2, 12 = 4×3, 16 = 4×4).
- **Slot vazio** (lado editável): clique abre o **seletor de inventário**. Mostra um losango fantasma no centro.
- **Slot preenchido**: mini-carta (arte por elemento, custo no canto, pip de raridade, nome embaixo). Clique **remove** (hover mostra "Remover").
- Um slot pode conter **ouro empacotado** (tile dourado "N Ouro") como alternativa ao campo de ouro — opcional; o `.jsx` permite ofertar ouro tanto pelo campo quanto por um tile.
- Slot recém-preenchido faz um **pop** de entrada (`scale 0.5 → 1`, ~0.32s, back-ease).

### 3. Campo de ouro
- Ícone de moeda + **campo numérico digitável** "Ouro Oferecido" + nota da **bolsa** total do jogador.
- Valor acima da bolsa fica **vermelho** (inválido). O lado do oponente mostra o ouro como **somente leitura**.

### 4. Botão Aceitar / estados
| Estado                | Visual                                                              |
|-----------------------|--------------------------------------------------------------------|
| Negociando            | Dourado "Aceitar Troca" (com shimmer no hover)                     |
| Aceito (este lado)    | Verde "✓ Aceito — Cancelar" + lado cinza + carimbo "Aceito" + pulso |
| Bloqueado (reset 3s)  | Apagado "Reconfira **N**" (desabilitado, contagem regressiva)       |

### 5. Conclusão
- Ambos aceitos → após ~0.4s, overlay **"Troca Concluída" / "Os itens foram transferidos"** + botão **"Nova Troca"**.
- `Player` transfere de fato as cartas e o ouro entre os inventários (no servidor, autoridade única).

### 6. Rodapé de status
Linha única que reflete o estado: "Negociação em andamento" · "Você aceitou — aguardando Korvash" · "Korvash aceitou — aguardando você" · "Confirmação reiniciada — aguarde Ns" · "Troca Concluída — itens transferidos".

---

## MÁQUINA DE ESTADOS (autoridade no servidor)

```
estado por lado: { items: Array[ItemRef], gold: int, accepted: bool }
ItemRef = { card_id: String }  ou  { gold: int }

mutação(lado, fn):
    other = 1 - lado
    other_estava_aceito = _accepted[other]      # LER ANTES de limpar
    fn()                                          # aplica a mudança no lado
    _accepted[0] = false
    _accepted[1] = false
    if other_estava_aceito:
        _lock_until = now() + reset_seconds       # bloqueio de reconfirmação
    emitir estado p/ ambos

aceitar(lado):
    if now() < _lock_until: return                # bloqueado
    _accepted[lado] = not _accepted[lado]
    if _accepted[0] and _accepted[1]:
        concluir_troca()
    emitir estado

concluir_troca():
    transferir items+gold entre os dois Player
    emitir trade_completed
```

No multiplayer real:
- Cliente chama `GameState.rpc_id(1, "rpc_trade_set_item", slot, card_id)`, `rpc_trade_set_gold`, `rpc_trade_remove_item`, `rpc_trade_accept`.
- Servidor valida (a carta está no inventário? ouro ≤ bolsa?), aplica a máquina acima e faz `_sync_trade.rpc(state)`.
- `GameBus.trade_state_synced(state)` → a janela redesenha.
- Um jogador **nunca** edita o lado do outro; cada cliente só envia intenções para o **próprio** lado. (No protótipo HTML os dois lados são editáveis só para demonstração.)

---

## ÁRVORE DE CENAS

### `TradeWindow.tscn`
```
TradeWindow (Control, anchors=full_rect, mouse_filter=STOP)  [script: trade_window.gd]
├─ Dim (ColorRect — escurece o tabuleiro atrás, alpha ~0.7 + vinheta radial)
├─ Window (PanelContainer, centralizado, escala-para-caber via _fit())   # ~1000px largura natural
│  ├─ CornerBrackets ×4 (decoração dourada em L)
│  ├─ VBox
│  │  ├─ TitleBar (PanelContainer)
│  │  │  └─ HBox: Ornamento — Label "TROCA" (CinzelDecorative gradient) — Ornamento
│  │  │     └─ CloseButton (✕, top-right)  → cancela a troca
│  │  ├─ Body (HBoxContainer)
│  │  │  ├─ PlayerSide.tscn  (instância — lado local "is-you")
│  │  │  ├─ Divider (VBox: linha — runa de troca ⇄ — linha)
│  │  │  └─ PlayerSide.tscn  (instância — oponente "is-them", layout espelhado)
│  │  └─ Footer (PanelContainer — Label de status)
│  ├─ ResetBanner (PanelContainer, top-center, visible=false)   # ⚠ "A oferta mudou…" + contagem
│  └─ CompleteOverlay (Control, visible=false)                  # "Troca Concluída" + "Nova Troca"
└─ CardPicker.tscn (instanciado on-demand)                       # seletor de inventário
```

### `PlayerSide.tscn`
```
PlayerSide (VBoxContainer)  [script: player_side.gd]   # @export var side_local: bool
├─ Head (HBoxContainer)            # invertido quando !side_local
│  ├─ Avatar (Panel + retrato/monograma + Crest)
│  └─ Info (VBox: Nome / [PílulaVocê] Nível N · badges)
├─ Grid (GridContainer, columns=4)
│  └─ [slot_count x Slot.tscn]
├─ GoldRow (PanelContainer)        # moeda + SpinBox/LineEdit numérico + nota da bolsa
├─ AcceptButton (Button)           # 3 estados (ver tabela)
├─ AcceptedStamp (Label "Aceito", rotacionado -9°, visible=false)
└─ GreyOverlay  → quando aceito: aplica material/modulate cinza no lado inteiro
```

**Efeito "cinza/finalizado":** aplicar `modulate = Color(0.6,0.6,0.62,1)` + um `CanvasItemMaterial`/shader de dessaturação no nó raiz do `PlayerSide` (exceto no `AcceptButton` e no `AcceptedStamp`, que devem permanecer coloridos/legíveis — reparente-os para um `CanvasLayer` local ou aplique `modulate` inverso). No HTML é `filter: grayscale(1) brightness(0.6)`.

### `Slot.tscn`
```
Slot (PanelContainer, custom_minimum_size por aspecto 3:4)
├─ Empty (CenterContainer — losango fantasma, visible quando vazio)
├─ MiniCard (Control, visible quando preenchido)
│  ├─ Art (TextureRect/ColorRect tingido pela cor do elemento + glyph SVG do elemento)
│  ├─ CostPip (canto sup-esq, círculo dourado com custo)
│  ├─ RarityPip (canto sup-dir, cor por raridade)
│  └─ NameLabel (rodapé, Cinzel pequeno)
└─ RemoveHint (overlay "Remover", aparece no hover quando editável)
```

### `CardPicker.tscn`
```
CardPicker (Control, anchors=full_rect)
├─ Veil (ColorRect semi-transparente — fecha ao clicar fora)
└─ Panel (VBox)
   ├─ Head: "Seu Inventário" / "Escolha uma carta…" + botão "+ Ofertar Ouro" + Fechar ✕
   └─ Grid (GridContainer ~auto-fill) com mini-cartas do inventário + "×N" de quantidade
       (cartas esgotadas: alpha 0.32, não clicáveis)
```

Marque os filhos relevantes com **Unique Name in Owner** (`%`).

---

## CORES DE ELEMENTO / RARIDADE (sRGB)

```gdscript
# Elementos
const EL_FOGO  := Color("d8602f")
const EL_TERRA := Color("9a8a4a")
const EL_AGUA  := Color("4f8fcf")
const EL_AR    := Color("a9c2cf")
const EL_DARK  := Color("8a5ad0")

# Raridade
const RAR_COMUM     := Color("b3b3a8")
const RAR_INCOMUM   := Color("4ec877")
const RAR_RARO      := Color("5aa3ec")
const RAR_EPICO     := Color("b376e8")
const RAR_LENDARIO  := Color("e6b94a")
```

Tema gold/navy padrão do projeto (ver `BoosterShop_GodotPrompt.md` para a paleta base completa: `GOLD #c89d4a`, `GOLD_GLOW #e6b455`, `BG_MID #12121f`, `PARCHMENT #e8dccb`, etc.). Verde de "aceito/concluído": `Color("3aa05a")` / glow `Color("4ec877")`. Vermelho de aviso (reset): `Color("e0853a")`.

**Fontes:** `CinzelDecorative-Bold` (título "TROCA", nomes, valores, carimbo, "Troca Concluída"), `Cinzel-SemiBold` (botões/labels em maiúsculas com tracking), `Cinzel-Regular` (eyebrows/rodapé), `CrimsonPro` (textos corridos).

---

## GLYPHS DE ELEMENTO

O `.jsx` desenha um SVG simples por elemento (chama, triângulo/montanha, gota, redemoinho de vento, lua crescente). No Godot, exporte cada um como PNG 64×64 branco e tinja com a cor do elemento, **ou** use uma fonte de ícones. Slots ficam pequenos (~100×132px), então um único glyph centralizado a ~40% da largura basta.

| Elemento | Glyph        |
|----------|--------------|
| fogo     | chama        |
| terra    | triângulo/montanha |
| agua     | gota         |
| ar       | linhas de vento (stroke) |
| dark     | lua crescente |

---

## TWEAKS / PARÂMETROS (expostos no protótipo)

| Parâmetro        | Padrão | Faixa        | Efeito                                    |
|------------------|--------|--------------|-------------------------------------------|
| `accent`         | #c89d4a| 5 opções     | cor de destaque (dourado/carmesim/azul/verde/roxo) |
| `slot_count`     | 16     | 8 / 12 / 16  | nº de slots por lado (sempre 4 colunas)   |
| `reset_seconds`  | 3      | 1–6          | duração do bloqueio de reconfirmação      |

No Godot, exponha-os como `@export` em `trade_window.gd`.

---

## ANIMAÇÕES — RESUMO

| Animação                  | Onde            | Duração | Curva                          |
|---------------------------|-----------------|---------|--------------------------------|
| Janela entra              | abrir           | 0.4s    | back/cubic ease-out (scale+fade) |
| Slot pop (item adicionado)| grade           | 0.32s   | back ease-out (scale 0.5→1)    |
| Carimbo "Aceito"          | aceitar         | 0.35s   | back ease-out (scale 1.6→1)    |
| Pulso do botão "Aceito"   | aguardando      | 1.6s loop | sine in/out (glow)           |
| Banner de reset           | reset           | 0.3s    | cubic ease-out (slide+fade)    |
| Contagem 3→2→1            | reset           | 1s/passo| —                              |
| Overlay "Troca Concluída" | concluir        | 0.45s   | back ease-out                  |

---

## ESCALA / RESPONSIVIDADE

A janela tem **largura natural ~1000px** e é **escalada para caber** no viewport (o `.jsx` calcula `scale = min(vw*0.97/w, vh*0.93/h, 1)` e aplica `transform: scale`). No Godot:
- `Project Settings > Display > Window > Stretch Mode = canvas_items, Aspect = expand`.
- Centralize a `Window` e, se necessário, aplique `scale` no nó raiz da janela com base no `get_viewport_rect()` para garantir que **cabeçalho, grade, ouro e botões** fiquem sempre visíveis (16 slots-retrato deixam a janela alta).

---

## CHECKLIST DE FIDELIDADE AO HTML

Abra `Trade Window.html` no navegador e compare:

- [ ] Janela modal centralizada, moldura dourada com cantos em L, título "TROCA"
- [ ] Dois lados (Você à esquerda / oponente à direita, cabeçalho espelhado)
- [ ] Grade 4×4 de slots; clicar slot vazio abre o inventário; clicar slot cheio remove
- [ ] Mini-carta: cor por elemento, custo (canto sup-esq), pip de raridade (canto sup-dir), nome
- [ ] Campo numérico de ouro + nota da bolsa; valor > bolsa fica vermelho
- [ ] Aceitar → **lado inteiro fica cinza** + carimbo "Aceito" + botão "✓ Aceito — Cancelar" (pulsando)
- [ ] Com um lado aceito, **alterar o outro lado** → aceitação revogada + **banner de reset** + **ambos os botões bloqueados com contagem 3→2→1**
- [ ] Após N segundos o bloqueio some e os botões voltam a "Aceitar Troca"
- [ ] Ambos aceitam → overlay **"Troca Concluída"** + "Nova Troca"
- [ ] Rodapé reflete cada estado
- [ ] Tweaks: trocar cor de destaque, 8/12/16 slots, timer 1–6s

---

## ORDEM SUGERIDA DE IMPLEMENTAÇÃO

1. `Slot.tscn` (vazio + mini-carta data-driven, via `Card`/`CardResource`)
2. `PlayerSide.tscn` (cabeçalho + grade + ouro + botão) com estados visuais isolados
3. `TradeWindow.tscn` (moldura, título, dois lados, divisor, rodapé) + `_fit()` de escala
4. Máquina de estados local (single-player/teste) — aceitar, cinza, reset 3s, conclusão
5. `CardPicker.tscn` + inventário do `Player`
6. Banner de reset + overlay de conclusão + animações
7. RPCs + autoridade do servidor + `GameBus.trade_state_synced` + transferência real no `Player`
8. Cena de teste `TradeWindowTest.tscn` que abre a janela com dois inventários fictícios

---

## ENTREGÁVEIS

- [ ] `res://scenes/ui/trade/TradeWindow.tscn` + `trade_window.gd`
- [ ] Sub-cenas: `PlayerSide.tscn` + `player_side.gd`, `Slot.tscn` + `slot.gd`, `CardPicker.tscn` + `card_picker.gd`
- [ ] RPCs de troca no `GameState` (`rpc_trade_set_item`, `rpc_trade_remove_item`, `rpc_trade_set_gold`, `rpc_trade_accept`, `rpc_trade_cancel`) + autoridade no servidor
- [ ] Sinais no `GameBus`: `trade_opened`, `trade_state_synced(state)`, `trade_completed`, `trade_reset(seconds)`
- [ ] Transferência real de cartas + ouro entre os dois `Player` ao concluir
- [ ] Glyphs de elemento (PNG 64×64) em `res://assets/trade/`
- [ ] Cena de teste `TradeWindowTest.tscn`

## REFERÊNCIA VISUAL

**Leia `Trade Window.html` e `trade-app.jsx` na raiz do projeto antes de começar.** Layout, estados, textos e a lógica exata do reset de 3s estão lá. Não invente — espelhe. Em caso de dúvida visual, abra o HTML no navegador e inspecione o elemento.

Pode começar.
