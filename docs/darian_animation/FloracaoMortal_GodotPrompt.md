# Prompt para Claude Code — `FloracaoMortal.tscn` (Godot 4)

Cole o conteúdo abaixo no Claude Code. Assume que `RosasNegras.tscn` (ver `RosasNegras_GodotPrompt.md`) já existe e que heróis do oponente podem ter **rosas cravadas persistentes** registradas via `hero_card.register_stuck_rose()`.

---

## CONTEXTO

**Taldorian TCCG**, Godot 4.x, tabuleiro 1280×720. A referência visual completa está em **`Floração Mortal.html`** na raiz do projeto — **leia antes de começar**. É a habilidade especial de **Darian**: detona todas as rosas negras já cravadas nos heróis do oponente.

## NATUREZA DO EFEITO

Efeito **one-shot**, disparado sobre o `Board.tscn`. Sequência (espelha `const T = {...}` do HTML):

1. **Banner (0.15–4.5s)** — "FLORAÇÃO MORTAL" no centro, subtítulo "Habilidade Especial".
2. **Varredura (0.30–1.60s)** — uma **onda de espinhos/pétalas negras varre a tela inteira da esquerda para a direita**, cobrindo toda a área do oponente (faixa vertical `y: 90–300`). É uma parede/linha vertical de energia (glow + pétalas girando) que se move em `x` de `0` a `1280` ao longo de 1.3s.
3. **Ignição por passagem** — cada rosa cravada **acende (pulsa)** no exato instante em que a onda cruza a posição X daquele herói: `igniteAt = SWEEP_START + (heroX / 1280) * (SWEEP_END - SWEEP_START)`. Da ignição até a explosão, a rosa pulsa crescente (brilho + escala, com leve tremor senoidal).
4. **Explosão escalonada** — cada rosa explode **`EXPLODE_DELAY` (0.4s) depois de ser ignitada** (+ pequeno offset de 0.06s por índice, para não ficarem idênticas). No momento da explosão: anel de choque expandindo, flash central curto, ~10 pétalas negras arremessadas radialmente, popup de dano subindo, HP cai, e a rosa cravada correspondente é removida (consumida) da carta.
5. **Fim (~5.0s)** — banner some; efeito conclui e emite `finished` + `queue_free()`.

**Ponto crítico:** a ordem de explosão segue a ordem em que a varredura atinge cada herói (esquerda → direita), não uma ordem arbitrária.

---

## ÁRVORE DE CENAS

```
FloracaoMortal (CanvasLayer, layer = 80)   [script: floracao_mortal.gd]
├─ Banner (Control, anchors=center)
│  ├─ Subtitle    (Label, "Habilidade Especial")
│  ├─ AbilityName (Label, "FLORAÇÃO MORTAL")
│  ├─ Rule        (ColorRect, 320x1)
│  └─ Status      (Label)
├─ SweepLayer (Node2D)
│  ├─ SweepBand  (ColorRect ou Sprite2D, 92px largura, altura = y:90→300, blend ADD)
│  ├─ SweepCore  (ColorRect fina, 6px, brilho central)
│  └─ SweepPetals (Node2D — ~16 Sprite2D "petal.png" espalhadas na faixa, seguindo o x da varredura com wobble senoidal)
├─ ExplosionsLayer (Node2D)          # anéis + flashes + pétalas radiais no pop de cada rosa
├─ DamagePopups (Node2D)
├─ ScreenFlash (ColorRect, anchors=full_rect, modulate.a=0)
└─ AudioPlayers
   ├─ Sweep    (AudioStreamPlayer)   # zumbido/whoosh contínuo durante a varredura
   ├─ Ignite   (AudioStreamPlayer)   # tocado por rosa ao acender (pitch aleatório)
   └─ Explode  (AudioStreamPlayer)   # tocado por rosa ao explodir
```

Marque cada nó dinâmico com **Unique Name in Owner** (`%`).

---

## ASSETS

Reaproveita `res://assets/vfx/rosas_negras/petal.png` e `impact_burst.png`. Novos, em `res://assets/vfx/floracao_mortal/`:

| Arquivo          | Tamanho | Uso                                                          |
|------------------|---------|---------------------------------------------------------------|
| `sweep_glow.png` | 128×512 | Faixa vertical de glow carmesim usada na `SweepBand` (esticada em altura) |
| `explosion_ring.png` | 256×256 | Anel de choque da explosão de cada rosa (compartilhável com `impact_burst.png` se preferir reusar) |

Import flags: `filter=true`, `mipmaps=true`, `compress/mode=0`, `process/fix_alpha_border=true`.

Paleta: reusa `rose-core / rose-crimson / rose-black / thorn` de `RosasNegras_GodotPrompt.md`.

---

## SCRIPT — `floracao_mortal.gd`

```gdscript
class_name FloracaoMortal extends CanvasLayer

@export var ability_name: String = "FLORAÇÃO MORTAL"

const STAGE_W := 1280.0
const SWEEP_Y_TOP := 90.0
const SWEEP_Y_BOT := 300.0
const T_BANNER_IN   := 0.15
const T_BANNER_OUT  := 4.5
const T_SWEEP_START := 0.30
const T_SWEEP_END   := 1.60
const EXPLODE_DELAY := 0.4
const T_HOLD_END    := 5.0

signal finished
signal target_exploded(hero_card: Node2D, total_dmg: int)

# targets: Array de { "hero_card": Node2D, "pos": Vector2, "hp_node": Range, "roses": Array }
# "roses" = resultado de hero_card.consume_stuck_roses() (cada item {node, dmg}) — colete ANTES de chamar play(),
# assim a ordem de explosão e a remoção visual ficam sob controle desta cena.
var _targets: Array = []
var _plan: Array = []   # {target_idx, ignite_at, explode_at}

func _ready() -> void:
    %Banner.modulate.a = 0.0
    %AbilityName.text = ability_name
    %Status.text = "Uma onda de espinhos varre o campo..."
    %ScreenFlash.modulate.a = 0.0
    _hide_sweep()

func play(targets: Array) -> void:
    _targets = targets
    _plan.clear()
    for i in _targets.size():
        var hero_x: float = _targets[i].pos.x
        var ignite_at: float = T_SWEEP_START + (hero_x / STAGE_W) * (T_SWEEP_END - T_SWEEP_START)
        var explode_at: float = ignite_at + EXPLODE_DELAY + i * 0.06
        _plan.append({"idx": i, "ignite_at": ignite_at, "explode_at": explode_at})
    _run()

func _run() -> void:
    var t := create_tween(); t.set_parallel(true)
    t.tween_property(%Banner, "modulate:a", 1.0, 0.35).set_delay(T_BANNER_IN)

    # Varredura: SweepBand/SweepCore atravessam x=0 -> 1280 entre T_SWEEP_START e T_SWEEP_END
    _show_sweep()
    t.tween_method(_set_sweep_x, 0.0, STAGE_W, T_SWEEP_END - T_SWEEP_START).set_delay(T_SWEEP_START)
    get_tree().create_timer(T_SWEEP_END, false).timeout.connect(_hide_sweep)

    for entry in _plan:
        get_tree().create_timer(entry.ignite_at, false).timeout.connect(_ignite_rose.bind(entry.idx, entry.explode_at))

    var last_explode: float = 0.0
    for entry in _plan: last_explode = max(last_explode, entry.explode_at)
    get_tree().create_timer(T_SWEEP_END, false).timeout.connect(func(): %Status.text = "O sangue sombrio se acumula...")
    get_tree().create_timer(last_explode, false).timeout.connect(func(): %Status.text = "As rosas desabrocham em fúria")
    t.tween_property(%Banner, "modulate:a", 0.0, 0.5).set_delay(T_BANNER_OUT - 0.5)

    get_tree().create_timer(T_HOLD_END, false).timeout.connect(func():
        emit_signal("finished")
        queue_free()
    )

func _show_sweep() -> void:
    for n in ["SweepBand", "SweepCore"]:
        get_node("%"+n).visible = true
        get_node("%"+n).modulate.a = 1.0

func _hide_sweep() -> void:
    for n in ["SweepBand", "SweepCore"]:
        get_node("%"+n).visible = false

func _set_sweep_x(x: float) -> void:
    %SweepBand.position.x = x - 46
    %SweepCore.position.x = x - 3
    for petal in %SweepPetals.get_children():
        petal.position.x = x + petal.get_meta("dx") + sin(Time.get_ticks_msec()/1000.0 * petal.get_meta("speed") + petal.get_meta("id")) * 10.0

# ── Rosa acende: pulso crescente até a hora de explodir ─────────────────────
func _ignite_rose(idx: int, explode_at: float) -> void:
    var target: Dictionary = _targets[idx]
    for r in target.roses:
        var node: Sprite2D = r.node
        var pt := create_tween().set_parallel(true)
        var dur: float = explode_at - _plan[idx].ignite_at
        pt.tween_property(node, "scale", node.scale * 1.35, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        pt.tween_property(node, "modulate", Color(1.3, 0.9, 0.95), dur)
    get_tree().create_timer(explode_at - _plan[idx].ignite_at, false).timeout.connect(_explode_target.bind(idx))

# ── Explosão: consome as rosas da carta, aplica dano somado, remove os ícones ──
func _explode_target(idx: int) -> void:
    var target: Dictionary = _targets[idx]
    var pos: Vector2 = target.pos
    var total_dmg := 0
    for r in target.roses:
        total_dmg += r.dmg
        if is_instance_valid(r.node): r.node.queue_free()

    _spawn_explosion(pos)

    if target.has("hp_node") and target.hp_node:
        var hp := target.hp_node as Range
        hp.value = max(0, hp.value - total_dmg)
    _spawn_damage_popup(pos, total_dmg)

    var ft := create_tween()
    ft.tween_property(%ScreenFlash, "modulate:a", 0.4, 0.05)
    ft.tween_property(%ScreenFlash, "modulate:a", 0.0, 0.25)

    emit_signal("target_exploded", target.hero_card, total_dmg)

func _spawn_explosion(pos: Vector2) -> void:
    var ring := Sprite2D.new()
    ring.texture = preload("res://assets/vfx/floracao_mortal/explosion_ring.png")
    ring.material = _add_material(); ring.position = pos; ring.scale = Vector2(0.1, 0.1)
    %ExplosionsLayer.add_child(ring)
    var rt := create_tween().set_parallel(true)
    rt.tween_property(ring, "scale", Vector2(1.3, 1.3), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    rt.tween_property(ring, "modulate:a", 0.0, 0.55)
    rt.chain().tween_callback(ring.queue_free)

    for i in 10:
        var petal := Sprite2D.new()
        petal.texture = preload("res://assets/vfx/rosas_negras/petal.png")
        petal.material = _add_material(); petal.position = pos
        %ExplosionsLayer.add_child(petal)
        var ang: float = (float(i)/10.0) * TAU + i * 0.4
        var dist := 60.0
        var pt := create_tween().set_parallel(true)
        pt.tween_property(petal, "position", pos + Vector2(cos(ang), sin(ang)) * dist, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        pt.tween_property(petal, "rotation", ang + PI, 0.5)
        pt.tween_property(petal, "modulate:a", 0.0, 0.5)
        pt.chain().tween_callback(petal.queue_free)

func _spawn_damage_popup(pos: Vector2, dmg: int) -> void:
    var lbl := Label.new()
    lbl.text = "−%d" % dmg
    lbl.add_theme_font_size_override("font_size", 26)
    lbl.add_theme_color_override("font_color", Color(0.90, 0.75, 0.78))
    lbl.position = pos - Vector2(18, 18)
    %DamagePopups.add_child(lbl)
    var pt := create_tween().set_parallel(true)
    pt.tween_property(lbl, "position:y", lbl.position.y - 44, 0.9)
    pt.tween_property(lbl, "modulate:a", 0.0, 0.9).set_delay(0.15)
    pt.chain().tween_callback(lbl.queue_free)

func _add_material() -> CanvasItemMaterial:
    var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD; return mat
```

---

## INTEGRAÇÃO COM O BOARD

```gdscript
func _on_darian_special() -> void:
    var opp_heroes := [$OpponentSide/Hero3, $OpponentSide/Hero2, $OpponentSide/Hero1, $OpponentSide/ActiveHero]
    var targets := []
    for hero in opp_heroes:
        var roses: Array = hero.consume_stuck_roses()   # ver hero_card.gd em RosasNegras_GodotPrompt.md
        if roses.is_empty(): continue
        targets.append({
            "hero_card": hero,
            "pos": hero.global_position,
            "hp_node": hero.get_node("HpBar"),
            "roses": roses,
        })
    if targets.is_empty():
        return   # nada a detonar — Darian não deveria poder usar a especial sem rosas cravadas

    var fx := preload("res://scenes/vfx/floracao_mortal/FloracaoMortal.tscn").instantiate()
    add_child(fx)
    fx.finished.connect(_on_ability_finished)
    fx.play(targets)
```

> **Nota de ordenação:** ordene `targets` por posição X (esquerda → direita) antes de passar para `play()`, pois a varredura calcula `ignite_at` a partir do X de cada alvo — a ordem do array não precisa ser explicitamente crescente (o cálculo já resolve por X), mas mantenha os `pos` corretos vindos do board real.

---

## CHECKLIST DE FIDELIDADE

- [ ] **0.3–1.6s** — uma única onda/parede de energia varre a tela inteira de X=0 a X=1280, cobrindo a faixa vertical dos heróis do oponente.
- [ ] Cada rosa cravada **acende exatamente quando a onda passa pelo X daquele herói** — não antes, não de forma simultânea para todas.
- [ ] Cada rosa **explode ~0.4s depois de acender**, na ordem esquerda → direita (com leve escalonamento entre elas).
- [ ] Dano é a **soma de todas as rosas** cravadas naquele herói (se houver mais de uma).
- [ ] Rosas cravadas são **removidas visualmente** (consumidas) no momento da explosão.
- [ ] Sem rosas cravadas em nenhum herói → habilidade não deveria ativar (ou não tem o que detonar).

## REFERÊNCIA VISUAL
Leia `Floração Mortal.html` e use o slider de tempo para comparar o avanço da varredura e o timing de ignição/explosão de cada rosa. Pode começar.
