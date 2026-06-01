# Prompt para Claude Code — `PauseMenu.tscn` (Godot 4)

Cole o conteúdo abaixo no Claude Code. Ele assume que o projeto Godot do **Taldorian TCCG** já existe em `res://`, que `Board.tscn` está rodando como cena principal de partida, e que `VictoryDefeat.tscn` (ou equivalente) **já foi criado** e exibe a tela de fim de jogo via um sinal/método público.

---

## CONTEXTO

Estou desenvolvendo **Taldorian TCCG** em Godot 4.x. Durante a partida (`Board.tscn`), quando o jogador pressiona **ESC**, deve abrir um **menu de pausa** sobreposto ao tabuleiro com três opções:

1. **Voltar ao Jogo** — fecha o overlay e retoma a partida.
2. **Configurações** — abre um subpainel com sliders de **Música** e **Efeitos** (0–100%).
3. **Desistir da Partida** — abre um **modal de confirmação** ("perderá pontos"); ao confirmar, dispara a tela de **Derrota** para o jogador que desistiu e **Vitória** para o oponente.

A referência visual completa em HTML/CSS está em **`Pause Menu.html`** na raiz do projeto. **Leia esse arquivo antes de começar** — ele tem:

- O layout do menu principal, subview de Configurações e modal de Desistir.
- Cores, fontes, espaçamentos, animações e estados de hover exatos.
- Comportamento de teclado (ESC abre/fecha; ESC no modal = cancelar).

## OBJETIVO

Construa **`res://scenes/ui/pausemenu/PauseMenu.tscn`** — uma cena que:

1. É **um overlay** (CanvasLayer no topo de tudo) que escurece o tabuleiro com blur radial.
2. Mostra três botões: **Voltar ao Jogo**, **Configurações**, **Desistir da Partida**.
3. Tem **subview interna** de Configurações com 2 sliders (Música, Efeitos), botão `← Voltar`.
4. Tem **modal de confirmação** vermelho para Desistir.
5. É **autocontida** — exporta sinais públicos para o `Board` reagir, mas não conhece a estrutura interna do jogo.
6. **Persiste** os volumes em `user://settings.cfg` e aplica imediatamente nos buses de áudio (`Music` e `SFX`).

A cena nasce em **1280×800** e adapta-se ao viewport via escala uniforme.

---

## ÁRVORE DE CENAS

### `PauseMenu.tscn`
```
PauseMenu (CanvasLayer, layer=10)  [script: pause_menu.gd]
└─ Root (Control, full_rect, mouse_filter=STOP)        # bloqueia cliques no tabuleiro
   ├─ Backdrop (ColorRect, full_rect)                  # fundo escuro radial
   │  └─ BlurOverlay (TextureRect com ShaderMaterial)  # blur 8px do conteúdo abaixo
   │
   ├─ ViewStack (Control, full_rect, mouse_filter=PASS)
   │  ├─ MainView (CenterContainer, full_rect)         [PauseCard]
   │  │  └─ PauseCard (VBoxContainer, custom_minimum_size.x=440, separation=0)
   │  │     ├─ Crest (TextureRect, custom_minimum_size=Vector2(76, 76))
   │  │     │   stretch_mode=KEEP_ASPECT_CENTERED
   │  │     │   texture = res://assets/ui/pausemenu/pause_crest.svg
   │  │     └─ Panel (PanelContainer, style=pause_panel)
   │  │        └─ Margin (MarginContainer, padding=38/42/35/42)
   │  │           └─ VBox (VBoxContainer, separation=0)
   │  │              ├─ Eyebrow  (Label, "PAUSA", style=eyebrow)
   │  │              ├─ Title    (Label, "Em Repouso", style=title)
   │  │              ├─ Divider  (HBoxContainer, alignment=CENTER)
   │  │              │   ├─ LineL (ColorRect 40×1, gradient transparent→gold_dim)
   │  │              │   ├─ Diamond (ColorRect 6×6, rotated 45°, glow)
   │  │              │   └─ LineR (ColorRect 40×1, gradient gold_dim→transparent)
   │  │              ├─ Spacer1 (Control, custom_minimum_size.y=24)
   │  │              ├─ MenuList (VBoxContainer, separation=11)
   │  │              │   ├─ BtnResume   (MenuButton "Voltar ao Jogo", icon=play,   variation=primary)
   │  │              │   ├─ BtnSettings (MenuButton "Configurações",  icon=gear,   variation=default)
   │  │              │   └─ BtnForfeit  (MenuButton "Desistir da Partida", icon=flag, variation=danger)
   │  │              └─ Footer (Label, "Pressione [kbd]ESC[/kbd] para retomar a batalha",
   │  │                         BBCode via RichTextLabel, style=footer)
   │  │
   │  ├─ SettingsView (CenterContainer, full_rect, visible=false)
   │  │  └─ SettingsCard (estrutura idêntica ao PauseCard, mas com:)
   │  │     ├─ Crest
   │  │     ├─ Panel
   │  │        ├─ BackBtn (Button "← Voltar", flat, anchor top_left, padding 14/14)
   │  │        ├─ Eyebrow  ("CONFIGURAÇÕES")
   │  │        ├─ Title    ("Áudio", font-size 30pt)
   │  │        ├─ Divider
   │  │        ├─ Spacer
   │  │        ├─ MusicRow (VolumeRow.tscn, label="Música",  bus_idx=Music)
   │  │        ├─ Spacer (custom_minimum_size.y=22)
   │  │        ├─ FxRow    (VolumeRow.tscn, label="Efeitos", bus_idx=SFX)
   │  │        └─ Footer   ("Use as setas [kbd]←[/kbd][kbd]→[/kbd] para ajustes finos")
   │  │
   │  └─ ConfirmModal (CenterContainer, full_rect, visible=false)
   │     ├─ ModalBackdrop (ColorRect, full_rect, color=#00000088)
   │     │   mouse_filter=STOP  → clique fora = cancelar
   │     └─ ModalCard (PanelContainer, style=modal_panel, custom_minimum_size.x=380)
   │        └─ Margin (padding=28/28/25/28)
   │           └─ VBox (separation=0)
   │              ├─ Icon (TextureRect, 44×44, warning_triangle.svg)
   │              ├─ Title  ("Desistir da Partida?", style=modal_title)
   │              ├─ Body   ("Tem certeza que deseja abandonar a batalha?",
   │              │           style=modal_body)
   │              ├─ Penalty ("— Você perderá pontos —", style=modal_penalty)
   │              ├─ Spacer (h=20)
   │              └─ Actions (HBoxContainer, separation=11)
   │                  ├─ BtnCancel  (Button "Cancelar",     variation=modal_cancel)
   │                  └─ BtnConfirm (Button "Sim, Desistir", variation=modal_confirm)
```

> Marque cada nó dinâmico com **Unique Name in Owner** (`%`).

---

## CENAS FILHAS REUTILIZÁVEIS

### `MenuButton.tscn` — botão grande do menu de pausa

```
MenuButton (Button, custom_minimum_size=Vector2(0, 56),
            theme_type_variation=pause_button_default)
└─ HBoxContainer (anchors=full_rect, alignment=CENTER, separation=14, mouse_filter=IGNORE)
   ├─ Icon  (TextureRect, custom_minimum_size=Vector2(14,14),
   │         stretch_mode=KEEP_ASPECT_CENTERED, modulate=gold)
   └─ Label (Label, font=Cinzel-SemiBold 13pt, letter_spacing=0.25em uppercase)
```

Variações de tema:
- `pause_button_default` — bg `oklch(0.14 0.05 268 / 0.9)`, border `gold @ 0.4`, color `gold`
- `pause_button_primary` — mesmo, mas com gradient interno escuro→médio e border `gold @ 0.7`
- `pause_button_danger`  — color `oklch(0.75 0.14 15)`, border `oklch(0.42 0.20 15 / 0.4)`

Hover (Tween 0.18s): `position:y -= 2`, border opacity sobe, brilho `*1.10`.
Press: scale `0.98` por 0.08s.

### `VolumeRow.tscn` — linha de slider de volume

```
VolumeRow (VBoxContainer, separation=10)  [script: volume_row.gd]
├─ Header (HBoxContainer)
│  ├─ Label (HBoxContainer)
│  │   ├─ Icon  (TextureRect 16×16, modulate=gold_mid)
│  │   └─ Text  (Label, "MÚSICA" / "EFEITOS", style=setting_label)
│  └─ Value (Label, "70%" / "Mudo", style=setting_value, h_align=RIGHT)
└─ Slider (HBoxContainer, separation=14)
   ├─ MinusBtn (Button "−", flat, custom_minimum_size=Vector2(22,22))
   ├─ Track    (Control, size_flags_horizontal=EXPAND_FILL, custom_minimum_size.y=24)
   │  ├─ Ticks (HBoxContainer, anchors=center_y, 11 traços de 1×6, separation=auto)
   │  ├─ Bg    (ColorRect, 100%×2px, anchors=center_y, color=gold_dim @ 0.18)
   │  ├─ Fill  (ColorRect, value%×2px, anchors=left+center_y,
   │  │         color=linear-gradient gold_mid→gold, shadow gold @ 0.5 8px)
   │  ├─ Thumb (ColorRect 14×14, rotated 45°, anchors=center_y,
   │  │         offset.x = value% * track_width,
   │  │         color=gold, border=1px bg_deep, shadow gold @ 0.7 12px)
   │  └─ HSlider (HSlider, full_rect, modulate=Color(1,1,1,0), step=1, min=0, max=100)
   │              → invisível, captura input e drive `value_changed`
   └─ PlusBtn  (Button "+", flat, custom_minimum_size=Vector2(22,22))
```

Sinais públicos: `value_changed(v: int)`.

### Assets de ícone

Salve **um único arquivo SVG** com o crest da pausa: `res://assets/ui/pausemenu/pause_crest.svg` (já fornecido com este pacote — escudo + duas barras verticais centrais douradas). Todos os outros ícones podem ser desenhados via `Control._draw()` ou usando o conjunto já existente do jogo:

- `play.svg`     — triângulo cheio (14×14)
- `gear.svg`     — engrenagem outline (14×14)
- `flag.svg`     — bandeira outline (14×14)
- `music.svg`    — duas semibreves ligadas (16×16)
- `speaker.svg`  — alto-falante + ondas (16×16)
- `warning.svg`  — triângulo com `!` (44×44, fill `oklch(0.42 0.20 15 / 0.15)`, stroke `oklch(0.65 0.22 15)`)
- `back.svg`     — chevron `<` (11×11)

Se você já tem ícones equivalentes no jogo, reutilize-os modulando para `gold`. Caso contrário, gere-os como `Control._draw()` em runtime ou peça PNGs/SVGs ao designer.

---

## SCRIPT — `pause_menu.gd`

```gdscript
class_name PauseMenu extends CanvasLayer

signal resumed
signal forfeit_requested
signal forfeit_confirmed    # jogador confirmou — abrir tela de Derrota
signal settings_changed(music_pct: int, fx_pct: int)

enum View { MAIN, SETTINGS, CONFIRM }

const SETTINGS_PATH := "user://settings.cfg"

@onready var main_view:    Control = %MainView
@onready var settings_view:Control = %SettingsView
@onready var confirm_modal:Control = %ConfirmModal
@onready var music_row:    Node    = %MusicRow
@onready var fx_row:       Node    = %FxRow

var _current_view: View = View.MAIN
var _is_open: bool = false
var _music_pct: int = 70
var _fx_pct:    int = 85

# ── Public API ────────────────────────────────────────────────────────────────
func open() -> void:
    _is_open = true
    _show_view(View.MAIN)
    visible = true
    get_tree().paused = true            # pausa todo o jogo
    process_mode = Node.PROCESS_MODE_ALWAYS  # mas este overlay continua processando
    _animate_in()

func close() -> void:
    _is_open = false
    _animate_out()
    await get_tree().create_timer(0.25).timeout
    visible = false
    get_tree().paused = false
    emit_signal("resumed")

func is_open() -> bool:
    return _is_open

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
    visible = false
    _load_settings()
    music_row.set_value(_music_pct); music_row.value_changed.connect(_on_music_changed)
    fx_row.set_value(_fx_pct);       fx_row.value_changed.connect(_on_fx_changed)

    %BtnResume.pressed.connect(close)
    %BtnSettings.pressed.connect(_on_settings_pressed)
    %BtnForfeit.pressed.connect(_on_forfeit_pressed)
    %BackBtn.pressed.connect(func(): _show_view(View.MAIN))
    %BtnCancel.pressed.connect(_on_confirm_cancel)
    %BtnConfirm.pressed.connect(_on_confirm_yes)
    %ModalBackdrop.gui_input.connect(_on_modal_backdrop_input)

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey and event.pressed and not event.echo):
        return
    if event.keycode != KEY_ESCAPE:
        return
    get_viewport().set_input_as_handled()
    match _current_view:
        View.MAIN:
            if _is_open: close() else: open()
        View.SETTINGS:
            _show_view(View.MAIN)
        View.CONFIRM:
            _on_confirm_cancel()

# ── View switching ────────────────────────────────────────────────────────────
func _show_view(v: View) -> void:
    _current_view = v
    main_view.visible     = (v == View.MAIN)
    settings_view.visible = (v == View.SETTINGS)
    confirm_modal.visible = (v == View.CONFIRM)
    if v == View.CONFIRM:
        main_view.visible = true   # mantém o painel atrás do modal

func _on_settings_pressed() -> void: _show_view(View.SETTINGS)
func _on_forfeit_pressed()  -> void: _show_view(View.CONFIRM)

func _on_confirm_cancel() -> void:
    _show_view(View.MAIN)

func _on_confirm_yes() -> void:
    _is_open = false
    visible = false
    get_tree().paused = false
    emit_signal("forfeit_confirmed")

# ── Volume ────────────────────────────────────────────────────────────────────
func _on_music_changed(v: int) -> void:
    _music_pct = v
    _apply_bus_volume("Music", v)
    _save_settings()
    emit_signal("settings_changed", _music_pct, _fx_pct)

func _on_fx_changed(v: int) -> void:
    _fx_pct = v
    _apply_bus_volume("SFX", v)
    _save_settings()
    emit_signal("settings_changed", _music_pct, _fx_pct)

func _apply_bus_volume(bus_name: String, pct: int) -> void:
    var idx := AudioServer.get_bus_index(bus_name)
    if idx == -1: return
    if pct == 0:
        AudioServer.set_bus_mute(idx, true)
    else:
        AudioServer.set_bus_mute(idx, false)
        AudioServer.set_bus_volume_db(idx, linear_to_db(pct / 100.0))

# ── Persistence ───────────────────────────────────────────────────────────────
func _load_settings() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SETTINGS_PATH) == OK:
        _music_pct = int(cfg.get_value("audio", "music", 70))
        _fx_pct    = int(cfg.get_value("audio", "fx",    85))
    _apply_bus_volume("Music", _music_pct)
    _apply_bus_volume("SFX",   _fx_pct)

func _save_settings() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("audio", "music", _music_pct)
    cfg.set_value("audio", "fx",    _fx_pct)
    cfg.save(SETTINGS_PATH)

# ── Animações ─────────────────────────────────────────────────────────────────
func _animate_in() -> void:
    %Backdrop.modulate.a = 0.0
    %PauseCard.modulate.a = 0.0
    %PauseCard.scale = Vector2(0.92, 0.92)
    var t := create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
    t.tween_property(%Backdrop, "modulate:a", 1.0, 0.35)
    t.tween_property(%PauseCard, "modulate:a", 1.0, 0.5).set_delay(0.05)
    t.tween_property(%PauseCard, "scale", Vector2.ONE, 0.5).set_delay(0.05)

func _animate_out() -> void:
    var t := create_tween().set_parallel().set_ease(Tween.EASE_IN)
    t.tween_property(%Backdrop, "modulate:a", 0.0, 0.25)
    t.tween_property(%PauseCard, "modulate:a", 0.0, 0.2)

func _on_modal_backdrop_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        _on_confirm_cancel()
```

### `volume_row.gd`
```gdscript
class_name VolumeRow extends VBoxContainer

signal value_changed(v: int)

@export var label_text: String = "MÚSICA"
@export var icon: Texture2D

@onready var icon_node: TextureRect = %Icon
@onready var text_node: Label       = %Text
@onready var value_node:Label       = %Value
@onready var minus_btn: Button      = %MinusBtn
@onready var plus_btn:  Button      = %PlusBtn
@onready var hslider:   HSlider     = %HSlider
@onready var fill:      ColorRect   = %Fill
@onready var thumb:     ColorRect   = %Thumb
@onready var track:     Control     = %Track

var _value: int = 70

func _ready() -> void:
    icon_node.texture = icon
    text_node.text = label_text
    hslider.value_changed.connect(_on_hslider)
    minus_btn.pressed.connect(func(): set_value(_value - 5))
    plus_btn.pressed.connect (func(): set_value(_value + 5))
    track.resized.connect(_refresh_visuals)
    set_value(_value)

func set_value(v: int) -> void:
    v = clampi(v, 0, 100)
    if v == _value: return
    _value = v
    hslider.set_value_no_signal(v)
    _refresh_visuals()
    emit_signal("value_changed", v)

func _on_hslider(v: float) -> void:
    set_value(int(v))

func _refresh_visuals() -> void:
    var w := track.size.x
    fill.size.x = w * _value / 100.0
    thumb.position.x = w * _value / 100.0 - 7    # 7 = metade do thumb (14px)
    value_node.text = "Mudo" if _value == 0 else "%d%%" % _value
    value_node.add_theme_color_override(
        "font_color",
        Color("a07d3a") if _value == 0 else Color("ffd676"))
```

---

## TEMA / ESTILOS — `res://themes/pausemenu_theme.tres`

Fontes (mesmas do resto do jogo):
- `CinzelDecorative-Bold`
- `Cinzel-SemiBold`
- `CrimsonPro-Italic`

### Paleta
```
gold        = oklch(0.82 0.16 80)   ≈ #ffd676
gold_mid    = oklch(0.73 0.13 78)   ≈ #e6b864
gold_dim    = oklch(0.55 0.10 78)   ≈ #a07d3a
gold_deep   = oklch(0.42 0.08 78)   ≈ #735726
red         = oklch(0.60 0.22 15)   ≈ #d75640
red_mid     = oklch(0.55 0.22 15)   ≈ #c84430
red_dim     = oklch(0.42 0.16 15)   ≈ #8e3325
bg_deep     = oklch(0.07 0.055 268) ≈ #0e0c1f
panel_bg    = oklch(0.10 0.04 268)  ≈ #16162a   com alpha 0.92
```

### StyleBoxFlat principais
- **pause_panel** — bg `panel_bg @ 0.92`, border 1px `gold @ 0.32`, shadow:
  - inner: `0 0 80px gold @ 0.08`
  - outer: `0 30px 60px #00000099`
- **modal_panel** — bg `panel_bg @ 0.92`, border 1px `red @ 0.45`, shadow `0 0 60px red @ 0.15 + 0 20px 50px #00000099`
- **pause_button_default** — bg `oklch(0.14 0.05 268) @ 0.9`, border 1px `gold @ 0.4`, padding `17/16/17/16`
- **pause_button_primary** — gradient `oklch(0.18 0.06 268) → oklch(0.12 0.05 268)`, border 1px `gold @ 0.7`
- **pause_button_danger**  — bg `oklch(0.14 0.05 268) @ 0.9`, border 1px `red @ 0.4`, font color `oklch(0.75 0.14 15)`
- **modal_btn_cancel**     — border `gold_dim @ 0.45`, color `gold_mid`
- **modal_btn_confirm**    — border `red @ 0.6`, color `oklch(0.75 0.14 15)`

### Cantos ornamentais (4 cantos do painel/modal)
São 4 `Control` filhos do painel, cada um com `_draw()` desenhando 2 linhas perpendiculares de 18×2px (14×2 no modal) na cor da borda do painel correspondente:
```gdscript
func _draw() -> void:
    var col := Color("ffd676", 0.55)        # ou red para o modal
    var L := 18.0
    var W := 2.0
    # canto top-left
    draw_rect(Rect2(0, 0, L, W), col, true)
    draw_rect(Rect2(0, 0, W, L), col, true)
```
(Espelhar a função por canto.)

### Textos
- **eyebrow**       — Cinzel-SemiBold 9pt, letter-spacing 0.5em, color `gold_dim` @ 0.85, uppercase
- **title**         — CinzelDecorative-Bold 36pt, gradient `gold_glow → gold_mid → gold_deep` (shader ou cor sólida `gold`), drop_shadow 18px `gold @ 0.5`
- **title (settings)** — mesmo, 30pt
- **footer**        — CrimsonPro-Italic 13pt, color `gold_dim` @ 0.7, alinhamento central, com `<kbd>` renderizados como Label inline com border 1px `gold @ 0.35` e fundo `bg_deep` (use RichTextLabel + BBCode customizado ou monte HBox manualmente)
- **setting_label** — Cinzel-SemiBold 11pt, letter-spacing 0.18em, color `gold_mid`, uppercase
- **setting_value** — Cinzel-Bold 13pt, color `gold` (vira `gold_dim` itálico CrimsonPro quando 0/"Mudo")
- **modal_title**   — CinzelDecorative-Bold 22pt, color `oklch(0.75 0.14 15)`
- **modal_body**    — CrimsonPro-Italic 15pt, color `oklch(0.72 0.04 78) @ 0.85`, alinhado ao centro
- **modal_penalty** — Cinzel-SemiBold 10pt, letter-spacing 0.25em, uppercase, color `oklch(0.65 0.18 15)`

---

## ANIMAÇÕES (Tween, todas `EASE_OUT_CUBIC`)

| Elemento         | Trigger          | Propriedade           | Valor                     | Duração |
|------------------|------------------|----------------------|---------------------------|---------|
| Backdrop         | open             | `modulate:a`         | 0 → 1                     | 0.35s   |
| Backdrop         | close            | `modulate:a`         | 1 → 0                     | 0.25s   |
| PauseCard        | open             | `modulate:a`, `scale`| 0→1, 0.92→1.0             | 0.5s, delay 0.05s |
| ViewSwitch       | troca            | `position:x`, `modulate:a` | +10→0, 0→1          | 0.3s    |
| MenuButton       | hover            | `position:y`, `modulate` | base − 2, *1.10       | 0.18s   |
| MenuButton       | press            | `scale`              | 0.98 (e volta)            | 0.08s   |
| Slider Thumb     | hover            | sombra externa       | gold @ 0.7 → 0.9          | 0.2s    |
| ConfirmModal     | open             | `modulate:a`, `scale`| 0→1, 0.95→1.0             | 0.3s    |
| Crest            | sempre           | `modulate` glow      | drop_shadow 16→26px loop  | 3s alternando (não-crítico) |

---

## INTERAÇÃO / FLUXO

1. **ESC no jogo (`Board.tscn`)** — O Board chama `pause_menu.open()`. A árvore inteira pausa via `get_tree().paused = true`. Esta cena tem `process_mode = ALWAYS` para continuar respondendo.
2. **"Voltar ao Jogo"** ou **ESC com menu aberto** — chama `close()` → animação de saída → `get_tree().paused = false` → emite `resumed`.
3. **"Configurações"** — troca para `SettingsView`. ESC volta ao MainView. Volumes aplicam imediatamente nos buses `Music` e `SFX`. São persistidos em `user://settings.cfg`.
4. **"Desistir da Partida"** — abre `ConfirmModal` por cima do MainView (overlay escuro). ESC ou clique fora cancela.
5. **"Sim, Desistir"** — fecha o menu sem chamar `close()` (não retomar o jogo), emite `forfeit_confirmed`. O Board recebe e:
   - Aplica a penalidade de pontos do jogador local.
   - Chama `VictoryDefeat.show("defeat", penalidade)` para o jogador local.
   - Notifica o servidor/oponente para mostrar `VictoryDefeat.show("victory")` no outro cliente.

---

## INTEGRAÇÃO COM `Board.tscn`

No script do tabuleiro (`board.gd`):

```gdscript
const PAUSE_MENU_SCENE := preload("res://scenes/ui/pausemenu/PauseMenu.tscn")

@onready var pause_menu: PauseMenu = PAUSE_MENU_SCENE.instantiate()

func _ready() -> void:
    add_child(pause_menu)
    pause_menu.resumed.connect(_on_resumed)
    pause_menu.forfeit_confirmed.connect(_on_forfeit_confirmed)

func _unhandled_key_input(event: InputEvent) -> void:
    # Deixar o PauseMenu lidar com ESC sozinho — ele tem process_mode=ALWAYS
    pass

func _on_resumed() -> void:
    pass    # nada a fazer; jogo já despausou

func _on_forfeit_confirmed() -> void:
    GameState.apply_forfeit_penalty(GameState.local_player_id)
    NetworkSync.notify_forfeit()
    VictoryDefeat.show_defeat({ "reason": "forfeit", "points_lost": 25 })
```

### `Music` e `SFX` buses
Se o projeto ainda não tiver, adicione em `default_bus_layout.tres`:
- bus `Music` → routes para `Master`
- bus `SFX`   → routes para `Master`

Todos os `AudioStreamPlayer` de música devem usar `bus = "Music"`; SFX usam `bus = "SFX"`.

---

## INPUT MAP

Adicione (se ainda não existir) em `Project Settings → Input Map`:
- `ui_pause` → tecla **Escape**

Substitua `KEY_ESCAPE` no script por `event.is_action_pressed("ui_pause")` para respeitar o remapeamento.

---

## CHECKLIST DE FIDELIDADE AO HTML

Abra `Pause Menu.html` lado a lado com a cena Godot e confirme:

- [ ] Overlay escurece o fundo com gradient radial — não opaco total
- [ ] Crest dourado (escudo + 2 barras) acima do painel, com glow pulsante leve
- [ ] Painel central com **cantos ornamentais** em L (4 cantos) na cor da borda
- [ ] Eyebrow "PAUSA" em caps espaçadas, título "Em Repouso" em fonte decorativa dourada
- [ ] Divider central: 2 linhas com diamante dourado no meio
- [ ] 3 botões verticais, **Voltar ao Jogo** com borda dourada mais forte (primary)
- [ ] **Desistir da Partida** com texto e borda em tons vermelhos
- [ ] Cada botão tem ícone à esquerda (play / gear / flag) e texto em caps espaçadas
- [ ] Hover dos botões: sobe 2px + brilho + sombra dourada
- [ ] Footer com hint "Pressione [ESC] para retomar a batalha" em itálico
- [ ] Subview de Configurações: idêntica em layout, com botão "← Voltar" no topo-esquerda
- [ ] Sliders mostram traços (11 ticks), trilho cinza fino, fill dourado com sombra, thumb diamante dourado
- [ ] Valor à direita mostra `%`; quando 0 vira "Mudo" em itálico dim
- [ ] Modal de Desistir: ícone triângulo vermelho, título dourado-vermelho decorativo, body itálico, linha "— Você perderá pontos —" em caps vermelhas
- [ ] Modal: botão "Cancelar" dourado, "Sim, Desistir" vermelho — ambos retangulares com mesmas dimensões
- [ ] ESC no modal = Cancelar; clique fora do card = Cancelar
- [ ] Ao confirmar desistência, o overlay some sem voltar para o jogo, e a tela de Derrota aparece

---

## ESCALA / RESPONSIVIDADE

- **Tamanho nativo:** 1280×800.
- O `CanvasLayer` raiz cobre toda a viewport. O `Root` Control usa `anchors=full_rect`.
- O conteúdo (`PauseCard`, `SettingsCard`, `ConfirmModal`) já é centrado por `CenterContainer`, então o ajuste de escala é automático.
- **Não** escale fontes individualmente; deixe o `Control` raiz com `scale = min(viewport.x/1280, viewport.y/800)` se necessário (mesmo padrão de outras cenas do jogo).

---

## ENTREGÁVEIS

- [ ] `res://scenes/ui/pausemenu/PauseMenu.tscn` + `pause_menu.gd`
- [ ] `res://scenes/ui/pausemenu/MenuButton.tscn` (cena reutilizável)
- [ ] `res://scenes/ui/pausemenu/VolumeRow.tscn` + `volume_row.gd`
- [ ] `res://themes/pausemenu_theme.tres`
- [ ] `res://assets/ui/pausemenu/pause_crest.svg` (já anexado neste pacote)
- [ ] SVGs/PNGs dos ícones (`play`, `gear`, `flag`, `music`, `speaker`, `warning`, `back`) — reutilize do conjunto de ícones do jogo se já existir; senão, gere SVGs simples a partir das descrições acima
- [ ] Buses de áudio `Music` e `SFX` em `default_bus_layout.tres` (se ainda não existirem)
- [ ] Action `ui_pause` no Input Map (tecla **Escape**)
- [ ] Integração no `board.gd` (3 linhas no `_ready` + 2 handlers)

---

## SINAIS PÚBLICOS

A `PauseMenu` deve expor exatamente:

- `signal resumed` — emitido quando o jogador fecha o menu
- `signal forfeit_requested` — emitido quando ele clica em "Desistir" (antes da confirmação) — útil para telemetria
- `signal forfeit_confirmed` — emitido após confirmação positiva no modal
- `signal settings_changed(music_pct: int, fx_pct: int)` — sempre que um slider mexe

A cena hospedeira (Board) conecta-se a `resumed` e `forfeit_confirmed` para gerenciar o estado da partida.

---

## REFERÊNCIA VISUAL

**Leia `Pause Menu.html` na raiz do projeto antes de começar.** Não invente posições, fontes ou cores — espelhe. As proporções foram desenhadas para 1280×800; use-as como tamanho nativo da cena e escale uniformemente.

Pode começar.
