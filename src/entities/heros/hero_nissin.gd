class_name HeroNissin
extends Hero

var _action_played: bool = false
var _bonus_played: bool = false
var _passive_bonus_active: bool = false

func _init() -> void:
	art_key          = "hero_nissin"
	hero_name        = "Nissin"
	hero_class       = HeroClass.MONK
	max_hp           = 10
	current_hp       = 10
	symbols_required.assign([GameSymbols.AR, GameSymbols.AR, GameSymbols.AGUA])
	skill_name       = "Passos Ágeis"
	skill_desc       = "Compra uma carta (ativa uma vez por turno)"
	passive_name     = "Fluxo Suave"
	passive_desc     = "Jogou ação + ação bônus: +1 de ataque até o fim do combate"
	base_attack      = 1
	base_defense     = 2

func on_turn_start(player: Player) -> void:
	super(player)
	_action_played = false
	_bonus_played = false
	_passive_bonus_active = false

## Passiva: rastreia ACTION e BONUS_ACTION para ativar o bônus de ataque
func on_card_played(card: Card, _player: Player) -> void:
	match card.timing:
		Card.TimingType.ACTION:
			_action_played = true
		Card.TimingType.BONUS_ACTION:
			_bonus_played = true
	_passive_bonus_active = _action_played and _bonus_played

func get_passive_attack_bonus() -> int:
	return 1 if _passive_bonus_active else 0

func on_before_attack(ctx: BattleContext) -> void:
	if _passive_bonus_active:
		ctx.bonus_damage += 1

## Ativa: Ar, Ar, Água → compra uma carta (chain só ativa uma vez por turno via _skill_activated_this_turn)
func on_skill_activated(player: Player) -> void:
	player.draw_cards(1)
	_skill_activated_this_turn = true
	GameBus.skill_activated.emit(self, skill_desc)
