class_name HeroHakai
extends Hero

var _was_stealth_at_combat_start: bool = false

func _init() -> void:
	art_key          = "hero_hakai"
	hero_name        = "Hakai"
	hero_class       = HeroClass.ROGUE
	max_hp           = 10
	current_hp       = 10
	symbols_required.assign([GameSymbols.AR, GameSymbols.AR, GameSymbols.AR])
	skill_name       = "Sombra Fugaz"
	skill_desc       = "Hakai se oculta novamente (fica furtivo)"
	passive_name     = "Golpe das Sombras"
	passive_desc     = "+1 de ataque permanente ao causar dano enquanto furtivo"
	base_attack      = 1
	base_defense     = 0

## Ativa: 3× Ar → torna Hakai furtivo novamente
func on_skill_activated(player: Player) -> void:
	GameState.set_hero_stealth(player.player_index)
	_skill_activated_this_turn = true
	GameBus.skill_activated.emit(self, skill_desc)

## Registra se Hakai está furtivo no início da resolução do combate
func on_before_attack(ctx: BattleContext) -> void:
	_was_stealth_at_combat_start = not GameState.get_hero_revealed(ctx.attacker_player.player_index)

## Passiva: se estava furtivo e causou dano → +1 de ataque permanente
func on_after_damage_dealt(damage: int, _ctx: BattleContext) -> void:
	if _was_stealth_at_combat_start and damage > 0:
		base_attack += 1
		GameBus.skill_activated.emit(self, passive_desc)
