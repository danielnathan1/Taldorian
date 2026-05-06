# scenes/cena_prototipo/combat_resolve/combat_resolve.gd
#
# Tela de resolução de combate.
# Exibe os dois heróis ativos, stats de ataque/defesa e anima o dano mútuo.
#
# USO — o board.gd chama show_resolve() logo ANTES de CombatResolver.resolve_round(),
# passando os totais já calculados. O sinal animation_finished é emitido ao clicar Continuar.
#
# show_resolve(hero0, hero1, dmg_to_0, dmg_to_1, atk0, def0, atk1, def1)
#   hero0 / hero1        : Hero — heróis ativos dos jogadores 0 e 1
#   dmg_to_0 / dmg_to_1  : int  — dano final que cada herói VAI receber
#   atk0 / def0          : int  — ataque e defesa totais do herói 0
#   atk1 / def1          : int  — ataque e defesa totais do herói 1
#
# NOTA: chame show_resolve() ANTES de apply_damage() para que as barras
# comecem no HP atual e animem a descida.

extends Control

# ── Sinal ──────────────────────────────────────────────────────────────────
signal animation_finished

# ── Referências de nó ──────────────────────────────────────────────────────
@onready var _slot_0      : HeroSlot = $Center/VBox/Row/Heroes/Col0/Slot0
@onready var _slot_1      : HeroSlot = $Center/VBox/Row/Heroes/Col1/Slot1
@onready var _name_0      : Label    = $Center/VBox/Row/Heroes/Col0/Stat0/Name0
@onready var _atk_0       : Label    = $Center/VBox/Row/Heroes/Col0/Stat0/Atk0
@onready var _def_0       : Label    = $Center/VBox/Row/Heroes/Col0/Stat0/Def0
@onready var _dmg_0       : Label    = $Center/VBox/Row/Heroes/Col0/Stat0/Dmg0
@onready var _name_1      : Label    = $Center/VBox/Row/Heroes/Col1/Stat1/Name1
@onready var _atk_1       : Label    = $Center/VBox/Row/Heroes/Col1/Stat1/Atk1
@onready var _def_1       : Label    = $Center/VBox/Row/Heroes/Col1/Stat1/Def1
@onready var _dmg_1       : Label    = $Center/VBox/Row/Heroes/Col1/Stat1/Dmg1
@onready var _result_lbl  : Label    = $Center/VBox/ResultLbl
@onready var _continue_btn: Button   = $Center/VBox/ContinueBtn

# ── Estado interno ─────────────────────────────────────────────────────────
var _busy: bool = false


func _ready() -> void:
	visible = false
	_continue_btn.visible = false
	_continue_btn.pressed.connect(_on_continue_pressed)
	_result_lbl.text = ""


# ──────────────────────────────────────────────────────────────────────────
## Ponto de entrada principal.
## Deve ser chamado com os dados de combate já calculados mas ANTES de
## aplicar o dano nos heróis (para a animação partir do HP atual).
func show_resolve(
	p_hero_0    : Hero,
	p_hero_1    : Hero,
	p_dmg_to_0  : int,
	p_dmg_to_1  : int,
	p_total_atk_0 : int,
	p_total_def_0 : int,
	p_total_atk_1 : int,
	p_total_def_1 : int,
) -> void:
	if _busy:
		return
	_busy = true

	# HP de partida para animação (ANTES do dano)
	var pre_hp_0 := p_hero_0.current_hp
	var pre_hp_1 := p_hero_1.current_hp
	# HP de chegada (APÓS o dano)
	var post_hp_0 := maxi(0, pre_hp_0 - p_dmg_to_0)
	var post_hp_1 := maxi(0, pre_hp_1 - p_dmg_to_1)

	# ─ Inicializa a tela ─
	_result_lbl.text = ""
	_continue_btn.visible = false
	_reset_stats_labels()
	visible = true
	modulate.a = 0.0

	# ─ Bind dos HeroSlots ─
	_slot_0.bind(p_hero_0)
	_slot_0.set_face_down(false)
	_slot_1.bind(p_hero_1)
	_slot_1.set_face_down(false)

	# Força as barras para o HP pré-dano (bind() já colocou o HP atual)
	_force_hp_bar(_slot_0, pre_hp_0, p_hero_0.max_hp)
	_force_hp_bar(_slot_1, pre_hp_1, p_hero_1.max_hp)

	# ─ Nomes ─
	_name_0.text = p_hero_0.hero_name
	_name_1.text = p_hero_1.hero_name

	# ─ Fade in ─
	var tw_fade := create_tween()
	tw_fade.tween_property(self, "modulate:a", 1.0, 0.35)
	await tw_fade.finished

	# ─ Revela stats do herói 0 ─
	await get_tree().create_timer(0.3).timeout
	_atk_0.text = "⚔  Ataque:  %d" % p_total_atk_0
	_fade_in(_atk_0)
	await get_tree().create_timer(0.2).timeout
	_def_0.text = "🛡  Defesa:  %d" % p_total_def_0
	_fade_in(_def_0)
	await get_tree().create_timer(0.22).timeout
	_dmg_0.text = "💥  Dano:  %d" % p_dmg_to_1    # herói 0 causa dano ao herói 1
	_fade_in(_dmg_0)

	# ─ Revela stats do herói 1 ─
	await get_tree().create_timer(0.28).timeout
	_atk_1.text = "⚔  Ataque:  %d" % p_total_atk_1
	_fade_in(_atk_1)
	await get_tree().create_timer(0.2).timeout
	_def_1.text = "🛡  Defesa:  %d" % p_total_def_1
	_fade_in(_def_1)
	await get_tree().create_timer(0.22).timeout
	_dmg_1.text = "💥  Dano:  %d" % p_dmg_to_0    # herói 1 causa dano ao herói 0
	_fade_in(_dmg_1)

	await get_tree().create_timer(0.55).timeout

	# ── ROUND 1: herói 0 ataca herói 1 ──
	await _play_strike(_slot_0, _slot_1, post_hp_1, p_hero_1.max_hp, p_dmg_to_1)

	await get_tree().create_timer(0.65).timeout

	# ── ROUND 2: herói 1 ataca herói 0 ──
	await _play_strike(_slot_1, _slot_0, post_hp_0, p_hero_0.max_hp, p_dmg_to_0)

	await get_tree().create_timer(0.4).timeout

	# ─ Resultado final ─
	var lines: Array[String] = []
	if post_hp_1 <= 0:
		lines.append("💀 %s foi derrotado!" % p_hero_1.hero_name)
	if post_hp_0 <= 0:
		lines.append("💀 %s foi derrotado!" % p_hero_0.hero_name)
	if lines.is_empty():
		lines.append(
			"%s: %d HP    |    %s: %d HP" % [
				p_hero_0.hero_name, post_hp_0,
				p_hero_1.hero_name, post_hp_1,
			]
		)
	_result_lbl.text = "\n".join(lines)
	_fade_in(_result_lbl)

	await get_tree().create_timer(0.4).timeout
	_continue_btn.visible = true
	_fade_in(_continue_btn)


# ──────────────────────────────────────────────────────────────────────────
## Anima um golpe completo: shake no atacante → flash → hit no defensor → HP desce.
func _play_strike(
	p_attacker : HeroSlot,
	p_defender : HeroSlot,
	p_post_hp  : int,
	p_max_hp   : int,
	p_damage   : int,
) -> void:
	await _shake(p_attacker)
	_screen_flash()
	_hit_flash(p_defender)
	_spawn_damage_float(p_defender, p_damage)

	if p_damage > 0:
		await _animate_hp_bar(p_defender, p_post_hp, p_max_hp)
	else:
		await get_tree().create_timer(0.35).timeout


# ── Helpers de animação ────────────────────────────────────────────────────

## Balança o nó horizontalmente simulando o impulso do ataque.
func _shake(node: Control) -> void:
	var orig := node.position
	var tw := create_tween()
	tw.tween_property(node, "position", orig + Vector2(11, 0), 0.05)
	tw.tween_property(node, "position", orig - Vector2( 8, 0), 0.05)
	tw.tween_property(node, "position", orig + Vector2( 6, 0), 0.05)
	tw.tween_property(node, "position", orig - Vector2( 3, 0), 0.04)
	tw.tween_property(node, "position", orig,                  0.04)
	await tw.finished


## Flash vermelho no slot que recebe o golpe.
func _hit_flash(slot: HeroSlot) -> void:
	var tw := create_tween()
	tw.tween_property(slot, "modulate", Color(2.8, 0.25, 0.25, 1.0), 0.07)
	tw.tween_property(slot, "modulate", Color.WHITE, 0.38)


## Overlay branco rápido sobre a tela inteira no momento do impacto.
func _screen_flash() -> void:
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.38)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.4)
	tw.tween_callback(flash.queue_free)


## Cria um Label de dano que flutua para cima e some sobre o slot defensor.
func _spawn_damage_float(slot: HeroSlot, p_damage: int) -> void:
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 34)

	if p_damage > 0:
		lbl.text = "−%d" % p_damage
		lbl.add_theme_color_override("font_color", Color(1.0, 0.22, 0.22, 1))
	else:
		lbl.text = "🛡 bloqueado"
		lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 1))

	add_child(lbl)

	# Aguarda 1 frame para o layout calcular o tamanho do slot
	await get_tree().process_frame

	var rect := slot.get_global_rect()
	lbl.size = Vector2(180, 50)
	lbl.global_position = Vector2(
		rect.get_center().x - 90.0,
		rect.get_center().y - 60.0
	)

	# Flutua para cima e desaparece
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 100.0, 1.3)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.3).set_delay(0.25)
	tw.tween_callback(lbl.queue_free)


## Anima a barra de HP descendo suavemente até o valor pós-dano.
func _animate_hp_bar(slot: HeroSlot, p_post_hp: int, p_max_hp: int) -> void:
	var bar  : ProgressBar = slot.hp_bar
	var lbl  : Label       = slot.hp_label
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(bar, "value", float(p_post_hp), 0.85)
	tw.tween_callback(func() -> void:
		lbl.text = "%d/%d" % [p_post_hp, p_max_hp]
	)
	await tw.finished


## Força os valores da barra de HP sem animação (usado na inicialização).
func _force_hp_bar(slot: HeroSlot, p_current: int, p_max_hp: int) -> void:
	var bar : ProgressBar = slot.hp_bar
	var lbl : Label       = slot.hp_label
	bar.max_value = p_max_hp
	bar.value     = float(p_current)
	bar.visible   = true
	lbl.text      = "%d/%d" % [p_current, p_max_hp]


## Anima a entrada de um nó com fade de alpha 0 → 1.
func _fade_in(node: CanvasItem) -> void:
	node.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", 1.0, 0.22)


## Reseta todas as labels de stats para "—" antes de exibir novos dados.
func _reset_stats_labels() -> void:
	for lbl: Label in [_atk_0, _def_0, _dmg_0, _atk_1, _def_1, _dmg_1]:
		lbl.text = "—"
		lbl.modulate.a = 1.0
	_result_lbl.modulate.a = 1.0
	_name_0.modulate.a = 1.0
	_name_1.modulate.a = 1.0


# ── Botão Continuar ────────────────────────────────────────────────────────
func _on_continue_pressed() -> void:
	_continue_btn.visible = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	await tw.finished
	visible = false
	_busy = false
	animation_finished.emit()
