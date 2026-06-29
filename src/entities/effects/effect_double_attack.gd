# Abrindo a Guarda — dobra seu ataque atual (base do herói + cartas da rodada + bônus
# pendentes). Implementado somando ao pending_bonus_attack o total atual.
class_name EffectDoubleAttack
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	var p := ctx.source_player
	var current := p.pending_bonus_attack + p.battle_bonus_attack
	if p.active_hero != null:
		current += p.active_hero.base_attack
	for card in p.turn_cards:
		current += card.attack_value
	if current > 0:
		p.pending_bonus_attack += current
