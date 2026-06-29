# Prompt para Claude Code — `VictoryDefeat.tscn` (Godot 4)

Cole o conteúdo abaixo no Claude Code. Ele assume que o projeto Godot do **Taldorian TCCG** já existe em `res://`, que `Board.tscn` está rodando como cena principal de partida, e que existe um `GameState` / `PlayerProfile` de onde vêm o rank atual e os pontos do jogador.

---

## CONTEXTO

Estou desenvolvendo **Taldorian TCCG** em Godot 4.x. Ao final de uma partida (`Board.tscn`), deve aparecer um **overlay de fim de jogo** sobreposto ao tabuleiro que mostra, para o jogador local:

1. **Resultado** — "Vitória!" (tema dourado) ou "Derrota" (tema carmesim).
2. **Rank atual** — escudo heráldico do tier + divisão (ex.: Prata II), com o label "Rank Atual".
3. **Pontos ganhos/perdidos** nesta partida — um *badge* `+24` (verde, vitória) ou `−18` (vermelho, derrota).
4. **Pontos atuais com animação** — o número de pontos **conta** do valor anterior para o novo (ex.: 64 → 88 numa vitória, 64 → 46 numa derrota), com a **barra de progresso** preenchendo/drenando junto.
5. **Ouro ganho** — uma linha de recompensa com ícone de moeda e o valor **contando** de 0 até o total (ex.: +340 numa vitória, +120 numa derrota).
6. **Botão "← Voltar para Taldorian"** — fecha o overlay e retorna ao hub/menu.

A referência visual completa em HTML/CSS está em **`Victory Defeat.html`** na raiz do projeto. **Leia esse arquivo antes de começar** — ele tem o layout exato, cores, fontes, espaçamentos, timeline de animação e os dois temas (vitória/derrota).

## OBJETIVO

Construa **`res://scenes/ui/victorydefeat/VictoryDefeat.tscn`** — uma cena que:

1. É **um overlay** (CanvasLayer no topo de tudo) que escurece o tabuleiro com gradient radial e partículas.
2. Recebe os dados da partida via um método público `show_result(data)` e se monta tanto em modo **vitória** quanto **derrota**.
3. Executa a **sequência animada** completa (fade do overlay → reveal do card → badge de delta → contagem dos pontos + barra → contagem do ouro).
4. É **autocontida** — expõe um sinal público `return_pressed` para o `Board` reagir, mas não conhece a estrutura interna do jogo.
5. Nasce em **1280×720** (16:9) e adapta-se ao viewport via escala uniforme.

---

## MODELO DE DADOS

A cena é dirigida por um único dicionário passado em `show_result(data)`:

```gdscript
# Exemplo (vitória)
{
    "result": "victory",          # "victory" | "defeat"
    "tier":     "Prata",          # Bronze | Prata | Ouro | Platina | Diamante | Mestre
    "div":      "II",             # "IV" | "III" | "II" | "I"
    "lp_before": 64,              # pontos antes da partida
    "lp_delta":  24,              # variação (positiva ou negativa)
    "lp_max":    100,             # pontos para promover de divisão
    "gold":      340,             # ouro ganho nesta partida
}
```

`lp_after = clamp(lp_before + lp_delta, 0, lp_max)`. (Não tratar promoção/rebaixamento de divisão neste card — apenas a barra dentro da divisão atual. Se quiser, exibir hint "Faltam N pts p/ promoção" ou "N pts até rebaixar".)

### Ladder de ranks (espelha `profile/data.js`)
```gdscript
const TIERS := {
    "Bronze":   { "c1": "#d39a6a", "c2": "#a96a3c", "deep": "#5e3a1f", "ink": "#2a1709" },
    "Prata":    { "c1": "#dfe6ef", "c2": "#a7b3c4", "deep": "#5a6679", "ink": "#1d2430" },
    "Ouro":     { "c1": "#f5cf6a", "c2": "#d39a2c", "deep": "#7a5410", "ink": "#2a1d04" },
    "Platina":  { "c1": "#9fe6dc", "c2": "#52b3a6", "deep": "#1f5a52", "ink": "#062421" },
    "Diamante": { "c1": "#a9defc", "c2": "#5aa8e0", "deep": "#1c5a86", "ink": "#04202f" },
    "Mestre":   { "c1": "#d3b8ff", "c2": "#9a72e0", "deep": "#4a2f86", "ink": "#1a0e33" },
}
```
O escudo do rank usa **sempre** as cores do tier do jogador, independentemente de vitória/derrota. Apenas o título, o badge de delta, as partículas, a barra e o glow seguem o tema vitória(dourado)/derrota(vermelho).

---

## ÁRVORE DE CENAS

### `VictoryDefeat.tscn`
```
VictoryDefeat (CanvasLayer, layer=20)  [script: victory_defeat.gd]
└─ Root (Control, full_rect, mouse_filter=STOP)            # bloqueia cliques no tabuleiro
   ├─ Backdrop (ColorRect, full_rect, material=radial_dim) # fundo escuro + tint radial do tema
   ├─ Particles (GPUParticles2D ou Node2D pool)            # partículas subindo (cor/qtd por tema)
   │
   └─ CardCenter (CenterContainer, full_rect)
      └─ ResultCard (VBoxContainer, custom_minimum_size.x=480, separation=0)  [%ResultCard]
         ├─ Crest (TextureRect, custom_minimum_size=Vector2(92,92),
         │          stretch_mode=KEEP_ASPECT_CENTERED)      # vitória/derrota crest, glow pulsante
         ├─ Spacer (Control, custom_minimum_size.y=21)
         └─ Panel (PanelContainer, style=result_panel)      # cantos ornamentais em L (4 Control _draw)
            └─ Margin (MarginContainer, padding=39/45/35/45)
               └─ VBox (VBoxContainer, separation=0)
                  ├─ Eyebrow (Label, "BATALHA ENCERRADA", style=eyebrow)
                  ├─ Title   (Label, "Vitória!"/"Derrota", style=title)        [%Title]
                  ├─ Divider (HBoxContainer, alignment=CENTER)
                  │   ├─ LineL (ColorRect 40×1, gradient transparent→accent_dim)
                  │   ├─ Diamond (ColorRect 6×6, rotated 45°, glow accent)
                  │   └─ LineR (ColorRect 40×1, gradient accent_dim→transparent)
                  ├─ Desc (Label/RichText, italic, style=desc)                  [%Desc]
                  ├─ Spacer (Control, custom_minimum_size.y=18)
                  │
                  ├─ RankModule (HBoxContainer, separation=18,
                  │              border_top 1px line @0.18, padding_top/bottom)
                  │   ├─ RankShield (Control, custom_minimum_size=Vector2(64,72)) [%RankShield]
                  │   │   _draw() do escudo + Label da divisão por cima
                  │   └─ RankInfo (VBoxContainer, size_flags=EXPAND_FILL, separation=0)
                  │      ├─ RankTop (HBoxContainer)
                  │      │   ├─ NameWrap (VBoxContainer, separation=2)
                  │      │   │   ├─ RankLabel (Label, "RANK ATUAL", style=rank_label)
                  │      │   │   └─ RankTier  (Label, "Prata II", style=rank_tier)  [%RankTier]
                  │      │   └─ DeltaBadge (PanelContainer, style=delta_box)        [%DeltaBadge]
                  │      │       └─ HBox (Arrow TextureRect 11×11 + Label "+24")    [%DeltaLabel]
                  │      ├─ Spacer (h=8)
                  │      ├─ PtsRow (HBoxContainer, alignment baseline, separation=7)
                  │      │   ├─ PtsValue (Label, "64", style=pts_value)             [%PtsValue]
                  │      │   └─ PtsUnit  (Label, "/ 100 pts", style=pts_unit)
                  │      ├─ Spacer (h=9)
                  │      ├─ PtsTrack (Control, custom_minimum_size.y=9,
                  │      │            style=track_bg, border 1px @0.3)              [%PtsTrack]
                  │      │   ├─ PtsFill (ColorRect, anchors=left+v_fill,
                  │      │   │           width=lp%×track, gradient accent, glow)    [%PtsFill]
                  │      │   └─ Ticks (HBoxContainer, 10 divisórias 1px)
                  │      ├─ Spacer (h=7)
                  │      └─ PtsFoot (HBoxContainer)
                  │          ├─ FootL (Label, "Prata II", style=pts_foot)
                  │          └─ FootR (Label, hint promoção/rebaixamento)           [%PtsHint]
                  │
                  ├─ RewardRow (HBoxContainer, separation=11,
                  │             border_top 1px @0.12, border_bottom 1px @0.18,
                  │             padding 14/0/15/0, margin_bottom 26)
                  │   ├─ Coin (TextureRect 19×19, glow dourado, flip ocasional)     [%Coin]
                  │   ├─ RewardLabel (Label, "OURO GANHO", style=reward_label)
                  │   └─ RewardValue (HBox, "+340" + "Ouro", style=reward_value)    [%RewardValue]
                  │
                  └─ ReturnBtn (Button, custom_minimum_size.y=54,
                               "← Voltar para Taldorian", style=return_btn)         [%ReturnBtn]
```

> Marque cada nó dinâmico com **Unique Name in Owner** (`%`).

---

## ESCUDO DE RANK — `RankShield` via `_draw()`

`res://assets/ui/victorydefeat/shield.svg` opcional; preferível desenhar via código para tingir pelo tier:

```gdscript
# RankShield desenha o brasão na cor do tier e escreve a divisão por cima.
const SHIELD_PTS := PackedVector2Array([
    Vector2(50,6), Vector2(88,22), Vector2(88,52),
    Vector2(50,96), Vector2(12,52), Vector2(12,22),
])  # aproximação do path "M50 6 L88 22 V52 ... V22 Z" num viewBox 0..100

func _draw() -> void:
    var t: Dictionary = TIERS[tier]
    var sc := size / 100.0
    var pts := PackedVector2Array()
    for p in SHIELD_PTS: pts.append(p * sc)
    # corpo com gradient vertical (c1→c2→deep): use draw_colored_polygon
    draw_colored_polygon(pts, Color(t.c2))
    draw_polyline(pts + PackedVector2Array([pts[0]]), Color(t.c1), 2.0 * sc.x, true)
    # brilho superior + número da divisão é um Label filho (não no _draw)
```
A `div` (IV/III/II/I) é um `Label` centralizado (Cinzel-Bold ~18pt, cor = `tier.ink`) por cima do escudo.

---

## ÍCONE DE MOEDA — `Coin`

`res://assets/ui/victorydefeat/coin.svg` (mesmo do World HUD):
```
<svg viewBox="0 0 16 16">
  <circle cx="8" cy="8" r="6.4" fill="#caa23e" stroke="#7a5c14" stroke-width="1.2"/>
  <circle cx="8" cy="8" r="4.1" fill="none" stroke="#f5cf6a" stroke-width="1"/>
  <path d="M8 5.4v5.2M6.4 8h3.2" stroke="#7a5c14" stroke-width="1.1" stroke-linecap="round"/>
</svg>
```
Glow dourado (drop-shadow) e um *flip* ocasional opcional (gira em Y a cada ~4s; cosmético, não-crítico).

---

## SCRIPT — `victory_defeat.gd`

```gdscript
class_name VictoryDefeat extends CanvasLayer

signal return_pressed     # jogador clicou em "Voltar para Taldorian"

const TIERS := {
    "Bronze":   { "c1": "#d39a6a", "c2": "#a96a3c", "deep": "#5e3a1f", "ink": "#2a1709" },
    "Prata":    { "c1": "#dfe6ef", "c2": "#a7b3c4", "deep": "#5a6679", "ink": "#1d2430" },
    "Ouro":     { "c1": "#f5cf6a", "c2": "#d39a2c", "deep": "#7a5410", "ink": "#2a1d04" },
    "Platina":  { "c1": "#9fe6dc", "c2": "#52b3a6", "deep": "#1f5a52", "ink": "#062421" },
    "Diamante": { "c1": "#a9defc", "c2": "#5aa8e0", "deep": "#1c5a86", "ink": "#04202f" },
    "Mestre":   { "c1": "#d3b8ff", "c2": "#9a72e0", "deep": "#4a2f86", "ink": "#1a0e33" },
}

# Temas (cores em hex; converta com Color(hex) — derivadas dos oklch do HTML)
const GOLD       := Color("ffd676")   # accent vitória
const GOLD_DIM   := Color("a07d3a")
const GREEN      := Color("6fe39a")   # delta positivo
const RED        := Color("d75640")   # accent derrota
const RED_DIM    := Color("8e3325")
const GOLD_COIN  := Color("f2cf6a")   # ouro (sempre dourado)

var _data: Dictionary = {}
var _is_victory: bool = false

@onready var title:       Label = %Title
@onready var desc:        Label = %Desc
@onready var rank_shield: Control = %RankShield
@onready var rank_tier:   Label = %RankTier
@onready var delta_label: Label = %DeltaLabel
@onready var delta_badge: Control = %DeltaBadge
@onready var pts_value:   Label = %PtsValue
@onready var pts_fill:    ColorRect = %PtsFill
@onready var pts_track:   Control = %PtsTrack
@onready var pts_hint:    Label = %PtsHint
@onready var reward_value:Label = %RewardValue
@onready var card:        Control = %ResultCard
@onready var return_btn:  Button = %ReturnBtn

# ── Public API ────────────────────────────────────────────────────────────────
func show_result(data: Dictionary) -> void:
    _data = data
    _is_victory = data.get("result", "victory") == "victory"
    visible = true
    _apply_theme()
    _populate_static()
    _spawn_particles()
    _run_sequence()

# ── Setup ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
    visible = false
    return_btn.pressed.connect(func(): emit_signal("return_pressed"))

func _accent() -> Color:        return GOLD if _is_victory else RED
func _accent_dim() -> Color:    return GOLD_DIM if _is_victory else RED_DIM

func _apply_theme() -> void:
    # Backdrop tint, partículas, glow do crest, cor do título/badge/barra
    # seguem _accent()/_accent_dim(). Aplique via theme variations / modulate.
    pass

func _populate_static() -> void:
    title.text = "Vitória!" if _is_victory else "Derrota"
    desc.text  = ("Seus heróis provaram seu valor nos campos de Taldorian."
        if _is_victory else "Seus heróis caíram em batalha. A lenda continua…")
    rank_tier.text = "%s %s" % [_data.tier, _data.div]
    # escudo
    rank_shield.tier = _data.tier
    rank_shield.div  = _data.div
    rank_shield.queue_redraw()
    # estado inicial dos contadores (antes da animação)
    pts_value.text = str(int(_data.lp_before))
    pts_fill.size.x = pts_track.size.x * float(_data.lp_before) / float(_data.lp_max)
    # badge e ouro começam escondidos
    delta_badge.modulate.a = 0.0
    reward_value.modulate.a = 0.0

# ── Sequência animada ─────────────────────────────────────────────────────────
func _run_sequence() -> void:
    # 0.0s  overlay fade-in
    _fade_in_overlay()
    # 0.2s  card reveal (scale 0.9→1, alpha 0→1)
    _reveal_card()
    # 1.45s badge de delta "pop" + começa contagem dos pontos (1.15s)
    _start_points_tween(1.45)
    # 2.05s linha de ouro aparece + contagem (0.95s)
    _start_gold_tween(2.05)

func _fade_in_overlay() -> void:
    %Backdrop.modulate.a = 0.0
    create_tween().tween_property(%Backdrop, "modulate:a", 1.0, 0.6)\
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _reveal_card() -> void:
    card.modulate.a = 0.0
    card.scale = Vector2(0.9, 0.9)
    card.pivot_offset = card.size / 2.0
    var t := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    t.tween_property(card, "modulate:a", 1.0, 0.9).set_delay(0.2)
    t.tween_property(card, "scale", Vector2.ONE, 0.9).set_delay(0.2)

func _start_points_tween(delay: float) -> void:
    var lp_after: int = clampi(int(_data.lp_before) + int(_data.lp_delta), 0, int(_data.lp_max))
    var up: bool = int(_data.lp_delta) >= 0
    var t := create_tween()
    t.tween_interval(delay)
    # badge pop (overshoot)
    t.tween_callback(func(): _show_delta_badge(up))
    # contagem do número (easeOutCubic) + barra
    t.parallel().tween_method(
        func(v: float):
            pts_value.text = str(int(round(v))),
        float(_data.lp_before), float(lp_after), 1.15
    ).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    t.parallel().tween_property(
        pts_fill, "size:x",
        pts_track.size.x * float(lp_after) / float(_data.lp_max), 1.15
    ).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    # bump de cor no número durante a contagem
    pts_value.add_theme_color_override("font_color", _accent())
    t.tween_callback(func():
        pts_value.add_theme_color_override("font_color", Color("f4f0e6")))
    # hint
    pts_hint.text = ("Faltam %d pts p/ promoção" % (int(_data.lp_max) - lp_after)) if up \
        else ("%d pts até rebaixar" % lp_after)

func _show_delta_badge(up: bool) -> void:
    delta_label.text = ("+%d" % int(_data.lp_delta)) if up else ("−%d" % abs(int(_data.lp_delta)))
    delta_label.add_theme_color_override("font_color", GREEN if up else RED)
    # pop com overshoot (scale 0.85→1.12→1, alpha 0→1)
    delta_badge.scale = Vector2(0.85, 0.85)
    delta_badge.pivot_offset = delta_badge.size / 2.0
    var t := create_tween().set_parallel()
    t.tween_property(delta_badge, "modulate:a", 1.0, 0.3)
    t.tween_property(delta_badge, "scale", Vector2(1.12,1.12), 0.32)\
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    t.chain().tween_property(delta_badge, "scale", Vector2.ONE, 0.18)

func _start_gold_tween(delay: float) -> void:
    var t := create_tween()
    t.tween_interval(delay)
    t.tween_property(reward_value, "modulate:a", 1.0, 0.4)
    t.parallel().tween_method(
        func(v: float):
            reward_value.text = "+%s Ouro" % _fmt(int(round(v))),
        0.0, float(_data.gold), 0.95
    ).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _fmt(n: int) -> String:
    # separador de milhar pt-BR: 1250 → "1.250"
    var s := str(n); var out := ""; var c := 0
    for i in range(s.length()-1, -1, -1):
        out = s[i] + out; c += 1
        if c % 3 == 0 and i > 0: out = "." + out
    return out

func _spawn_particles() -> void:
    # vitória: ~40 partículas douradas; derrota: ~18 vermelhas.
    # sobem da base ao topo, fade in/out, leve drift horizontal. Loop contínuo.
    pass
```

---

## TEMA / ESTILOS — `res://themes/victorydefeat_theme.tres`

Fontes (mesmas do resto do jogo):
- `CinzelDecorative-Bold` (título)
- `Cinzel` / `Cinzel-SemiBold` (labels, rank, botão)
- `CrimsonPro-Italic` (descrição)
- `SplineSansMono` (números: pontos, delta, ouro)

### Paleta (derivada dos oklch do HTML)
```
# Comuns
bg_deep      = oklch(0.07 0.055 268) ≈ #0e0c1f
panel_bg     = oklch(0.10 0.04 268)  ≈ #16162a   (alpha 0.90)
ink          = oklch(0.95 0.02 78)   ≈ #f4f0e6   (números/títulos claros)
line         = oklch(0.5 0.02 268)   ≈ #6f7382   (divisórias @ 0.12–0.18)
gold_coin    = #f2cf6a / unidade #b89a52

# Tema VITÓRIA (accent dourado)
accent       = oklch(0.82 0.16 80)   ≈ #ffd676
accent_dim   = oklch(0.6 0.10 78)    ≈ #b89a5e
delta_pos    = oklch(0.86 0.16 145)  ≈ #6fe39a   (verde — ganho)
fill         = gradient #e8c14a → #ffd676

# Tema DERROTA (accent carmesim)
accent       = oklch(0.62 0.22 15)   ≈ #d75640
accent_dim   = oklch(0.5 0.14 15)    ≈ #9e4435
delta_neg    = oklch(0.72 0.20 18)   ≈ #e9694f   (vermelho — perda)
fill         = gradient #8e3325 → #c84634
```

### StyleBoxFlat
- **result_panel** — bg `panel_bg @ 0.90`, border 1px `accent @ 0.30`, shadow `0 0 80px accent @ 0.09 + 0 30px 60px #00000099`.
- **delta_box** — border 1px (`delta_pos @ 0.5` / `delta_neg @ 0.5`), bg tint suave do mesmo, padding `4/10/4/10`.
- **track_bg** — bg `oklch(0.16 0.03 268)` ≈ `#1d1d33`, border 1px `#4a4e6e @ 0.3`, sem corner radius (retangular fino, 9px alto).
- **return_btn** — bg `oklch(0.14 0.05 268) @ 0.9` ≈ `#1b1b30`, border 1px `accent @ 0.55`, padding `17/16`.

### Cantos ornamentais (4 cantos do painel)
4 `Control` filhos do painel, cada um com `_draw()` desenhando 2 retângulos perpendiculares de 18×2px na cor `accent @ 0.7` (mesma técnica do `PauseMenu`).

### Textos
- **eyebrow**     — Cinzel-SemiBold 9pt, letter-spacing 0.5em, uppercase, color `accent_dim @ 0.8`, centro.
- **title**       — CinzelDecorative-Bold 34pt, color `accent` (ou gradient do tema), drop_shadow 24px `accent @ 0.5`, centro.
- **desc**        — CrimsonPro-Italic 15pt, color `oklch(0.72 0.03 78) @ 0.72` ≈ `#b6ad9a`, centro.
- **rank_label**  — Cinzel 9pt, letter-spacing 0.34em, uppercase, color `accent_dim @ 0.85`.
- **rank_tier**   — Cinzel-SemiBold 17pt, color `#e6e2ee`.
- **delta**       — SplineSansMono-SemiBold 16pt, color `delta_pos`/`delta_neg`.
- **pts_value**   — SplineSansMono-SemiBold 28pt, tabular-nums, color `ink` (vira `accent` durante a contagem).
- **pts_unit**    — Cinzel 11pt, letter-spacing 0.28em, uppercase, color `accent_dim`.
- **pts_foot**    — SplineSansMono 10pt, color `#9094a8`; hint à direita em `accent_dim @ 0.9`.
- **reward_label**— Cinzel 9pt, letter-spacing 0.32em, uppercase, color `#c2a766 @ 0.9`.
- **reward_value**— SplineSansMono-SemiBold 19pt, color `gold_coin`, text_shadow 16px dourado @ 0.4; unidade "Ouro" em Cinzel 9pt `#b89a52`.
- **return_btn**  — Cinzel-Bold 13pt, letter-spacing 0.22em, uppercase, color `accent`.

---

## ANIMAÇÕES (Tween, `EASE_OUT_CUBIC` salvo indicado) — TIMELINE

| t (s) | Elemento        | Propriedade               | De → Para                 | Duração | Trans |
|-------|-----------------|---------------------------|---------------------------|---------|-------|
| 0.0   | Backdrop        | `modulate:a`              | 0 → 1                     | 0.6s    | CUBIC |
| 0.2   | ResultCard      | `modulate:a`, `scale`     | 0→1, 0.9→1.0              | 0.9s    | CUBIC |
| 1.45  | DeltaBadge      | `modulate:a`, `scale`     | 0→1, 0.85→1.12→1.0        | 0.32+0.18s | BACK |
| 1.45  | PtsValue        | texto (contador)          | lp_before → lp_after      | 1.15s   | CUBIC |
| 1.45  | PtsFill         | `size:x`                  | %before → %after          | 1.15s   | CUBIC |
| 1.45  | PtsValue        | `font_color`              | accent → ink (ao fim)     | —       | —     |
| 2.05  | RewardValue     | `modulate:a`              | 0 → 1                     | 0.4s    | BACK  |
| 2.05  | RewardValue     | texto (contador)          | 0 → gold                  | 0.95s   | CUBIC |
| loop  | Crest           | glow (drop_shadow/scale)  | 18px → 38px e volta       | 3s      | SINE  |
| loop  | Partículas      | sobem + fade              | base → topo               | 7–17s   | LINEAR|
| loop  | Coin (opcional) | rotação Y (flip)          | 0 → 360 a cada ~4s        | 0.6s    | —     |

> Numa derrota a barra **drena** (largura diminui) e o badge usa vermelho; numa vitória ela **preenche** e o badge usa verde — sempre na mesma timeline.
> Respeite `prefers-reduced-motion` (em Godot: opção de acessibilidade): se ligado, pule os tweens e mostre o **estado final** direto (contadores nos valores finais, alphas em 1).

---

## INTERAÇÃO / FLUXO

1. O `Board` detecta o fim da partida e monta o dicionário de resultado a partir do `GameState`/`PlayerProfile`.
2. Chama `victory_defeat.show_result(data)`. O overlay aparece, roda a sequência e fica aguardando.
3. O jogador clica **"← Voltar para Taldorian"** → a cena emite `return_pressed`.
4. O `Board` troca para o hub/menu principal (ex.: `Lobby.tscn` / `World HUD`).

O overlay **não** muda o estado do jogo nem grava pontos — apenas exibe o resultado já calculado. A persistência de rank/ouro é responsabilidade do `GameState`/servidor.

---

## INTEGRAÇÃO COM `Board.tscn`

```gdscript
const VICTORY_DEFEAT_SCENE := preload("res://scenes/ui/victorydefeat/VictoryDefeat.tscn")

@onready var victory_defeat: VictoryDefeat = VICTORY_DEFEAT_SCENE.instantiate()

func _ready() -> void:
    add_child(victory_defeat)
    victory_defeat.return_pressed.connect(_on_return_to_hub)

func _on_match_ended(local_won: bool) -> void:
    var rank := PlayerProfile.current_rank          # { tier, div, lp, lp_max }
    var delta := GameState.last_lp_delta            # +/− calculado pelo matchmaking
    var gold  := GameState.last_gold_reward
    victory_defeat.show_result({
        "result":   "victory" if local_won else "defeat",
        "tier":     rank.tier,
        "div":      rank.div,
        "lp_before":rank.lp,
        "lp_delta": delta,
        "lp_max":   rank.lp_max,
        "gold":     gold,
    })

func _on_return_to_hub() -> void:
    get_tree().change_scene_to_file("res://scenes/ui/lobby/Lobby.tscn")
```

---

## CHECKLIST DE FIDELIDADE AO HTML

Abra `Victory Defeat.html` lado a lado com a cena Godot e confirme:

- [ ] Overlay escurece o tabuleiro com gradient radial + tint do tema (dourado/vermelho), não opaco total.
- [ ] Partículas sobem da base ao topo (mais e mais brilhantes na vitória, menos e vermelhas na derrota).
- [ ] Crest acima do painel com glow pulsante — vitória: escudo+coroa+estrela; derrota: escudo trincado.
- [ ] Painel central com **cantos ornamentais em L** (4 cantos) na cor da borda do tema.
- [ ] Eyebrow "BATALHA ENCERRADA"; título "Vitória!" (dourado) / "Derrota" (carmesim) em fonte decorativa.
- [ ] Divider central: 2 linhas + diamante.
- [ ] Descrição em itálico (CrimsonPro).
- [ ] **Rank module**: escudo do tier (Prata II) com a divisão por cima; label "RANK ATUAL" + "Prata II".
- [ ] **Badge de delta** aparece com "pop" (overshoot): `+24` verde (vitória) / `−18` vermelho (derrota), com seta.
- [ ] **Pontos** contam do valor anterior ao novo; número muda de cor (accent) durante a contagem e volta ao claro.
- [ ] **Barra** preenche (vitória) / drena (derrota) junto com a contagem; 10 divisórias (ticks) visíveis.
- [ ] Hint à direita: "Faltam N pts p/ promoção" (vitória) / "N pts até rebaixar" (derrota).
- [ ] **Linha de ouro**: ícone de moeda dourado + "OURO GANHO" + "+340 Ouro" contando de 0; surge depois dos pontos.
- [ ] Botão **"← Voltar para Taldorian"** com borda do accent; hover sobe 2px + brilho + sombra; seta desliza −3px.
- [ ] Toda a sequência respeita a ordem temporal: overlay → card → badge+pontos → ouro.

---

## ESCALA / RESPONSIVIDADE

- **Tamanho nativo:** 1280×720 (16:9).
- O `CanvasLayer` raiz cobre toda a viewport; `Root` Control usa `anchors=full_rect`.
- O `CenterContainer` centra o card; aplique `scale = min(viewport.x/1280, viewport.y/720)` no `Root` se precisar manter proporção (mesmo padrão das outras cenas).
- **Não** escale fontes individualmente.

---

## ENTREGÁVEIS

- [ ] `res://scenes/ui/victorydefeat/VictoryDefeat.tscn` + `victory_defeat.gd`
- [ ] `res://themes/victorydefeat_theme.tres`
- [ ] `res://assets/ui/victorydefeat/coin.svg` (reutilize o do World HUD se já existir)
- [ ] Crests `victory_crest.svg` / `defeat_crest.svg` (ou desenho via `_draw()` / reutilize do conjunto do jogo)
- [ ] `RankShield` desenhado via `_draw()` usando a tabela `TIERS` (sem asset por tier)
- [ ] Integração no `board.gd` (`show_result` no fim da partida + handler de `return_pressed`)

---

## SINAIS PÚBLICOS

A `VictoryDefeat` deve expor exatamente:

- `signal return_pressed` — emitido quando o jogador clica em "Voltar para Taldorian".

E o método público:

- `func show_result(data: Dictionary) -> void` — recebe o dicionário descrito em **MODELO DE DADOS**, monta o tema e dispara a sequência animada.

---

## REFERÊNCIA VISUAL

**Leia `Victory Defeat.html` na raiz do projeto antes de começar.** Não invente posições, fontes ou cores — espelhe. Os valores de exemplo (`SCENARIOS` no topo do `<script>`: rank Prata II, lp 64, delta +24/−18, gold 340/120) servem de referência; em produção vêm do `GameState`. As proporções foram desenhadas para 1280×720; use-as como tamanho nativo e escale uniformemente.

Pode começar.
