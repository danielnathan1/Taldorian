## scenes/ui/boardv2/dice_roll/dice_roll.gd
## Overlay da fase OPENING_ROLL: dados 3D (2d6 por jogador) num SubViewport sobre o
## tabuleiro. O jogador clica-e-arrasta para arremessar; ao soltar, os dados rolam
## em arco até o centro e param mostrando o valor.
##
## IMPORTANTE: o VALOR vem do servidor (RNG autoritativo). A física aqui é uma
## animação GUIADA — eu mapeio a orientação final de cada valor (REST_EULER), então
## a direção/força do arrasto só dão tempero (arco, giros, duração), nunca o resultado.
##
## Conduzido pelo board via sync:
##   setup(local_idx) → play_roll(player_idx, values, throw_vec) → show_winner_choice(...)
## Sinais: thrown(dir, force) ao soltar o arrasto; first_player_chosen(idx) na escolha.
class_name DiceRoll
extends Control

signal thrown(dir: Vector2, force: float)
signal first_player_chosen(idx: int)

# ── Tuning 3D (ajuste livre — não consigo ver o render daqui) ──────────────────
const DIE_HALF   := 0.4
const TABLE_Y    := 0.0
const CAM_POS    := Vector3(0.0, 7.5, 7.0)
const CAM_FOV    := 52.0
const MAX_DRAG   := 320.0   # px de arrasto = força máxima

# Posições (x, y, z). +z = perto da câmera (base da tela) = jogador local.
const START_LOCAL := [Vector3(-0.7, DIE_HALF, 4.4), Vector3(0.7, DIE_HALF, 4.4)]
const LAND_LOCAL  := [Vector3(-0.8, DIE_HALF, 1.1), Vector3(0.8, DIE_HALF, 1.1)]
const START_OPP   := [Vector3(-0.7, DIE_HALF, -4.4), Vector3(0.7, DIE_HALF, -4.4)]
const LAND_OPP    := [Vector3(-0.8, DIE_HALF, -1.1), Vector3(0.8, DIE_HALF, -1.1)]

# value → rotação de repouso (graus) que deixa a face do valor virada para cima.
# Faces do dado: +Y=1, -Y=6, +X=2, -X=5, +Z=3, -Z=4.
const REST_EULER := {
	1: Vector3(0, 0, 0),
	2: Vector3(0, 0, 90),
	3: Vector3(-90, 0, 0),
	4: Vector3(90, 0, 0),
	5: Vector3(0, 0, -90),
	6: Vector3(180, 0, 0),
}

const FACE_COLOR := Color(0.94, 0.93, 0.88)
const PIP_COLOR  := Color(0.10, 0.10, 0.13)

var _local_idx: int = 0
var _can_throw: bool = false
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO

var _sub: SubViewport
var _dice: Array = [[], []]   # [side 0=local, 1=opp][2 × Node3D]
var _pip_tex: Dictionary = {}

var _aim: Line2D
var _status: Label
var _choice_box: VBoxContainer
var _built: bool = false

# ── API pública ────────────────────────────────────────────────────────────────

func setup(local_idx: int) -> void:
	_local_idx = local_idx
	if not _built:
		_build()
		_built = true
	reset_for_reroll()

func set_can_throw(v: bool) -> void:
	_can_throw = v

## Anima os 2 dados de um jogador rolando até o centro e parando nos valores.
func play_roll(player_idx: int, values: Array, throw_vec: Vector2) -> void:
	if not _built or values.size() < 2:
		return
	var side := 0 if player_idx == _local_idx else 1
	var force := clampf(throw_vec.length() / MAX_DRAG, 0.25, 1.0)
	if throw_vec == Vector2.ZERO:
		force = 0.6
	var starts: Array = START_LOCAL if side == 0 else START_OPP
	var lands: Array  = LAND_LOCAL if side == 0 else LAND_OPP
	for k in 2:
		_animate_die(_dice[side][k], starts[k], lands[k], int(values[k]), force, float(k) * 0.08)

func show_winner_choice(local_is_winner: bool) -> void:
	if local_is_winner:
		_status.text = "Você venceu a rolagem! Quem começa?"
		_choice_box.visible = true
	else:
		_status.text = "Oponente venceu a rolagem — aguardando a escolha…"
		_choice_box.visible = false

func reset_for_reroll() -> void:
	_choice_box.visible = false
	_aim.visible = false
	_dragging = false
	for side in 2:
		var starts: Array = START_LOCAL if side == 0 else START_OPP
		for k in 2:
			var die: Node3D = _dice[side][k]
			die.position = starts[k]
			die.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	_status.text = "Arraste para arremessar seus dados"

func set_status(text: String) -> void:
	_status.text = text

# ── Construção ───────────────────────────────────────────────────────────────

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Fundo escurecido
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	for v in range(1, 7):
		_pip_tex[v] = _make_pip_texture(v)

	# SubViewport 3D
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)

	_sub = SubViewport.new()
	_sub.own_world_3d = true
	_sub.transparent_bg = true
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub.msaa_3d = Viewport.MSAA_4X
	svc.add_child(_sub)

	# Câmera + luz + ambiente
	var cam := Camera3D.new()
	cam.position = CAM_POS
	cam.look_at_from_position(CAM_POS, Vector3.ZERO, Vector3.UP)
	cam.fov = CAM_FOV
	_sub.add_child(cam)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55.0, -40.0, 0.0)
	key.light_energy = 1.2
	key.shadow_enabled = true
	_sub.add_child(key)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.03, 0.06)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.55, 0.7)
	e.ambient_light_energy = 0.6
	env.environment = e
	_sub.add_child(env)

	# 4 dados (2 por lado)
	for side in 2:
		var starts: Array = START_LOCAL if side == 0 else START_OPP
		_dice[side] = []
		for k in 2:
			var die := _make_die()
			die.position = starts[k]
			_sub.add_child(die)
			_dice[side].append(die)

	# UI (sobre o SubViewport)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 22)
	_status.add_theme_color_override("font_color", Color(0.95, 0.93, 0.8))
	_status.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_status.add_theme_constant_override("shadow_offset_y", 2)
	_status.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_status.offset_top = 28.0
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status)

	_aim = Line2D.new()
	_aim.width = 4.0
	_aim.default_color = Color(0.95, 0.85, 0.4, 0.85)
	_aim.visible = false
	add_child(_aim)

	_choice_box = VBoxContainer.new()
	_choice_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice_box.add_theme_constant_override("separation", 10)
	_choice_box.set_anchors_preset(Control.PRESET_CENTER)
	_choice_box.position = Vector2(-110.0, 60.0)
	_choice_box.custom_minimum_size = Vector2(220.0, 0.0)
	_choice_box.visible = false
	add_child(_choice_box)

	var btn_me := Button.new()
	btn_me.text = "Eu começo"
	btn_me.custom_minimum_size = Vector2(220.0, 40.0)
	btn_me.pressed.connect(func() -> void: first_player_chosen.emit(_local_idx))
	_choice_box.add_child(btn_me)

	var btn_opp := Button.new()
	btn_opp.text = "Oponente começa"
	btn_opp.custom_minimum_size = Vector2(220.0, 40.0)
	btn_opp.pressed.connect(func() -> void: first_player_chosen.emit(1 - _local_idx))
	_choice_box.add_child(btn_opp)

func _make_die() -> Node3D:
	var die := Node3D.new()
	# [value, position, rotation_degrees] — QuadMesh nasce no plano XY virado para +Z.
	var faces := [
		[3, Vector3(0, 0, DIE_HALF),  Vector3(0, 0, 0)],
		[4, Vector3(0, 0, -DIE_HALF), Vector3(0, 180, 0)],
		[2, Vector3(DIE_HALF, 0, 0),  Vector3(0, 90, 0)],
		[5, Vector3(-DIE_HALF, 0, 0), Vector3(0, -90, 0)],
		[1, Vector3(0, DIE_HALF, 0),  Vector3(-90, 0, 0)],
		[6, Vector3(0, -DIE_HALF, 0), Vector3(90, 0, 0)],
	]
	for f in faces:
		var qm := QuadMesh.new()
		qm.size = Vector2(DIE_HALF * 2.0, DIE_HALF * 2.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = _pip_tex[f[0]]
		mat.roughness = 0.5
		qm.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = qm
		mi.position = f[1]
		mi.rotation_degrees = f[2]
		die.add_child(mi)
	return die

func _animate_die(die: Node3D, start: Vector3, land: Vector3, value: int, force: float, delay: float) -> void:
	die.position = start
	die.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	var dur := lerpf(0.95, 1.55, force)
	var hop := lerpf(0.7, 1.5, force)

	# Posição: arco (lerp + parábola de altura) até o ponto de pouso.
	var pos_t := create_tween()
	if delay > 0.0:
		pos_t.tween_interval(delay)
	pos_t.tween_method(
		func(t: float) -> void:
			if not is_instance_valid(die):
				return
			var e := 1.0 - pow(1.0 - t, 3.0)
			var p := start.lerp(land, e)
			p.y += sin(t * PI) * hop
			die.position = p,
		0.0, 1.0, dur)

	# Rotação: gira muito durante o voo, depois assenta (slerp) na face do valor.
	var spins := Vector3(
		(4.0 + force * 5.0) * TAU * (1.0 if randf() < 0.5 else -1.0),
		(2.0 + force * 3.0) * TAU * (1.0 if randf() < 0.5 else -1.0),
		(3.0 + force * 4.0) * TAU * (1.0 if randf() < 0.5 else -1.0))
	var rest := Quaternion(Basis.from_euler(Vector3(
		deg_to_rad(REST_EULER[value].x),
		deg_to_rad(REST_EULER[value].y),
		deg_to_rad(REST_EULER[value].z))))
	var rot_t := create_tween()
	if delay > 0.0:
		rot_t.tween_interval(delay)
	rot_t.tween_property(die, "rotation", spins, dur * 0.78).as_relative() \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rot_t.tween_property(die, "quaternion", rest, dur * 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ── Arrasto ──────────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if not _can_throw:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_start = event.position
			_aim.visible = true
			_aim.points = PackedVector2Array([_drag_start, _drag_start])
		elif _dragging:
			_dragging = false
			_aim.visible = false
			var vec: Vector2 = event.position - _drag_start
			if vec.length() < 14.0:
				return
			var force := clampf(vec.length() / MAX_DRAG, 0.25, 1.0)
			_can_throw = false
			_status.text = "Rolando…"
			thrown.emit(vec, force)
	elif event is InputEventMouseMotion and _dragging:
		_aim.points = PackedVector2Array([_drag_start, event.position])

# ── Textura de pips (gerada em código) ───────────────────────────────────────

func _make_pip_texture(value: int, size: int = 128) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(FACE_COLOR)
	# borda sutil
	var border := Color(0.78, 0.76, 0.68)
	for i in size:
		img.set_pixel(i, 0, border); img.set_pixel(i, size - 1, border)
		img.set_pixel(0, i, border); img.set_pixel(size - 1, i, border)

	var lo := size * 0.26
	var mid := size * 0.5
	var hi := size * 0.74
	var layouts := {
		1: [[mid, mid]],
		2: [[lo, lo], [hi, hi]],
		3: [[lo, lo], [mid, mid], [hi, hi]],
		4: [[lo, lo], [hi, lo], [lo, hi], [hi, hi]],
		5: [[lo, lo], [hi, lo], [mid, mid], [lo, hi], [hi, hi]],
		6: [[lo, lo], [hi, lo], [lo, mid], [hi, mid], [lo, hi], [hi, hi]],
	}
	var r := size * 0.1
	for pip in layouts[value]:
		_draw_disc(img, pip[0], pip[1], r)
	return ImageTexture.create_from_image(img)

func _draw_disc(img: Image, cx: float, cy: float, r: float) -> void:
	var r2 := r * r
	var x0 := int(maxf(0.0, cx - r))
	var x1 := int(minf(float(img.get_width() - 1), cx + r))
	var y0 := int(maxf(0.0, cy - r))
	var y1 := int(minf(float(img.get_height() - 1), cy + r))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := float(x) - cx
			var dy := float(y) - cy
			if dx * dx + dy * dy <= r2:
				img.set_pixel(x, y, PIP_COLOR)
