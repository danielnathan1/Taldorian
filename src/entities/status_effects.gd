## src/entities/status_effects.gd
## Fonte de verdade (reutilizável) dos EFEITOS DE STATUS NEGATIVOS que um herói pode
## carregar durante a partida. Cada entrada descreve o efeito do ponto de vista do herói
## AFETADO (diferente do passive_desc do causador, que descreve o custo/uso).
##
## Uso: StatusEffects.active_on(hero) -> Array[String] (ids ativos), e
##      StatusEffects.INFO[id] -> { "label", "desc", "icon" } para popular a UI.
## A arte dos ícones é placeholder por ora (ver plano).
class_name StatusEffects

const SEAL := "sealed_ruin"
const BURN := "burn"
const POISON := "poison"
const BLEED := "bleed"
const MARK := "mark"
const WOUND := "wound"
const SILENCE := "silence"

static var INFO := {
	SEAL: {
		"label": "Selo da Ruína",
		"desc": "Sempre que sofrer dano, bane metade desse dano (arredondado para baixo) em cartas do topo do deck (mín. 1).",
		"icon": "res://assets/icons/elements/dark.png",   # placeholder
	},
	BURN: {
		"label": "Queimadura",
		"desc": "No final de cada turno, o herói perde vida. Some quando os turnos de queimadura acabam.",
		"icon": "res://assets/icons/elements/fire.png",
	},
	POISON: {
		"label": "Veneno",
		"desc": "Enquanto envenenado, o herói tem sua defesa reduzida no combate (−1 por turno de veneno acumulado). Perde 1 turno por rodada.",
		"icon": "res://assets/icons/elements/dark.png",   # placeholder
	},
	BLEED: {
		"label": "Sangramento",
		"desc": "Ao atacar/causar dano, o herói perde vida. Dura alguns turnos.",
		"icon": "res://assets/icons/elements/dark.png",   # placeholder
	},
	MARK: {
		"label": "Marca",
		"desc": "Enquanto marcado, o herói recebe dano adicional a cada golpe.",
		"icon": "res://assets/icons/elements/dark.png",   # placeholder
	},
	WOUND: {
		"label": "Ferida",
		"desc": "Enquanto ferido, o herói não pode ser curado.",
		"icon": "res://assets/icons/elements/dark.png",   # placeholder
	},
	SILENCE: {
		"label": "Silêncio",
		"desc": "Enquanto silenciado, o herói ativo não ativa habilidades nem a skill de cadeia.",
		"icon": "res://assets/icons/elements/dark.png",   # placeholder
	},
}

## Ids de status negativos atualmente ativos no herói, na ordem de exibição.
static func active_on(hero: Hero) -> Array[String]:
	var ids: Array[String] = []
	if hero == null:
		return ids
	if hero.sealed_ruin:
		ids.append(SEAL)
	if hero.burn_turns > 0:
		ids.append(BURN)
	if hero.poison_turns > 0:
		ids.append(POISON)
	if hero.bleed_turns > 0:
		ids.append(BLEED)
	if hero.mark_turns > 0:
		ids.append(MARK)
	if hero.wound_turns > 0:
		ids.append(WOUND)
	if hero.silence_turns > 0:
		ids.append(SILENCE)
	return ids
