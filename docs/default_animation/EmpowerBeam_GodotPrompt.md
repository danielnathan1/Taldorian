# Prompt para Claude Code — `EmpowerBeam.tscn` (Godot 4)

Cole o conteúdo abaixo no Claude Code. Ele assume que o projeto Godot do **Taldorian TCCG** já existe em `res://`, que `Card.tscn` e `Board.tscn` já foram criados conforme `Card_GodotPrompt.md`, e que o efeito será disparado quando um herói lança um **encantamento de fortalecimento** sobre um aliado.

---

## CONTEXTO

Estou desenvolvendo **Taldorian TCCG** em Godot 4.x. No Board, cada lado (jogador / oponente) tem 1 herói ativo + 3 do banco + Arsenal + Deck + Cemitério, dispostos em um tabuleiro 1280×720 (espelhado verticalmente). A referência visual completa do efeito em HTML/CSS/SVG está em **`Empower Beam.html`** na raiz do projeto.

**Leia esse arquivo antes de começar.** Ele tem:
- Posicionamento exato em px da origem (`SOURCE = {x: 720, y: 512}` — o conjurador / Arquimaga) e do alvo aliado (`TARGET = {x: 360, y: 524}` — o Cavaleiro fortalecido).
- O arco do feixe: **bézier quadrática** com um único ponto de controle elevado (`BOW = 70`), ver `PC` + `qbez()`.
- A timeline completa em segundos (`T.CHARGE_START`…`T.HOLD_END`).
- O sistema de **cores selecionáveis** (`COLORS` + `makeTheme()`) que pinta feixe, luz e números: **vermelho, amarelo, azul, branco, marrom**.

## OBJETIVO

Construir **`res://scenes/vfx/empower_beam/EmpowerBeam.tscn`** — uma cena de VFX **autocontida** e **reutilizável**, instanciada sobre o `Board.tscn` quando um aliado recebe um buff de Ataque/Defesa. Sequência:

1. **Carga (0.0–0.5s)** — a carta do conjurador pulsa na cor do encantamento; um nó luminoso se forma na origem.
2. **Banner (0.1–2.7s)** — "FORTALECER" surge no centro com subtítulo, mudando de "Canalizando o encantamento" → "O aliado é fortalecido".
3. **Feixe (0.42–1.0s)** — um feixe de magia se **estende em arco** da origem até o aliado, com cabeça brilhante na ponta + motes de energia fluindo ao longo da curva.
4. **Conexão / Luz (1.0s)** — ao alcançar o alvo, uma **luz floresce sobre a carta**: flash radial + anéis + 12 raios ascendentes; a carta passa a brilhar na cor do encantamento (estado fortalecido sustentado) + partículas subindo.
5. **Buff (1.18s)** — dois chips popam acima da carta com bounce: **`+ATK`** (ícone de espada) e **`+DEF`** (ícone de escudo), sobem e desvanecem.
6. **Hold (1.85–3.3s)** — o feixe some, a luz assenta num glow residual (o aliado **continua** fortalecido), banner some; efeito conclui e emite `finished`.

A cena precisa ser **data-driven** (`play(source_pos, target_pos, color, atk_gain, def_gain)`) — qualquer carta de buff reusa trocando a cor e os valores.

---

## ÁRVORE DE CENAS

### `EmpowerBeam.tscn`
```
EmpowerBeam (Node2D)  [script: empower_beam.gd]
├─ ScreenFlash (CanvasLayer layer=50 → ColorRect, anchors=full_rect, modulate.a=0)
├─ Beam (Node2D)
│  ├─ BeamGlow  (Line2D, width=15, blend ADD)   # halo macio
│  ├─ BeamMid   (Line2D, width=6.5, blend ADD)
│  ├─ BeamCore  (Line2D, width=2.6, blend ADD)  # núcleo quase branco
│  ├─ Motes     (Node2D)                         # faíscas fluindo pela curva
│  ├─ SourceNode (Sprite2D, texture=node_glow.png, blend ADD)
│  └─ Head       (Sprite2D, texture=node_glow.png, blend ADD)  # ponta enquanto estende
├─ Bloom (Node2D)                                 # luz no alvo
│  ├─ Halo   (Sprite2D, texture=bloom_halo.png, blend ADD, modulate.a=0)
│  ├─ Flash  (Sprite2D, texture=bloom_flash.png, blend ADD, modulate.a=0)
│  ├─ Ring   (Sprite2D, texture=bloom_ring.png, blend ADD, modulate.a=0)
│  ├─ Rays   (CPUParticles2D, raios ascendentes)
│  └─ Rising (CPUParticles2D, motes subindo, contínuo enquanto fortalecido)
├─ TargetGlow (Sprite2D)                          # glow aplicado por baixo da carta-alvo
├─ BuffPopups (Control)
│  ├─ AtkChip (PanelContainer → HBox[ SwordIcon(TextureRect) + AtkNum(Label) + "ATK"(Label) ])
│  └─ DefChip (PanelContainer → HBox[ ShieldIcon(TextureRect) + DefNum(Label) + "DEF"(Label) ])
├─ Banner (Control, anchors=center)
│  ├─ Subtitle    (Label, "Encantamento")
│  ├─ AbilityName (Label, "FORTALECER")
│  ├─ Rule        (ColorRect, 300x1)
│  └─ Status      (Label, "Canalizando o encantamento")
└─ AudioPlayers
   ├─ Charge  (AudioStreamPlayer)
   ├─ Beam    (AudioStreamPlayer)   # zumbido contínuo do feixe
   └─ Empower (AudioStreamPlayer)   # "chime" de fortalecimento na conexão
```

Marque cada nó dinâmico com **Unique Name in Owner** (`%`).

---

## ASSETS — em `res://assets/vfx/empower_beam/`

Todas as texturas são **brancas/claras com fundo transparente**, pré-multiplicadas para blend aditivo — a cor vem do `modulate` (definido pela cor do encantamento). **Não recrie coloridas; mantenha brancas e tinja por código.**

| Arquivo            | Tamanho | Uso                                                                |
|--------------------|---------|--------------------------------------------------------------------|
| `node_glow.png`    | 128×128 | Nó luminoso na origem + cabeça da ponta do feixe (orbe radial)     |
| `mote.png`         | 32×32   | Faísca que flui pela curva do feixe                                |
| `bloom_halo.png`   | 256×256 | Halo radial macio sustentado sobre a carta fortalecida            |
| `bloom_flash.png`  | 256×256 | Flash central brilhante no instante da conexão                     |
| `bloom_ring.png`   | 256×256 | Anel fino que expande na conexão (escalar ~0.1 → 1.2)             |
| `ray.png`          | 16×96   | Raio ascendente (12 instâncias em leque, via CPUParticles)         |
| `sword_icon.png`   | 48×48   | Ícone de espada do chip `+ATK` (branco, tinja por modulate)        |
| `shield_icon.png`  | 48×48   | Ícone de escudo do chip `+DEF` (branco, tinja por modulate)        |
| `card_buff_glow.png`| 256×320| Glow colorido por baixo da carta-alvo enquanto fortalecida         |

### Import flags (no `.import` de cada PNG)
- `filter = true`, `mipmaps = true`
- `compress/mode = 0` (Lossless)
- `process/fix_alpha_border = true`

---

## SISTEMA DE CORES — espelha `COLORS` + `makeTheme()` do HTML

```gdscript
# Cada cor define: tom claro do núcleo + tom "bright". O resto é derivado por
# alpha. Valores aproximam os oklch do HTML convertidos para sRGB.
const PALETTES := {
    "vermelho": { "bright": Color(0.95, 0.35, 0.26), "core": Color(1.00, 0.86, 0.80) },
    "amarelo":  { "bright": Color(0.98, 0.80, 0.28), "core": Color(1.00, 0.97, 0.84) },
    "azul":     { "bright": Color(0.36, 0.55, 0.98), "core": Color(0.84, 0.90, 1.00) },
    "branco":   { "bright": Color(0.93, 0.94, 0.97), "core": Color(0.99, 0.99, 1.00) },
    "marrom":   { "bright": Color(0.70, 0.52, 0.30), "core": Color(0.90, 0.82, 0.68) },
}

func _theme(key: String) -> Dictionary:
    var p: Dictionary = PALETTES.get(key, PALETTES["azul"])
    var b: Color = p.bright
    return {
        "core":   p.core,
        "bright": b,
        "mid":    Color(b.r, b.g, b.b, 0.90),
        "glow":   Color(b.r, b.g, b.b, 0.50),
        "soft":   Color(b.r, b.g, b.b, 0.22),
        "faint":  Color(b.r, b.g, b.b, 0.10),
    }
```

---

## SCRIPT — `empower_beam.gd`

```gdscript
class_name EmpowerBeam extends Node2D

@export var ability_name: String     = "FORTALECER"
@export var ability_subtitle: String = "Encantamento"

# ── Timeline (segundos) — idêntica ao objeto T do HTML ───────────────────────
const T_CHARGE_END   := 0.5
const T_BANNER_IN    := 0.1
const T_BANNER_OUT   := 2.7
const T_BEAM_START   := 0.42
const T_BEAM_CONNECT := 1.0
const T_BUFF_POP     := 1.18
const T_FADE_START   := 1.85
const T_FADE_END     := 2.35
const T_HOLD_END     := 3.3
const BOW            := 70.0

signal finished

var _src: Vector2
var _tgt: Vector2
var _theme: Dictionary
var _atk: int
var _def: int
var _pc: Vector2     # ponto de controle da bézier

# API pública — chame do Board quando o buff for aplicado.
func play(source_pos: Vector2, target_pos: Vector2, color_key: String, atk_gain: int, def_gain: int) -> void:
    _src = source_pos
    _tgt = target_pos
    _theme = _theme(color_key)
    _atk = atk_gain
    _def = def_gain
    _pc = (_src + _tgt) * 0.5 + Vector2(0, -BOW)
    _tint_nodes()
    _run()

# Bézier quadrática (igual a qbez() do HTML)
func _qbez(t: float) -> Vector2:
    var u := 1.0 - t
    return u*u*_src + 2.0*u*t*_pc + t*t*_tgt

func _ease_out_cubic(t: float) -> float: return 1.0 - pow(1.0 - t, 3.0)

func _run() -> void:
    %SourceNode.position = _src
    %Bloom.position = _tgt
    %TargetGlow.position = _tgt
    %TargetGlow.modulate = _theme.glow; %TargetGlow.modulate.a = 0.0
    _setup_banner()

    var tw := create_tween().set_parallel(true)

    # Carga: pulso de cor no conjurador (assuma que o Board expõe a carta)
    # emit_signal para o Board destacar a carta-conjuradora, se desejar.

    # Banner
    tw.tween_property(%Banner, "modulate:a", 1.0, 0.35).set_delay(T_BANNER_IN)
    tw.tween_property(%Banner, "modulate:a", 0.0, 0.4).set_delay(T_BANNER_OUT - 0.4)
    get_tree().create_timer(T_BEAM_CONNECT, false).timeout.connect(func():
        %Status.text = "O aliado é fortalecido")

    # Crescimento do feixe (estende em arco)
    var grow := create_tween()
    grow.set_delay(T_BEAM_START)
    grow.tween_method(_update_beam, 0.0, 1.0, T_BEAM_CONNECT - T_BEAM_START)
    grow.tween_callback(_on_connect)

    # Fade do feixe no fim
    get_tree().create_timer(T_FADE_START, false).timeout.connect(_fade_beam)

    # Encerramento
    get_tree().create_timer(T_HOLD_END, false).timeout.connect(func():
        emit_signal("finished"); queue_free())

# Atualiza os 3 Line2D amostrando a curva real até `progress`, + cabeça + motes
func _update_beam(progress: float) -> void:
    var draw_len := _ease_out_cubic(progress)
    var pts := PackedVector2Array()
    var steps := 56
    for i in range(0, steps + 1):
        var u := float(i) / steps
        if u > draw_len: break
        pts.append(_qbez(u))
    pts.append(_qbez(draw_len))                 # ponta exata
    %BeamGlow.points = pts
    %BeamMid.points  = pts
    %BeamCore.points = pts
    %Head.position = _qbez(draw_len)
    %Head.visible = draw_len < 0.999
    # (Os motes fluindo podem ser um CPUParticles2D ao longo da curva, ou
    #  Sprites reposicionados em _process — ver HTML função Beam(), array `motes`.)

func _on_connect() -> void:
    %Head.visible = false
    # Flash de tela curto
    %ScreenFlash.modulate = _theme.core
    var sf := create_tween()
    sf.tween_property(%ScreenFlash, "modulate:a", 0.45, 0.04)
    sf.tween_property(%ScreenFlash, "modulate:a", 0.0, 0.3)

    # Luz que floresce sobre a carta
    _bloom_burst()

    # Glow sustentado na carta (continua fortalecida — fica num resíduo)
    var tg := create_tween()
    tg.tween_property(%TargetGlow, "modulate:a", 0.9, 0.22)
    tg.tween_property(%TargetGlow, "modulate:a", 0.5, 0.6).set_delay(T_FADE_START - T_BEAM_CONNECT)
    %Rising.emitting = true

    # Chips +ATK / +DEF com bounce
    get_tree().create_timer(T_BUFF_POP - T_BEAM_CONNECT, false).timeout.connect(_pop_buffs)

func _bloom_burst() -> void:
    for n in ["Halo", "Flash", "Ring"]:
        get_node("%" + n).modulate = _theme.bright
    # Halo sustentado
    %Halo.modulate.a = 0.0
    create_tween().tween_property(%Halo, "modulate:a", 0.85, 0.2)
    # Flash central
    %Flash.scale = Vector2(0.4, 0.4); %Flash.modulate.a = 0.9
    var ft := create_tween().set_parallel(true)
    ft.tween_property(%Flash, "scale", Vector2(0.9, 0.9), 0.5)
    ft.tween_property(%Flash, "modulate:a", 0.0, 0.5)
    # Anel expansivo
    %Ring.scale = Vector2(0.1, 0.1); %Ring.modulate = _theme.bright
    var rt := create_tween().set_parallel(true)
    rt.tween_property(%Ring, "scale", Vector2(1.2, 1.2), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    rt.tween_property(%Ring, "modulate:a", 0.0, 0.6)
    # Raios ascendentes
    %Rays.modulate = _theme.bright
    %Rays.emitting = true

func _pop_buffs() -> void:
    # +ATK estoura pela ESQUERDA da carta, +DEF pela DIREITA
    %AtkChip.position = _tgt + Vector2(-50, -6)   # pivot na borda direita do chip → cresce p/ esquerda
    %DefChip.position = _tgt + Vector2( 50, -6)   # pivot na borda esquerda do chip → cresce p/ direita
    %AtkChip.pivot_offset = Vector2(%AtkChip.size.x, %AtkChip.size.y * 0.5)
    %DefChip.pivot_offset = Vector2(0, %DefChip.size.y * 0.5)
    for chip in [%AtkChip, %DefChip]:
        chip.modulate = _theme.bright
    %AtkNum.text = "+%d" % _atk
    %DefNum.text = "+%d" % _def
    for chip in [%AtkChip, %DefChip]:
        chip.scale = Vector2(0.4, 0.4)
        chip.modulate.a = 0.0
        var pt := create_tween().set_parallel(true)
        pt.tween_property(chip, "scale", Vector2(1, 1), 0.4)\
            .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        pt.tween_property(chip, "modulate:a", 1.0, 0.2)
        pt.tween_property(chip, "position:y", chip.position.y - 26, 1.2)
        pt.chain().tween_property(chip, "modulate:a", 0.0, 0.35)\
            .set_delay(T_HOLD_END - T_BUFF_POP - 0.5)

func _fade_beam() -> void:
    var ft := create_tween().set_parallel(true)
    for n in ["BeamGlow", "BeamMid", "BeamCore", "SourceNode"]:
        ft.tween_property(get_node("%" + n), "modulate:a", 0.0, T_FADE_END - T_FADE_START)
    %Rising.emitting = false

func _tint_nodes() -> void:
    for n in ["BeamGlow", "BeamMid", "SourceNode", "Head"]:
        get_node("%" + n).modulate = _theme.mid
    %BeamCore.modulate = _theme.core
    %BeamGlow.modulate = _theme.soft
    for n in ["Motes"]:
        pass

func _setup_banner() -> void:
    %Banner.modulate.a = 0.0
    %AbilityName.text = ability_name
    %Subtitle.text = ability_subtitle
    %Status.text = "Canalizando o encantamento"
    %AbilityName.add_theme_color_override("font_color", _theme.core)
    %Subtitle.add_theme_color_override("font_color", _theme.bright)
    %Status.add_theme_color_override("font_color", _theme.bright)
```

> **Motes do feixe:** o HTML reposiciona ~7 faíscas em `u = ((t*0.85)+i/N) % 1` ao longo da curva (só quando `u <= draw_len`). Replique com um `CPUParticles2D` configurado em modo *path*, ou com Sprites reposicionados em `_process()` usando `_qbez(u)`. Veja a função `Beam()` no HTML.

---

## INTEGRAÇÃO COM O BOARD

No `board.gd`, quando um aliado recebe o buff:

```gdscript
func _on_ally_empowered(caster: Node2D, ally: Node2D, color_key: String, atk: int, deff: int) -> void:
    var fx := preload("res://scenes/vfx/empower_beam/EmpowerBeam.tscn").instantiate()
    add_child(fx)
    fx.play(
        caster.global_position + Vector2(0, -28),   # ponta do conjurador (~SOURCE do HTML)
        ally.global_position   + Vector2(0, -16),   # alvo aliado (~TARGET do HTML)
        color_key,                                   # "vermelho" | "amarelo" | "azul" | "branco" | "marrom"
        atk, deff
    )
    fx.finished.connect(func():
        ally.stats.atk += atk
        ally.stats.defense += deff
        ally.refresh_stat_labels())
```

> Aplique os ganhos de stat **no `finished`** (ou já no `_on_connect`, se quiser o número da carta mudando junto com o popup) — o VFX é puramente visual.

---

## TEMA / TIPOGRAFIA DO BANNER

- **Subtitle** — `Cinzel-Regular.ttf`, size **14**, cor = `theme.bright`, uppercase, letter_spacing wide
- **AbilityName** — `CinzelDecorative-Bold.ttf`, size **48**, cor = `theme.core`, shadow blur 18 com `theme.glow`
- **Rule** — ColorRect 300×1, gradient horizontal transparente → `theme.bright` → transparente
- **Status** — `Cinzel-Regular.ttf`, size **12**, cor = `theme.bright`, opacity 0.85, uppercase

**Chips +ATK/+DEF:** painel `Color(0.10,0.07,0.12,0.66)`, borda 1px = `theme.bright`, box_shadow glow = `theme.glow`. Número em `CinzelDecorative-Bold` size 26 cor `theme.core`; tag "ATK"/"DEF" em `Cinzel` size 9 uppercase.

---

## SOM (OPCIONAL — não-bloqueante)

- **Charge** — hum crescente curto em `play()` (0.0s), ~0.5s.
- **Beam** — zumbido suave de `T_BEAM_START` até a conexão.
- **Empower** — "chime" ascendente de fortalecimento em `_on_connect()` (1.0s); pitch um pouco mais alto = mais "mágico".

---

## CHECKLIST DE FIDELIDADE AO HTML

Abra `Empower Beam.html` e use o slider de tempo + os botões de cor para comparar:

- [ ] **0.0–0.5s** — conjurador carrega; nó luminoso na origem na cor escolhida
- [ ] **0.7s** — feixe **em arco** se estendendo da origem, cabeça brilhante na ponta, motes fluindo
- [ ] **1.0s** — feixe **conecta sobre a carta do aliado**; flash + anel + raios ascendentes; flash de tela curto
- [ ] **1.18s** — chip **+ATK** (espada) estoura pela **esquerda** da carta e **+DEF** (escudo) pela **direita**, ambos sobem e desvanecem
- [ ] **1.0–1.85s** — carta do aliado brilha na cor (estado fortalecido); partículas subindo
- [ ] **1.85–2.35s** — feixe desvanece; glow assenta num resíduo (segue fortalecido)
- [ ] **3.3s** — efeito limpa, `finished` emitido; stats aplicados
- [ ] **Cores** — testar `vermelho / amarelo / azul / branco / marrom`: feixe, luz, chips e glow da carta TODOS na mesma cor

**Ponto crítico:** a luz deve nascer **sobre a carta do aliado** (TARGET) e os chips devem flanquear a carta — **+ATK à esquerda, +DEF à direita** — não empilhados no centro da tela. Se estiverem deslocados, confira `target_pos` passado ao `play()` e o offset usado no Board.

---

## ENTREGÁVEIS

- [ ] `res://scenes/vfx/empower_beam/EmpowerBeam.tscn` + `empower_beam.gd`
- [ ] Todos os PNGs em `res://assets/vfx/empower_beam/` (brancos, tingidos por `modulate`)
- [ ] Hook no `board.gd` que instancia a cena quando um aliado é fortalecido
- [ ] Cena de teste `EmpowerBeamTest.tscn` com botão "Conjurar" + 5 botões de cor que chamam `fx.play(SOURCE, TARGET, cor, 3, 2)` com posições fixas (idênticas às do HTML) para QA isolado

---

## REFERÊNCIA VISUAL

**Leia `Empower Beam.html` na raiz do projeto antes de começar.** Não invente timings, o arco do feixe ou as cores — espelhe. Os valores em `const T_*`, `BOW` e o dicionário `PALETTES` já batem com `T.*`, `BOW` e `COLORS`/`makeTheme()` no HTML. Em caso de divergência, abra o HTML pausado no tempo/cor correspondente e compare lado a lado.

Pode começar.
