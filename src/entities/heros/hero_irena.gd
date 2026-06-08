class_name HeroIrena
extends Hero

var _heal_bonus: int = 0

func _init() -> void:
	art_key          = "hero_irena"
	hero_name        = "Irena"
	hero_class       = HeroClass.CLERIC
	max_hp           = 9
	current_hp       = 9
	symbols_required.assign([GameSymbols.AGUA, GameSymbols.AGUA, GameSymbols.TERRA])
	skill_name       = "Toque Revigorante"
	skill_desc       = "Enquanto estiver ativa, todas as curas de Irena aumentam em +1"
	passive_name     = "Crescimento Natural"
	passive_desc     = "No final da batalha, Irena cura a si mesma e todos aliados em 1"
	base_attack      = 0
	base_defense     = 2
	passive_animation = "holy_heal"

func on_battle_start(player: Player) -> void:
	super(player)
	_heal_bonus = 0

## Ativa: Água, Água, Terra → curas de Irena ganham +1 até o final do turno
func on_skill_activated(player: Player) -> void:
	_heal_bonus = 1
	_skill_activated_this_battle = true
	GameBus.skill_activated.emit(self, skill_desc)

## Passiva: cura todos os heróis vivos do time em 1 (+bônus se ativa foi acionada).
## Retorna passive_desc para o GameState emitir o sinal via RPC (não emite aqui).
func on_battle_end(player: Player) -> String:
	if not is_alive():
		return ""
	var amount := 1 + _heal_bonus
	for h in player.heroes:
		if h.is_alive():
			h.heal(amount)
	return passive_desc
