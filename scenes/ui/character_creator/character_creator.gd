# scenes/ui/character_creator/character_creator.gd
# Lógica da tela de criação de personagem ("Cena Viva").
# TODA a estrutura visual e estilos vivem em character_creator.tscn —
# este script só carrega dados, mantém o estado, atualiza o preview e salva.
extends Control

const LOGIN_SCENE := "res://scenes/ui/main.tscn"   # tela de login (entry point do app)
const WORLD_SCENE := "res://scenes/world/world_root.tscn"
const ONBOARDING_SCENE := "res://scenes/world/quests/onboarding/onboarding.tscn"
const WORLD_PORT  := 7001   # host vem do ServerConfig (resolve por ambiente)

# ── Cenários trocáveis ─────────────────────────────────────────────────────────
const SCENERY := [
	"res://assets/specifics/chracter_creator/BG_1.png",
	"res://assets/specifics/chracter_creator/BG_2.png",
	"res://assets/specifics/chracter_creator/BG_3.png",
]

# Frame base do walk.png usado no preview (vista frontal = linha 2). hframes=9.
const PREVIEW_FRAME := 18
# Direção exibida pelas setas de girar: linhas frente, direita, costas, esquerda.
const FACING_ROWS := [2, 3, 0, 1]

# ── Dados ─────────────────────────────────────────────────────────────────────
const RACES := [
	{ "id": "human", "label": "Humano",
	  "skins": {
		  "male": [
			  { "id": "white",  "label": "Clara",   "path": "res://assets/character/body/human/male/white/walk.png" },
			  { "id": "brown",  "label": "Morena",  "path": "res://assets/character/body/human/male/brown/walk.png" },
			  { "id": "olive",  "label": "Oliva",   "path": "res://assets/character/body/human/male/olivie/walk.png" },
			  { "id": "black",  "label": "Escura",  "path": "res://assets/character/body/human/male/black/walk.png" },
		  ],
		  "female": [
			  { "id": "white",  "label": "Clara",   "path": "res://assets/character/body/human/female/white/walk.png" },
			  { "id": "brown",  "label": "Morena",  "path": "res://assets/character/body/human/female/brown/walk.png" },
			  { "id": "olive",  "label": "Oliva",   "path": "res://assets/character/body/human/female/olive/walk.png" },
			  { "id": "black",  "label": "Escura",  "path": "res://assets/character/body/human/female/black/walk.png" },
		  ],
	  }
	},
	{ "id": "orc", "label": "Orc",
	  "skins": {
		  "male": [
			  { "id": "green",  "label": "Verde",   "path": "res://assets/character/body/orc/orc_male/green/walk.png" },
			  { "id": "brown",  "label": "Marrom",  "path": "res://assets/character/body/orc/orc_male/brown/walk.png" },
		  ],
		  "female": [
			  { "id": "green",  "label": "Verde",   "path": "res://assets/character/body/orc/orc_female/green/walk.png" },
			  { "id": "brown",  "label": "Marrom",  "path": "res://assets/character/body/orc/orc_female/brown/walk.png" },
			  { "id": "black",  "label": "Escura",  "path": "res://assets/character/body/orc/orc_female/black/walk.png" },
		  ],
	  }
	},
]

# Roupas com path fixo por sexo. Cabelo/barba são escaneados das pastas (ver _scan_styles).
const STYLES := {
	"chest": [
		{ "id": "basic_tshirt", "label": "Camiseta",
		  "paths": { "male":   "res://assets/character/chest/male/basic_tshirt/walk.png",
					 "female": "res://assets/character/chest/female/basic_tshirt/walk.png" } },
	],
	"legs": [
		{ "id": "basic_pants", "label": "Calça Básica",
		  "paths": { "male":   "res://assets/character/pants/male/basic_pants/walk.png",
					 "female": "res://assets/character/pants/female/basic_pants/walk.png" } },
	],
	"shoes": [
		{ "id": "basic_shoes", "label": "Sapatos Básicos",
		  "paths": { "male":   "res://assets/character/shoes/male/basic_shoes/walk.png",
					 "female": "res://assets/character/shoes/female/basic_shoes/walk.png" } },
	],
}

# ── Cabelo / barba dinâmicos ───────────────────────────────────────────────────
const HAIR_DIR   := "res://assets/character/hair"
const FACIAL_DIR := "res://assets/character/facial"

const HAIR_LABELS := {
	"spiked_1":     "Espetado",
	"spiked_2":     "Espetado 2",
	"afro":         "Afro",
	"carecabeludo": "Careca",
	"dread":        "Dreads",
	"half_up":      "Meio Preso",
	"long_1":       "Cabelo Longo",
	"bob":          "Chanel",
	"pigtails":     "Maria-chiquinha",
}
const BEARD_LABELS := {
	"basic_beard": "Barba Curta",
	"full_beard":  "Barba Cheia",
	"mustache":    "Bigode",
}

const RANDOM_NAMES := [
	"Aelwyn", "Brimstone", "Calyx", "Drakir", "Eowyn",
	"Faelin", "Gareth", "Hekla", "Ilyra", "Joren",
	"Kalix", "Lyren", "Mireth", "Nalos", "Orvyn",
]

# Categorias de roupa/cabelo que têm seletor + cor (a ordem casa com os nós no .tscn).
const LAYER_FIELDS := ["hair", "beard", "chest", "legs", "shoes"]

# Rótulos dos seletores (id da categoria → texto exibido).
const FIELD_LABELS := {
	"race":  "Raça",
	"body":  "Pele",
	"hair":  "Cabelo",
	"beard": "Barba",
	"chest": "Blusa",
	"legs":  "Calça",
	"shoes": "Sapatos",
}

# ── Estado ────────────────────────────────────────────────────────────────────
var _state := {
	"name":  "",
	"race":  "human",
	"sex":   "male",
	"body":  { "style": "white" },
	"hair":  { "style": "", "color": Color(0.08, 0.04, 0.02) },
	"beard": { "style": "none", "color": Color(0.08, 0.04, 0.02) },
	"chest": { "style": "basic_tshirt", "color": Color(0.70, 0.70, 0.80) },
	"legs":  { "style": "basic_pants",  "color": Color(0.25, 0.30, 0.50) },
	"shoes": { "style": "basic_shoes",  "color": Color(0.40, 0.25, 0.15) },
}
var _styles      := {}          # STYLES + cabelo/barba escaneados. Montado em _ready.
var _frame       := PREVIEW_FRAME
var _facing      := 0
var _scenery_idx := 0
var _selectors   := {}          # field_id → OptionSelector
var _music: AudioStreamPlayer

# ── @onready — nós do .tscn ───────────────────────────────────────────────────
@onready var _scenery_img  : TextureRect = %SceneryImage
@onready var _scenery_btn  : Button      = %SceneryBtn
@onready var _skeleton     : Node2D      = %Skeleton
@onready var _body_sprite  : Sprite2D    = $Skeleton/Body/Sprite2D
@onready var _pants_sprite : Sprite2D    = $Skeleton/Pants/Sprite2D
@onready var _shoes_sprite : Sprite2D    = $Skeleton/Shoes/Sprite2D
@onready var _chest_sprite : Sprite2D    = $Skeleton/Chest/Sprite2D
@onready var _hair_sprite  : Sprite2D    = $Skeleton/Hair/Sprite2D
@onready var _beard_sprite : Sprite2D    = $Skeleton/Beard/Sprite2D
@onready var _turn_left    : Button      = %TurnLeftBtn
@onready var _turn_right   : Button      = %TurnRightBtn
@onready var _preview_name : Label       = %PreviewName
@onready var _preview_race : Label       = %PreviewRace
@onready var _name_input   : LineEdit    = %NameInput
@onready var _dice_btn     : Button      = %DiceBtn
@onready var _sex_male     : Button      = %SexMaleBtn
@onready var _sex_female   : Button      = %SexFemaleBtn
@onready var _confirm_btn  : Button      = %ConfirmBtn
@onready var _back_btn     : Button      = %BackBtn

# ═══════════════════════════════════════════════════════════════════════════════
# READY
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_styles = _build_styles()
	_state.name = RANDOM_NAMES.pick_random()
	# Cabelo padrão = primeiro estilo real (pula "Sem Cabelo").
	for h in _styles.get("hair", []):
		if str(h.get("id", "")) != "none":
			_state["hair"]["style"] = str(h.get("id", ""))
			break
	_reset_body_skin()
	_collect_selectors()
	_bind_selectors()
	_wire_signals()
	_name_input.text = _state.name
	_refresh_all_layers()
	_update_info_labels()
	_animate_entrance()
	_start_bob()
	_start_music()

func _collect_selectors() -> void:
	_selectors = {
		"race":  %SelRace,
		"body":  %SelSkin,
		"hair":  %SelHair,
		"beard": %SelBeard,
		"chest": %SelChest,
		"legs":  %SelLegs,
		"shoes": %SelShoes,
	}

func _bind_selectors() -> void:
	for field_id in _selectors:
		var sel: Node = _selectors[field_id]
		var opts := _options_for(field_id)
		var has_color: bool = field_id in LAYER_FIELDS
		sel.bind(field_id, str(FIELD_LABELS.get(field_id, field_id)), opts, has_color)
		sel.set_index(_current_index(field_id, opts))
		if has_color:
			sel.set_color(_layer_color(field_id))
		sel.changed.connect(_on_selector_changed)
		if has_color:
			sel.color_changed.connect(_on_selector_color)

# Opções de cada seletor (race/body são especiais; o resto vem de _styles).
func _options_for(field_id: String) -> Array:
	match field_id:
		"race": return RACES
		"body": return _current_skins()
		_:      return _styles.get(field_id, [])

# Índice da opção atualmente selecionada para o seletor.
func _current_index(field_id: String, opts: Array) -> int:
	var current := ""
	match field_id:
		"race": current = str(_state.get("race", ""))
		"body": current = str((_state.get("body", {}) as Dictionary).get("style", ""))
		_:      current = str((_state.get(field_id, {}) as Dictionary).get("style", ""))
	for i in opts.size():
		if str((opts[i] as Dictionary).get("id", "")) == current:
			return i
	return 0

# ═══════════════════════════════════════════════════════════════════════════════
# ESTILOS DISPONÍVEIS — roupas (fixas) + cabelo/barba (escaneados)
# ═══════════════════════════════════════════════════════════════════════════════

func _build_styles() -> Dictionary:
	var out := STYLES.duplicate(true)
	out["hair"]  = _scan_styles(HAIR_DIR,   HAIR_LABELS,  "Sem Cabelo")
	out["beard"] = _scan_styles(FACIAL_DIR, BEARD_LABELS, "Sem Barba")
	return out

func _scan_styles(dir_path: String, labels: Dictionary, none_label: String) -> Array:
	var found: Array = [{ "id": "none", "label": none_label, "path": "" }]
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("character_creator: não foi possível abrir %s" % dir_path)
		return found
	var folders := dir.get_directories()
	folders.sort()
	for folder in folders:
		var path := "%s/%s/walk.png" % [dir_path, folder]
		if not ResourceLoader.exists(path):
			continue
		found.append({
			"id":    folder,
			"label": _humanize_label(folder, labels),
			"path":  path,
		})
	return found

func _humanize_label(folder_id: String, labels: Dictionary) -> String:
	if labels.has(folder_id):
		return str(labels[folder_id])
	return folder_id.capitalize()

# ═══════════════════════════════════════════════════════════════════════════════
# SINAIS
# ═══════════════════════════════════════════════════════════════════════════════

func _wire_signals() -> void:
	_back_btn.pressed.connect(_on_back_pressed)
	_confirm_btn.pressed.connect(_on_confirm)
	_scenery_btn.pressed.connect(_on_cycle_scenery)
	_turn_left.pressed.connect(func() -> void: _on_turn(-1))
	_turn_right.pressed.connect(func() -> void: _on_turn(1))
	_sex_male.pressed.connect(func() -> void: _set_sex("male"))
	_sex_female.pressed.connect(func() -> void: _set_sex("female"))
	_dice_btn.pressed.connect(func() -> void:
		_state.name = RANDOM_NAMES.pick_random()
		_name_input.text = _state.name
		_update_info_labels())
	_name_input.text_changed.connect(func(t: String) -> void:
		_state.name = t
		_update_info_labels())

# ═══════════════════════════════════════════════════════════════════════════════
# HANDLERS
# ═══════════════════════════════════════════════════════════════════════════════

func _on_selector_changed(field_id: String, idx: int) -> void:
	var opts := _options_for(field_id)
	if idx < 0 or idx >= opts.size():
		return
	var opt_id := str((opts[idx] as Dictionary).get("id", ""))
	match field_id:
		"race":
			_state.race = opt_id
			_reset_body_skin()
			_refresh_body_layer()
			_rebind_skin_selector()
			_update_info_labels()
		"body":
			(_state["body"] as Dictionary)["style"] = opt_id
			_refresh_body_layer()
		_:
			(_state[field_id] as Dictionary)["style"] = opt_id
			_refresh_layer(field_id)

func _on_selector_color(field_id: String, color: Color) -> void:
	(_state[field_id] as Dictionary)["color"] = color
	_apply_layer_color(field_id)

func _set_sex(sex: String) -> void:
	_state["sex"] = sex
	_sex_male.button_pressed   = sex == "male"
	_sex_female.button_pressed = sex == "female"
	_validate_body_skin()
	_rebind_skin_selector()
	_refresh_all_layers()
	_update_info_labels()

func _on_turn(dir: int) -> void:
	_facing = (_facing + dir + FACING_ROWS.size()) % FACING_ROWS.size()
	_frame = FACING_ROWS[_facing] * 9
	_apply_frame()

func _on_cycle_scenery() -> void:
	if SCENERY.is_empty():
		return
	_scenery_idx = (_scenery_idx + 1) % SCENERY.size()
	var path: String = SCENERY[_scenery_idx]
	if not ResourceLoader.exists(path):
		return
	var tex := load(path)
	var t := create_tween()
	t.tween_property(_scenery_img, "modulate:a", 0.0, 0.18)
	t.tween_callback(func() -> void: _scenery_img.texture = tex)
	t.tween_property(_scenery_img, "modulate:a", 1.0, 0.22)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(LOGIN_SCENE)

func _on_confirm() -> void:
	if _state.name.strip_edges().is_empty():
		_state.name      = RANDOM_NAMES.pick_random()
		_name_input.text = _state.name
	# Salva no backend (fonte da verdade). Só entra no mundo se o save deu certo.
	_confirm_btn.disabled = true
	_confirm_btn.text = "SALVANDO…"
	var ok := await CharacterStore.save_character(_build_save_data())
	if not ok:
		_confirm_btn.disabled = false
		_confirm_btn.text = "✗ FALHA — TENTAR DE NOVO"
		return
	NetworkState.just_created_character = true
	_connect_to_world()

# Rebind do seletor de Pele quando raça/sexo mudam (a lista de tons muda).
func _rebind_skin_selector() -> void:
	var sel: Node = _selectors.get("body")
	if sel == null:
		return
	var skins := _current_skins()
	sel.set_options(skins)
	sel.set_index(_current_index("body", skins))

# ── Conexão com o mundo (IP mockado por enquanto, igual ao login) ──────────────
func _connect_to_world() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ServerConfig.server_host(), WORLD_PORT)
	if err != OK:
		_confirm_btn.text = "✗ FALHA AO CONECTAR (%d)" % err
		return
	multiplayer.multiplayer_peer = peer
	NetworkState.local_player_index = 1
	if not multiplayer.connected_to_server.is_connected(_on_world_connected):
		multiplayer.connected_to_server.connect(_on_world_connected, CONNECT_ONE_SHOT)
	if not multiplayer.connection_failed.is_connected(_on_world_failed):
		multiplayer.connection_failed.connect(_on_world_failed, CONNECT_ONE_SHOT)
	_confirm_btn.disabled = true
	_confirm_btn.text = "CONECTANDO…"

func _on_world_connected() -> void:
	if multiplayer.connection_failed.is_connected(_on_world_failed):
		multiplayer.connection_failed.disconnect(_on_world_failed)
	# Personagem recém-criado → sempre passa pelo onboarding (tutorial do Olho Arcano),
	# que ao terminar entra na cidade. O peer ENet persiste através da troca de cena.
	get_tree().change_scene_to_file(ONBOARDING_SCENE)

func _on_world_failed() -> void:
	if multiplayer.connected_to_server.is_connected(_on_world_connected):
		multiplayer.connected_to_server.disconnect(_on_world_connected)
	multiplayer.multiplayer_peer = null
	_confirm_btn.disabled = false
	_confirm_btn.text = "✗ NÃO FOI POSSÍVEL CONECTAR"

# Constrói o dicionário salvo com paths resolvidos e cores em hex.
func _build_save_data() -> Dictionary:
	var data := {}
	data["name"] = str(_state.get("name", ""))
	data["race"] = str(_state.get("race", ""))
	data["sex"]  = str(_state.get("sex",  ""))

	# Body — path do tom de pele selecionado
	var body_state := _state.get("body", {}) as Dictionary
	var skin_id    := str(body_state.get("style", ""))
	var body_path  := ""
	for s in _current_skins():
		if str(s.get("id", "")) == skin_id:
			body_path = str(s.get("path", ""))
			break
	data["body"] = { "style": skin_id, "path": body_path }

	# Demais categorias — path resolvido por sexo + cor em hex
	for cat_id in LAYER_FIELDS:
		var cat_state := _state.get(cat_id, {}) as Dictionary
		var style_id  := str(cat_state.get("style", ""))
		var style_d   := _find_style(cat_id, style_id)
		var path      := ""
		if not style_d.is_empty():
			if style_d.has("paths"):
				var paths := style_d.get("paths", {}) as Dictionary
				path = str(paths.get(str(_state.get("sex", "")), ""))
			else:
				path = str(style_d.get("path", ""))
		var color := cat_state.get("color", Color.WHITE) as Color
		data[cat_id] = {
			"style": style_id,
			"path":  path,
			"color": color.to_html(true),
		}
	return data

# ═══════════════════════════════════════════════════════════════════════════════
# PREVIEW
# ═══════════════════════════════════════════════════════════════════════════════

func _refresh_all_layers() -> void:
	_refresh_body_layer()
	for cat in LAYER_FIELDS:
		_refresh_layer(cat)

func _refresh_body_layer() -> void:
	var sex_skins := _current_skins()
	var skin_id   := str((_state.get("body", {}) as Dictionary).get("style", ""))
	var path := ""
	for s in sex_skins:
		if str(s.get("id", "")) == skin_id:
			path = str(s.get("path", ""))
			break
	if path == "" and sex_skins.size() > 0:
		path = str(sex_skins[0].get("path", ""))
		(_state["body"] as Dictionary)["style"] = str(sex_skins[0].get("id", ""))
	if path == "" or not ResourceLoader.exists(path):
		_body_sprite.texture = null
		return
	_body_sprite.texture  = load(path)
	_body_sprite.hframes  = 9
	_body_sprite.vframes  = 4
	_body_sprite.frame    = _frame
	_body_sprite.modulate = Color.WHITE

func _refresh_layer(cat_id: String) -> void:
	var sprite := _get_sprite(cat_id)
	if not sprite:
		return
	var cat_state := _state.get(cat_id, {}) as Dictionary
	var style     := _find_style(cat_id, str(cat_state.get("style", "")))
	if style.is_empty():
		sprite.texture = null
		_apply_layer_color(cat_id)
		return
	var path: String
	if style.has("paths"):
		var sex   := str(_state.get("sex", "male"))
		var paths := style.get("paths", {}) as Dictionary
		path = str(paths.get(sex, ""))
	else:
		path = str(style.get("path", ""))
	if path == "" or not ResourceLoader.exists(path):
		sprite.texture = null
		_apply_layer_color(cat_id)
		return
	sprite.texture = load(path)
	sprite.hframes = 9
	sprite.vframes = 4
	sprite.frame   = _frame
	_apply_layer_color(cat_id)

func _apply_layer_color(cat_id: String) -> void:
	var sprite := _get_sprite(cat_id)
	if sprite:
		var cat_state := _state.get(cat_id, {}) as Dictionary
		sprite.modulate = cat_state.get("color", Color.WHITE) as Color

# Atualiza só o frame (vista) de todas as camadas — usado pelas setas de girar.
func _apply_frame() -> void:
	for s in [_body_sprite, _pants_sprite, _shoes_sprite, _chest_sprite, _hair_sprite, _beard_sprite]:
		if s and s.texture:
			s.frame = _frame

func _get_sprite(cat_id: String) -> Sprite2D:
	match cat_id:
		"body":  return _body_sprite
		"hair":  return _hair_sprite
		"beard": return _beard_sprite
		"chest": return _chest_sprite
		"legs":  return _pants_sprite
		"shoes": return _shoes_sprite
	return null

func _update_info_labels() -> void:
	var name_raw  := str(_state.get("name", ""))
	var name_txt  := name_raw if name_raw.strip_edges() != "" else "—"
	var race_data := _find_race(str(_state.get("race", "")))
	var race_txt  := str(race_data.get("label", "—")).to_upper()
	var sex_txt   := "MASCULINO" if _state.get("sex", "") == "male" else "FEMININO"
	_preview_name.text = name_txt
	_preview_race.text = "%s · %s" % [race_txt, sex_txt]

# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS DE DADOS
# ═══════════════════════════════════════════════════════════════════════════════

func _current_skins() -> Array:
	var race := _find_race(str(_state.get("race", "")))
	var skins := race.get("skins", {}) as Dictionary
	return skins.get(str(_state.get("sex", "male")), []) as Array

func _layer_color(field_id: String) -> Color:
	return (_state.get(field_id, {}) as Dictionary).get("color", Color.WHITE) as Color

func _find_race(race_id: String) -> Dictionary:
	for r in RACES:
		if r.id == race_id: return r
	return {}

func _find_style(cat_id: String, style_id: String) -> Dictionary:
	for s in _styles.get(cat_id, []):
		if s.id == style_id: return s
	return {}

func _reset_body_skin() -> void:
	var sex_skins := _current_skins()
	if sex_skins.size() > 0:
		(_state["body"] as Dictionary)["style"] = str(sex_skins[0].get("id", ""))

func _validate_body_skin() -> void:
	var sex_skins := _current_skins()
	var current   := str((_state.get("body", {}) as Dictionary).get("style", ""))
	for s in sex_skins:
		if str(s.get("id", "")) == current:
			return
	if sex_skins.size() > 0:
		(_state["body"] as Dictionary)["style"] = str(sex_skins[0].get("id", ""))

# ═══════════════════════════════════════════════════════════════════════════════
# AMBIENTE
# ═══════════════════════════════════════════════════════════════════════════════

func _animate_entrance() -> void:
	modulate.a = 0.0
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(self, "modulate:a", 1.0, 0.40)

# Sobe-desce sutil do personagem (idle bob).
func _start_bob() -> void:
	var base_y := _skeleton.position.y
	var tween := create_tween().set_loops().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_skeleton, "position:y", base_y - 10.0, 1.7)
	tween.tween_property(_skeleton, "position:y", base_y, 1.7)

# Mantém a música ambiente do lobby tocando na criação de personagem.
func _start_music() -> void:
	var path := "res://audio/theme/lobby_theme.mp3"
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStreamMP3
	if stream == null:
		return
	stream.loop = true
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.stream = stream
	add_child(_music)
	_music.play()
