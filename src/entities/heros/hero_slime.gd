class_name HeroSlime
extends Hero

# Slime — herói COLECIONÁVEL obtido por scan (Olho Arcano), não faz parte do pool padrão.
# Stats definidos (ATK 0 / DEF 0 / HP 2); a SKILL é PLACEHOLDER por enquanto — a identidade
# real será desenhada depois. Classe reusa WARRIOR (não há "criatura" no enum ainda).

func _init() -> void:
	art_key          = "hero_blue_slime"
	hero_name        = "Slime"
	hero_class       = HeroClass.WARRIOR
	max_hp           = 2
	current_hp       = 2
	base_attack      = 0
	base_defense     = 0
	symbols_required.assign([GameSymbols.AGUA, GameSymbols.AGUA])
	skill_name       = "Divisão"
	skill_desc       = "(placeholder) +1 de ataque"
	passive_name     = "Gelatinoso"
	passive_desc     = "(placeholder)"

## Skill placeholder — só para existir um efeito; será redesenhada depois.
func on_skill_activated(player: Player) -> void:
	player.pending_bonus_attack += 1
	_skill_activated_this_battle = true
	GameBus.skill_activated.emit(self, skill_desc)
