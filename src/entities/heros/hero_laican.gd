class_name HeroLaican
extends Hero

## Lai'can — Barbarian (Coleção "Ecos do Abismo"). Bárbaro auto-destrutivo: quanto mais
## apanha, mais forte fica. A especial (Trevas·Trevas·Fogo) fere os DOIS heróis da
## frontline (o próprio e o do oponente), 2 vezes — o auto-dano alimenta a passiva.
var _permanent_attack_bonus: int = 0

func _init() -> void:
	art_key      = "hero_laican"
	hero_name    = "Lai'can"
	hero_class   = HeroClass.BARBARIAN
	max_hp       = 12
	current_hp   = 12
	base_attack  = -1
	base_defense = -1
	collection   = "Ecos do Abismo"
	symbols_required.assign([GameSymbols.TREVAS, GameSymbols.TREVAS, GameSymbols.FOGO])
	skill_name   = "Fúria das Trevas"
	skill_desc   = "Causa 1 de dano ambos heróis da linha de frente, 2 vezes"
	passive_name = "Sede de Dor"
	passive_desc = "Ao sofrer dano, ganha +1 de *ataque* permanente"

func get_passive_attack_bonus() -> int:
	return _permanent_attack_bonus

## Aplica o bônus permanente acumulado ao ataque do combate.
func on_before_attack(ctx: TurnContext) -> void:
	if _permanent_attack_bonus > 0:
		ctx.bonus_damage += _permanent_attack_bonus

## Passiva: ao sofrer dano (enquanto não exausto e vivo), +1 de ataque permanente.
## on_after_damage_taken só roda quando o herói SOBREVIVE ao dano (morto não ataca).
func on_after_damage_taken(_ctx: TurnContext) -> void:
	if state != State.EXHAUSTED and is_alive():
		_permanent_attack_bonus += 1
		# Notifica via GameState para o popup/VFX aparecer no servidor E nos clientes.
		GameState.notify_skill_activated(self, passive_desc)

## Especial (Trevas·Trevas·Fogo): 1 de dano ao herói ativo do próprio jogador E ao do
## oponente, repetido 2 vezes. O auto-dano dispara a passiva de Lai'can.
func on_skill_activated(player: Player) -> void:
	var opponent: Player = GameState.players[1 - player.player_index]
	for _i in 2:
		_hit_active(player, player)
		_hit_active(player, opponent)
	_skill_activated_this_battle = true
	GameBus.skill_activated.emit(self, skill_desc)

func _hit_active(attacker_player: Player, defender_player: Player) -> void:
	var target: Hero = defender_player.active_hero
	if target == null or not target.is_alive():
		return
	var ctx := TurnContext.new()
	ctx.attacker_player = attacker_player
	ctx.attacker = self
	ctx.defender_player = defender_player
	ctx.defender = target
	var dealt := target.take_direct_damage(1, ctx)  # respeita o escudo
	if dealt > 0:
		GameBus.hero_damaged.emit(target, dealt)
