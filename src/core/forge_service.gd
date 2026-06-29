# Lógica pura da forja do Ferreiro (sem UI, sem rede). Porte adaptado do protótipo
# `ferreiro-data.js` para o nosso modelo de dados: cartas são DICTS do catálogo
# (`Collection.all_card_dicts`), com `id` (int) e `rarity` (string do backend).
#
# ⚠️ Raridades: o protótipo assumia 5 raridades de carta (Comum..Lendário). No nosso
# set base só existem COMMON, RARE e LEGENDARY (MYSTIC reservado). Mantemos os 4 TIERS
# de FORJA (cor da luz final), mas o tier `mistica` cai para a raridade mais alta
# disponível enquanto não houver cartas MYSTIC — ver `roll_result`.
class_name ForgeService
extends RefCounted

# Ordem dos tiers de forja (do mais fraco ao mais forte). Define a cor da luz no reveal.
const TIER_ORDER: Array[String] = ["comum", "rara", "lendaria", "mistica"]

const TIERS := {
	"comum": {
		"name": "Comum", "light": "Branca",
		"color": Color("eae7df"), "glow": Color("f3f1ea"), "deep": Color("c5c2b8"),
		"chromatic": false, "pool": ["COMMON"],
	},
	"rara": {
		"name": "Rara", "light": "Azul",
		"color": Color("3f8fe0"), "glow": Color("5aa3ec"), "deep": Color("2c5fb0"),
		"chromatic": false, "pool": ["RARE"],
	},
	"lendaria": {
		"name": "Lendária", "light": "Âmbar",
		"color": Color("e8b84a"), "glow": Color("f3cc5e"), "deep": Color("b88f30"),
		"chromatic": false, "pool": ["LEGENDARY"],
	},
	"mistica": {
		"name": "Mística", "light": "Cromática",
		"color": Color("c060d8"), "glow": Color("d97fe8"), "deep": Color("9040b0"),
		"chromatic": true, "pool": ["MYSTIC"],
	},
}

# ── Modelo de VALOR (tributo) ─────────────────────────────────────────────────
# Cada carta tributada vale um "valor de forja". Foil = +0.5× (×1.5 total). O valor
# total `P` empurra a distribuição para raridades maiores, por dois marcos:
#   P ≈ 20  (ex.: 20 comuns OU 1 rara)  → rara praticamente garantida, lendária baixa
#   P ≈ 400 (ex.: 20 raras)             → lendária quase garantida
const RARITY_VALUE := { "COMMON": 1.0, "RARE": 20.0, "LEGENDARY": 40.0, "MYSTIC": 80.0 }
const FOIL_MULT := 1.5
const VALUE_RARE_LOCK := 20.0    # P em que comum zera e rara domina
const VALUE_LEG_HIGH := 400.0    # P em que lendária fica quase garantida
const MAX_STONE_SLOTS := 20      # encaixes máximos da pedra-runa

# Custo em ouro que cada carta encaixada adiciona à forja (por raridade).
const RARITY_COST := { "COMMON": 1, "RARE": 6, "LEGENDARY": 24, "MYSTIC": 42 }
# Custo base fixo somado ao custo das cartas (forja aleatória).
const FORGE_BASE_COST := 6


# Valor de forja de uma carta (considera foil).
static func card_value(card: Dictionary) -> float:
	var base: float = float(RARITY_VALUE.get(str(card.get("rarity", "COMMON")), 1.0))
	if bool(card.get("is_foil", false)):
		base *= FOIL_MULT
	return base


# Soma do valor de forja das cartas encaixadas.
static func total_value(placed: Array) -> float:
	var p := 0.0
	for c in placed:
		p += card_value(c)
	return p


# placed: Array[Dictionary] — cartas do catálogo encaixadas (sem nulos).
# Retorna { comum, rara, lendaria, mistica } em % somando 100.0, dirigido pelo VALOR.
static func compute_odds(placed: Array, _max_slots: int = MAX_STONE_SLOTS) -> Dictionary:
	if placed.is_empty():
		return { "comum": 100.0, "rara": 0.0, "lendaria": 0.0, "mistica": 0.0 }

	var p := total_value(placed)
	# a: progresso até "travar" comum (0→1 conforme P vai de 0 a 20).
	var a: float = clampf(p / VALUE_RARE_LOCK, 0.0, 1.0)
	# b: progresso de rara→lendária (0→1 conforme P vai de 20 a 400).
	var b: float = clampf((p - VALUE_RARE_LOCK) / (VALUE_LEG_HIGH - VALUE_RARE_LOCK), 0.0, 1.0)

	var comum: float = (1.0 - a) * 100.0
	var remaining: float = 100.0 - comum
	# Místicas só raspam o topo (e ainda não dropam — fallback no roll).
	var mistica: float = remaining * 0.02 * b
	# Lendária tem um piso (5% do restante) que cresce até 93% quando P→400.
	var lendaria: float = remaining * (0.05 + 0.88 * b)
	var rara: float = maxf(0.0, remaining - lendaria - mistica)

	var total := comum + rara + lendaria + mistica
	var out := {
		"comum":    snappedf(comum    / total * 100.0, 0.1),
		"rara":     snappedf(rara     / total * 100.0, 0.1),
		"lendaria": snappedf(lendaria / total * 100.0, 0.1),
		"mistica":  snappedf(mistica  / total * 100.0, 0.1),
	}
	# Comum (ou rara, se comum já é 0) absorve o arredondamento para fechar 100.0.
	var sum: float = out.comum + out.rara + out.lendaria + out.mistica
	var slack := snappedf(100.0 - sum, 0.1)
	if out.comum > 0.0:
		out.comum = snappedf(out.comum + slack, 0.1)
	else:
		out.rara = snappedf(out.rara + slack, 0.1)
	return out


# Custo da forja aleatória: 0 se vazio; senão base + soma dos custos por raridade.
static func compute_cost(placed: Array) -> int:
	if placed.is_empty():
		return 0
	var cards := 0
	for c in placed:
		cards += int(RARITY_COST.get(str(c.get("rarity", "COMMON")), 10))
	return FORGE_BASE_COST + cards


# Sorteia um tier pelas chances e devolve uma carta aleatória do pool desse tier.
# Se o pool do tier estiver vazio (ex.: MYSTIC sem cartas), desce para o tier
# imediatamente inferior até achar cartas — a luz continua na cor sorteada.
static func roll_result(placed: Array, max_slots: int) -> Dictionary:
	var odds := compute_odds(placed, max_slots)
	var r := randf() * 100.0
	var acc := 0.0
	var tier_key := "comum"
	for k in TIER_ORDER:
		acc += float(odds[k])
		if r < acc:
			tier_key = k
			break

	var tier: Dictionary = TIERS[tier_key]
	var card := _pick_card_for_tier(tier_key)
	return { "tier_key": tier_key, "tier": tier, "card": card }


# Custo FIXO do ritual dirigido por raridade do alvo (espelha ForgeProperties.targetedCost).
const TARGETED_COST := { "COMMON": 10, "RARE": 40, "LEGENDARY": 100, "MYSTIC": 200 }

# Custo do ritual dirigido (carta-alvo escolhida): fixo pela raridade do alvo.
static func targeted_cost(target: Dictionary) -> int:
	if target.is_empty():
		return 0
	return int(TARGETED_COST.get(str(target.get("rarity", "COMMON")), 10))


# ── Internos ────────────────────────────────────────────────────────────────────

# Escolhe uma carta do pool do tier; faz fallback para tiers inferiores se vazio.
static func _pick_card_for_tier(tier_key: String) -> Dictionary:
	var start := TIER_ORDER.find(tier_key)
	for i in range(start, -1, -1):
		var pool: Array = TIERS[TIER_ORDER[i]].pool
		var candidates := _cards_in_pool(pool)
		if not candidates.is_empty():
			return candidates[randi() % candidates.size()]
	# Último recurso: qualquer carta do catálogo.
	var all: Array = Collection.all_card_dicts
	return all[randi() % all.size()] if not all.is_empty() else {}


static func _cards_in_pool(pool: Array) -> Array:
	var out: Array = []
	for d in Collection.all_card_dicts:
		if str(d.get("rarity", "COMMON")) in pool:
			out.append(d)
	return out
