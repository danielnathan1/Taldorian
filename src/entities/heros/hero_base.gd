# hero_base.gd
class_name HeroBase
extends RefCounted
enum State { ACTIVE, EXHAUSTED, DEFEATED }
enum HeroClass { TANK, DPS, UTILITY }

var hero_name: String
var max_hp: int
var current_hp: int
var hero_class: HeroClass
var state: State = State.ACTIVE
var symbols_required: Array[String] = []

func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)
	if current_hp == 0:
		state = State.DEFEATED

func is_alive() -> bool:
	return state != State.DEFEATED

func exhaust() -> void:
	if state == State.ACTIVE:
		state = State.EXHAUSTED

func refresh() -> void:
	if state == State.EXHAUSTED:
		state = State.ACTIVE

# "virtual" no GDScript — subclasse deve fazer override
func on_skill_activated(context: BattleContext) -> void:
	push_error("HeroBase.on_skill_activated() não implementado em " + hero_name)

func on_turn_start(context: BattleContext) -> void:
	pass  # opcional — subclasse faz override se quiser

func on_damage_taken(amount: int, context: BattleContext) -> int:
	return amount  # subclasse pode modificar (ex: Tank reduz dano
