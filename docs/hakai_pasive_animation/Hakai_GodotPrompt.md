# Prompt para Claude Code — `Hakai.tscn` (Godot 4)

Cole o conteúdo abaixo no Claude Code. Ele assume que o projeto Godot do **Taldorian TCCG** já existe em `res://`, que `Board.tscn` já foi criado, e que o efeito será disparado **uma única vez** quando o herói **Destruidor** ativa sua passiva **Hakai** (o mundo se parte ao meio).

---

## CONTEXTO

Estou desenvolvendo **Taldorian TCCG** em Godot 4.x. O Board é um tabuleiro **1280×720** (espelhado verticalmente: oponente em cima, jogador embaixo, com uma linha central em `y = 360`). A referência visual completa do efeito em HTML/CSS está em **`Hakai.html`** na raiz do projeto.

**Leia esse arquivo antes de começar.** Ele tem a timeline completa em segundos (`const T = {…}`), a geometria do corte e os parâmetros das partículas (névoa, glints, faíscas).

## NATUREZA DO EFEITO — IMPORTANTE

**Este é um efeito FULLSCREEN e ONE-SHOT.** Diferente de `BattleFury.tscn` (que é persistente e preso a uma carta), o Hakai:

- **Não** se vincula a nenhuma carta nem segue posição.
- Cobre **a tela inteira** (1280×720).
- **Começa, executa e termina sozinho** — toca a sequência completa (~3,55s), restaura a tela ao normal e emite `finished`, fazendo `queue_free()`.
- **Não tem** banner de texto, nem nome de habilidade na tela. É puramente o efeito visual: tela escurece → névoa aparece → corte azul → dissipa.

```
play()  →  [escurece + névoa 0–0.75s]
        →  [carga azul no centro 0.70–1.55s]
        →  [CORTE horizontal + flash 1.55s]
        →  [metades se separam, fenda azul 1.60–2.45s]
        →  [dissipa tudo 2.45–3.55s]
        →  finished  →  queue_free()
```

## OBJETIVO

Construir **`res://scenes/vfx/hakai/Hakai.tscn`** — uma cena de VFX **autocontida e fullscreen** que toca a animação inteira do corte e se remove ao final. Sequência exata (espelha `Hakai.html`):

1. **Escurecimento (0.0–0.75s)** — um overlay escuro com vinheta cobre o tabuleiro inteiro, atingindo opacidade máxima em 0.75s.
2. **Névoa (0.15–1.00s)** — 7 blobs de névoa azulada surgem e ficam flutuando lentamente (drift senoidal) por cima do tabuleiro, em blend ADD/Screen.
3. **Carga (0.70–1.55s)** — um ponto de luz azul-branca se concentra no **centro da tela** (`640, 360`), crescendo em brilho e tamanho.
4. **Corte (1.55s, dura 0.26s)** — a partir do ponto central, um **feixe azul horizontal** dispara para os dois lados até atingir as bordas esquerda e direita (em `y = 360`). Acompanha:
   - **Flash** de tela curto (1.55–1.95s).
   - **22 faíscas** disparando da costura.
   - Pontas brilhantes ("caps") nas duas extremidades enquanto o feixe avança.
5. **Separação (1.60–2.45s)** — o tabuleiro é dividido em **duas metades** (topo e base) que se afastam verticalmente da linha central (overshoot até ~13px e assenta em ~7px), revelando um **vão preto** entre elas com a **costura azul brilhante** pulsando. **18 glints** (pontos de luz) correm horizontalmente pela costura.
6. **Dissipação (2.45–3.55s)** — escurecimento, névoa, costura, separação e flash fazem fade-out em paralelo; as metades voltam a se unir; a tela volta ao normal. Ao chegar em 3.55s → `finished` → `queue_free()`.

A cena deve ser **disparável com um único `play()`** e **reutilizável** (cor/duração configuráveis via `@export`).

---

## COMO DIVIDIR A TELA EM DUAS METADES

O truque visual central é mostrar **duas cópias recortadas** do que está atrás do efeito, deslocadas. Há duas abordagens — escolha conforme sua arquitetura:

### Opção A (recomendada) — capturar o Board via `SubViewport`
Se o Board já é renderizado, capture-o em um `SubViewport` e desenhe duas cópias com `clip`:
- `TopHalf` (`TextureRect`) mostra a textura do viewport recortada à metade superior (`region`/`clip` em `0,0 → 1280,360`), com `position.y` animando para **cima** (`-sep`).
- `BottomHalf` mostra a metade inferior (`0,360 → 1280,720`), com `position.y` animando para **baixo** (`+sep`).
- Entre elas, o `GapVoid` (ColorRect preto) preenche a fenda.

### Opção B (mais simples) — só a fenda + costura, sem deslocar o board real
Se não quiser capturar o Board, **pule o deslocamento das metades** e renderize apenas:
- O `GapVoid` (faixa preta fina) crescendo em `y = 360`.
- A costura azul por cima.

Isso já entrega a leitura de "a tela foi cortada" sem precisar do SubViewport. O HTML usa a Opção A (cópias deslocadas); a Opção B é um fallback aceitável se a captura de viewport for custosa. **Implemente a Opção A se possível.**

---

## ÁRVORE DE CENAS

### `Hakai.tscn`
```
Hakai (CanvasLayer, layer = 80)            [script: hakai.gd]
│   # CanvasLayer fullscreen sobre o jogo inteiro
├─ BoardCapture (Node2D)                   # só na Opção A
│  ├─ TopHalf    (TextureRect, texture = board_viewport_tex, z_index = 1)
│  └─ BottomHalf (TextureRect, texture = board_viewport_tex, z_index = 1)
├─ Darken (ColorRect)                       # z_index = 2, anchors=full_rect
│  # cor escura translúcida + vinheta via shader (ver abaixo); modulate.a animado
├─ FogLayer (Node2D)                        # z_index = 3
│  └─ (7× Sprite2D "FogBlob" spawnados via script, texture=fog_blob.png, blend=ADD)
├─ GapVoid (ColorRect)                       # z_index = 4, faixa preta na costura
├─ SliceLayer (Node2D)                       # z_index = 5, blend ADD em tudo
│  ├─ ChargeDot  (Sprite2D, texture=charge_dot.png, modulate.a=0)
│  ├─ SliceBloom (Sprite2D/NinePatchRect, texture=slice_bloom.png)  # halo largo
│  ├─ SliceCore  (NinePatchRect, texture=slice_core.png)            # linha fina
│  ├─ CapLeft    (Sprite2D, texture=charge_dot.png)                 # ponta esquerda
│  └─ CapRight   (Sprite2D, texture=charge_dot.png)                 # ponta direita
├─ SeamFX (Node2D)                           # z_index = 6
│  ├─ Glints (GPUParticles2D, process_material=glints_material.tres,
│  │          texture=glint.png, amount=18, lifetime=2.2, one_shot=false, emitting=false)
│  └─ Sparks (GPUParticles2D, process_material=sparks_material.tres,
│             texture=spark.png, amount=22, lifetime=0.5, one_shot=true, emitting=false)
├─ ScreenFlash (ColorRect)                   # z_index = 7, anchors=full_rect, modulate.a=0
└─ AudioPlayers
   ├─ Charge   (AudioStreamPlayer)           # zumbido grave crescente da carga
   ├─ Cut      (AudioStreamPlayer)           # impacto/lâmina no momento do corte
   └─ Dissipate(AudioStreamPlayer)           # sopro grave ao dissipar
```

Marque cada nó dinâmico com **Unique Name in Owner** (`%`).

---

## ASSETS — ONDE FICAM

> **Todos os PNGs vão em `res://assets/vfx/hakai/`.** Crie a pasta. Se algum não existir ainda, **gere por procedimental** (ColorRect + shader, ou desenhe em GIMP/Krita/Aseprite) seguindo as descrições. São texturas simples (gradientes radiais/lineares azuis) — nenhuma arte complexa.

### Paleta-mestre da habilidade
| Token          | OKLCH                      | Hex aprox. | Uso                                  |
|----------------|----------------------------|------------|--------------------------------------|
| `hakai-core`   | `oklch(0.99 0.03 240)`     | `#eaf4ff`  | Núcleo branco-azulado da lâmina/carga |
| `hakai-bright` | `oklch(0.80 0.20 250)`     | `#5aa0ff`  | Azul brilhante (bloom, glints, caps) |
| `hakai-mid`    | `oklch(0.55 0.16 255)`     | `#3360c8`  | Azul médio (halo da névoa)           |
| `hakai-deep`   | `oklch(0.20 0.06 260)`     | `#141a33`  | Azul profundo (sombra da fenda)      |
| `hakai-void`   | `oklch(0.02 0.01 260)`     | `#04050a`  | Preto do vão entre as metades        |

### Lista de texturas (todas em `res://assets/vfx/hakai/`)
| Arquivo            | Tamanho   | Descrição                                                                                       |
|--------------------|-----------|-------------------------------------------------------------------------------------------------|
| `fog_blob.png`     | 512×512   | Blob de névoa: gradiente radial azulado `hakai-mid`, alpha alto no centro → 0 nas bordas, MUITO suave (borrado). |
| `charge_dot.png`   | 128×128   | Ponto de luz: núcleo branco `hakai-core` → `hakai-bright` → transparente. Usado na carga e nas pontas (caps). |
| `slice_core.png`   | 256×8 (NinePatch borders H=8) | Linha horizontal fina: centro branco `hakai-core`, bordas (topo/base) → transparente. |
| `slice_bloom.png`  | 256×64 (NinePatch borders H=8) | Halo largo da lâmina: faixa horizontal azul `hakai-bright`, gradiente vertical suave para transparente. |
| `glint.png`        | 32×32     | Glint da costura: ponto central branco + halo azul pequeno.                                     |
| `spark.png`        | 24×24     | Faísca: ponto azul-branco `hakai-bright`, gradiente radial.                                      |

### Import flags (no `.import` de cada PNG)
- `filter = true`
- `mipmaps = true`
- `compress/mode = 0` (Lossless)
- `process/fix_alpha_border = true`

### Shader do `Darken` (vinheta) — sem textura
Use um `ShaderMaterial` no `Darken` (ColorRect fullscreen) para a vinheta radial idêntica ao HTML:
```glsl
shader_type canvas_item;
uniform float amount : hint_range(0,1) = 0.0;   // animado por tween
void fragment() {
    vec2 c = UV - vec2(0.5);
    float d = length(c * vec2(1.1, 1.4));        // elipse ~90%x70%
    float vig = smoothstep(0.30, 0.85, d);       // mais escuro nas bordas
    float a = mix(0.55, 0.92, vig) * amount;     // centro 0.55 → bordas 0.92
    COLOR = vec4(vec3(0.01, 0.012, 0.02), a);    // hakai-void
}
```

---

## MATERIAIS DE PARTÍCULA (ParticleProcessMaterial)

### `glints_material.tres` — pontos correndo pela costura
| Propriedade                | Valor                                                        |
|----------------------------|--------------------------------------------------------------|
| `emission_shape`           | Box                                                          |
| `emission_box_extents`     | `Vector3(640, 3, 0)` (largura total, na linha y=360)         |
| `direction`                | `Vector3(1, 0, 0)`                                           |
| `spread`                   | `0.0`                                                        |
| `initial_velocity_min/max` | `60 / 190` (metade vai p/ um lado — ver nota)                |
| `gravity`                  | `Vector3.ZERO`                                               |
| `scale_min/max`            | `0.5 / 1.6`                                                  |
| `color`                    | `hakai-bright`                                               |
| `color_ramp`               | 0%→`hakai-core` 0%a, 15%→`hakai-core`, 85%→`hakai-bright`, 100%→0%a |
| `alpha_curve`              | 0.0→0.0, 0.12→1.0, 0.78→0.8, 1.0→0.0                         |

> Para metade dos glints irem para a esquerda, use 2 `GPUParticles2D` (um com `direction.x = +1`, outro `-1`), ou um `process_material` com `spread = 180` e velocidade só no eixo X.

### `sparks_material.tres` — explosão no momento do corte
| Propriedade                | Valor                                                        |
|----------------------------|--------------------------------------------------------------|
| `emission_shape`           | Box                                                          |
| `emission_box_extents`     | `Vector3(410, 2, 0)` (faixa central horizontal)              |
| `direction`                | `Vector3(0, -1, 0)`                                          |
| `spread`                   | `80.0` (espalha p/ cima e baixo da costura)                  |
| `initial_velocity_min/max` | `60 / 200`                                                   |
| `gravity`                  | `Vector3.ZERO`                                               |
| `scale_min/max`            | `0.4 / 1.2`                                                  |
| `scale_curve`              | 0.0→1.0, 1.0→0.0                                             |
| `color`                    | `hakai-bright`                                               |
| `alpha_curve`              | 0.0→1.0, 1.0→0.0                                             |

Ambos com `material = CanvasItemMaterial.new()` + `blend_mode = ADD`.

---

## SCRIPT — `hakai.gd`

```gdscript
class_name Hakai extends CanvasLayer

# ── Configuração (reutilizável p/ outras "lâminas de tela") ────────────────
@export var slice_color: Color        = Color("#5aa0ff")   # hakai-bright
@export var board_texture: Texture2D  = null               # textura do SubViewport do Board (Opção A)
@export var use_split_halves: bool    = true               # false = Opção B (só fenda + costura)

# ── Timeline (segundos — espelha EXATAMENTE o const T do Hakai.html) ───────
const T_DARK_IN    := 0.0
const T_DARK_FULL  := 0.75
const T_FOG_IN     := 0.15
const T_FOG_FULL   := 1.00
const T_CHARGE_AT  := 0.70
const T_SLICE_AT   := 1.55
const T_SLICE_DUR  := 0.26
const T_FLASH_AT   := 1.55
const T_FLASH_DUR  := 0.40
const T_SEP_FROM   := 1.60
const T_SEP_DUR    := 0.45
const T_HOLD_UNTIL := 2.45
const T_WIND_FROM  := 2.45
const T_WIND_DUR   := 1.05
const T_END        := 3.55

const STAGE := Vector2(1280, 720)
const MID_Y := 360.0
const MAX_SEP := 13.0
const REST_SEP := 7.0
const NUM_FOG := 7

signal finished               # emitido ao terminar (antes do queue_free)

var _rng := RandomNumberGenerator.new()
var _fog: Array[Sprite2D] = []

func _ready() -> void:
    # tudo invisível no começo
    %Darken.material.set_shader_parameter("amount", 0.0)
    %GapVoid.modulate.a = 0.0
    %ChargeDot.modulate.a = 0.0
    %SliceBloom.modulate.a = 0.0
    %SliceCore.modulate.a = 0.0
    %CapLeft.modulate.a = 0.0
    %CapRight.modulate.a = 0.0
    %ScreenFlash.modulate.a = 0.0
    %Glints.emitting = false
    %Sparks.emitting = false
    %ChargeDot.position = STAGE / 2.0
    %ScreenFlash.color = slice_color
    %ScreenFlash.color.a = 1.0   # alpha controlado por modulate
    if board_texture and use_split_halves:
        %TopHalf.texture = board_texture
        %BottomHalf.texture = board_texture

# ── API pública ────────────────────────────────────────────────────────────
func play() -> void:
    _rng.seed = 71
    _spawn_fog()
    _run_sequence()

# ── Sequência completa one-shot ─────────────────────────────────────────────
func _run_sequence() -> void:
    var t := create_tween().set_parallel(true)

    # 1. Escurecimento (0 → 0.75)
    t.tween_method(func(v): %Darken.material.set_shader_parameter("amount", v),
        0.0, 1.0, T_DARK_FULL - T_DARK_IN).set_delay(T_DARK_IN)

    # 2. Névoa: fade-in coletivo (0.15 → 1.0); o drift é feito no _process
    for f in _fog:
        t.tween_property(f, "modulate:a", f.get_meta("max_op"), T_FOG_FULL - T_FOG_IN)\
            .set_delay(T_FOG_IN)

    # 3. Carga: ponto cresce e brilha (0.70 → 1.55)
    t.tween_property(%ChargeDot, "modulate:a", 1.0, T_SLICE_AT - T_CHARGE_AT)\
        .set_delay(T_CHARGE_AT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    t.tween_property(%ChargeDot, "scale", Vector2(2.2, 2.2), T_SLICE_AT - T_CHARGE_AT)\
        .set_delay(T_CHARGE_AT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

    # 4. CORTE em T_SLICE_AT
    get_tree().create_timer(T_SLICE_AT, false).timeout.connect(_trigger_cut)

    # 6. Dissipação a partir de T_WIND_FROM
    get_tree().create_timer(T_WIND_FROM, false).timeout.connect(_trigger_dissipate)

    # Fim
    get_tree().create_timer(T_END, false).timeout.connect(func():
        emit_signal("finished")
        queue_free()
    )

# ── Disparo do corte ─────────────────────────────────────────────────────────
func _trigger_cut() -> void:
    %ChargeDot.modulate.a = 0.0

    # Lâmina expande do centro até as bordas (half-width 0 → 640)
    %SliceCore.position.y = MID_Y
    %SliceBloom.position.y = MID_Y
    %SliceCore.modulate.a = 1.0
    %SliceBloom.modulate.a = 1.0
    %CapLeft.modulate.a = 1.0
    %CapRight.modulate.a = 1.0

    var grow := create_tween().set_parallel(true)
    grow.tween_method(_set_slice_width, 0.0, 1.0, T_SLICE_DUR)\
        .set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

    # Flash de tela (1.55 → 1.95)
    var ft := create_tween()
    ft.tween_property(%ScreenFlash, "modulate:a", 0.85, 0.04)
    ft.tween_property(%ScreenFlash, "modulate:a", 0.0, T_FLASH_DUR - 0.04)\
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

    # Faíscas one-shot
    %Sparks.position = Vector2(STAGE.x / 2.0, MID_Y)
    %Sparks.emitting = true

    # Glints contínuos na costura
    %Glints.position = Vector2(STAGE.x / 2.0, MID_Y)
    %Glints.emitting = true

    # Esconde as caps quando a lâmina chega ao fim
    get_tree().create_timer(T_SLICE_DUR, false).timeout.connect(func():
        var hide := create_tween().set_parallel(true)
        hide.tween_property(%CapLeft, "modulate:a", 0.0, 0.12)
        hide.tween_property(%CapRight, "modulate:a", 0.0, 0.12)
    )

    # 5. Separação das metades (1.60 → 2.45) — só Opção A
    if use_split_halves and board_texture:
        var sep := create_tween().set_parallel(true)
        # overshoot até MAX e assenta em REST
        sep.tween_method(_set_separation, 0.0, MAX_SEP, 0.18)\
            .set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
        sep.chain().tween_method(_set_separation, MAX_SEP, REST_SEP, T_SEP_DUR - 0.18)\
            .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    else:
        # Opção B: só cresce a fenda preta
        var gap := create_tween()
        gap.tween_method(func(v): _set_gap_only(v), 0.0, REST_SEP, T_SEP_DUR)\
            .set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

# largura da lâmina: frac 0→1 mapeia half-width 0→640
func _set_slice_width(frac: float) -> void:
    var half := frac * (STAGE.x / 2.0)
    var w := half * 2.0
    var left := STAGE.x / 2.0 - half
    for n in [%SliceCore, %SliceBloom]:
        n.position.x = left
        n.size.x = w               # NinePatchRect: ajusta largura
    %CapLeft.position = Vector2(left, MID_Y)
    %CapRight.position = Vector2(left + w, MID_Y)

# separa as metades verticalmente + abre o vão preto + posiciona a costura
func _set_separation(sep: float) -> void:
    %TopHalf.position.y = -sep
    %BottomHalf.position.y = sep
    _set_gap_only(sep)

func _set_gap_only(sep: float) -> void:
    %GapVoid.modulate.a = 1.0 if sep > 0.2 else 0.0
    %GapVoid.position = Vector2(0, MID_Y - sep)
    %GapVoid.size = Vector2(STAGE.x, sep * 2.0)
    # a costura (slice) acompanha o centro do vão
    %SliceCore.position.y = MID_Y
    %SliceBloom.position.y = MID_Y

# ── Dissipação (2.45 → 3.55): tudo faz fade-out em paralelo ───────────────
func _trigger_dissipate() -> void:
    %Glints.emitting = false
    %Sparks.emitting = false
    if %Dissipate.stream:
        %Dissipate.play()

    var d := create_tween().set_parallel(true)
    d.tween_method(func(v): %Darken.material.set_shader_parameter("amount", v),
        1.0, 0.0, T_WIND_DUR)
    for f in _fog:
        d.tween_property(f, "modulate:a", 0.0, T_WIND_DUR)
    d.tween_property(%SliceCore, "modulate:a", 0.0, T_WIND_DUR)
    d.tween_property(%SliceBloom, "modulate:a", 0.0, T_WIND_DUR)
    d.tween_property(%GapVoid, "modulate:a", 0.0, T_WIND_DUR)
    # metades voltam a se juntar
    if use_split_halves and board_texture:
        d.tween_property(%TopHalf, "position:y", 0.0, T_WIND_DUR)\
            .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
        d.tween_property(%BottomHalf, "position:y", 0.0, T_WIND_DUR)\
            .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

# ── Névoa: spawn de 7 blobs + drift contínuo ──────────────────────────────
func _spawn_fog() -> void:
    for i in NUM_FOG:
        var s := Sprite2D.new()
        s.texture = preload("res://assets/vfx/hakai/fog_blob.png")
        s.material = CanvasItemMaterial.new()
        (s.material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
        var bx := _rng.randf() * STAGE.x
        var by := 120.0 + _rng.randf() * (STAGE.y - 240.0)
        var sc := (0.7 + _rng.randf() * 0.8)
        s.position = Vector2(bx, by)
        s.scale = Vector2(sc, sc * 0.55)
        s.modulate = Color(0.55, 0.62, 0.95)   # azulado
        s.modulate.a = 0.0
        s.set_meta("base", Vector2(bx, by))
        s.set_meta("drift", Vector2(30.0 + _rng.randf()*70.0, 14.0 + _rng.randf()*26.0))
        s.set_meta("speed", 0.04 + _rng.randf()*0.06)
        s.set_meta("phase", _rng.randf() * TAU)
        s.set_meta("max_op", 0.10 + _rng.randf()*0.12)
        %FogLayer.add_child(s)
        _fog.append(s)

func _process(_dt: float) -> void:
    var t := Time.get_ticks_msec() / 1000.0
    for f in _fog:
        var base: Vector2 = f.get_meta("base")
        var drift: Vector2 = f.get_meta("drift")
        var speed: float = f.get_meta("speed")
        var phase: float = f.get_meta("phase")
        f.position = base + Vector2(
            sin(t * speed * 6.0 + phase) * drift.x,
            cos(t * speed * 4.4 + phase * 1.3) * drift.y
        )
```

> **Notas de fidelidade:**
> - O `ChargeDot`, `SliceCore`, `SliceBloom`, `CapLeft/Right`, `Glints`, `Sparks` e o `ScreenFlash` usam **blend ADD** (igual ao `mix-blend-mode: screen` do HTML).
> - A lâmina expande do **centro** para fora (não aparece inteira de uma vez). Isso é o `_set_slice_width`.
> - As metades fazem **overshoot** (vão até 13px) e **assentam** em 7px — daí a `chain()` no tween de separação.

---

## INTEGRAÇÃO COM O BOARD

No `board.gd`, quando o Destruidor ativa a passiva Hakai:

```gdscript
func _on_destruidor_passive() -> void:
    var fx := preload("res://scenes/vfx/hakai/Hakai.tscn").instantiate()
    add_child(fx)

    # Opção A: passe a textura do SubViewport que renderiza o Board
    # fx.board_texture = $BoardViewport.get_texture()
    # fx.use_split_halves = true

    fx.finished.connect(func():
        print("[Hakai] efeito concluído")
    )
    fx.play()
```

Como é **one-shot**, não há `deactivate()` — a cena se limpa sozinha ao emitir `finished`.

### Sobre a captura do Board (Opção A)
Para as metades mostrarem o tabuleiro real, o Board precisa ser renderizado dentro de um `SubViewport`:
```
BoardRoot
├─ BoardViewport (SubViewport, size = 1280×720)
│  └─ Board (… todo o conteúdo do jogo …)
└─ BoardDisplay (TextureRect, texture = BoardViewport.get_texture())
```
Aí passe `fx.board_texture = $BoardViewport.get_texture()`. **Se isso for complexo demais agora, deixe `use_split_halves = false`** (Opção B) — o efeito ainda funciona, apenas sem o board real deslizando para os lados.

---

## SOM (OPCIONAL — não-bloqueante)

- **Charge** — zumbido/whine grave crescente, fade-in de 0.70s, pico em 1.55s.
- **Cut** — impacto seco + lâmina metálica rasgando, em 1.55s.
- **Dissipate** — sopro grave / reverberação sumindo, em 2.45s.

---

## CHECKLIST DE FIDELIDADE AO HTML

Abra `Hakai.html`, clique em **Ativar Hakai** e use **Pausar** para travar estados:

- [ ] **0.0s** — tabuleiro normal, nada na tela.
- [ ] **0.4s** — tela já visivelmente escura (vinheta); névoa começando a aparecer.
- [ ] **0.75s** — escurecimento no máximo; névoa flutuando.
- [ ] **1.2s** — ponto de luz azul concentrado e brilhante no centro (`640, 360`).
- [ ] **1.55s** — flash; lâmina azul dispara do centro para as bordas; faíscas saem.
- [ ] **1.7s** — lâmina cobre a largura toda; metades começam a se afastar; fenda preta + costura azul.
- [ ] **2.3s** — fenda aberta com costura pulsando; glints correndo na horizontal.
- [ ] **2.45s** — começa a dissipar.
- [ ] **3.1s** — escurecimento/névoa/costura sumindo; metades voltando.
- [ ] **3.55s** — tela 100% normal; `finished` emitido; nó liberado.
- [ ] **Sem banner** — nenhum texto de nome de habilidade aparece em momento algum.

---

## ENTREGÁVEIS

- [ ] `res://scenes/vfx/hakai/Hakai.tscn` + `hakai.gd`
- [ ] PNGs em **`res://assets/vfx/hakai/`**: `fog_blob.png`, `charge_dot.png`, `slice_core.png`, `slice_bloom.png`, `glint.png`, `spark.png` (gerar conforme tabela)
- [ ] Shader de vinheta no `Darken` (inline no `.tscn` ou `res://assets/vfx/hakai/darken_vignette.gdshader`)
- [ ] `res://assets/vfx/hakai/glints_material.tres` + `sparks_material.tres`
- [ ] Hook no `board.gd` que instancia e chama `play()` quando o Destruidor ativa a passiva
- [ ] Cena de teste `res://scenes/vfx/hakai/HakaiTest.tscn` com 1 botão **Ativar Hakai** que instancia a cena sobre um tabuleiro dummy 1280×720 e chama `play()`

---

## REFERÊNCIA VISUAL

**Leia `Hakai.html` na raiz do projeto antes de começar.** Não invente timings ou cores — espelhe. Os valores em `const T_*` no script já batem exatamente com `const T = {…}` no HTML. Em caso de divergência, abra o HTML, clique em **Ativar Hakai** e use **Pausar** para comparar lado a lado.

Pode começar.
