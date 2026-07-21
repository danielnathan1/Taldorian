# Sacrifício genérico (Ecos) — o herói ativo paga `hp` de vida ao jogar a carta e, em troca,
# ganha `attack` de ataque no combate e/ou compra `draw` cartas. Custo de HP pode derrotar o
# próprio herói (é sacrifício). Ver Pacto de Sangue, Oferenda, Comunhão Dolorosa, Autoflagelo.
class_name EffectPayHp
extends CardEffect

var _hp: int = 0
var _attack: int = 0
var _draw: int = 0

func setup(params: Dictionary) -> void:
	_hp     = params.get("hp", 0)
	_attack = params.get("attack", 0)
	_draw   = params.get("draw", 0)

func execute(ctx: CardEffectContext) -> void:
	var h := ctx.source_player.active_hero
	if h == null:
		return
	if _hp > 0:
		var tctx := TurnContext.new()
		tctx.defender = h
		h.take_damage(_hp, tctx)
	if _attack > 0:
		ctx.source_player.pending_bonus_attack += _attack
	if _draw > 0:
		ctx.source_player.draw_cards(_draw)
		ctx.request_vfx("draw")
