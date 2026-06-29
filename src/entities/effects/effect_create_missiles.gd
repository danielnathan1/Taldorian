# Salva de Mísseis — cria N Mísseis Mágicos (mesmo token do Nox). Disparados pela
# habilidade do herói ou consumidos por efeitos de token.
class_name EffectCreateMissiles
extends CardEffect

var _count: int = 1

func setup(params: Dictionary) -> void:
	_count = params.get("count", 1)

func execute(ctx: CardEffectContext) -> void:
	for _i in _count:
		ctx.source_player.tokens.append(TokenMagicMissile.new())
