class_name HeroDarian
extends Hero

## Darian — Ranger (Coleção "Ecos do Abismo"). Herói de RETAGUARDA: enquanto está na
## retaguarda, o jogador ativo pode gastar uma AÇÃO BÔNUS para jogar 3 Rosas Negras em
## heróis aleatórios do oponente (podem empilhar). A especial (Trevas·Ar·Trevas) explode
## todas as rosas: cada herói sofre 1 de dano por rosa; quem sofre ≥3 assim fica exausto.
const ABILITY_ROSES := "darian_roses"

func _init() -> void:
	art_key      = "hero_darian"
	hero_name    = "Darian"
	hero_class   = HeroClass.RANGER
	max_hp       = 10
	current_hp   = 10
	base_attack  = 1
	base_defense = 1
	collection   = "Ecos do Abismo"
	symbols_required.assign([GameSymbols.TREVAS, GameSymbols.AR, GameSymbols.TREVAS])
	skill_name   = "Jardim de Espinhos"
	skill_desc   = "Explode todas as Rosas Negras nos inimigos, cada rosa causa 1 de dano, se um inimigo sofrer 3 ou mais de dano dessa maneira ele fica *exausto*"
	passive_name = "Rosas Negras"
	passive_zone = "backline"
	passive_desc = "*Ação bônus*: jogue 3 *Rosas Negras* em heróis aleatórios do oponente"

## Habilidade de retaguarda ativável como AÇÃO BÔNUS pelo jogador ativo (from_backline:
## não revela o herói ativo nem abre janela de reação — ver action_activate_ability).
func get_backline_bonus_ability(_player: Player, _opponent: Player) -> Dictionary:
	if state != State.ACTIVE:
		return {}
	return {
		"id": ABILITY_ROSES,
		"label": "Jogar 3 Rosas Negras",
		"cost": "BONUS",
		"needs_target": false,
		"from_backline": true,
		"reveals_self": true,  # usar a habilidade quebra a furtividade do PRÓPRIO Darian
	}

func activate_ability(id: String, player: Player, opponent: Player, _targets: Array) -> String:
	match id:
		ABILITY_ROSES:
			var alive: Array[Hero] = opponent.heroes.filter(func(h: Hero) -> bool: return h.is_alive())
			if alive.is_empty():
				return ""
			# Sorteia 3 alvos (podem repetir), incrementa as rosas e coleta os índices
			# atingidos para o servidor anunciar o VFX aos dois clientes.
			var caster_idx: int = GameState.players.find(player)
			var source_hero_idx: int = player.heroes.find(self)
			var opp_idx: int = GameState.players.find(opponent)
			var fired: Array = []
			for _i in 3:
				var target: Hero = alive[randi() % alive.size()]
				target.black_roses += 1
				fired.append([opp_idx, opponent.heroes.find(target)])
			GameState.announce_roses_fired(caster_idx, source_hero_idx, fired)
			return "Jogou 3 Rosas Negras"
	return ""

## Especial (Trevas·Ar·Trevas): explode TODAS as rosas negras do campo. Cada herói sofre
## 1 de dano por rosa que carrega; quem sofre ≥3 de dano assim fica exausto. Depois, some
## com todas as rosas. Respeita o Muro de Aço (Valkar) para os heróis de retaguarda.
func on_skill_activated(player: Player) -> void:
	# Detona SÓ as rosas cravadas nos heróis INIMIGOS (as rosas só são plantadas no
	# oponente pela passiva; nunca em aliados). Coleta [player_idx, hero_idx, dmg]
	# para o VFX (rosas varrendo o campo + explosão de sangue por herói).
	var caster_idx := GameState.players.find(player)
	var opp_idx := 1 - caster_idx
	var opponent: Player = GameState.players[opp_idx]
	var detonated: Array = []
	for h in opponent.heroes:
		if h.black_roses <= 0:
			continue
		if not h.is_alive() or opponent.is_targeting_protected(h):
			h.black_roses = 0
			continue
		var ctx := TurnContext.new()
		ctx.attacker_player = player
		ctx.attacker = self
		ctx.defender_player = opponent
		ctx.defender = h
		var dealt := h.take_direct_damage(h.black_roses, ctx)  # respeita o escudo
		if dealt > 0:
			GameBus.hero_damaged.emit(h, dealt)
		detonated.append([opp_idx, opponent.heroes.find(h), dealt])
		if dealt >= 3:
			h.exhaust()
		h.black_roses = 0
	if not detonated.is_empty():
		GameState.announce_roses_detonated(caster_idx, detonated)
	_skill_activated_this_battle = true
	GameBus.skill_activated.emit(self, skill_desc)
