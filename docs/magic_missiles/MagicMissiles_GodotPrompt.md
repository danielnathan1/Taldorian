# Prompt para Claude Code — `MagicMissiles.tscn` (Godot 4)

Cole o conteúdo abaixo no Claude Code. Ele assume que o projeto Godot do **Taldorian TCCG** já existe em `res://`, que `Card.tscn` e `Board.tscn` já foram criados conforme `Card_GodotPrompt.md`, e que o efeito será disparado quando o herói **Arquimaga** ativa sua habilidade.

---

## CONTEXTO

Estou desenvolvendo **Taldorian TCCG** em Godot 4.x. No Board, cada lado (jogador / oponente) tem 1 herói ativo + 3 do banco + Arsenal + Deck + Cemitério, dispostos em um tabuleiro 1280×720 (espelhado verticalmente). A referência visual completa do efeito em HTML/CSS/SVG está em **`Magic Missiles.html`** na raiz do projeto.

**Leia esse arquivo antes de começar.** Ele tem:
- Posicionamento exato em px de quem dispara (`CASTER_ORIGIN = {x: 720, y: 500}` — a ponta do cajado da Arquimaga) e dos alvos no lado do oponente (`OPP.active = {x:720,y:200}`, `OPP.h1 = {x:560,y:200}`, etc.).
- A timeline completa em segundos (`T.CHARGE_START`…`T.HOLD_END`).
- O cálculo de trajetória **curva** de cada míssil: Bézier **cúbica** com dois pontos de controle empurrados para o mesmo lado (ver `paths.map(...)` + funções `cbez()`, `cbezTangent()`, `missilePos()`). **Esse é o coração do efeito — a trajetória NÃO é reta.**

## OBJETIVO

Construir **`res://scenes/vfx/magic_missiles/MagicMissiles.tscn`** — uma cena de VFX **autocontida**, instanciada sobre o `Board.tscn` quando a Arquimaga do jogador ativa **Mísseis Mágicos**. Sequência:

1. **Carga (0.0–1.0s)** — a carta da Arquimaga pulsa em violeta; um glow cresce ao redor dela e orbes arcanos espiralam para dentro, concentrando-se na ponta do cajado.
2. **Banner (0.15–2.5s)** — texto "MÍSSEIS MÁGICOS" surge no centro com subtítulo; o status muda de "Concentrando energia arcana" → "Os feixes perseguem o alvo".
3. **Marcação do alvo (0.55–3.4s)** — moldura violeta com cantos em L + haze radial sobre o herói ativo do oponente.
4. **Disparo (1.0–1.55s)** — 5 feixes saem da ponta do cajado em sequência escalonada, cada um com ~0.95s de voo.
5. **Voo em curva** — cada feixe percorre uma **Bézier cúbica em arco** (controles empurrados para um dos lados, alternando), com uma **ondulação senoidal** que serpenteia no meio do voo e desaparece perto do alvo. Rastro luminoso seguindo a curva real + cabeça brilhante tipo cometa + motes de faísca.
6. **Impactos** — cada feixe pousa com burst arcano expansivo + flash central + 8 faíscas radiais; popup de dano sobe acima do herói atingido; HP cai.
7. **Hold (até 3.9s)** — banner some; alvo desbota; efeito conclui e emite sinal `finished`.

A cena precisa ser **data-driven** (`play(source_pos, targets)`) e **reutilizável** — outras habilidades de "projétil mágico perseguidor" podem reusá-la trocando textura/cor/número de feixes.

---

## ÁRVORE DE CENAS

### `MagicMissiles.tscn`
```
MagicMissiles (Node2D)  [script: magic_missiles.gd]
├─ Background (CanvasLayer, layer = 50)
│  └─ ScreenFlash (ColorRect, anchors=full_rect, color=#f3ddff, modulate.a=0)
├─ Aura (Node2D)
│  ├─ TargetAura (Sprite2D, texture=target_aura.png)
│  ├─ CornerTL   (Sprite2D, texture=target_corner.png, rotation=0)
│  ├─ CornerTR   (Sprite2D, texture=target_corner.png, rotation=PI/2)
│  ├─ CornerBR   (Sprite2D, texture=target_corner.png, rotation=PI)
│  └─ CornerBL   (Sprite2D, texture=target_corner.png, rotation=-PI/2)
├─ ChargeGlow (Sprite2D, texture=charge_glow.png, modulate.a=0,
│              material=CanvasItemMaterial(blend_mode=ADD))
├─ ChargeOrbs (Node2D)                # orbes que espiralam para dentro na carga
├─ MissilesLayer (Node2D)            # feixes em voo (cabeça + rastro)
├─ ImpactsLayer (Node2D)             # bursts + flashes + faíscas
├─ DamagePopups (Node2D)             # labels "-N" subindo
├─ Banner (Control, anchors=center)
│  ├─ Subtitle    (Label, "Magia Arcana")
│  ├─ AbilityName (Label, "MÍSSEIS MÁGICOS")
│  ├─ Rule        (ColorRect, 300x1, modulate=#bd7ef0)
│  └─ Status      (Label, "Concentrando energia arcana")
├─ Timer (Timer, one_shot=true)
└─ AudioPlayers
   ├─ Charge   (AudioStreamPlayer)
   ├─ Release  (AudioStreamPlayer)
   ├─ Whoosh   (AudioStreamPlayer)   # zumbido por feixe (opcional)
   └─ Impact   (AudioStreamPlayer)
```

Marque cada nó dinâmico com **Unique Name in Owner** (`%`).

---

## ASSETS — ENTREGUES JUNTO COM ESTE PROMPT

Todos em `res://assets/vfx/magic_missiles/` (já existem na pasta `godot/vfx/magic_missiles/` do projeto — basta copiar):

| Arquivo                  | Tamanho   | Uso                                                                |
|--------------------------|-----------|--------------------------------------------------------------------|
| `missile_head.png`       | 256×256   | Cabeça brilhante do feixe (orbe radial violeta-branco, blend ADD)  |
| `missile_trail.png`      | 256×48    | Rastro afilado, brilhante na ponta direita (use em `Line2D`/`Trail`) |
| `charge_orb.png`         | 96×96     | Mote arcano que espirala para dentro durante a carga               |
| `charge_glow.png`        | 512×512   | Glow violeta em torno da carta da Arquimaga durante a carga        |
| `impact_burst.png`       | 256×256   | Anel arcano da onda de choque (escalar de ~0.1 → 1.4)              |
| `impact_flash.png`       | 256×256   | Flash central brilhante no momento do impacto                      |
| `spark_particle.png`     | 64×64     | Faísca (textura do `CPUParticles2D`)                               |
| `target_aura.png`        | 256×320   | Haze violeta radial sobre o herói-alvo                             |
| `target_corner.png`      | 96×96     | Canto em "L" para marcar o alvo (rotacionar para 4 cantos)         |
| `archmage_portrait.png`  | 512×512   | Retrato placeholder da Arquimaga (use no Card)                     |

> Todas as texturas estão prontas para uso direto e já são **pré-multiplicadas para blend aditivo** (fundo transparente, núcleo claro). **Não recrie** — copie os PNGs para `res://assets/vfx/magic_missiles/` e configure os import flags abaixo.

### Import flags (no `.import` de cada PNG)
- `filter = true`
- `mipmaps = true`
- `compress/mode = 0` (Lossless) — texturas pequenas, qualidade prioritária
- `process/fix_alpha_border = true` — evita borda escura ao escalar

---

## SCRIPT — `magic_missiles.gd`

```gdscript
class_name MagicMissiles extends Node2D

# ── Configuração (pode ser sobrescrita por outras habilidades de "homing bolt") ──
@export var head_texture: Texture2D   = preload("res://assets/vfx/magic_missiles/missile_head.png")
@export var trail_texture: Texture2D  = preload("res://assets/vfx/magic_missiles/missile_trail.png")
@export var flight_time: float        = 0.95
@export var ability_name: String      = "MÍSSEIS MÁGICOS"
@export var ability_subtitle: String  = "Magia Arcana"
@export var bolt_color: Color         = Color(0.78, 0.45, 1.0)   # violeta arcano

# Cada míssil: alvo (índice em _targets), lado da curva, força da curva, nº de ondas, dano.
# Espelha o array MISSILES do HTML.
const MISSILES := [
    {"target": "active", "side":  1.0, "curve": 200.0, "waves": 2.0, "dmg": 4},
    {"target": "active", "side": -1.0, "curve": 230.0, "waves": 2.4, "dmg": 4},
    {"target": "h1",     "side": -1.0, "curve": 180.0, "waves": 1.8, "dmg": 3},
    {"target": "h2",     "side":  1.0, "curve": 250.0, "waves": 2.2, "dmg": 3},
    {"target": "active", "side":  1.0, "curve": 150.0, "waves": 2.6, "dmg": 4},
]

# ── Timeline (em segundos) — idêntica ao objeto T do HTML ────────────────────
const T_CHARGE_START := 0.0
const T_CHARGE_END   := 1.0
const T_BANNER_IN    := 0.15
const T_BANNER_OUT   := 2.5
const T_TARGET_IN    := 0.55
const T_TARGET_OUT   := 3.4
const T_LAUNCH_FIRST := 1.0
const T_LAUNCH_LAST  := 1.55
const T_HOLD_END     := 3.9

signal finished

# ── Estado ───────────────────────────────────────────────────────────────────
var _source: Vector2
var _targets: Dictionary = {}          # { "active": {pos, hp_node}, "h1": {...}, ... }
var _rng := RandomNumberGenerator.new()

# Public API — chame isto a partir do Board quando a habilidade for ativada.
# targets: Dictionary mapeando chave -> { "pos": Vector2, "hp_node": Range }
func play(source_pos: Vector2, targets: Dictionary) -> void:
    _source = source_pos
    _targets = targets
    _rng.seed = 7
    _run()

# ── Sequência principal ───────────────────────────────────────────────────────
func _run() -> void:
    _setup_initial_state()
    var t := create_tween()
    t.set_parallel(true)

    _animate_charge(t)        # glow + orbes espiralando
    _animate_banner(t)
    _animate_target_zone(t)

    # Flash de tela curtinho na liberação
    t.tween_property(%ScreenFlash, "modulate:a", 0.32, 0.05).set_delay(T_CHARGE_END - 0.05)
    t.tween_property(%ScreenFlash, "modulate:a", 0.0, 0.3).set_delay(T_CHARGE_END)

    # Dispara cada míssil em sequência escalonada
    for i in MISSILES.size():
        var launch_t: float = T_LAUNCH_FIRST + (T_LAUNCH_LAST - T_LAUNCH_FIRST) * float(i) / float(MISSILES.size() - 1)
        get_tree().create_timer(launch_t, false).timeout.connect(_spawn_missile.bind(i))

    # Fim
    get_tree().create_timer(T_HOLD_END, false).timeout.connect(func():
        emit_signal("finished")
        queue_free()
    )

# ── Setup ─────────────────────────────────────────────────────────────────────
func _setup_initial_state() -> void:
    %ChargeGlow.position = _source
    %ChargeGlow.modulate.a = 0.0
    %ChargeGlow.scale = Vector2(0.2, 0.2)

    var c: Vector2 = _targets["active"].pos
    %TargetAura.position = c
    %TargetAura.modulate.a = 0.0
    %CornerTL.position = c + Vector2(-52, -70)
    %CornerTR.position = c + Vector2( 52, -70)
    %CornerBR.position = c + Vector2( 52,  70)
    %CornerBL.position = c + Vector2(-52,  70)
    for n in ["CornerTL","CornerTR","CornerBR","CornerBL","TargetAura"]:
        get_node("%"+n).modulate.a = 0.0

    %Banner.modulate.a = 0.0
    %AbilityName.text = ability_name
    %Subtitle.text = ability_subtitle
    %Status.text = "Concentrando energia arcana"

# ── Tween: carga (glow + orbes espiralando para dentro) ───────────────────────
func _animate_charge(t: Tween) -> void:
    t.tween_property(%ChargeGlow, "modulate:a", 0.85, T_CHARGE_END)\
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    t.tween_property(%ChargeGlow, "scale", Vector2(1.4, 1.4), T_CHARGE_END)\
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    t.tween_property(%ChargeGlow, "modulate:a", 0.0, 0.4).set_delay(T_CHARGE_END)

    # 8 orbes giram e encolhem o raio até colapsarem na ponta do cajado
    for i in 8:
        var orb := Sprite2D.new()
        orb.texture = preload("res://assets/vfx/magic_missiles/charge_orb.png")
        orb.material = _add_material()
        orb.z_index = 12
        %ChargeOrbs.add_child(orb)
        var phase: float = float(i) * TAU / 8.0
        var ot := create_tween()
        ot.tween_method(func(p: float):
                var ang := p * 3.0 * TAU + phase
                var rad := (1.0 - p) * 42.0 + 8.0
                orb.position = _source + Vector2(cos(ang), sin(ang)) * rad
                orb.modulate.a = p,
            0.0, 1.0, T_CHARGE_END)
        ot.tween_callback(orb.queue_free)

# ── Tween: banner ─────────────────────────────────────────────────────────────
func _animate_banner(t: Tween) -> void:
    t.tween_property(%Banner, "modulate:a", 1.0, 0.35).set_delay(T_BANNER_IN)
    get_tree().create_timer(T_CHARGE_END, false).timeout.connect(func():
        %Status.text = "Os feixes perseguem o alvo"
    )
    t.tween_property(%Banner, "modulate:a", 0.0, 0.4).set_delay(T_BANNER_OUT - 0.4)

# ── Tween: zona alvo ──────────────────────────────────────────────────────────
func _animate_target_zone(t: Tween) -> void:
    for n in ["TargetAura","CornerTL","CornerTR","CornerBR","CornerBL"]:
        t.tween_property(get_node("%"+n), "modulate:a", 1.0, 0.4).set_delay(T_TARGET_IN)
    for n in ["TargetAura","CornerTL","CornerTR","CornerBR","CornerBL"]:
        t.tween_property(get_node("%"+n), "modulate:a", 0.0, 0.5).set_delay(T_TARGET_OUT - 0.5)

# ═══════════════════════════════════════════════════════════════════════════════
#  TRAJETÓRIA CURVA — o coração do efeito. Espelha cbez/missilePos do HTML.
# ═══════════════════════════════════════════════════════════════════════════════
func _build_path(m: Dictionary) -> Dictionary:
    var p0: Vector2 = _source
    var p3: Vector2 = _targets[m.target].pos + Vector2(0, 6)
    var dir: Vector2 = (p3 - p0).normalized()
    var nrm := Vector2(-dir.y, dir.x)                 # perpendicular
    var length: float = p0.distance_to(p3)
    # Os DOIS controles empurrados para o mesmo lado => um arco em "C" bem visível;
    # o segundo volta um pouco para o centro para o feixe cravar reto no alvo.
    var c1: Vector2 = p0 + dir * length * 0.30 + nrm * m.curve * m.side
    var c2: Vector2 = p0 + dir * length * 0.72 + nrm * (m.curve * 0.55) * m.side
    return {"p0": p0, "c1": c1, "c2": c2, "p3": p3, "waves": m.waves}

func _cbez(p: Dictionary, t: float) -> Vector2:
    var u := 1.0 - t
    return u*u*u*p.p0 + 3.0*u*u*t*p.c1 + 3.0*u*t*t*p.c2 + t*t*t*p.p3

func _cbez_tangent(p: Dictionary, t: float) -> Vector2:
    var u := 1.0 - t
    return 3.0*u*u*(p.c1-p.p0) + 6.0*u*t*(p.c2-p.c1) + 3.0*t*t*(p.p3-p.c2)

# Posição final = bezier + ondulação senoidal que some perto dos extremos
func _missile_pos(p: Dictionary, u: float, idx: int) -> Vector2:
    var base := _cbez(p, u)
    var tan := _cbez_tangent(p, u).normalized()
    var wn := Vector2(-tan.y, tan.x)
    var fade := sin(u * PI)                            # 0 nos extremos, 1 no meio
    var wob := sin(u * PI * p.waves + idx) * 16.0 * fade * (1.0 - u * 0.4)
    return base + wn * wob

# ── Spawn de um míssil em voo ─────────────────────────────────────────────────
func _spawn_missile(idx: int) -> void:
    var m: Dictionary = MISSILES[idx]
    var path := _build_path(m)

    # Cabeça brilhante
    var head := Sprite2D.new()
    head.texture = head_texture
    head.material = _add_material()
    head.modulate = bolt_color.lightened(0.3)
    head.scale = Vector2(0.18, 0.18)
    head.z_index = 14
    %MissilesLayer.add_child(head)

    # Rastro: Line2D que sampleia a curva REAL para trás (não uma reta)
    var trail := Line2D.new()
    trail.width = 7.0
    trail.default_color = Color(bolt_color.r, bolt_color.g, bolt_color.b, 0.35)
    trail.joint_mode = Line2D.LINE_JOINT_ROUND
    trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
    trail.end_cap_mode = Line2D.LINE_CAP_ROUND
    trail.material = _add_material()
    # Gradiente: brilhante na cabeça, transparente na cauda
    var grad := Gradient.new()
    grad.set_color(0, Color(bolt_color.r, bolt_color.g, bolt_color.b, 0.0))
    grad.set_color(1, Color(0.92, 0.78, 1.0, 0.8))
    trail.gradient = grad
    trail.z_index = 13
    %MissilesLayer.add_child(trail)

    const TRAIL_STEPS := 14
    const TRAIL_SPAN := 0.16

    var fly := create_tween()
    fly.tween_method(func(local: float):
            var u := _ease_in_out_cubic(local)        # acelera e depois "homing"
            head.position = _missile_pos(path, u, idx)
            head.rotation = _cbez_tangent(path, u).angle()
            # reconstrói o rastro amostrando a curva para trás
            var pts := PackedVector2Array()
            for i in range(TRAIL_STEPS, -1, -1):
                var uu: float = u - (float(i)/TRAIL_STEPS) * TRAIL_SPAN
                if uu < 0.0: continue
                pts.append(_missile_pos(path, uu, idx))
            trail.points = pts,
        0.0, 1.0, flight_time)

    fly.tween_callback(func():
        head.queue_free()
        # rastro encolhe e some
        var tt := create_tween()
        tt.tween_property(trail, "modulate:a", 0.0, 0.18)
        tt.tween_callback(trail.queue_free)
        _on_missile_impact(path.p3, m.target, m.dmg)
    )

func _ease_in_out_cubic(t: float) -> float:
    return 4.0*t*t*t if t < 0.5 else 1.0 - pow(-2.0*t + 2.0, 3.0) / 2.0

# ── Impacto ───────────────────────────────────────────────────────────────────
func _on_missile_impact(pos: Vector2, target_key: String, dmg: int) -> void:
    # Burst expansivo
    var burst := Sprite2D.new()
    burst.texture = preload("res://assets/vfx/magic_missiles/impact_burst.png")
    burst.material = _add_material()
    burst.position = pos
    burst.scale = Vector2(0.1, 0.1)
    burst.z_index = 15
    %ImpactsLayer.add_child(burst)
    var bt := create_tween().set_parallel(true)
    bt.tween_property(burst, "scale", Vector2(1.4, 1.4), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    bt.tween_property(burst, "modulate:a", 0.0, 0.55)
    bt.chain().tween_callback(burst.queue_free)

    # Flash central
    var flash := Sprite2D.new()
    flash.texture = preload("res://assets/vfx/magic_missiles/impact_flash.png")
    flash.material = _add_material()
    flash.position = pos
    flash.scale = Vector2(0.35, 0.35)
    flash.z_index = 16
    %ImpactsLayer.add_child(flash)
    var ft := create_tween().set_parallel(true)
    ft.tween_property(flash, "scale", Vector2(0.7, 0.7), 0.22)
    ft.tween_property(flash, "modulate:a", 0.0, 0.22)
    ft.chain().tween_callback(flash.queue_free)

    # Faíscas radiais
    var spark := CPUParticles2D.new()
    spark.position = pos
    spark.texture = preload("res://assets/vfx/magic_missiles/spark_particle.png")
    spark.material = _add_material()
    spark.amount = 8
    spark.lifetime = 0.5
    spark.one_shot = true
    spark.explosiveness = 1.0
    spark.spread = 180.0
    spark.initial_velocity_min = 60
    spark.initial_velocity_max = 140
    spark.scale_amount_min = 0.3
    spark.scale_amount_max = 0.6
    spark.color = Color(0.9, 0.75, 1.0, 0.8)
    spark.emitting = true
    %ImpactsLayer.add_child(spark)
    get_tree().create_timer(0.9, false).timeout.connect(spark.queue_free)

    # Dano
    if _targets.has(target_key):
        _apply_damage(_targets[target_key], dmg, pos)

func _apply_damage(hero: Dictionary, dmg: int, _pos: Vector2) -> void:
    if hero.has("hp_node") and hero.hp_node:
        var hp := hero.hp_node as Range
        hp.value = max(0, hp.value - dmg)

    var lbl := Label.new()
    lbl.text = "−%d" % dmg
    lbl.add_theme_font_size_override("font_size", 26)
    lbl.add_theme_color_override("font_color", Color(0.93, 0.78, 1.0))
    lbl.add_theme_color_override("font_shadow_color", Color(0,0,0,0.6))
    lbl.add_theme_constant_override("shadow_offset_y", 2)
    lbl.position = hero.pos - Vector2(18, 18)
    %DamagePopups.add_child(lbl)
    var pt := create_tween().set_parallel(true)
    pt.tween_property(lbl, "position:y", lbl.position.y - 42, 0.85)
    pt.tween_property(lbl, "modulate:a", 0.0, 0.85).set_delay(0.15)
    pt.chain().tween_callback(lbl.queue_free)

# ── Helper: material com blend aditivo ────────────────────────────────────────
func _add_material() -> CanvasItemMaterial:
    var mat := CanvasItemMaterial.new()
    mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    return mat
```

---

## INTEGRAÇÃO COM O BOARD

No `board.gd`, quando o jogador ativa a habilidade da Arquimaga:

```gdscript
func _on_archmage_ability_activated() -> void:
    var fx := preload("res://scenes/vfx/magic_missiles/MagicMissiles.tscn").instantiate()
    add_child(fx)
    fx.play(
        archmage_staff_tip_position(),            # Vector2 — ponta do cajado
        gather_opponent_targets_for_vfx()         # Dictionary{ chave -> {pos, hp_node} }
    )
    fx.finished.connect(_on_ability_finished)
```

Helpers:

```gdscript
func archmage_staff_tip_position() -> Vector2:
    # ~ CASTER_ORIGIN no HTML (acima/à frente da carta da Arquimaga)
    return $PlayerSide/ActiveHero.global_position + Vector2(0, -40)

func gather_opponent_targets_for_vfx() -> Dictionary:
    return {
        "active": { "pos": $OpponentSide/ActiveHero.global_position, "hp_node": $OpponentSide/ActiveHero/HpBar },
        "h1":     { "pos": $OpponentSide/Hero1.global_position,      "hp_node": $OpponentSide/Hero1/HpBar },
        "h2":     { "pos": $OpponentSide/Hero2.global_position,      "hp_node": $OpponentSide/Hero2/HpBar },
    }
```

> **Nota:** o efeito mira majoritariamente o herói ativo (3 dos 5 feixes), com 2 feixes "espirrando" para Herói 1 e Herói 2 — igual ao HTML. Se quiser concentrar tudo no alvo único, basta apontar todos os `"target"` de `MISSILES` para `"active"`.

---

## TEMA / TIPOGRAFIA DO BANNER

- **Subtitle** — `Cinzel-Regular.ttf`, size **14**, color `#bd7ef0` (violeta), letter_spacing wide, uppercase
- **AbilityName** — `CinzelDecorative-Bold.ttf`, size **48**, color `#eddafa`, shadow offset (0,2) blur 18 color `#a85ce0`
- **Rule** — ColorRect 300×1, gradient horizontal: transparente → `#bd7ef0` → transparente
- **Status** — `Cinzel-Regular.ttf`, size **12**, color `#bd7ef0`, opacity 0.85, uppercase, letter_spacing very_wide

Cor do dano: `#eec8ff` com sombra preta.

---

## SOM (OPCIONAL — não-bloqueante)

- **Charge** — hum arcano crescente; toca no início de `_run()` (0.0s), ~1.0s.
- **Release** — pop mágico em `T_CHARGE_END` (1.0s).
- **Whoosh** — zumbido por feixe, dispare no `_spawn_missile()` com `pitch_scale` aleatório 0.9–1.2.
- **Impact** — toque no `_on_missile_impact()` com volume reduzido (-10dB) por causa do empilhamento.

---

## CHECKLIST DE FIDELIDADE AO HTML

Abra `Magic Missiles.html` e use o slider de tempo (controle no rodapé) para comparar momento a momento:

- [ ] **0.0s** — cena ociosa, carta da Arquimaga normal
- [ ] **0.5s** — glow violeta cresce; orbes espiralando para dentro; banner começou a aparecer
- [ ] **1.0s** — glow no pico; flash branco breve; primeiro feixe sai do cajado; alvo marcado
- [ ] **1.35s** — vários feixes no ar simultaneamente, cada um em **arco curvo** (não reto) com serpenteio no meio
- [ ] **1.75s** — feixes curvando de volta para "homing" nos alvos; primeiros impactos
- [ ] **2.2s** — bursts arcanos; popups de dano subindo; HP dos heróis caindo
- [ ] **3.0s** — todos os feixes pousaram; banner sumindo; marcação desbotando
- [ ] **3.9s** — efeito limpa, signal `finished` emitido

**Ponto crítico:** a 1.35s, confira que NENHUM feixe está em linha reta. Cada um deve descrever um arco lateral claro (controles bezier para o mesmo lado) + uma ondulação senoidal. Se algum estiver reto, verifique `_build_path` (sinal de `side` e valor de `curve`) e `_missile_pos` (termo `wob`).

---

## ENTREGÁVEIS

- [ ] `res://scenes/vfx/magic_missiles/MagicMissiles.tscn` + `magic_missiles.gd`
- [ ] Todos os PNGs em `res://assets/vfx/magic_missiles/` (copiados da pasta `godot/vfx/magic_missiles/`)
- [ ] Hook no `board.gd` que instancia a cena quando a habilidade é ativada
- [ ] Cena de teste `res://scenes/vfx/magic_missiles/MagicMissilesTest.tscn` com um botão "Conjurar" que chama `fx.play(...)` com posições fixas (idênticas às do HTML) para QA isolado

---

## REFERÊNCIA VISUAL

**Leia `Magic Missiles.html` na raiz do projeto antes de começar.** Não invente timings ou trajetórias — espelhe. Os valores em `const T_*` e o array `MISSILES` no script já batem exatamente com `T.*` e `MISSILES` no HTML. A trajetória curva (Bézier cúbica + ondulação senoidal) é a assinatura do efeito; em caso de divergência visual, compare lado a lado abrindo o HTML pausado no tempo correspondente.

Pode começar.
