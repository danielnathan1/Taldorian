# Hemorragia — dobra o *Sangramento* (dano e duração) do herói ativo inimigo. Ver
# Hero.double_bleed.
class_name EffectDoubleBleed
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	var h := ctx.opponent_player.active_hero
	if h == null or not h.is_alive():
		return
	h.double_bleed()
