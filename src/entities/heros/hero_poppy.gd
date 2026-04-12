# hero_kael.gd
class_name HeroPoppy
extends Hero

func _init() -> void:
	art_key          = "hero_poppy"
	hero_name        = "Poppy, Martelo do Destino"
	hero_class       = HeroClass.DPS
	max_hp           = 1
	current_hp       = 1
	symbols_required = [GameSymbols.FOGO, GameSymbols.FOGO]
	skill_desc       = "Fogo·Fogo → +2 dano"

func on_skill_activated(ctx: BattleContext) -> void:
	print("Habilidade de %s ativada!" % hero_name)
	ctx.bonus_damage += 2
	GameBus.skill_activated.emit(self, skill_desc)