# Salva de Mísseis — cria N Mísseis Mágicos (mesmo token do Nox). Disparados pela
# habilidade do herói ou consumidos por efeitos de token.
class_name EffectCreateMissiles
extends CardEffect

var _count: int = 1
# Se > 0 e o jogador JÁ controla ao menos 1 míssil, cria este número em vez de _count
# (Chuva de Estrelas: cria 1, ou 4 se já houver mísseis no campo).
var _count_if_has: int = 0

func setup(params: Dictionary) -> void:
	_count = params.get("count", 1)
	_count_if_has = params.get("count_if_has", 0)

func execute(ctx: CardEffectContext) -> void:
	var n := _count
	if _count_if_has > 0:
		for t in ctx.source_player.tokens:
			if t is TokenMagicMissile:
				n = _count_if_has
				break
	for _i in n:
		ctx.source_player.tokens.append(TokenMagicMissile.new())
