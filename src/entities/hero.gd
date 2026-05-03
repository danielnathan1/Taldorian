# hero_base.gd
class_name Hero
extends RefCounted

enum State { ACTIVE, EXHAUSTED, DEFEATED }
enum HeroClass { BARBARIAN, WARRIOR, MONK, ROGUE }

var art_key: String = "hero_default"
var hero_name: String
var hero_class: HeroClass
var max_hp: int
var current_hp: int
var state: State = State.ACTIVE
var symbols_required: Array[String] = []
var skill_name: String = "Habilidade Ativa"  # nome da habilidade ativa (chain)
var skill_desc: String = ""                  # descrição curta do efeito ativo
var passive_name: String = "Passiva"         # nome da habilidade passiva
var passive_desc: String = ""               # descrição curta do efeito passivo
var base_attack: int = 0
var base_defense: int = 0
var _skill_activated_this_turn: bool = false

# ── hooks virtuais ──────────────────────────────────────
# Subclasse faz override APENAS dos que precisa.
# Todos têm implementação padrão segura (não fazem nada).

## Chamado quando a cadeia de símbolos é completada (antes do combate)
func on_skill_activated(player: Player) -> void:
	pass

## Chamado antes do dano ser aplicado — pode modificar o valor
func on_before_damage_taken(amount: int, ctx: BattleContext) -> int:
	return amount

## Chamado depois de receber dano (herói ainda vivo)
func on_after_damage_taken(ctx: BattleContext) -> void:
	pass

## Chamado quando o herói é escolhido como ativo — reseta estado do turno
func on_turn_start(player: Player) -> void:
	_skill_activated_this_turn = false

## Chamado a cada carta adicionada ao jogo pelo jogador deste herói
func on_card_played(card: Card, player: Player) -> void:
	pass

## Chamado ao ser derrotado
func on_defeated(ctx: BattleContext) -> void:
	pass

## Chamado pelo CombatResolver após causar dano (pode ser 0) — permite passivas pós-dano
func on_after_damage_dealt(damage: int, ctx: BattleContext) -> void:
	pass

## Bônus de ataque da passiva para exibição em tempo real no UI.
## Subclasse faz override se tiver passiva que modifique ataque.
func get_passive_attack_bonus() -> int:
	return 0

## Chamado antes de calcular o ataque — pode modificar bonus_damage via passiva
func on_before_attack(ctx: BattleContext) -> void:
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
	var path := "res://assets/heros/%s.png" % art_key
	var art := load(path)
	if ResourceLoader.exists(path):
		return load(path)
	return load("res://assets/heros/placeholder.png")
