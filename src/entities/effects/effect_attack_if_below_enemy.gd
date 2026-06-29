# Sobrecarga Competitiva — se o ataque atual do seu herói ativo for menor que o do
# herói ativo inimigo, +1 de ataque. Compara o ataque TOTAL projetado dos dois lados
# de forma simétrica (current_attack já desconta o battle_attack_penalty de cada um).
class_name EffectAttackIfBelowEnemy
extends CardEffect

var _bonus: int = 1

func setup(params: Dictionary) -> void:
	_bonus = params.get("bonus", 1)

func execute(ctx: CardEffectContext) -> void:
	var me := ctx.source_player
	var opp := ctx.opponent_player
	if me.active_hero == null or opp.active_hero == null:
		return
	if me.current_attack() < opp.current_attack():
		me.pending_bonus_attack += _bonus
		ctx.request_empower(_bonus, 0)
