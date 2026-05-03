# hero_kael.gd
class_name HeroGrok
extends Hero

func _init() -> void:
	art_key          = "hero_grok"
	hero_name        = "Grok, O carregador"
	hero_class       = HeroClass.BARBARIAN
	max_hp           = 10
	current_hp       = 10
	symbols_required.assign([GameSymbols.FOGO, GameSymbols.FOGO, GameSymbols.TERRA, GameSymbols.TERRA])
	skill_name       = "Golpe Devastador"
	skill_desc       = "+4 de dano"
	passive_name     = "Colossal"
	passive_desc     = "Reduz em 1 toda defesa recebida pelo oponente"
	base_attack      = 3
	base_defense     = 1

func on_skill_activated(player: Player) -> void:
	player.pending_bonus_attack += 4
	_skill_activated_this_turn = true
	GameBus.skill_activated.emit(self, skill_desc)
