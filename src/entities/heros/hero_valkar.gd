class_name HeroValkar
extends Hero

func _init() -> void:
	art_key          = "hero_valkar"
	hero_name        = "Valkar"
	hero_class       = HeroClass.GUARDIAN
	max_hp           = 11
	current_hp       = 11
	symbols_required.assign([GameSymbols.TERRA, GameSymbols.TERRA, GameSymbols.AGUA])
	skill_name       = "Escudo de Espinhos"
	skill_desc       = "Recebe metade da defesa atual como bônus de ataque"
	passive_name     = "Muro de Aço"
	passive_desc     = "Enquanto está na linha de frente, nenhum aliado pode ser alvo de dano direcionado"
	base_attack      = 0
	base_defense     = 3

## Passiva de linha de frente — Muro de Aço: protege os aliados de retaguarda de dano
## direcionado/direto (Chuva de Flechas, Mísseis Mágicos, alvo escolhido). NÃO é mais
## automática: a Valkar entra furtiva como qualquer herói e só ativa o Muro se o jogador
## quebrar a furtividade — na confirmação pós-seleção ou ao se revelar durante o turno.
## A própria Valkar continua sendo um alvo válido.
func protects_backline_from_targeting() -> bool:
	return is_alive() and wall_active

## Oferece a escolha de quebrar furtividade para ativar o Muro de Aço ao virar ativa.
func wants_frontline_confirm() -> bool:
	return is_alive()

## Ativa: Terra, Terra, Água → Valkar recebe metade de sua defesa base como bônus de ataque
func on_skill_activated(player: Player) -> void:
	var bonus := base_defense / 2
	player.pending_bonus_attack += bonus
	_skill_activated_this_battle = true
	GameBus.skill_activated.emit(self, skill_desc)
