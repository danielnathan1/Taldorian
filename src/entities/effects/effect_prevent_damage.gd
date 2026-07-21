# Esquiva (Desvio Rápido) — previne até `amount` de dano que o seu herói ativo sofreria
# neste combate. Marca o modificador no jogador; o CombatResolver aplica na resolução.
class_name EffectPreventDamage
extends CardEffect

var _amount: int = 1

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func execute(ctx: CardEffectContext) -> void:
	ctx.source_player.pending_damage_prevention += _amount
	ctx.request_vfx("shield")
