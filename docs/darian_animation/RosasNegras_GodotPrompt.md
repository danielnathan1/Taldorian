# Prompt para Claude Code — `RosasNegras.tscn` (Godot 4)

Cole o conteúdo abaixo no Claude Code. Ele assume que o projeto Godot do **Taldorian TCCG** já existe em `res://`, que `Card.tscn` e `Board.tscn` já foram criados, e que o efeito é disparado quando o herói **Darian** usa seu ataque de **Rosas Negras**.

---

## CONTEXTO

Estou desenvolvendo **Taldorian TCCG** em Godot 4.x. Tabuleiro 1280×720, espelhado verticalmente (oponente em cima, jogador embaixo). A referência visual completa está em **`Rosas Negras.html`** na raiz do projeto — **leia esse arquivo antes de começar**. Ele tem:

- Origem do disparo: `CASTER_ORIGIN = {x:720, y:500}` (mão de Darian).
- Alvos possíveis do oponente: `OPP.h3/h2/h1/active`.
- A timeline completa em segundos (`const T = {...}`).
- A trajetória curva de cada rosa: Bézier cúbica com ondulação senoidal (`cbez`, `rosePos`) — **igual em espírito ao Magic Missiles**, mas com 3 projéteis (não 5), visual de rosa/espinho em vez de míssil arcano.
- **O detalhe crítico deste efeito:** cada rosa que acerta **permanece cravada visualmente na carta do alvo** (`StuckRose`) até o fim da cena — isso é estado persistente que a habilidade especial (`Floração Mortal`) consome depois.

## OBJETIVO

Construir **`res://scenes/vfx/rosas_negras/RosasNegras.tscn`** — VFX autocontido, instanciado sobre `Board.tscn` quando Darian dispara. Sequência:

1. **Carga (0.0–0.9s)** — a carta de Darian pulsa em carmesim; pétalas negras espiralam para dentro da mão dele.
2. **Banner (0.15–2.6s)** — "ROSAS NEGRAS" no centro; status "Colhendo espinhos sombrios" → "As rosas cravam nos inimigos".
3. **Disparo (0.9–1.5s)** — 3 rosas saem da mão em sequência escalonada, cada uma mirando um alvo **escolhido aleatoriamente** entre os inimigos (`h3, h2, h1, active` — pode repetir alvo).
4. **Voo em curva** — cada rosa percorre uma Bézier cúbica em arco + ondulação senoidal (mesmo princípio do Magic Missiles). Rastro de pétalas negras se desprendendo atrás da cabeça (botão de rosa brilhante em carmesim).
5. **Impacto** — burst de pétalas + anel de choque; popup de dano `-N` em carmesim; HP cai.
6. **Rosa cravada (persistente)** — no instante do impacto, um ícone de rosa negra pequena (`StuckRose`) aparece fixado no canto superior-direito da carta atingida e **permanece visível** pelo resto da cena (não desaparece com a "hold"). Se dois disparos acertarem o mesmo alvo, ambas as rosas ficam visíveis (offset levemente entre si).
7. **Hold (até 4.0s)** — banner some; rosas cravadas continuam visíveis.

Esse estado de "rosa cravada" **precisa ser persistido no estado real de jogo** (não só no VFX) — outra habilidade (Floração Mortal) precisa saber quais heróis têm rosas cravadas para detoná-las depois.

---

## ÁRVORE DE CENAS

```
RosasNegras (Node2D)  [script: rosas_negras.gd]
├─ Background (CanvasLayer, layer = 50)
│  └─ ScreenFlash (ColorRect, anchors=full_rect, color=#e0a0a8, modulate.a=0)
├─ ChargeGlow (Sprite2D, texture=charge_glow.png, modulate.a=0, material=ADD)
├─ ChargePetals (Node2D)              # pétalas espiralando na carga
├─ RosesLayer (Node2D)                # rosas em voo (cabeça + rastro de pétalas)
├─ ImpactsLayer (Node2D)              # bursts de pétala no impacto
├─ StuckRosesLayer (Node2D)           # rosas cravadas PERSISTENTES por herói-alvo
├─ DamagePopups (Node2D)
├─ Banner (Control, anchors=center)
│  ├─ Subtitle    (Label, "Magia Sombria")
│  ├─ AbilityName (Label, "ROSAS NEGRAS")
│  ├─ Rule        (ColorRect, 300x1)
│  └─ Status      (Label)
└─ AudioPlayers
   ├─ Charge (AudioStreamPlayer)
   ├─ Release (AudioStreamPlayer)
   ├─ Whoosh (AudioStreamPlayer)
   └─ Impact (AudioStreamPlayer)
```

Marque cada nó dinâmico com **Unique Name in Owner** (`%`).

---

## ASSETS

Todos em `res://assets/vfx/rosas_negras/` (gerar/gerar proceduralmente se ainda não existirem — são texturas simples, gradientes radiais):

| Arquivo             | Tamanho | Uso                                                            |
|---------------------|---------|-----------------------------------------------------------------|
| `rose_head.png`     | 256×256 | Botão de rosa brilhante carmesim-preto, blend ADD               |
| `petal.png`         | 64×64   | Pétala individual (usada no rastro, no burst e na carga)         |
| `charge_glow.png`   | 512×512 | Glow carmesim ao redor da carta de Darian durante a carga        |
| `impact_burst.png`  | 256×256 | Anel de choque do impacto                                        |
| `stuck_rose.png`    | 96×96   | Ícone de rosa cravada — pequena, com espinho, fica fixo na carta |
| `darian_portrait.png`| 512×512| Retrato placeholder de Darian                                    |

Import flags: `filter=true`, `mipmaps=true`, `compress/mode=0`, `process/fix_alpha_border=true`.

Paleta:
| Token          | OKLCH                  | Uso                          |
|----------------|------------------------|-------------------------------|
| `rose-core`    | `oklch(0.66 0.18 18)`  | Núcleo brilhante do botão     |
| `rose-crimson` | `oklch(0.50 0.20 20)`  | Carmesim médio (glow, rastro) |
| `rose-black`   | `oklch(0.13 0.03 20)`  | Pétala/base quase preta       |
| `thorn`        | `oklch(0.28 0.05 130)` | Verde-espinho bem escuro (caule) |

---

## SCRIPT — `rosas_negras.gd`

```gdscript
class_name RosasNegras extends Node2D

@export var flight_time: float = 0.85
@export var ability_name: String = "ROSAS NEGRAS"
@export var rose_color: Color = Color(0.66, 0.30, 0.34)

# Cada rosa: alvo (escolhido em runtime), lado da curva, força, ondas, dano.
var roses: Array = []   # preenchido em play() com alvos sorteados

const T_CHARGE_END   := 0.9
const T_BANNER_IN    := 0.15
const T_BANNER_OUT   := 2.6
const T_LAUNCH_FIRST := 0.9
const T_LAUNCH_LAST  := 1.5
const T_HOLD_END     := 4.0

signal finished
signal rose_stuck(target_key: String, world_pos: Vector2)   # emitido por rosa cravada — o Board deve persistir esse estado

var _source: Vector2
var _targets: Dictionary = {}
var _rng := RandomNumberGenerator.new()

# targets: Dictionary chave -> {pos, hp_node}
# target_pool: chaves elegíveis para sorteio aleatório (ex: ["h3","h2","h1","active"])
func play(source_pos: Vector2, targets: Dictionary, target_pool: Array, num_roses: int = 3) -> void:
    _source = source_pos
    _targets = targets
    _rng.randomize()
    roses.clear()
    for i in num_roses:
        var key: String = target_pool[_rng.randi_range(0, target_pool.size() - 1)]
        roses.append({
            "target": key,
            "side": 1.0 if _rng.randf() < 0.5 else -1.0,
            "curve": 150.0 + _rng.randf() * 80.0,
            "waves": 1.4 + _rng.randf() * 0.8,
            "dmg": 5,
        })
    _run()

func _run() -> void:
    _setup_initial_state()
    var t := create_tween(); t.set_parallel(true)
    _animate_charge(t)
    _animate_banner(t)
    for i in roses.size():
        var launch_t: float = T_LAUNCH_FIRST + (T_LAUNCH_LAST - T_LAUNCH_FIRST) * float(i) / float(max(1, roses.size() - 1))
        get_tree().create_timer(launch_t, false).timeout.connect(_spawn_rose.bind(i))
    get_tree().create_timer(T_HOLD_END, false).timeout.connect(func():
        emit_signal("finished")
        queue_free()   # StuckRosesLayer's roses must already have been reparented to Board/HeroCard nodes, see nota abaixo
    )

func _setup_initial_state() -> void:
    %ChargeGlow.position = _source; %ChargeGlow.modulate.a = 0.0; %ChargeGlow.scale = Vector2(0.2, 0.2)
    %Banner.modulate.a = 0.0
    %AbilityName.text = ability_name
    %Status.text = "Colhendo espinhos sombrios"

func _animate_charge(t: Tween) -> void:
    t.tween_property(%ChargeGlow, "modulate:a", 0.8, T_CHARGE_END).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    t.tween_property(%ChargeGlow, "scale", Vector2(1.3, 1.3), T_CHARGE_END).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    t.tween_property(%ChargeGlow, "modulate:a", 0.0, 0.4).set_delay(T_CHARGE_END)
    for i in 7:
        var petal := Sprite2D.new()
        petal.texture = preload("res://assets/vfx/rosas_negras/petal.png")
        petal.material = _add_material()
        %ChargePetals.add_child(petal)
        var phase: float = float(i) * TAU / 7.0
        var pt := create_tween()
        pt.tween_method(func(p: float):
                var ang := p * 2.6 * TAU + phase
                var rad := (1.0 - p) * 40.0 + 8.0
                petal.position = _source + Vector2(cos(ang), sin(ang)) * rad
                petal.rotation = ang
                petal.modulate.a = p,
            0.0, 1.0, T_CHARGE_END)
        pt.tween_callback(petal.queue_free)

func _animate_banner(t: Tween) -> void:
    t.tween_property(%Banner, "modulate:a", 1.0, 0.35).set_delay(T_BANNER_IN)
    get_tree().create_timer(T_CHARGE_END, false).timeout.connect(func(): %Status.text = "As rosas cravam nos inimigos")
    t.tween_property(%Banner, "modulate:a", 0.0, 0.4).set_delay(T_BANNER_OUT - 0.4)

# ═══ Trajetória — espelha MagicMissiles (Bézier cúbica + ondulação) ═══
func _build_path(m: Dictionary) -> Dictionary:
    var p0: Vector2 = _source
    var p3: Vector2 = _targets[m.target].pos + Vector2(0, 6)
    var dir: Vector2 = (p3 - p0).normalized()
    var nrm := Vector2(-dir.y, dir.x)
    var length: float = p0.distance_to(p3)
    var c1: Vector2 = p0 + dir * length * 0.30 + nrm * m.curve * m.side
    var c2: Vector2 = p0 + dir * length * 0.72 + nrm * (m.curve * 0.55) * m.side
    return {"p0": p0, "c1": c1, "c2": c2, "p3": p3, "waves": m.waves}

func _cbez(p: Dictionary, u: float) -> Vector2:
    var v := 1.0 - u
    return v*v*v*p.p0 + 3.0*v*v*u*p.c1 + 3.0*v*u*u*p.c2 + u*u*u*p.p3
func _cbez_tangent(p: Dictionary, u: float) -> Vector2:
    var v := 1.0 - u
    return 3.0*v*v*(p.c1-p.p0) + 6.0*v*u*(p.c2-p.c1) + 3.0*u*u*(p.p3-p.c2)
func _rose_pos(p: Dictionary, u: float, idx: int) -> Vector2:
    var base := _cbez(p, u)
    var tan := _cbez_tangent(p, u).normalized()
    var wn := Vector2(-tan.y, tan.x)
    var fade := sin(u * PI)
    var wob := sin(u * PI * p.waves + idx) * 14.0 * fade * (1.0 - u * 0.4)
    return base + wn * wob

func _spawn_rose(idx: int) -> void:
    var m: Dictionary = roses[idx]
    var path := _build_path(m)
    var head := Sprite2D.new()
    head.texture = preload("res://assets/vfx/rosas_negras/rose_head.png")
    head.material = _add_material(); head.modulate = rose_color; head.scale = Vector2(0.16, 0.16)
    %RosesLayer.add_child(head)

    var trail := Line2D.new()
    trail.width = 5.0
    trail.default_color = Color(rose_color.r, rose_color.g, rose_color.b, 0.35)
    trail.material = _add_material()
    %RosesLayer.add_child(trail)

    const TRAIL_STEPS := 12
    const TRAIL_SPAN := 0.15
    var fly := create_tween()
    fly.tween_method(func(local: float):
            var u := _ease_in_out_cubic(local)
            head.position = _rose_pos(path, u, idx)
            head.rotation = _cbez_tangent(path, u).angle()
            var pts := PackedVector2Array()
            for i in range(TRAIL_STEPS, -1, -1):
                var uu: float = u - (float(i)/TRAIL_STEPS) * TRAIL_SPAN
                if uu < 0.0: continue
                pts.append(_rose_pos(path, uu, idx))
            trail.points = pts,
        0.0, 1.0, flight_time)
    fly.tween_callback(func():
        head.queue_free()
        var tt := create_tween(); tt.tween_property(trail, "modulate:a", 0.0, 0.15); tt.tween_callback(trail.queue_free)
        _on_rose_impact(path.p3, m.target, m.dmg)
    )

func _ease_in_out_cubic(u: float) -> float:
    return 4.0*u*u*u if u < 0.5 else 1.0 - pow(-2.0*u + 2.0, 3.0) / 2.0

func _on_rose_impact(pos: Vector2, target_key: String, dmg: int) -> void:
    var burst := Sprite2D.new()
    burst.texture = preload("res://assets/vfx/rosas_negras/impact_burst.png")
    burst.material = _add_material(); burst.position = pos; burst.scale = Vector2(0.08, 0.08)
    %ImpactsLayer.add_child(burst)
    var bt := create_tween().set_parallel(true)
    bt.tween_property(burst, "scale", Vector2(1.1, 1.1), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    bt.tween_property(burst, "modulate:a", 0.0, 0.5)
    bt.chain().tween_callback(burst.queue_free)

    # Rosa cravada — PERSISTENTE. Reparente para o nó da carta-alvo (não para esta cena),
    # para sobreviver ao queue_free() do RosasNegras e para a Floração Mortal poder achá-la depois.
    if _targets.has(target_key) and _targets[target_key].has("card_node"):
        var card: Node2D = _targets[target_key].card_node
        var stuck := Sprite2D.new()
        stuck.texture = preload("res://assets/vfx/rosas_negras/stuck_rose.png")
        stuck.position = Vector2(32, -40) + Vector2(randf_range(-4,4), randf_range(-4,4))
        stuck.name = "StuckRose_%d" % Time.get_ticks_msec()
        card.add_child(stuck)
        if card.has_method("register_stuck_rose"):
            card.register_stuck_rose(stuck, dmg)   # persiste no estado do herói p/ Floração Mortal consumir depois

    if _targets.has(target_key):
        _apply_damage(_targets[target_key], dmg)

func _apply_damage(hero: Dictionary, dmg: int) -> void:
    if hero.has("hp_node") and hero.hp_node:
        var hp := hero.hp_node as Range
        hp.value = max(0, hp.value - dmg)
    var lbl := Label.new()
    lbl.text = "−%d" % dmg
    lbl.add_theme_font_size_override("font_size", 24)
    lbl.add_theme_color_override("font_color", Color(0.90, 0.75, 0.78))
    lbl.position = hero.pos - Vector2(18, 18)
    %DamagePopups.add_child(lbl)
    var pt := create_tween().set_parallel(true)
    pt.tween_property(lbl, "position:y", lbl.position.y - 40, 0.8)
    pt.tween_property(lbl, "modulate:a", 0.0, 0.8).set_delay(0.15)
    pt.chain().tween_callback(lbl.queue_free)

func _add_material() -> CanvasItemMaterial:
    var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD; return mat
```

---

## INTEGRAÇÃO COM O BOARD

```gdscript
func _on_darian_attack() -> void:
    var fx := preload("res://scenes/vfx/rosas_negras/RosasNegras.tscn").instantiate()
    add_child(fx)
    fx.play(
        $PlayerSide/ActiveHero.global_position + Vector2(0, -40),
        gather_opponent_targets_with_cards(),
        ["h3", "h2", "h1", "active"],
        3
    )
    fx.finished.connect(_on_ability_finished)

func gather_opponent_targets_with_cards() -> Dictionary:
    return {
        "active": { "pos": $OpponentSide/ActiveHero.global_position, "hp_node": $OpponentSide/ActiveHero/HpBar, "card_node": $OpponentSide/ActiveHero },
        "h1": { "pos": $OpponentSide/Hero1.global_position, "hp_node": $OpponentSide/Hero1/HpBar, "card_node": $OpponentSide/Hero1 },
        "h2": { "pos": $OpponentSide/Hero2.global_position, "hp_node": $OpponentSide/Hero2/HpBar, "card_node": $OpponentSide/Hero2 },
        "h3": { "pos": $OpponentSide/Hero3.global_position, "hp_node": $OpponentSide/Hero3/HpBar, "card_node": $OpponentSide/Hero3 },
    }
```

No script da carta de herói (`hero_card.gd`), adicione:
```gdscript
var stuck_roses: Array = []   # [{node: Sprite2D, dmg: int}]
func register_stuck_rose(node: Sprite2D, dmg: int) -> void:
    stuck_roses.append({"node": node, "dmg": dmg})
func consume_stuck_roses() -> Array:
    var out := stuck_roses.duplicate()
    stuck_roses.clear()
    return out
```
`Floração Mortal` vai chamar `hero_card.consume_stuck_roses()` em cada alvo para saber quantas rosas detonar e qual dano somar.

---

## CHECKLIST DE FIDELIDADE

- [ ] **0.0–0.9s** — carta de Darian pulsa carmesim; pétalas espiralando para a mão.
- [ ] **0.9–1.5s** — 3 rosas saem escalonadas, cada uma para um alvo sorteado (pode repetir).
- [ ] **Trajetória em arco** — nenhuma rosa em linha reta; ondulação senoidal visível no meio do voo.
- [ ] **Impacto** — burst de pétalas + popup de dano + HP cai.
- [ ] **Rosa cravada permanece** visível na carta do alvo **depois** que a cena de VFX termina e é liberada (reparentada para a carta, não para o RosasNegras).
- [ ] Estado persistido é consultável depois pela Floração Mortal (`consume_stuck_roses()`).

## REFERÊNCIA VISUAL
Leia `Rosas Negras.html` e use o slider de tempo para comparar timing e curvatura das trajetórias lado a lado. Pode começar.
