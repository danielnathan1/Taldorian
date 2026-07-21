# Saraivada (Ieldor) — causa `amount` de dano direto a `count` heróis inimigos vivos
# aleatórios (distintos). Respeita o Muro de Aço (Valkar protege a retaguarda), o *Provocar*
# (Provocação puxa o dano) e a redução de dano de área. Ver GameState.deal_direct_damage_random.
class_name EffectRandomDirectDamage
extends CardEffect

var _amount: int = 1
var _count: int = 2

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)
	_count  = params.get("count", 2)

func execute(ctx: CardEffectContext) -> void:
	GameState.deal_direct_damage_random(ctx.opponent_player.player_index, _amount, _count)
