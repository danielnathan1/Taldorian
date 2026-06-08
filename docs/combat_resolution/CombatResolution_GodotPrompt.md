# Prompt para Claude Code — `CombatResolution.tscn` (Godot 4)

Cole o conteúdo abaixo no Claude Code. Ele assume que o projeto Godot do **Taldorian TCCG** já existe em `res://`, que `Card.tscn` / `CardView.tscn` e `Board.tscn` já foram criados conforme `Card_GodotPrompt.md`, e que esta cena será disparada na **fase COMBAT** (resolução de dano ao fim de cada rodada), quando os dois **heróis ativos** trocam golpes.

---

## CONTEXTO

Estou desenvolvendo **Taldorian TCCG** em Godot 4.x. No Board, cada lado (jogador / oponente) tem 1 herói ativo + 3 do banco + Arsenal + Deck + Cemitério, num tabuleiro **1280×720** (espelhado verticalmente). A referência visual completa do efeito em HTML/CSS/SVG está em **`Combat Resolution.html`** na raiz do projeto.

**Leia esse arquivo antes de começar.** Ele tem:
- Geometria exata em px dos slots (casa) e do duelo (centro).
- A timeline completa em segundos (`T.ENTRANCE_END`, `T.A1_*`, `T.A2_*`, `T.HOLD_END`).
- A função `attackFX(t, start, type, dmg, dir, attacker, target)` que define **as 3 variantes de ataque** (`lamina`, `machado`, `magia`) com suas sub-fases (windup → golpe → impacto → recuo).
- As paletas por tipo (`ATK_COLORS`) e as geometrias de partícula pré-semeadas (`AXE_SHARDS`, `AXE_DUST`, `MAGIC_SPARKS`).
- O popup de dano `-X`, a queda da barra de HP, o flash vermelho de impacto, o recuo e o screen shake.

## O QUE ESTE EFEITO É

Diferente de `BattleFury.tscn` (buff **persistente**), `CombatResolution.tscn` é uma **animação one-shot** com começo, meio e fim. Toca a resolução completa de uma rodada e emite `finished`. Sequência macro:

```
play(config)
  → [ENTRADA 0.0–1.15s]  ambas cartas dos heróis ativos saem dos slots,
                          sobem ao centro num arco crescendo de tamanho;
                          o resto do tabuleiro escurece (vinheta de foco)
  → [PAUSA 1.15–1.55s]   encaram-se no centro (idle bob suave)
  → [ATAQUE 1 1.55–3.35s] Aliado golpeia Inimigo (tipo escolhido)
  → [PAUSA 3.35–3.70s]
  → [ATAQUE 2 3.70–5.50s] Inimigo revida no Aliado (tipo escolhido)
  → [DESFECHO 5.50–6.20s] segura o resultado; cartas podem voltar aos slots
  → emit finished
```

**Quem chama gerencia o gameplay.** A cena NÃO calcula dano — recebe os valores já resolvidos pelo `combat_resolver.gd` e apenas os encena. Ela emite `hero_impacted(side, amount)` no exato frame do impacto de cada golpe, para o Board aplicar o dano no modelo (barra de HP, `hero_damaged`, checagem de morte) sincronizado com o VFX.

## OBJETIVO

Construir **`res://scenes/vfx/combat_resolution/CombatResolution.tscn`** — cena de VFX **autocontida e data-driven** que encena a troca de golpes entre os dois heróis ativos. Precisa:

1. Animar duas **cartas-duelistas** (cópias visuais dos heróis ativos) da casa ao centro e de volta.
2. Suportar **3 arquétipos de ataque** trocáveis por golpe: `LAMINA`, `MACHADO`, `MAGIA`.
3. Disparar **popup de dano**, **queda de HP**, **flash vermelho**, **recuo** e **screen shake** no alvo.
4. Ser **reutilizável**: qualquer par de heróis, qualquer combinação de tipos e qualquer dano.

---

## GEOMETRIA (espelha o HTML — não invente)

```gdscript
const STAGE := Vector2(1280, 720)

# Casa (slot do herói ativo) — ponto de partida/retorno
const H1_HOME := Vector2(720, 540)   # jogador (embaixo)
const H2_HOME := Vector2(720, 200)   # oponente (em cima)

# Duelo (centro) — Aliado à esquerda, Inimigo à direita
const H1_DUEL := Vector2(472, 360)
const H2_DUEL := Vector2(808, 360)

const HOME_SIZE := Vector2(90, 126)
const DUEL_SIZE := Vector2(164, 230)
```

> `dir`: o Aliado (esquerda) golpeia para a **direita** (`dir = +1`); o Inimigo (direita) golpeia para a **esquerda** (`dir = -1`). Recuo do alvo é sempre no mesmo sentido do golpe.

---

## TIMELINE (segundos — espelha `const T` no HTML)

```gdscript
const T_ENTRANCE_END := 1.15
const T_A1_START     := 1.55
const T_A1_END       := 3.35
const T_A2_START     := 3.70
const T_A2_END       := 5.50
const T_HOLD_END     := 6.20

const ATTACK_DUR := 1.80   # duração de cada janela de ataque
const POPUP_DUR  := 1.30   # vida do popup "-X"
```

### Sub-fases dentro de uma janela de ataque (`u` = 0..1 local)

| Tipo      | Windup        | Golpe / Viagem | Impacto (`u`) | Lunge (px) | Recuo alvo (px) | Notas                                              |
|-----------|---------------|----------------|---------------|------------|------------------|-----------------------------------------------------|
| `LAMINA`  | 0.00–0.30     | 0.30–0.50      | **0.50**      | 60         | 24               | Dois cortes em "X" desenhados cruzando o alvo       |
| `MACHADO` | 0.00–0.38     | 0.38–0.54      | **0.54**      | 88         | 46               | Lunge pesado, sobe e desce; shockwave + screen shake|
| `MAGIA`   | 0.00–0.34     | 0.34–0.62      | **0.60**      | ~0 (recuo de cast) | 30        | Orbe carrega na mão, projétil viaja, estoura no alvo|

`impact_abs = a_start + impact_local * ATTACK_DUR`. No `impact_abs`: emitir `hero_impacted`, iniciar queda de HP (ease cubic-out em 0.35s), spawnar popup, disparar flash/recuo/shake.

`hand = attacker.pos + Vector2(dir * attacker.size.x * 0.30, -attacker.size.y * 0.16)` — origem do corte/orbe.

---

## ÁRVORE DE CENAS

### `CombatResolution.tscn`
```
CombatResolution (Node2D)  [script: combat_resolution.gd]
├─ FocusLayer (CanvasLayer, layer = 40)
│  ├─ BoardDim   (ColorRect, full_rect, color=#05060b, modulate.a=0)   # escurece o tabuleiro
│  └─ Vignette   (TextureRect, full_rect, texture=duel_vignette.png, modulate.a=0)  # foco radial no centro
├─ DuelLayer (Node2D)                              # z_index = 5 — as cartas-duelistas
│  ├─ AllyCard  (Node2D)  → instancia DuelCard.tscn (cópia visual do herói ativo do jogador)
│  └─ EnemyCard (Node2D)  → instancia DuelCard.tscn (cópia visual do herói ativo do oponente)
├─ ChargeLayer (Node2D)                            # z_index = 4 — glow de carga ATRÁS das cartas
│  ├─ AllyGlow  (Sprite2D, texture=charge_glow.png, modulate.a=0, blend=ADD)
│  └─ EnemyGlow (Sprite2D, texture=charge_glow.png, modulate.a=0, blend=ADD)
├─ FxLayer (Node2D)                                # z_index = 8 — golpes/projéteis/impactos (acima das cartas)
│  ├─ SlashParent  (Node2D)
│  ├─ AxeParent    (Node2D)
│  └─ MagicParent  (Node2D)
├─ PopupLayer (Node2D)                             # z_index = 12 — popups "-X"
├─ FlashLayer (CanvasLayer, layer = 45)
│  └─ ScreenFlash (ColorRect, full_rect, modulate.a=0, material=screen_blend)
├─ BannerLayer (CanvasLayer, layer = 46)
│  ├─ TitleBanner (Control, anchors=center)
│  │  ├─ Sub   (Label, "FIM DA RODADA")
│  │  ├─ Name  (Label, "RESOLUÇÃO DE COMBATE")
│  │  └─ Rule  (TextureRect, 320×1 gradient dourado)
│  └─ Caption (Label, top-center, "Heróis ativos avançam")
└─ AudioPlayers
   ├─ Whoosh   (AudioStreamPlayer)   # entrada das cartas subindo
   ├─ HitLamina(AudioStreamPlayer)   # corte metálico
   ├─ HitMachado(AudioStreamPlayer)  # impacto grave + crunch
   ├─ HitMagia (AudioStreamPlayer)   # zumbido arcano + estouro
   └─ Resolve  (AudioStreamPlayer)   # acorde de desfecho
```

### `DuelCard.tscn` (cópia visual da carta no duelo)
```
DuelCard (Node2D)  [script: duel_card.gd]
├─ Frame    (NinePatchRect, texture=card_frame_<player|enemy>.png)   # 164×230
├─ Portrait (TextureRect ou Sprite2D)   # retrato/arquétipo do herói (sword/axe/staff)
├─ AtkBadge (Panel + Label)             # canto sup-esq, valor de ataque
├─ NameLabel(Label)                     # nome do herói (rodapé)
├─ HpBar    (ProgressBar ou TextureProgressBar)  # rodapé, cor por lado
└─ HitFlash (ColorRect/TextureRect, modulate.a=0, blend=SCREEN, cor vermelha radial)
```

Marque nós dinâmicos com **Unique Name in Owner** (`%`).

---

## ASSETS

Todos em `res://assets/vfx/combat_resolution/`. **Crie os PNGs faltantes** seguindo as descrições e as paletas por tipo abaixo.

### Paletas por arquétipo de ataque (espelha `ATK_COLORS`)

| Tipo      | core (núcleo)            | bright                  | mid                     | glow                    | dust/extra              |
|-----------|--------------------------|-------------------------|-------------------------|-------------------------|-------------------------|
| `LAMINA`  | `oklch(0.98 0.02 230)` `#eef3fb` | `oklch(0.90 0.10 225)` `#a9cdf0` | `oklch(0.80 0.13 228)` `#7fb4e6` | `oklch(0.86 0.12 225)` `#97c2ec` | `oklch(0.70 0.08 230)` |
| `MACHADO` | `oklch(0.98 0.10 75)` `#ffedb8`  | `oklch(0.90 0.20 55)` `#ffba6e`  | `oklch(0.74 0.22 38)` `#e8703a`  | `oklch(0.80 0.22 42)` `#f5904a`  | `oklch(0.45 0.05 60)` (poeira) |
| `MAGIA`   | `oklch(0.96 0.07 305)` `#f3e6fb` | `oklch(0.82 0.18 302)` `#c79af0` | `oklch(0.68 0.21 300)` `#a463e0` | `oklch(0.76 0.20 300)` `#b97fe6` | `oklch(0.62 0.16 300)` |

Cor do popup de dano: `oklch(0.66 0.24 25)` ≈ `#e8503a` (texto), sombra `oklch(0.18 0.10 25)`.
Cor do flash vermelho no alvo: radial `oklch(0.65 0.26 25)` em SCREEN.

### Texturas

| Arquivo                  | Tamanho   | Uso                                                                                       |
|--------------------------|-----------|-------------------------------------------------------------------------------------------|
| `duel_vignette.png`      | 1280×720  | Vinheta radial: transparente no centro (~42%) → escuro `#05060b` nas bordas. Foco no duelo.|
| `charge_glow.png`        | 256×256   | Glow radial branco (tingido por `glow` do tipo via `modulate`). Aparece atrás do atacante. |
| `card_frame_player.png`  | 168×234 (NinePatch 18) | Moldura da carta-duelista do jogador (borda azul `#3f9fd0`).                  |
| `card_frame_enemy.png`   | 168×234 (NinePatch 18) | Moldura da carta-duelista do oponente (borda vermelha `#d0563a`).            |
| `slash_streak.png`       | 256×64    | Streak de corte: linha curva com gradiente (transparente → core → transparente). Usado 2× cruzando.|
| `shockwave.png`          | 256×256   | Onda de choque circular (anel) — tingida por tipo via `modulate`.                          |
| `impact_shard.png`       | 16×80     | Estilhaço/raio radial do impacto de machado.                                               |
| `dust_puff.png`          | 48×48     | Poeira marrom macia (machado).                                                             |
| `magic_orb.png`          | 96×96     | Orbe arcano: núcleo branco + halo. Carga e projétil de magia.                              |
| `magic_spark.png`        | 24×24     | Faísca/estrela arcana do estouro de magia.                                                 |
| `portrait_sword.png`     | 256×360   | Retrato/arquétipo placeholder — espada + escudo (lâmina).                                  |
| `portrait_axe.png`       | 256×360   | Retrato placeholder — machado de uma lâmina + haste.                                       |
| `portrait_staff.png`     | 256×360   | Retrato placeholder — cajado + orbe (magia).                                               |

> Os retratos placeholder espelham os SVGs de `HeroPortrait` no HTML. Em produção, troque por `hero.get_texture()`.

### Import flags (cada PNG)
`filter = true`, `mipmaps = true`, `compress/mode = 0` (Lossless), `process/fix_alpha_border = true`.

---

## SCRIPT — `combat_resolution.gd`

```gdscript
class_name CombatResolution extends Node2D

# ── Tipos de ataque ────────────────────────────────────────────────────────
enum AtkType { LAMINA, MACHADO, MAGIA }

# ── Config de entrada ──────────────────────────────────────────────────────
# Quem chama monta isto a partir do combate já resolvido.
class CombatConfig:
    var ally_portrait: Texture2D
    var enemy_portrait: Texture2D
    var ally_name: String = "Aliado"
    var enemy_name: String = "Inimigo"
    var ally_atk: int = 0          # valor exibido no badge do Aliado
    var enemy_atk: int = 0
    var ally_max_hp: int = 20
    var enemy_max_hp: int = 20
    var ally_hp_before: int = 20   # HP do Aliado ANTES de levar o golpe do Inimigo
    var enemy_hp_before: int = 20
    var atk1_type: AtkType = AtkType.LAMINA   # golpe do Aliado -> Inimigo
    var atk2_type: AtkType = AtkType.MACHADO  # golpe do Inimigo -> Aliado
    var dmg1: int = 0              # dano que o Aliado causa no Inimigo
    var dmg2: int = 0             # dano que o Inimigo causa no Aliado

# ── Timeline (espelha Combat Resolution.html) ──────────────────────────────
const T_ENTRANCE_END := 1.15
const T_A1_START := 1.55
const T_A1_END   := 3.35
const T_A2_START := 3.70
const T_A2_END   := 5.50
const T_HOLD_END := 6.20
const ATTACK_DUR := 1.80
const POPUP_DUR  := 1.30

const H1_HOME := Vector2(720, 540)
const H2_HOME := Vector2(720, 200)
const H1_DUEL := Vector2(472, 360)
const H2_DUEL := Vector2(808, 360)
const HOME_SIZE := Vector2(90, 126)
const DUEL_SIZE := Vector2(164, 230)

# ── Sinais ─────────────────────────────────────────────────────────────────
signal hero_impacted(side: String, amount: int)   # "ally" / "enemy" — no frame do impacto
signal finished

# ── Estado ─────────────────────────────────────────────────────────────────
var _cfg: CombatConfig
var _impacted := { "ally": false, "enemy": false }
var _rng := RandomNumberGenerator.new()

# ── Public API ─────────────────────────────────────────────────────────────
func play(p_cfg: CombatConfig) -> void:
    _cfg = p_cfg
    _rng.seed = 1337
    _setup_cards()
    _run_timeline()

# ── Setup das cartas-duelistas ─────────────────────────────────────────────
func _setup_cards() -> void:
    %AllyCard.bind(_cfg.ally_portrait, _cfg.ally_name, _cfg.ally_atk,
        _cfg.ally_hp_before, _cfg.ally_max_hp, "player")
    %EnemyCard.bind(_cfg.enemy_portrait, _cfg.enemy_name, _cfg.enemy_atk,
        _cfg.enemy_hp_before, _cfg.enemy_max_hp, "enemy")

    # começam na CASA, tamanho de slot
    %AllyCard.position = H1_HOME;  %AllyCard.set_card_size(HOME_SIZE)
    %EnemyCard.position = H2_HOME; %EnemyCard.set_card_size(HOME_SIZE)

    %BoardDim.modulate.a = 0.0
    %Vignette.modulate.a = 0.0
    %ScreenFlash.modulate.a = 0.0
    %TitleBanner.modulate.a = 0.0
    %AllyGlow.modulate.a = 0.0
    %EnemyGlow.modulate.a = 0.0

# ── Timeline mestra ────────────────────────────────────────────────────────
func _run_timeline() -> void:
    # 1) ENTRADA — sobem ao centro crescendo, com arco; tabuleiro escurece
    var ent := create_tween().set_parallel(true)
    _tween_entrance(ent, %AllyCard, H1_HOME, H1_DUEL)
    _tween_entrance(ent, %EnemyCard, H2_HOME, H2_DUEL)
    ent.tween_property(%BoardDim, "modulate:a", 0.55, T_ENTRANCE_END)\
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    ent.tween_property(%Vignette, "modulate:a", 1.0, T_ENTRANCE_END)\
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    %Whoosh.play()

    # Banner de título (0.1–1.5s)
    _animate_title_banner()

    # 2) ATAQUE 1 — Aliado -> Inimigo
    _schedule(T_A1_START, func(): _set_caption("Aliado ataca"))
    _schedule(T_A1_START, func():
        _play_attack(_cfg.atk1_type, _cfg.dmg1, +1, %AllyCard, %EnemyCard,
            %AllyGlow, "enemy", _cfg.enemy_hp_before, _cfg.enemy_max_hp))

    # 3) ATAQUE 2 — Inimigo -> Aliado
    _schedule(T_A2_START, func(): _set_caption("Inimigo revida"))
    _schedule(T_A2_START, func():
        _play_attack(_cfg.atk2_type, _cfg.dmg2, -1, %EnemyCard, %AllyCard,
            %EnemyGlow, "ally", _cfg.ally_hp_before, _cfg.ally_max_hp))

    # 4) DESFECHO + fim
    _schedule(T_A2_END, func(): _set_caption("Combate resolvido"))
    _schedule(T_HOLD_END, func():
        %Resolve.play()
        emit_signal("finished")
        queue_free())

# entrada com arco "subindo" (espelha rise = -sin(eP*PI)*20 + easeOutBack na escala)
func _tween_entrance(tw: Tween, card: Node2D, home: Vector2, duel: Vector2) -> void:
    # posição via path custom (arco): usamos tween_method para reproduzir o arco
    tw.tween_method(func(p: float):
        var pos := home.lerp(duel, _ease_out_cubic(p))
        pos.y += -sin(p * PI) * 20.0
        card.position = pos
        var sz := HOME_SIZE.lerp(DUEL_SIZE, _ease_out_back(clamp(p * 1.05, 0.0, 1.0)))
        card.set_card_size(sz),
        0.0, 1.0, T_ENTRANCE_END)

# ── Um ataque ──────────────────────────────────────────────────────────────
func _play_attack(type: AtkType, dmg: int, dir: int, attacker: Node2D, target: Node2D,
                  glow: Sprite2D, target_side: String, target_hp_before: int, target_max: int) -> void:
    var impact_local := 0.50
    if type == AtkType.MACHADO: impact_local = 0.54
    elif type == AtkType.MAGIA: impact_local = 0.60

    var a_start := Time.get_ticks_msec()  # ilustrativo; use o relógio da própria tween

    # glow de carga do atacante (cresce no windup, some no recover)
    _tween_charge_glow(glow, attacker, type)

    # movimento do atacante (lunge) + retorno
    _tween_attacker_motion(attacker, type, dir)

    # FX do golpe (corte / projétil / shockwave) agendados em fração da janela
    match type:
        AtkType.LAMINA:  _schedule_local(0.42, func(): _spawn_slash(target, type, dir))
        AtkType.MACHADO: _schedule_local(impact_local, func(): _spawn_axe_impact(target, type))
        AtkType.MAGIA:
            _schedule_local(0.00, func(): _spawn_charge_orb(attacker, dir, type))
            _schedule_local(0.34, func(): _spawn_projectile(attacker, target, dir, type))
            _schedule_local(impact_local, func(): _spawn_magic_burst(target, type))

    # IMPACTO no alvo (no impact_local da janela)
    _schedule_local(impact_local, func():
        emit_signal("hero_impacted", target_side, dmg)           # gameplay aplica dano
        target.flash_hit()                                       # flash vermelho
        target.tween_hp(target_hp_before - dmg, target_max, 0.35) # barra cai
        _recoil(target, type, dir)                               # recuo do alvo
        _spawn_dmg_popup(target, dmg)                            # popup "-X"
        if type == AtkType.MACHADO: _screen_shake(11.0, 0.34)    # tremor pesado
        _impact_flash(type))

# ── Recuo + screen shake + flash + popup: ver Combat Resolution.html ────────
#   _recoil:       desloca o alvo `dir * (24|46|30)` e volta com ease cubic-out
#   _screen_shake: offset senoidal decaindo em ~0.34s aplicado à FxLayer/DuelLayer
#   _impact_flash: ScreenFlash com cor `core` do tipo; alfa pico ~0.14|0.22|0.20, fade 0.24–0.30s
#   _spawn_dmg_popup: Label "-{dmg}" sobe `target.size.y/2 + 16 + 50px`, fade in/out em POPUP_DUR

# (implementações completas: espelhe attackFX() e os componentes FX do HTML —
#  SlashFX, AxeFX, OrbFX, ProjFX, BurstFX — usando Sprite2D + tween + queue_free.)

# ── Helpers de agendamento ─────────────────────────────────────────────────
func _schedule(t_abs: float, cb: Callable) -> void:
    get_tree().create_timer(t_abs, false).timeout.connect(cb)

# agenda relativo ao início da janela de ataque corrente (passe a_start fora)
func _schedule_local(local_frac: float, cb: Callable) -> void:
    get_tree().create_timer(local_frac * ATTACK_DUR, false).timeout.connect(cb)

# ── Easings (espelham o HTML) ──────────────────────────────────────────────
func _ease_out_cubic(t: float) -> float: return 1.0 - pow(1.0 - t, 3.0)
func _ease_out_back(t: float) -> float:
    var c1 := 1.70158; var c3 := c1 + 1.0
    return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)
```

> **Nota sobre relógio:** o exemplo usa `create_timer` por clareza. Para fidelidade total ao HTML (que deriva tudo de um único `t`), prefira **uma `Tween` por ataque** com `tween_method(0→1, ATTACK_DUR)` que recebe `u` e reproduz `attackFX(u)` internamente (lunge, charge, recoil, flash) — assim o efeito é scrubável e determinístico igual ao HTML. Os `create_timer` ficam só para os spawns pontuais (slash/projétil/burst/popup).

### `duel_card.gd` (API mínima)
```gdscript
class_name DuelCard extends Node2D

func bind(portrait: Texture2D, hero_name: String, atk: int, hp: int, max_hp: int, side: String) -> void
func set_card_size(size: Vector2) -> void      # redimensiona Frame/Portrait/HpBar
func flash_hit() -> void                        # pisca HitFlash vermelho (fade 0.26s)
func tween_hp(to_hp: int, max_hp: int, dur: float) -> void   # anima a barra
```

---

## INTEGRAÇÃO COM O BOARD

Na fase **COMBAT**, depois que `combat_resolver.gd` calcula o dano dos dois lados:

```gdscript
var _combat_vfx: CombatResolution = null

func _on_combat_resolved(ctx: BattleContext) -> void:
    # Esconde as cartas reais dos slots ativos durante a encenação
    $PlayerSide/ActiveHero.visible = false
    $OpponentSide/ActiveHero.visible = false

    _combat_vfx = preload("res://scenes/vfx/combat_resolution/CombatResolution.tscn").instantiate()
    add_child(_combat_vfx)

    var cfg := CombatResolution.CombatConfig.new()
    cfg.ally_portrait  = ctx.ally_hero.get_texture()
    cfg.enemy_portrait = ctx.enemy_hero.get_texture()
    cfg.ally_name  = ctx.ally_hero.hero_name
    cfg.enemy_name = ctx.enemy_hero.hero_name
    cfg.ally_atk   = ctx.ally_attack
    cfg.enemy_atk  = ctx.enemy_attack
    cfg.ally_max_hp = ctx.ally_hero.max_hp
    cfg.enemy_max_hp = ctx.enemy_hero.max_hp
    cfg.ally_hp_before  = ctx.ally_hero.hp        # antes de aplicar o golpe do inimigo
    cfg.enemy_hp_before = ctx.enemy_hero.hp
    cfg.atk1_type = _weapon_to_type(ctx.ally_hero)   # mapear arquétipo do herói -> AtkType
    cfg.atk2_type = _weapon_to_type(ctx.enemy_hero)
    cfg.dmg1 = ctx.damage_to_enemy
    cfg.dmg2 = ctx.damage_to_ally

    # aplica o dano no MODELO no exato frame do impacto (sincronizado com o VFX)
    _combat_vfx.hero_impacted.connect(func(side: String, amount: int):
        var hero = ctx.enemy_hero if side == "enemy" else ctx.ally_hero
        GameBus.hero_damaged.emit(hero, amount))

    _combat_vfx.finished.connect(func():
        $PlayerSide/ActiveHero.visible = true
        $OpponentSide/ActiveHero.visible = true
        _combat_vfx = null
        _advance_after_combat())   # próxima rodada / fim de fase
```

### Mapeando herói → arquétipo de golpe
O `AtkType` é só estética. Sugestão: derive da classe/arma do herói (ex.: `BARBARIAN`→`MACHADO`, classes de gume→`LAMINA`, conjuradores→`MAGIA`), ou exponha um `@export var attack_archetype` em `HeroBase`.

---

## TEMA / TIPOGRAFIA

- **Banner Sub** — `Cinzel-Regular`, size 14, `#d9b88a`, uppercase, letter_spacing largo
- **Banner Name** — `CinzelDecorative-Black`, size 48, `#e8e0c0`, shadow (0,2) blur 22 cor `#bfa14a`
- **Caption** (topo) — `Cinzel-Regular`, size 13, `#c9a86a`, uppercase, letter_spacing 0.4em
- **Popup "-X"** — `CinzelDecorative-Black`, size 40, cor `#e8503a`, glow vermelho + sombra escura; sobe ~66px e some
- **AtkBadge** — `Cinzel-Bold`, size 14, `#f2d28a`, fundo `#2a160e`, borda da cor do lado
- **NameLabel** — `Cinzel-Bold`, size 13, cor do lado (azul/vermelho), uppercase, letter_spacing 0.16em

---

## SOM (opcional, não-bloqueante)

- **Whoosh** — sopro grave crescente quando as cartas sobem (0.0–1.0s).
- **HitLamina** — corte metálico nítido no impacto da lâmina.
- **HitMachado** — impacto grave + estilhaço/crunch; combina com o screen shake.
- **HitMagia** — zumbido arcano subindo no windup + estouro no impacto.
- **Resolve** — acorde curto de desfecho ao fim (5.5–6.2s).

---

## CHECKLIST DE FIDELIDADE AO HTML

Abra `Combat Resolution.html`, use o **scrub** e compare:

- [ ] **0.0s** — cartas nos slots (casa), tabuleiro visível, sem dim.
- [ ] **0.7s** — ambas subindo ao centro, maiores; banner "RESOLUÇÃO DE COMBATE"; tabuleiro escurecendo.
- [ ] **1.15s** — cartas chegam ao centro no tamanho de duelo; vinheta de foco ativa.
- [ ] **~2.4s** — Aliado em windup/golpe; glow de carga da cor do tipo; FX do golpe iniciando.
- [ ] **impacto 1 (~2.45–2.65s)** — FX de impacto no Inimigo, flash vermelho, recuo, HP cai, popup "-dmg1"; `hero_impacted("enemy", dmg1)` emitido.
- [ ] **machado** — verificar onda de choque + estilhaços + screen shake; **magia** — orbe carrega, projétil cruza o vão, estoura; **lâmina** — dois cortes em "X".
- [ ] **~4.6s** — Inimigo em carga/golpe (espelhado).
- [ ] **impacto 2 (~4.7–4.9s)** — idem no Aliado; `hero_impacted("ally", dmg2)`.
- [ ] **6.2s** — `finished` emitido; cartas reais reaparecem nos slots; Board avança.
- [ ] Trocar `atk1_type`/`atk2_type` e `dmg` muda os golpes/números corretamente (data-driven).

---

## ENTREGÁVEIS

- [ ] `res://scenes/vfx/combat_resolution/CombatResolution.tscn` + `combat_resolution.gd`
- [ ] `res://scenes/vfx/combat_resolution/DuelCard.tscn` + `duel_card.gd`
- [ ] Todos os PNGs em `res://assets/vfx/combat_resolution/` (conforme tabela)
- [ ] Hook na fase COMBAT do `board.gd`: instancia, monta `CombatConfig`, conecta `hero_impacted`/`finished`, esconde/reexibe as cartas ativas reais
- [ ] Cena de teste `CombatResolutionTest.tscn` com botões para escolher **tipo do Golpe 1 / Golpe 2** (Lâmina/Machado/Magia) e **dano** de cada, + botão **Tocar** — espelha os controles do HTML

---

## REFERÊNCIA VISUAL

**Leia `Combat Resolution.html` na raiz do projeto antes de começar.** Não invente timings, posições ou cores — espelhe. Os `const T_*`, `H*_HOME/DUEL`, `*_SIZE` e as paletas `ATK_COLORS` já batem com o HTML. Em caso de dúvida, abra o HTML, use o **scrub** e o seletor de tipo de ataque por herói para travar cada estado e comparar lado a lado.

Pode começar.
