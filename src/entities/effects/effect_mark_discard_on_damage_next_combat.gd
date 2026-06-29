# Estocada Marcante — se o herói ativo inimigo sofrer dano no PRÓXIMO combate, o oponente
# descarta uma carta.
# STUB: o gatilho cross-combat ainda não tem dispatch no GameState (ver plano, item C7).
# A carta funciona como baunilha (5/-3) até a mecânica ser implementada.
class_name EffectMarkDiscardOnDamageNextCombat
extends CardEffect

func execute(_ctx: CardEffectContext) -> void:
	push_warning("EffectMarkDiscardOnDamageNextCombat: gatilho cross-combat ainda não implementado (TODO C7)")
