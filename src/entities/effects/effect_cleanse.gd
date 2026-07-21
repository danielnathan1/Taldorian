# Purificar (Reflexo Líquido) — remove todas as Queimaduras dos seus heróis.
# Contrajogo direto ao arquétipo de queimadura do Fogo.
class_name EffectCleanse
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	for h in ctx.source_player.heroes:
		h.clear_burn()
