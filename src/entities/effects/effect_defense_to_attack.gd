# Contra Ataque — converte toda a sua defesa (base + cartas da rodada + bônus pendentes)
# em ataque. A defesa convertida é anulada para o combate deste turno.
class_name EffectDefenseToAttack
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	var p := ctx.source_player
	var total_defense := p.pending_bonus_defense
	if p.active_hero != null:
		total_defense += p.active_hero.base_defense
	for card in p.turn_cards:
		total_defense += card.defense_value
	if total_defense <= 0:
		return
	p.pending_bonus_attack += total_defense
	# Anula a defesa convertida descontando do bônus pendente (a base/cartas são
	# compensadas pelo mesmo valor negativo).
	p.pending_bonus_defense -= total_defense
