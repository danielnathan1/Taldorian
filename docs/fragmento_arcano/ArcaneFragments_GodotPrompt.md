# Prompt para Claude Code — `ArcaneFragments.tscn` (Godot 4)

Cole o conteúdo abaixo no Claude Code. Ele assume que o projeto Godot do **Taldorian TCCG** já existe em `res://`, que `Card.tscn` e `Board.tscn` já foram criados conforme `Card_GodotPrompt.md`, e que o efeito é disparado quando o herói **Conjurador** ativa a magia **Fragmentos Arcanos**.

---

## CONTEXTO

Estou desenvolvendo **Taldorian TCCG** em Godot 4.x. No Board, cada lado (jogador / oponente) tem 1 herói ativo + banco + Arsenal + Deck + Cemitério, dispostos em um tabuleiro **1280×720** (espelhado verticalmente). A referência visual completa do efeito em HTML/CSS/SVG está em **`Arcane Fragments.html`** na raiz do projeto.

**Leia esse arquivo antes de começar.** Diferente dos outros VFX do jogo, este é **100% procedural** — não usa nenhuma textura PNG externa. Tudo é desenhado com **polígonos, linhas e gradientes radiais** (cristais como `Polygon2D`, rastros como `Line2D`, glows como `GradientTexture2D` aditivo). O HTML faz exatamente isso com SVG; espelhe a abordagem.

O HTML contém **três efeitos selecionáveis** (botões `I / II / III` no rodapé) que **escalam em intensidade**. Os três compartilham o mesmo board, banner, runa central e barra de controle — só muda a coreografia dos fragmentos e o clímax de luz.

## OBJETIVO

Construir **`res://scenes/vfx/arcane_fragments/ArcaneFragments.tscn`** — uma cena de VFX **autocontida e data-driven**, instanciada sobre o `Board.tscn` quando o Conjurador ativa **Fragmentos Arcanos**. A cena recebe `play(effect: int, center: Vector2)` onde `effect ∈ {1,2,3}`:

- **Efeito 1 — Impacto (`END = 3.1s`)** — UMA pedra arcana surge de uma fenda abaixo do conjurador, descreve um arco até o centro do board (a carta do Conjurador pulsa em violeta enquanto carrega) e **detona** numa explosão: onda de choque expansiva + flash + estilhaços radiais + tremor de tela.
- **Efeito 2 — Colisão (`END = 3.5s`)** — DUAS pedras surgem de fendas nos flancos (esquerda/direita), convergem ao centro e **se chocam**. Do impacto nasce uma **pequena luz contida** — um orbe suave que pulsa (respira) e desvanece no fim. Explosão bem menor que o Efeito 1.
- **Efeito 3 — Fusão (`END = 4.3s`)** — TRÊS pedras surgem de fendas (topo, inferior-esquerda, inferior-direita), voam até um anel orbital e **giram entre si** num anel arcano que **acelera** enquanto o raio encolhe; ao colapsarem no centro, **se fundem** e liberam uma **luz forte e intensa** — o maior clímax: múltiplos anéis de choque + raios giratórios + **pilar vertical de luz** + flash forte + tremor grande.

A cena deve emitir o sinal `finished` ao concluir e dar `queue_free()`.

---

## ÁRVORE DE CENAS

### `ArcaneFragments.tscn`
```
ArcaneFragments (Node2D)  [script: arcane_fragments.gd]
├─ Shake (Node2D)                       # tudo o que treme fica aqui dentro
│  ├─ CenterRune (Node2D)               # runa/círculo arcano no centro (desenhado em _draw)
│  ├─ Rifts (Node2D)                    # fendas de surgimento (Polygon2D/elipse aditiva)
│  ├─ TrailsLayer (Node2D)              # Line2D dos rastros dos fragmentos
│  ├─ FragmentsLayer (Node2D)           # cristais (Node2D > Polygon2D + glow)
│  ├─ Rays (Node2D)                     # raios giratórios (só efeito 3)
│  ├─ Bursts (Node2D)                   # anéis de onda de choque
│  ├─ Debris (Node2D)                   # CPUParticles2D de estilhaços/faíscas
│  ├─ LightOrb (Sprite2D)               # luz pequena contida (só efeito 2)
│  └─ Pillar (TextureRect)              # pilar vertical de luz (só efeito 3)
├─ ScreenFlash (CanvasLayer layer=50 > ColorRect full_rect, modulate.a=0)
├─ Banner (Control, anchors=top-center)
│  ├─ Subtitle    (Label, "FRAGMENTOS ARCANOS · I")
│  ├─ AbilityName (Label, "IMPACTO")
│  ├─ Rule        (ColorRect, 300x1)
│  └─ Status      (Label, "A pedra arcana converge ao centro")
└─ AudioPlayers
   ├─ Charge   (AudioStreamPlayer)
   ├─ Impact   (AudioStreamPlayer)
   └─ Fuse     (AudioStreamPlayer)
```

Marque cada nó dinâmico com **Unique Name in Owner** (`%`).

> **Por que `_process` e não só `Tween`?** O HTML é dirigido por uma única variável de tempo `t` e uma função `deriveScene(t)` que **recalcula tudo a cada quadro** (posições, glows, vida das explosões). A forma mais fiel é replicar isso: um `_t` acumulado em `_process(delta)` e funções `_update_e1/2/3(_t)` que reposicionam nós **persistentes** (pool) por quadro — exatamente como o React re-renderiza. Não use uma cadeia de tweens; ela vai divergir do HTML.

---

## ASSETS — NENHUM PNG EXTERNO

Este efeito **não copia texturas**. Gere em código:

1. **Glow radial** (`GradientTexture2D` radial, núcleo claro → transparente) — reutilizado para o glow dos cristais, núcleo dos bursts, orbe do efeito 2, fendas. Crie **uma vez** no `_ready()` e compartilhe.
2. **Cristais** — `Polygon2D` (losango facetado) desenhados com vértices fixos (ver `CrystalShard` no HTML).
3. **Rastros / anéis / raios / runa** — `Line2D` e `_draw()` customizado.
4. **Pilar de luz** — `TextureRect` com `GradientTexture2D` horizontal (transparente → branco no centro → transparente), esticado em altura total.

Helper para o glow radial:
```gdscript
func _make_radial_glow(core: Color) -> GradientTexture2D:
    var grad := Gradient.new()
    grad.set_color(0, Color(core.r, core.g, core.b, 1.0))
    grad.set_color(1, Color(core.r, core.g, core.b, 0.0))
    grad.add_point(0.45, Color(core.r, core.g, core.b, 0.45))
    var tex := GradientTexture2D.new()
    tex.gradient = grad
    tex.fill = GradientTexture2D.FILL_RADIAL
    tex.fill_from = Vector2(0.5, 0.5)
    tex.fill_to = Vector2(1.0, 0.5)
    tex.width = 256; tex.height = 256
    return tex
```

Todo material visível usa **blend aditivo** (`CanvasItemMaterial.BLEND_MODE_ADD`), salvo os cristais sólidos (corpo do losango usa normal; o glow ao redor usa ADD).

### Paleta arcana (idêntica ao HTML)
| Uso                 | Cor aprox. (RGB)        | Notas |
|---------------------|-------------------------|-------|
| Núcleo branco-quente| `#FCF5FF` (0.99,0.96,1) | centro de flashes/orbes |
| Violeta brilhante   | `#D9A8FF` (0.85,0.66,1) | glow, raios |
| Violeta médio       | `#B07EF0`               | anéis, rastros |
| Violeta profundo    | `#7C5AE0`               | bordas, fendas |
| Corpo do cristal    | `#3A1E5C` (escuro)      | preenchimento do losango |

---

## CONSTANTES — ESPELHE O HTML EXATAMENTE

```gdscript
const STAGE := Vector2(1280, 720)
var CENTER := Vector2(640, 360)         # sobrescrito por play(effect, center)

# ── Efeito 1 — Impacto ──
const E1_SPAWN  := Vector2(640, 628)
const E1_REL    := 0.35                  # pedra emerge da fenda
const E1_IMPACT := 1.40                  # detonação
const E1_ARC    := -200.0                # bow lateral do arco
const E1_END    := 3.10

# ── Efeito 2 — Colisão ──
const E2_L      := Vector2(130, 352)
const E2_R      := Vector2(1150, 368)
const E2_REL    := 0.35
const E2_IMPACT := 1.35
const E2_ARC    := 70.0
const E2_END    := 3.50

# ── Efeito 3 — Fusão ──
const E3_SPAWNS := [Vector2(640, 92), Vector2(232, 600), Vector2(1048, 600)]
const E3_ARRIVE := 1.20                  # fragmentos chegam ao anel
const E3_MERGE  := 2.35                  # fusão / clímax
const E3_ORBIT_R := 158.0
const E3_END    := 4.30
```

### Funções de trajetória (idênticas ao HTML)
```gdscript
# Arco quadrático de p0→p1, "arc" = deslocamento perpendicular (bow)
func _travel(p0: Vector2, p1: Vector2, u: float, arc := 0.0) -> Vector2:
    var mid := (p0 + p1) * 0.5
    var dir := (p1 - p0).normalized()
    var nrm := Vector2(-dir.y, dir.x)
    var c := mid + nrm * arc
    var v := 1.0 - u
    return v*v*p0 + 2.0*v*u*c + u*u*p1

# Easings usados (mesmos nomes do HTML)
func _ease_in_quad(t): return t*t
func _ease_in_cubic(t): return t*t*t
func _ease_out_cubic(t): return 1.0 - pow(1.0-t, 3.0)
func _clamp01(v): return clampf(v, 0.0, 1.0)
```

### Efeito 3 — posição orbital de um fragmento (o coração do efeito)
```gdscript
func _e3_frag_pos(i: int, tt: float) -> Vector2:
    var base_ang := -PI/2.0 + float(i) * (TAU/3.0)
    if tt < E3_ARRIVE:
        var u := _ease_out_cubic(_clamp01((tt - 0.4) / (E3_ARRIVE - 0.4)))
        var target := CENTER + Vector2(cos(base_ang), sin(base_ang)) * E3_ORBIT_R
        return _travel(E3_SPAWNS[i], target, u, 60.0 * (1.0 if i == 0 else -1.0))
    var lt := _clamp01((tt - E3_ARRIVE) / (E3_MERGE - E3_ARRIVE))
    var spin := (lt + lt*lt*1.8) * TAU * 2.4        # rotação acelerando
    var rad := lerp(E3_ORBIT_R, 4.0, _ease_in_cubic(lt))   # raio encolhe a 0
    var ang := base_ang + spin
    return CENTER + Vector2(cos(ang), sin(ang)) * rad
```

> **Ponto crítico do Efeito 3:** entre `E3_ARRIVE` (1.2s) e `E3_MERGE` (2.35s) os três cristais formam um **anel girando cada vez mais rápido** enquanto fecham para o centro. O rastro (`Line2D` amostrando posições passadas) desenha o "anel de energia" característico. Se ficar estático ou reto, confira o termo `spin` e o encolhimento de `rad`.

---

## LÓGICA POR QUADRO — espelha `deriveE1/E2/E3(t)` do HTML

No `_process(delta)`: acumule `_t += delta`; ao passar de `END + 1.0` reinicie `_t = 0` se estiver em modo teste em loop, ou emita `finished` se for one-shot (ver API). Depois chame o `_update_eN(_t)` do efeito ativo. Cada update faz:

### `_update_e1(t)` — Impacto
- **Fenda** em `E1_SPAWN`: abre em `t∈[0,0.3]`, fecha até `0.7` (escala em X, glow aditivo).
- **Cristal** (1 nó) visível em `t∈[E1_REL, E1_IMPACT]`: `u = ease_in_quad((t-REL)/FLIGHT)`, posição `= _travel(SPAWN, CENTER, u, -200)`, rotação girando (`t*320°`), escala `0.85→1.35`, glow `0.5→1.2`. **Rastro** = `Line2D` amostrando ~6 posições passadas (`t - i*0.028`).
- **Runa central** (`CenterRune`): `centerGlow` cresce com `u` até o impacto.
- **Em `t ≥ E1_IMPACT`** (`since = t - IMPACT`, vida `= since/1.3`):
  - 2 **Bursts** (anéis): intensidade `1.0` e `0.55`, raio `10→130px`, opacidade `1→0`.
  - **Debris**: `CPUParticles2D` one-shot, `amount≈22`, spread 360°, `spread_px≈230`.
  - **Flash** de tela: pico em `since<0.32` (alpha ~0.85→0).
  - **Tremor**: `shake = max(0, 1 - since/0.5) * 14 * sin(since*60)` aplicado em `%Shake.position`.
- Esconda o cristal após o impacto.

### `_update_e2(t)` — Colisão
- **2 fendas** (E2_L, E2_R), mesma abertura.
- **2 cristais** em `t∈[E2_REL, E2_IMPACT]`: convergem de L e R ao centro com `arc=70` (um curva por cima, outro por baixo — sinais opostos do bow), rotações opostas (`+t*260°` / `-t*260°`). Rastros iguais ao E1.
- **Em `t ≥ E2_IMPACT`** (`since`):
  - **1 Burst pequeno** intensidade `0.42` (`vida = since/0.5`) + **Debris** menor (`amount≈12`, `spread_px≈90`).
  - **Flash** fraco (alpha ~0.4, dura 0.18s); **tremor** pequeno (`5 * sin(since*70)`).
  - **LightOrb sustentado** (a "pequena luz"): aparece em `since` com fade-in `since/0.45` e **fade-out** `(E2_END - t)/0.6`; raio **pulsa** `13 * (0.78 + 0.22*sin(since*5.5))`; halo respirando. **Este orbe é o ponto do efeito 2** — uma centelha contida, não uma explosão.

### `_update_e3(t)` — Fusão
- **3 fendas** (E3_SPAWNS), abrem/fecham (janela até ~0.85s).
- **3 cristais** em `t < E3_MERGE`: posição via `_e3_frag_pos(i, t)`. Rastro amostra 7 posições passadas (`t - i*0.024`) → desenha o anel girando. Escala/glow crescem com `lt`. `centerGlow = 0.1 + lt² * 0.85` durante a órbita.
- **Em `t ≥ E3_MERGE`** (`since`, vida `= since/1.7`):
  - **3 Bursts** intensidades `1.35`, `0.8`, `0.5` (com pequenos delays) — anéis maiores que todos os outros efeitos.
  - **Debris** forte (`amount≈28`, `spread_px≈330`).
  - **Rays**: nó com 12 `Line2D` radiais, **girando** (`angle = since*90°`), comprimento `60→360px`, alternando linhas longas/curtas.
  - **Pillar**: `TextureRect` de luz vertical, opacidade sobe rápido (`since/0.3`) e cai (`(1.5-since)/1.0`).
  - **Flash** forte (alpha ~1.0, 0.4s) + **tremor grande** (`20 * sin(since*55)`).
- Esconda os cristais após a fusão.

> Mantenha um **pool fixo** de nós (3 cristais, 3 rastros, 3 fendas, N bursts, 1 orbe, raios, pilar) criado no `_ready()` e só **ligue/desligue `visible` + atualize transform/modulate** por quadro. Não instancie/free por quadro (custo e GC).

---

## API PÚBLICA

```gdscript
class_name ArcaneFragments extends Node2D
signal finished

var _effect := 1
var _t := 0.0
var _running := false

# effect ∈ {1,2,3}; center = ponto central do board em coords globais.
func play(effect: int, center: Vector2 = Vector2(640, 360)) -> void:
    _effect = clampi(effect, 1, 3)
    CENTER = center
    _t = 0.0
    _running = true
    _setup_banner_for_effect(_effect)
    # _toca som de carga aqui (opcional)

func _process(delta: float) -> void:
    if not _running: return
    _t += delta
    match _effect:
        1: _update_e1(_t)
        2: _update_e2(_t)
        3: _update_e3(_t)
    var end := [0.0, E1_END, E2_END, E3_END][_effect]
    if _t >= end + 0.6:
        _running = false
        emit_signal("finished")
        queue_free()
```

### Banner por efeito (textos exatos do HTML)
```gdscript
const EFFECT_META := {
    1: {"roman": "I",   "name": "IMPACTO", "sub": "Fragmento único"},
    2: {"roman": "II",  "name": "COLISÃO", "sub": "Par instável"},
    3: {"roman": "III", "name": "FUSÃO",   "sub": "Tríade arcana"},
}
```
O **Status** (subtítulo inferior) muda conforme a fase — espelhe as strings `banner` retornadas em cada `deriveEN`:
- E1: `"A pedra arcana converge ao centro"` → (no impacto) `"Detonação arcana"`
- E2: `"Dois fragmentos rumam ao impacto"` → `"Uma centelha nasce do choque"`
- E3: `"Três fragmentos despertam"` → `"Os fragmentos giram e se atraem"` → `"Fusão — uma luz intensa irrompe"`

---

## CRISTAL — `Polygon2D` (espelha `CrystalShard` do HTML)

Cada fragmento é um `Node2D` com:
- **Glow** (Sprite2D do glow radial, ADD, escala segue `glow*scale`).
- **Corpo** `Polygon2D` losango: vértices `[(0,-13),(7,-2),(0,13),(-7,-2)]`, cor `#3A1E5C`, contorno claro via `Line2D` fechada (`#D9A8FF`).
- **Faceta** `Polygon2D` superior `[(0,-13),(7,-2),(0,2),(-7,-2)]` cor `#B07EF0`.
- **Linha central** `Line2D` `(0,-13)→(0,13)` clara.
- **Núcleo** pequeno `Sprite2D` glow em `(0,-1)`.
O `Node2D` recebe `position`, `rotation` (graus→rad) e `scale` por quadro.

---

## TEMA / TIPOGRAFIA DO BANNER

- **Subtitle** — `Cinzel-Regular.ttf`, size **14**, color `#BD7EF0`, uppercase, letter_spacing wide. Texto: `"FRAGMENTOS ARCANOS · {roman}"`.
- **AbilityName** — `CinzelDecorative-Bold.ttf`, size **46**, color `#EDDAFA`, shadow (0,2) blur 18 `#A85CE0`.
- **Rule** — ColorRect 300×1, gradiente horizontal transparente → `#BD7EF0` → transparente.
- **Status** — `Cinzel-Regular.ttf`, size **12**, color `#BD7EF0`, opacity 0.85, uppercase, letter_spacing very_wide.

Banner posicionado no topo (`y ≈ 84px` em coords de board), centralizado.

---

## INTEGRAÇÃO COM O BOARD

No `board.gd`, ao ativar a magia (passando qual variante o jogador/IA escolheu):

```gdscript
func cast_arcane_fragments(variant: int) -> void:   # variant ∈ {1,2,3}
    var fx := preload("res://scenes/vfx/arcane_fragments/ArcaneFragments.tscn").instantiate()
    add_child(fx)
    fx.play(variant, board_center_position())
    fx.finished.connect(_on_ability_finished)

func board_center_position() -> Vector2:
    return $BoardRect.global_position + Vector2(640, 360)  # centro do tabuleiro 1280×720
```

> As fendas de surgimento (`E1_SPAWN`, `E2_L/R`, `E3_SPAWNS`) são **relativas ao board** no HTML. Some `CENTER - Vector2(640,360)` a cada ponto fixo se o board não estiver na origem, OU mantenha a cena em um `SubViewport`/canvas de 1280×720 e converta uma vez. Escolha a abordagem que já é usada nos outros VFX do projeto.

---

## SOM (OPCIONAL — não-bloqueante)

- **Charge** — hum arcano crescente no início de cada `play()`; intensidade proporcional ao efeito.
- **Impact** — E1: estouro grave e seco no `E1_IMPACT`. E2: "tink" curto e suave no `E2_IMPACT`.
- **Fuse** — E3: build-up agudo durante a órbita (1.2→2.35s) culminando num "boom" cristalino no `E3_MERGE`.

---

## CHECKLIST DE FIDELIDADE AO HTML

Abra `Arcane Fragments.html`, selecione o efeito (`I/II/III`) e use o slider de tempo no rodapé para comparar quadro a quadro:

**Efeito 1 — Impacto**
- [ ] **0.3s** — fenda violeta abre abaixo do conjurador; pedra emerge
- [ ] **1.0s** — pedra em arco subindo ao centro; carta do Conjurador pulsando; runa central acendendo
- [ ] **1.40s** — **detonação**: anéis expandindo + flash + estilhaços radiais + tremor
- [ ] **2.4s** — onda dissipando; runa esmaecendo
- [ ] **3.1s** — limpo, `finished`

**Efeito 2 — Colisão**
- [ ] **1.0s** — duas pedras convergindo dos flancos, cada uma com rastro curvo (bows opostos)
- [ ] **1.35s** — **choque**: flash pequeno + poucos estilhaços
- [ ] **1.8s** — **pequena luz contida** pulsando no centro (sem explosão grande)
- [ ] **3.5s** — orbe desvanece; `finished`

**Efeito 3 — Fusão**
- [ ] **0.8s** — três fendas abertas; cristais voando ao anel
- [ ] **1.8s** — **anel girando** acelerando, raio encolhendo (rastros formam o anel de energia)
- [ ] **2.35s** — **fusão**: múltiplos anéis + raios giratórios + **pilar vertical de luz** + flash forte + tremor grande
- [ ] **2.5s** — luz intensa no pico (a maior de todos os efeitos)
- [ ] **4.3s** — limpo, `finished`

**Regra de ouro da escalada:** Efeito 1 = explosão única e forte; Efeito 2 = choque pequeno + luz contida (o menor clímax); Efeito 3 = fusão com a luz mais intensa de todos. Se 2 parecer maior que 1, ou 3 não for o mais brilhante, reveja `intensity`/`spread` dos bursts e o pilar.

---

## ENTREGÁVEIS

- [ ] `res://scenes/vfx/arcane_fragments/ArcaneFragments.tscn` + `arcane_fragments.gd`
- [ ] Glows/gradientes gerados em código (nenhum PNG externo)
- [ ] Hook no `board.gd` (`cast_arcane_fragments(variant)`) instanciando a cena
- [ ] Cena de teste `res://scenes/vfx/arcane_fragments/ArcaneFragmentsTest.tscn` com **3 botões (`I/II/III`)** + um "Conjurar" que chama `fx.play(variant, Vector2(640,360))` com posições fixas idênticas às do HTML, para QA isolado de cada efeito

---

## REFERÊNCIA VISUAL

**Leia `Arcane Fragments.html` na raiz do projeto antes de começar.** Não invente timings, trajetórias ou intensidades — espelhe. As constantes `E1_*`, `E2_*`, `E3_*` e a função `_e3_frag_pos` já batem com os objetos/derives do HTML (`deriveE1/E2/E3`, `EFFECTS`, `travel`, `fragPosAt`). A assinatura do efeito é a **escalada de intensidade** (1 explode → 2 centelha → 3 funde em luz forte) e o **anel orbital giratório** do efeito 3; em caso de divergência visual, compare lado a lado abrindo o HTML pausado no tempo correspondente, com o efeito certo selecionado.

Pode começar.
