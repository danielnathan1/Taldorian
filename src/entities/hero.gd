# hero_base.gd
class_name Hero
extends RefCounted

enum State { ACTIVE, EXHAUSTED, DEFEATED }
enum HeroClass { TANK, DPS, UTILITY }

var art_key: String = "hero_default"
var hero_name: String
var hero_class: HeroClass
var max_hp: int
var current_hp: int
var state: State = State.ACTIVE
var symbols_required: Array[String] = []
var skill_desc: String

# ── hooks virtuais ──────────────────────────────────────
# Subclasse faz override APENAS dos que precisa.
# Todos têm implementação padrão segura (não fazem nada).

## Chamado quando a cadeia de símbolos é completada
func on_skill_activated(ctx: BattleContext) -> void:
	pass

## Chamado antes do dano ser aplicado — pode modificar o valor
func on_before_damage_taken(amount: int, ctx: BattleContext) -> int:
	return amount

## Chamado depois de receber dano (herói ainda vivo)
func on_after_damage_taken(ctx: BattleContext) -> void:
	pass

## Chamado no início do turno em que este herói foi escolhido
func on_turn_start(ctx: BattleContext) -> void:
	pass

## Chamado ao ser derrotado
func on_defeated(ctx: BattleContext) -> void:
	pass

# ── lógica base (não faz override disso) ────────────────
## O hook `on_before_damage_taken` é aplicado pelo CombatResolver antes de chamar isto.
func take_damage(amount: int, ctx: BattleContext) -> void:
	current_hp = max(0, current_hp - amount)
	if current_hp == 0:
		state = State.DEFEATED
		on_defeated(ctx)
		GameBus.hero_defeated.emit(self)
	else:
		on_after_damage_taken(ctx)

func exhaust() -> void:
	if state == State.ACTIVE:
		state = State.EXHAUSTED

func refresh() -> void:
	if state == State.EXHAUSTED:
		state = State.ACTIVE

func is_alive() -> bool:
	return state != State.DEFEATED

func hp_percent() -> float:
	return float(current_hp) / float(max_hp)

func get_texture() -> Texture2D: 
	print("Carregando arte de %s..." % hero_name)
	var path := "res://assets/heros/%s.png" % art_key
	var art := load(path)
	print(art)
	if ResourceLoader.exists(path):
		return load(path)
	return load("res://assets/heros/placeholder.png")
