# Provocação (Valkar) — *Provocar*: o herói ativo passa a puxar o dano DIRECIONADO ao seu
# time (mísseis, flecha de retaguarda, alvo aleatório) para si, por 1 turno. Inverso do Muro
# de Aço. Ver Player.redirect_target / Hero.taunt_active (resetado a cada turno).
class_name EffectTaunt
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	var h := ctx.source_player.active_hero
	if h != null and h.is_alive():
		h.taunt_active = true
