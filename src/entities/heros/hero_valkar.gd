class_name HeroValkar
extends Hero

var _shield_available: bool = true

func _init() -> void:
	art_key          = "hero_valkar"
	hero_name        = "Valkar"
	hero_class       = HeroClass.GUARDIAN
	max_hp           = 10
	current_hp       = 10
	symbols_required.assign([GameSymbols.TERRA, GameSymbols.TERRA, GameSymbols.AGUA])
	skill_name       = "Escudo de Espinhos"
	skill_desc       = "Recebe metade da defesa atual como bônus de ataque"
	passive_name     = "Muro de Aço"
	passive_desc     = "Enquanto ativa, previne 1 de dano no primeiro ataque a um aliado por rodada"
	base_attack      = 0
	base_defense     = 3
	starts_face_up   = true

func on_turn_start(player: Player) -> void:
	super(player)
	_shield_available = true

func on_round_reset() -> void:
	_shield_available = true

## Para dano de área: reduz 1 de dano por herói atingido, sem consumir o escudo de combate.
func get_aoe_damage_reduction(ctx: BattleContext) -> int:
	if not is_alive():
		return 0
	if self != ctx.defender_player.active_hero:
		return 0
	GameBus.skill_activated.emit(self, passive_desc)
	return 1

## Passiva: reduz o primeiro dano sofrido por um aliado em 1 por rodada,
## mas somente enquanto Valkar for o herói ativo do time defensor.
func get_team_damage_reduction(ctx: BattleContext) -> int:
	if not is_alive():
		return 0
	if self != ctx.defender_player.active_hero:
		return 0
	if not _shield_available:
		return 0
	_shield_available = false
	GameBus.skill_activated.emit(self, passive_desc)
	return 1

## Ativa: Terra, Terra, Água → Valkar recebe metade de sua defesa base como bônus de ataque
func on_skill_activated(player: Player) -> void:
	var bonus := base_defense / 2
	player.pending_bonus_attack += bonus
	_skill_activated_this_turn = true
	GameBus.skill_activated.emit(self, skill_desc)
