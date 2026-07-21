# Perfuração (Corrente) — este ataque ignora até `amount` de defesa e escudo do alvo.
# Marca o modificador no jogador; o CombatResolver aplica na resolução do combate.
class_name EffectPierce
extends CardEffect

var _amount: int = 1

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func execute(ctx: CardEffectContext) -> void:
	ctx.source_player.pending_pierce += _amount
