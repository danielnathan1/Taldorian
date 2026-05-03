class_name HeroPoppy
extends Hero

var _passive_active: bool = false

func _init() -> void:
	art_key          = "hero_poppy"
	hero_name        = "Poppy, Martelo do Destino"
	hero_class       = HeroClass.BARBARIAN
	max_hp           = 10
	current_hp       = 10
	symbols_required.assign([GameSymbols.TERRA, GameSymbols.TERRA, GameSymbols.FOGO])
	skill_name       = "Impacto Sísmico"
	skill_desc       = "+3 de ataque"
	passive_name     = "Ataque Descuidado"
	passive_desc     = "Enquanto Poppy não aumentar sua defesa, o ataque dela recebe +1"
	base_attack      = 2
	base_defense     = 1

## Herói entrou em campo: nenhuma carta jogada ainda, passiva começa ativa
func on_turn_start(player: Player) -> void:
	super(player)
	_passive_active = true

## Reavalia a passiva a cada carta jogada na rodada
func on_card_played(_card: Card, player: Player) -> void:
	for c in player.round_cards:
		if c.defense_value > 0:
			_passive_active = false
			return
	_passive_active = true

func get_passive_attack_bonus() -> int:
	return 1 if _passive_active else 0

## Passiva: se nenhuma carta de defesa foi jogada, ganha +1 de ataque
func on_before_attack(ctx: BattleContext) -> void:
	if _passive_active:
		ctx.bonus_damage += 1

## Ativa: Terra, Terra, Fogo → +3 de ataque (disparada ao completar a cadeia)
func on_skill_activated(player: Player) -> void:
	player.pending_bonus_attack += 3
	_skill_activated_this_turn = true
	GameBus.skill_activated.emit(self, skill_desc)
