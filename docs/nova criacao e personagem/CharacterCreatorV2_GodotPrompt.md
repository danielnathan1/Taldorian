# Prompt para Claude Code — `CharacterCreator.tscn` (Godot 4) — **Redesign v2 "Cena Viva"**

Cole o conteúdo abaixo no Claude Code. Ele assume que o projeto Godot do **Taldorian TCCG** já existe em `res://` e que esta tela é exibida **após o Lobby**, quando o jogador cria seu personagem antes de entrar em partidas.

> **Esta é a versão v2** — substitui o layout antigo de 3 colunas (`CharacterCreator_GodotPrompt.md`). A diferença: agora a tela é uma **cena viva** — um **cenário de fundo trocável**, o **personagem em pé** à esquerda sobre um pedestal, e um **painel de atributos** flutuando à direita com seletores `‹ valor ›`. Se a cena antiga já existir, **arquive/renomeie** para `CharacterCreator_legacy.tscn` e construa esta do zero.

---

## CONTEXTO

Estou desenvolvendo **Taldorian TCCG** em Godot 4.x. A **Tela de Criação de Personagem** permite ao jogador customizar visualmente seu avatar antes de jogar. O jogador define **nome**, **sexo**, **raça** e as peças visuais: **cabelo**, **barba**, **camisa**, **calça** e **tênis** (calçado). Cada peça é um **seletor cíclico** com seta esquerda/direita.

A referência visual completa em HTML/CSS está em **`Character Creator v2.html`** na raiz do projeto. **Leia esse arquivo antes de começar** — ele tem layout em **1280×720**, cores, fontes, espaçamentos e estados de hover/selected exatos.

## OBJETIVO

Construa **`res://scenes/ui/character_creator/CharacterCreator.tscn`** — a cena que:

1. Renderiza um **cenário de fundo** em camada própria (`%SceneryLayer`), **trocável** por um botão **"Trocar Cenário"** que cicla entre as texturas de cenário disponíveis. Sobre o cenário vão um **vinheta** e um **grão** sutis para o restante da UI continuar legível.
2. Mostra o **personagem em pé** à esquerda — slot `%CharacterMount` (Node2D dentro de SubViewport). Esta tela **só reserva** a região; o sprite real é montado por você fora. Embaixo: **pedestal** com brilho dourado, duas **setas de girar** (`‹ ›`) decorativas e uma **placa de nome** (nome + "raça · classe").
3. Mostra o **painel direito** flutuante (cantos em L dourados) com, de cima pra baixo:
   - **Nome** — `LineEdit` com ornamento `❦` e botão de **dado** (nome aleatório).
   - **Sexo** — toggle segmentado de 2 botões: **♂ Masculino** / **♀ Feminino**.
   - **Seletores cíclicos** (`‹ valor ›`), um por linha: **Raça, Cabelo, Barba, Camisa, Calça, Tênis**.
   - **Footer** — botão **Criar** (crimson) + botão **Voltar** (ghost).
4. Emite `character_confirmed(loadout: Dictionary)` ao clicar em **Criar** e `back_pressed` ao clicar em **Voltar**.

A cena é **autocontida** e **escalável** — nasce em 1280×720 e adapta-se ao viewport.

---

## ÁRVORE DE CENAS

### `CharacterCreator.tscn`
```
CharacterCreator (Control, full_rect, custom_minimum_size=Vector2(1280, 720)) [script: character_creator.gd]
│
├─ SceneryLayer (Control, full_rect, mouse_filter=IGNORE)
│  ├─ SceneryDefault (ColorRect/TextureRect)   # gradient de fallback (céu→serra) se nenhuma textura
│  └─ %SceneryImage  (TextureRect, full_rect, stretch_mode=KEEP_ASPECT_COVERED)  # cenário atual
│
├─ SceneryGrain   (TextureRect, full_rect, modulate.a=0.05, mouse_filter=IGNORE)
├─ SceneryVignette(TextureRect/ColorRect c/ shader, full_rect, mouse_filter=IGNORE)
│  # escurece bordas esquerda/direita/baixo p/ a UI escura ler sobre qualquer cenário
│
├─ SceneryBtn (Button, anchors=top_left, offset=(22,22), "❖ TROCAR CENÁRIO", style=scenery_btn)
│
├─ Preview (Control, anchors=left, custom_minimum_size.x=560, mouse_filter=IGNORE)
│  ├─ PreviewGlow (TextureRect, anchors=bottom_center, 340×340, modulate=gold@0.18)
│  ├─ CharacterSlot (SubViewportContainer, anchors=center,
│  │                 custom_minimum_size=Vector2(320, 420))
│  │  └─ SubViewport (transparent_bg=true)
│  │     └─ %CharacterMount (Node2D)            # ← AQUI ENTRA O SPRITE REAL (idle, vista frontal)
│  ├─ Pedestal (Control, anchors=bottom_center, custom_minimum_size=Vector2(230, 30))
│  │  ├─ PedestalDisc (TextureRect/ColorRect c/ gradient elíptico, style=pedestal_glow)
│  │  └─ PedestalRune (TextureRect, anel 200×14, border gold@0.30, rótulo elíptico)
│  ├─ %TurnLeftBtn  (Button, "‹", anchors=bottom_left,  style=turn_btn)
│  ├─ %TurnRightBtn (Button, "›", anchors=bottom_right, style=turn_btn)
│  └─ Nameplate (VBoxContainer, anchors=bottom_center, alignment=CENTER, separation=3)
│     ├─ %PreviewName (Label, "Joran", style=preview_name)
│     └─ %PreviewSub  (Label, "Humano · Guerreiro", style=preview_sub)
│
└─ Panel (PanelContainer, anchors=right_center, custom_minimum_size.x=452,
          offset_right=-46, style=panel_bg) [margens internas 26/30]
   ├─ CornerTL/TR/BL/BR (Control, 18×18, style=corner_*)   # 4 cantos em L dourados
   └─ VBox (VBoxContainer, separation=16)
      │
      ├─ PanelHead (VBoxContainer, alignment=CENTER, separation=5)
      │  ├─ Eyebrow (Label, "— CRIAÇÃO DE PERSONAGEM —", style=eyebrow)   # com filetes laterais
      │  └─ Title   (Label, "Forje seu Herói", style=title)
      │
      ├─ NameField (NameField.tscn)            # %NameField
      │
      ├─ SexField (VBoxContainer, separation=7)
      │  ├─ Label (Label, "SEXO", style=field_label)
      │  └─ SexToggle (HBoxContainer, separation=10)        # %SexToggle
      │     ├─ %SexMaleBtn   (Button, "♂ MASCULINO", style=seg_btn, toggle_mode=true)
      │     └─ %SexFemaleBtn (Button, "♀ FEMININO",  style=seg_btn, toggle_mode=true)
      │
      ├─ Selectors (VBoxContainer, separation=11)           # %Selectors
      │  ├─ SelRace   (OptionSelector.tscn, label="Raça")
      │  ├─ SelHair   (OptionSelector.tscn, label="Cabelo")
      │  ├─ SelBeard  (OptionSelector.tscn, label="Barba")
      │  ├─ SelShirt  (OptionSelector.tscn, label="Camisa")
      │  ├─ SelPants  (OptionSelector.tscn, label="Calça")
      │  └─ SelShoes  (OptionSelector.tscn, label="Tênis")
      │
      └─ Footer (HBoxContainer, separation=12)              # grid 1.4fr / 1fr
         ├─ %ConfirmBtn (Button, "⚔ CRIAR", style=primary, size_flags=EXPAND_FILL)
         └─ %BackBtn    (Button, "← VOLTAR", style=ghost)
```

> Marque cada nó dinâmico com **Unique Name in Owner** (`%`): `%SceneryImage`, `%CharacterMount`, `%TurnLeftBtn`, `%TurnRightBtn`, `%PreviewName`, `%PreviewSub`, `%NameField`, `%SexToggle`, `%SexMaleBtn`, `%SexFemaleBtn`, `%Selectors`, `%ConfirmBtn`, `%BackBtn` e cada `OptionSelector` (`%SelRace`, `%SelHair`, `%SelBeard`, `%SelShirt`, `%SelPants`, `%SelShoes`).

---

## CENAS FILHAS REUTILIZÁVEIS

Crie sob `res://scenes/ui/character_creator/components/`:

### `NameField.tscn` — campo de nome com botão de dado

```
NameField (VBoxContainer, separation=7) [script: name_field.gd]
├─ Label (Label, "NOME", style=field_label)
└─ InputRow (HBoxContainer, custom_minimum_size.y=46, style=input_bg)
   ├─ Ornament (Label, "❦", style=name_orn)              # decorativo, color=gold
   ├─ Input    (LineEdit, max_length=18, flat=true, placeholder="Dê um nome ao herói",
   │             size_flags_horizontal=EXPAND_FILL, style=name_input)
   └─ DiceBtn  (Button, ícone dado ⚄, custom_minimum_size=44×46, style=dice_btn)
```

Sinais: `signal name_changed(name: String)` · `signal random_requested`
Método: `func set_value(v: String) -> void`

### `OptionSelector.tscn` — linha de seletor cíclico `‹ valor ›`

```
OptionSelector (GridContainer, columns=2) [script: option_selector.gd]
# colunas: Label(78px fixo) | Control(EXPAND_FILL)
├─ FieldLabel (Label, "Raça", style=field_label_row)     # sem caps no row? ver tipografia
└─ Control (HBoxContainer, custom_minimum_size.y=42, style=field_bg)
   ├─ PrevBtn (Button, "‹", custom_minimum_size.x=42, style=sel_arrow)
   ├─ ValueLabel (Label, "Humano", align=CENTER, size_flags=EXPAND_FILL, style=sel_value)
   └─ NextBtn (Button, "›", custom_minimum_size.x=42, style=sel_arrow)
```

Sinais: `signal changed(field_id: String, option_index: int)`
API:
```gdscript
func bind(field_id: String, label_text: String, options: Array) -> void
func set_index(i: int) -> void          # atualiza ValueLabel; wrap-around
func current_index() -> int
func current_option()                   # retorna o SelectorOption atual
```
Comportamento: `PrevBtn`/`NextBtn` fazem `set_index((i ± 1 + n) % n)` (cíclico, igual ao mock) e emitem `changed`.

---

## DADOS / RESOURCES

Crie em `res://scripts/resources/`:

### `SelectorOption.gd`
```gdscript
class_name SelectorOption extends Resource
@export var id: String                 # "hair_braid", "beard_goatee", "shirt_linen", ...
@export var display_label: String      # "Trança Guerreira", "Cavanhaque", "Túnica de Linho"
@export var sprite_texture: Texture2D  # camada aplicada ao personagem (opcional p/ "Nenhum")
@export var is_none: bool = false      # "Nenhum"/"Liso"/"Sem barba" — camada vazia
@export var locked: bool = false       # bloqueado (premium / não desbloqueado)
```

### `CustomizationField.gd`
```gdscript
class_name CustomizationField extends Resource
@export var id: String                 # "race" | "hair" | "beard" | "shirt" | "pants" | "shoes"
@export var display_label: String      # "Raça", "Cabelo", "Barba", "Camisa", "Calça", "Tênis"
@export var options: Array[SelectorOption]
```

> **Raça** é um `CustomizationField` como os outros (id="race") — mas a opção atual também troca o **sprite base** do personagem (não só uma camada). Trate isso no `CharacterMount.apply_loadout()`.

Coloque dados de exemplo em `res://data/character/`:

```
fields/
├── field_race.tres    Humano, Elfo, Anão, Orc, Fada, Demônio
├── field_hair.tres    Careca, Liso Curto, Trança Guerreira, Cacheado, Rabo de Cavalo, Moicano  (...)
├── field_beard.tres   Sem Barba(is_none), Cavanhaque, Cheia, Bigode, Tranças       (...)
├── field_shirt.tres   Sem Camisa(is_none), Túnica de Linho, Cota de Malha, Gibão, Manto  (...)
├── field_pants.tres   Bombacha de Couro, Calça de Tecido, Grevas, Saiote           (...)
└── field_shoes.tres   Descalço(is_none), Botas de Viajante, Sandálias, Grevas de Aço (...)
```

### Cenários — `SceneryResource.gd`
```gdscript
class_name SceneryResource extends Resource
@export var id: String                 # "vale", "floresta", "pico_nevado", "ruinas"
@export var display_label: String      # "Vale Verdejante"
@export var texture: Texture2D         # arte de fundo 1280×720 (cover)
```
Coloque ao menos 3 em `res://data/character/scenery/` (ex: `vale.tres`, `floresta.tres`, `pico_nevado.tres`). O botão **"Trocar Cenário"** cicla por essa lista.

---

## SCRIPT — `character_creator.gd`

```gdscript
class_name CharacterCreator extends Control

signal character_confirmed(loadout: Dictionary)
signal back_pressed

const NAME_OPTIONS := ["Joran","Aelwyn","Brimstone","Calyx","Drakir","Eowyn","Faelin","Gareth","Hekla","Ilyra"]

# ── Dados injetados via setup() ──
var _fields: Array = []        # Array[CustomizationField] na ordem: race,hair,beard,shirt,pants,shoes
var _scenery: Array = []       # Array[SceneryResource]

# ── Estado ──
# {
#   "name": "Joran",
#   "sex": "male",                 # "male" | "female"
#   "race": 0, "hair": 2, "beard": 1, "shirt": 1, "pants": 0, "shoes": 1,   # índices
# }
var _state: Dictionary = {}
var _scenery_idx: int = 0

# ── Referências ──
@onready var scenery_image: TextureRect = %SceneryImage
@onready var character_mount: Node2D = %CharacterMount
@onready var preview_name: Label = %PreviewName
@onready var preview_sub:  Label = %PreviewSub
@onready var name_field:   Control = %NameField
@onready var sex_male:     Button = %SexMaleBtn
@onready var sex_female:   Button = %SexFemaleBtn
@onready var selectors_box:VBoxContainer = %Selectors
@onready var confirm_btn:  Button = %ConfirmBtn
@onready var back_btn:     Button = %BackBtn

var _selectors: Dictionary = {}   # field_id -> OptionSelector node

func setup(fields: Array, scenery: Array) -> void:
    _fields = fields
    _scenery = scenery
    _state = _make_initial_state()
    _bind_selectors()
    _wire()
    _apply_scenery(0)
    _refresh_sex_toggle()
    _refresh_preview()
    _emit_loadout_update()

func _make_initial_state() -> Dictionary:
    var s := { "name": "Joran", "sex": "male" }
    for f in _fields:
        s[f.id] = 0
    return s

func _bind_selectors() -> void:
    # Os 6 OptionSelector já estão na cena; faz bind por ordem/índice de id.
    var nodes := selectors_box.get_children()
    for i in _fields.size():
        var f: CustomizationField = _fields[i]
        var sel := nodes[i]
        sel.bind(f.id, f.display_label, f.options)
        sel.set_index(_state[f.id])
        sel.changed.connect(_on_selector_changed)
        _selectors[f.id] = sel

func _wire() -> void:
    name_field.name_changed.connect(_on_name_changed)
    name_field.random_requested.connect(_on_random_name)
    name_field.set_value(_state["name"])
    sex_male.pressed.connect(func(): _set_sex("male"))
    sex_female.pressed.connect(func(): _set_sex("female"))
    confirm_btn.pressed.connect(_on_confirm)
    back_btn.pressed.connect(func(): emit_signal("back_pressed"))
    # SceneryBtn está na raiz da cena:
    %SceneryImage.get_parent().get_parent().get_node("SceneryBtn").pressed.connect(_on_cycle_scenery)
    # (ou exponha SceneryBtn como % e conecte direto)

# ── Handlers ──
func _on_name_changed(n: String) -> void:
    _state["name"] = n
    _refresh_preview()

func _on_random_name() -> void:
    _state["name"] = NAME_OPTIONS[randi() % NAME_OPTIONS.size()]
    name_field.set_value(_state["name"])
    _refresh_preview()

func _set_sex(sex: String) -> void:
    _state["sex"] = sex
    _refresh_sex_toggle()
    _emit_loadout_update()

func _on_selector_changed(field_id: String, idx: int) -> void:
    _state[field_id] = idx
    _refresh_preview()
    _emit_loadout_update()

func _on_cycle_scenery() -> void:
    if _scenery.is_empty(): return
    _scenery_idx = (_scenery_idx + 1) % _scenery.size()
    _apply_scenery(_scenery_idx)

func _on_confirm() -> void:
    emit_signal("character_confirmed", _build_loadout())

# ── Visual ──
func _apply_scenery(i: int) -> void:
    _scenery_idx = i
    if i < _scenery.size() and _scenery[i].texture:
        scenery_image.texture = _scenery[i].texture
        scenery_image.show()
    else:
        scenery_image.hide()   # cai no SceneryDefault (gradient)

func _refresh_sex_toggle() -> void:
    sex_male.button_pressed   = _state["sex"] == "male"
    sex_female.button_pressed = _state["sex"] == "female"

func _refresh_preview() -> void:
    preview_name.text = _state["name"] if _state["name"] != "" else "— sem nome —"
    var race_label := _field_option_label("race")
    preview_sub.text = "%s · Guerreiro" % race_label   # "classe" é placeholder por enquanto

func _field_option_label(field_id: String) -> String:
    var f := _find_field(field_id)
    if f == null: return "—"
    return f.options[_state[field_id]].display_label

func _build_loadout() -> Dictionary:
    var out := { "name": _state["name"], "sex": _state["sex"] }
    for f in _fields:
        out[f.id] = f.options[_state[f.id]].id
    return out

func _emit_loadout_update() -> void:
    if character_mount and character_mount.has_method("apply_loadout"):
        character_mount.apply_loadout(_build_loadout())

func _find_field(id: String) -> CustomizationField:
    for f in _fields:
        if f.id == id: return f
    return null
```

> Os scripts dos componentes (`name_field.gd`, `option_selector.gd`) são pequenos — `bind()` + setters + sinais públicos.

---

## TEMA / ESTILOS — `res://themes/character_creator_theme.tres`

Fontes (mesmas do projeto): `CinzelDecorative-Bold`, `Cinzel-SemiBold`, `Cinzel-Bold`, `CrimsonPro-Regular`, `CrimsonPro-Italic`. Se já existe `heropick_theme.tres`/`launcher_theme.tres`, **estenda-o** — a paleta é compartilhada.

Cores (idênticas ao Launcher / HeroPick):
```
gold        = #e6b864    gold_dim    = #a07d3a    gold_glow = #ffd676    gold_deep = #7a6326
crimson     = #a23a2c    crimson_br  = #c4503a
parchment   = #f0ead6    parchment_d = #b5a98a    ink_faint = #8a8270
panel_bg    = rgba(25,21,16,0.92)
field_bg    = rgba(22,18,14,0.78)
line        = rgba(230,184,100,0.30)
line_soft   = rgba(230,184,100,0.14)
```

### Estilos (StyleBoxFlat / shaders)

| Style              | Propriedades                                                                              |
|--------------------|-------------------------------------------------------------------------------------------|
| **panel_bg**       | bg `panel_bg`, border 1px `line`, inset highlight 1px `gold@0.12`, sombra 0/30/70 preta    |
| **corner_***       | 18×18, 2px gold em L no respectivo canto, opacity 0.65                                     |
| **scenery_btn**    | bg `rgba(22,18,14,0.72)`, border 1px `line`, glifo ❖ em gold. Hover: border `gold_dim`, color gold |
| **input_bg**       | bg `field_bg`, border 1px `line`. Focus: border `gold_dim` + outline 2px `gold@0.12`       |
| **field_bg**       | bg `field_bg`, border 1px `line`. Hover: border `gold_dim`                                 |
| **seg_btn (idle)** | bg `field_bg`, border 1px `line`, color `parchment_d`. Hover: border `gold_dim`, parchment |
| **seg_btn (pressed)** | bg gradient `gold@0.18 → gold_deep@0.10`, border 1px gold, color gold, inset 1px gold@0.4 |
| **sel_arrow**      | flat, color `gold_dim`. Hover: color `gold_glow`, bg `gold@0.10`                           |
| **turn_btn**       | 38×54, bg `rgba(22,18,14,0.6)`, border 1px `line_soft`, color `gold_dim`. Hover: border `gold_dim`, color gold, bg `rgba(28,24,18,0.7)` |
| **pedestal_glow**  | gradient elíptico radial `rgba(46,34,22,0.9) → transparent`, border-top 1px gold@0.45      |
| **dice_btn**       | flat, border_left 1px `line_soft`, color `gold_dim`. Hover: bg `gold@0.08`, color `gold_glow` |

### Tipografia

| Style              | Font                    | Size | Letter-spacing | Color            |
|--------------------|-------------------------|------|----------------|------------------|
| **eyebrow**        | Cinzel-SemiBold         | 9pt  | 0.46em         | gold_dim         |
| **title**          | CinzelDecorative-Bold   | 26pt | 0.04em         | gradient gold    |
| **field_label**    | Cinzel-SemiBold         | 10pt | 0.30em (caps)  | gold_dim         |
| **field_label_row**| Cinzel-SemiBold         | 11pt | 0.04em         | gold_dim         |
| **name_input**     | Cinzel-SemiBold         | 15pt | 0.06em         | parchment        |
| **name_orn**       | CinzelDecorative-Bold   | 16pt | -              | gold @ 0.7       |
| **seg_btn_label**  | Cinzel-SemiBold         | 11pt | 0.16em (caps)  | (segue estado)   |
| **sel_value**      | Cinzel-Medium           | 13pt | 0.06em         | parchment        |
| **sel_arrow**      | Cinzel (qualquer)       | 19pt | -              | gold_dim         |
| **preview_name**   | CinzelDecorative-Bold   | 22pt | 0.03em         | parchment (sombra forte) |
| **preview_sub**    | Cinzel-SemiBold         | 9pt  | 0.42em (caps)  | gold_dim         |

### Botões do footer

- **ConfirmBtn (Criar)** — bg gradient `#7c2a1e → #4a1a10`, border 1px `crimson_br @ 0.75`, color `#f5e8c8`, font Cinzel-Bold 13pt, letter-spacing 0.22em, altura 50, glifo `⚔`, inset highlight 1px `gold@0.18`. Hover: Tween `y -= 2`, `modulate *1.1`, sombra crimson.
- **BackBtn (Voltar)** — bg transparente, border 1px `line`, color `parchment_d`, font Cinzel-Bold 13pt, letter-spacing 0.22em, altura 50, glifo `←`. Hover: border `gold_dim`, color gold, bg `gold@0.05`.

---

## ANIMAÇÕES (Tween, `EASE_OUT_CUBIC`)

| Elemento             | Trigger    | Propriedade                  | Valor          | Duração   |
|----------------------|------------|------------------------------|----------------|-----------|
| CharacterMount/sprite| sempre     | `position:y` (idle bob)      | 0 → −7px → 0   | 3.4s loop |
| ConfirmBtn           | hover      | `position:y`, `modulate`     | base−2, *1.1   | 0.16s     |
| ConfirmBtn           | shimmer    | gradient-pos via Shader      | −120% → 160%   | 0.55s     |
| seg_btn / sel_arrow  | hover      | `modulate`/bg                | conforme estilo| 0.18s     |
| SceneryImage         | troca      | `modulate:a`                 | 0 → 1 (crossfade)| 0.35s   |
| Tela inteira (entrada)| spawn     | `modulate:a`, `position:y`   | 0→1, +14→0     | 0.40s     |

> O "bob" do personagem corresponde ao `@keyframes heroBob` do mock (scale fixo, leve sobe-desce). No Godot, aplique no Node2D do sprite dentro do SubViewport, não no SubViewportContainer.

---

## INTERAÇÃO / FLUXO

1. **Entrada** — `setup(fields, scenery)` é chamado pelo Lobby; a cena faz bind dos 6 seletores, aplica cenário 0 e monta o loadout inicial.
2. **Trocar Cenário** — clica em "Trocar Cenário" → cicla `_scenery` com crossfade. (Visual; persistência opcional.)
3. **Girar personagem** — `‹` / `›` ao lado do pedestal: por ora **decorativos** (engate futuro de rotação 4-direções via `%CharacterMount`). Conecte os sinais mesmo que vazios.
4. **Nome** — digitar atualiza placa do preview; dado sorteia um nome.
5. **Sexo** — toggle exclusivo Masculino/Feminino; troca a base do personagem via `apply_loadout`.
6. **Seletores** — `‹`/`›` ciclam (wrap-around) as opções de cada peça; cada troca atualiza o preview via `apply_loadout`.
7. **Criar** — emite `character_confirmed(loadout)` com `{ name, sex, race, hair, beard, shirt, pants, shoes }` (ids das opções).
8. **Voltar** — emite `back_pressed`.

---

## INTEGRAÇÃO COM O SPRITE DO PERSONAGEM

A cena **não desenha** o personagem — só reserva `%CharacterMount` (Node2D em SubViewport ~320×420). Implemente **separadamente** `CharacterMount.gd`:

```gdscript
# Anexe ao Node2D %CharacterMount.
extends Node2D

func apply_loadout(loadout: Dictionary) -> void:
    # 1. Base = raça (loadout.race) + sexo (loadout.sex)
    # 2. Camadas, na ordem de pintura: calça → camisa → tênis → cabelo → barba
    #    usando o sprite_texture da SelectorOption escolhida (ids em loadout[campo]).
    # 3. Opções is_none (Sem barba / Sem camisa / Descalço) = pular a camada.
    pass
```

`CharacterCreator.gd` chama `apply_loadout(_build_loadout())` a cada mudança; você monta a pilha de Sprite2D lá. O personagem aparece **de frente, parado** (idle frontal).

> **Dica de protótipo:** enquanto a montagem por camadas não existe, dá pra plugar o `elf_walk.png` (576×256, grid 64×64) e mostrar o **frame 0 da linha 2 (frente)** como boneco-base — é o que o mock HTML usa.

---

## ESCALA / RESPONSIVIDADE

- **Tamanho nativo:** 1280×720 (16:9).
- `CanvasLayer` raiz com `Control` filho de 1280×720 e `scale = min(viewport.x/1280, viewport.y/720)` no `_ready()` + sinal `size_changed`; centralize via offset `(viewport − 1280*scale)/2`.
- O cenário usa `KEEP_ASPECT_COVERED` para preencher sem distorcer.
- **Não** ajuste tamanhos de fonte individualmente.

---

## PASTAS DE ASSETS QUE PRECISO QUE VOCÊ CRIE

Onde indicado **placeholder**, gere PNGs sólidos neutros com glifo central — eu substituo pela arte final.

```
res://assets/ui/character_creator/
├── icons/
│   ├── dice.png            (botão de nome aleatório, branco s/ transparente)
│   ├── scenery.png         (glifo ❖ p/ botão Trocar Cenário — opcional, pode ser texto)
│   ├── arrow_left.png      (botão Voltar — opcional, pode ser "←")
│   └── sword.png           (glifo ⚔ do Criar — opcional, pode ser texto)
└── decor/
    ├── preview_glow.png     (radial dourado 340×340 @ 18%)
    ├── pedestal_disc.png    (elipse com gradient dourado→transparente, 230×30)
    ├── corner_l.png         (canto em L 18×18 dourado)
    └── vignette.png         (vinheta full-screen: escurece esq/dir/baixo)  ← ou shader

res://assets/character/scenery/      ← cenários 1280×720 (placeholders de gradient ok)
│   ├── vale.png
│   ├── floresta.png
│   └── pico_nevado.png

res://assets/character/parts/        ← sprites das peças aplicados ao personagem (idle frontal)
│   ├── race/    (humano, elfo, anao, orc, fada, demonio) × sexo
│   ├── hair/    (uma textura por opção de cabelo)
│   ├── beard/   (idem; "sem barba" não precisa de PNG)
│   ├── shirt/   (idem; "sem camisa" não precisa de PNG)
│   ├── pants/   (idem)
│   └── shoes/   (idem; "descalço" não precisa de PNG)
```

**Opções "Nenhum"** (Sem barba / Sem camisa / Descalço): `is_none=true`, sem PNG — a camada é pulada.

---

## ENTREGÁVEIS

- [ ] `res://scenes/ui/character_creator/CharacterCreator.tscn` + `character_creator.gd`
- [ ] `res://scenes/ui/character_creator/components/NameField.tscn` + `name_field.gd`
- [ ] `res://scenes/ui/character_creator/components/OptionSelector.tscn` + `option_selector.gd`
- [ ] `res://scripts/resources/SelectorOption.gd`
- [ ] `res://scripts/resources/CustomizationField.gd`
- [ ] `res://scripts/resources/SceneryResource.gd`
- [ ] `res://themes/character_creator_theme.tres` (ou extensão do tema existente)
- [ ] 6 `.tres` em `res://data/character/fields/` (race, hair, beard, shirt, pants, shoes) com opções de exemplo
- [ ] ≥3 `.tres` em `res://data/character/scenery/`
- [ ] Estrutura de pastas de assets com placeholders neutros

---

## SINAIS PÚBLICOS

A `CharacterCreator` deve expor exatamente:

- `signal character_confirmed(loadout: Dictionary)` — `{ name, sex, race, hair, beard, shirt, pants, shoes }` (sexo como "male"/"female"; peças como ids de `SelectorOption`)
- `signal back_pressed`

A cena hospedeira (Lobby) conecta-se e, ao receber `character_confirmed`, persiste o loadout (ex: `user://character.tres`) e navega.

---

## CHECKLIST DE FIDELIDADE AO HTML

Abra **`Character Creator v2.html`** lado a lado com a cena Godot e confirme:

- [ ] Cenário de fundo ocupa a tela toda; vinheta escurece bordas esq/dir/baixo; botão "❖ TROCAR CENÁRIO" no canto superior esquerdo
- [ ] Personagem em pé à esquerda, sobre pedestal com brilho dourado elíptico e anel rúnico; setas `‹ ›` flanqueando; placa "Joran" (CinzelDecorative) + "HUMANO · GUERREIRO" (caps dourado) abaixo
- [ ] Painel à direita, vertical, com 4 cantos em L dourados e fundo escuro translúcido
- [ ] Cabeçalho: eyebrow "— CRIAÇÃO DE PERSONAGEM —" com filetes + título "Forje seu Herói" em gradiente dourado
- [ ] Nome: campo com ornamento ❦ + botão de dado à direita
- [ ] Sexo: dois botões segmentados; o ativo com borda/fundo dourados
- [ ] 6 seletores `‹ valor ›` (Raça, Cabelo, Barba, Camisa, Calça, Tênis): label à esquerda (78px), pílula com seta‑valor‑seta; setas acendem em gold no hover
- [ ] Footer: "⚔ CRIAR" (crimson, mais largo) + "← VOLTAR" (ghost)
- [ ] Tudo escala uniformemente a partir de 1280×720

---

## REFERÊNCIA VISUAL

**Leia `Character Creator v2.html` na raiz do projeto antes de começar.** Não invente posições, fontes ou cores — espelhe. As proporções foram desenhadas para 1280×720; use-as como tamanho nativo da cena e escale uniformemente.

Pode começar.
