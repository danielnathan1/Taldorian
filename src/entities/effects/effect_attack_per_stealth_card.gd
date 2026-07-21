# Dança das Lâminas — +bonus de ataque por carta furtiva jogada neste combate
# (inclui a própria carta, se ela for furtiva).
class_name EffectAttackPerStealthCard
extends CardEffect

var _bonus: int = 1

func setup(params: Dictionary) -> void:
	_bonus = params.get("bonus", 1)

func execute(ctx: CardEffectContext) -> void:
	var n := 0
	for c in ctx.source_player.cards_this_battle:
		if c.is_stealth:
			n += 1
	if n > 0:
		var total := _bonus * n
		ctx.source_player.pending_bonus_attack += total
		ctx.request_empower(total, 0)
