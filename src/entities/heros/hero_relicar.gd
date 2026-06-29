class_name HeroRelicar
extends Hero

## Relicar — Feiticeiro. Gera Fragmentos Arcanos por dois caminhos:
##  - Passiva (enquanto NÃO exausto, ativo ou na retaguarda): ao descartar uma
##    carta da mão, cria 1 fragmento.
##  - Habilidade ativa (só quando ATIVO): ao jogar 2 elementos DISTINTOS na
##    batalha, cria 2 fragmentos.
const FRAGMENT_ID := "arcane_fragment"

func _init() -> void:
	art_key      = "hero_relicar"
	hero_name    = "Relicar"
	hero_class   = HeroClass.SORCERER
	max_hp       = 10
	current_hp   = 10
	base_attack  = 0
	base_defense = 1
	# symbols_required fica vazio — o gatilho da skill é customizado (is_skill_triggered).
	skill_name   = "Ressonância Elemental"
	skill_desc   = "Jogue 2 elementos diferentes: crie 2 Fragmentos Arcanos"
	passive_name = "Coleta Arcana"
	passive_desc = "Enquanto não exausto: ao descartar uma carta, crie 1 Fragmento Arcano"

## Gatilho da skill ativa: pelo menos 2 símbolos DISTINTOS na cadeia da batalha.
func is_skill_triggered(chain: Array[String]) -> bool:
	var distinct := {}
	for s in chain:
		distinct[s] = true
	return distinct.size() >= 2

## Skill ativa (só roda no herói ativo): cria 2 Fragmentos Arcanos.
func on_skill_activated(player: Player) -> void:
	player.tokens.append(TokenArcaneFragment.new())
	player.tokens.append(TokenArcaneFragment.new())
	_skill_activated_this_battle = true
	GameBus.skill_activated.emit(self, skill_desc)

## Passiva: ao descartar uma carta (com Relicar não-exausto). O GameState já filtra
## para heróis com state == ACTIVE; cria 1 fragmento.
func on_card_discarded(_card: Card, player: Player) -> String:
	player.tokens.append(TokenArcaneFragment.new())
	return passive_desc

## Criar o fragmento é visível → revela o Relicar. O GameState confirma antes
## quando ele está furtivo (ativo oculto ou na retaguarda não revelada).
func discard_passive_reveals() -> bool:
	return true
