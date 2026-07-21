# Escudo persistente — concede um escudo que se re-aplica no início de cada turno, por
# `turns` turnos (ver Hero.grant_persistent_shield / GameState._tick_status_effects).
# Suporta condições opcionais (o "debuff/buff" que dura vários turnos):
#   condition == ""          → incondicional (Pequenos Riscos)
#   condition == "nth"       → só se esta for a N-ésima carta do turno (Encadeamento)
#   condition == "no_damage" → só se NÃO sofrer dano no turno; exige "timing": "after_turn"
#                              no JSON (resolve após o combate — Solo Firme)
class_name EffectPersistentShield
extends CardEffect

var _amount: int = 1
var _turns: int = 1
var _condition: String = ""
var _n: int = 0

func setup(params: Dictionary) -> void:
	_amount    = params.get("amount", 1)
	_turns     = params.get("turns", 1)
	_condition = params.get("condition", "")
	_n         = params.get("n", 0)

# INSTANT/AFTER_REACTION: incondicional ou condição "nth" (contagem no turno, inclui esta carta).
func execute(ctx: CardEffectContext) -> void:
	if _condition == "nth" and ctx.source_player.cards_this_battle.size() < _n:
		return
	_grant(ctx)

# AFTER_TURN: condição "no_damage" (dano já conhecido).
func resolve_after_combat(ctx: CardEffectContext) -> void:
	if _condition == "no_damage" and ctx.damage_taken > 0:
		return
	_grant(ctx)

func _grant(ctx: CardEffectContext) -> void:
	var h := ctx.source_player.active_hero
	if h == null:
		return
	h.grant_persistent_shield(_amount, _turns)
	ctx.request_vfx("shield")
