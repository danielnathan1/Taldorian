# src/entities/card.gd
class_name Card
extends RefCounted

enum TimingType { ACTION, BONUS_ACTION, REACTION }
enum Rarity { COMMON, RARE, LEGENDARY, MYSTIC }

var id: int = 0
var card_name: String
var timing: TimingType = TimingType.ACTION
var rarity: Rarity = Rarity.COMMON
var attack_value: int  = 0   # contribuição ao ataque (pode ser negativo)
var defense_value: int = 0   # contribuição à defesa (pode ser negativo)
## IDs de símbolo (`String`, ex.: GameSymbols.FOGO); um ou N por carta.
var symbols: Array[String] = []
var is_stealth: bool = false  # carta furtiva não revela herói
var is_heal: bool = false     # carta temática de cura — dispara VFX de cura ao ser jogada
var is_foil: bool = false     # cosmético — versão holográfica; flag vem do backend (booster/inventário)
var art_key: String = ""
var description: String = ""
var effects: Array[CardEffect] = []


## Aceita `Array` "solto" e normaliza para `Array[String]` válido.
func set_symbols(ids: Array) -> void:
	symbols = GameSymbols.filter_valid(ids)

func get_symbol_ids() -> Array[String]:
	return symbols.duplicate()

func symbols_display() -> String:
	return GameSymbols.display_chain(symbols)

func get_texture() -> Texture2D:
	return CardArt.texture_for(art_key)

func execute_pre_window_effects(ctx: CardEffectContext) -> void:
	for effect in effects:
		effect.pre_window_execute(ctx)

func execute_effects(ctx: CardEffectContext) -> void:
	for effect in effects:
		# Efeitos AFTER_TURN são enfileirados pelo GameState e resolvidos após o
		# combate (resolve_after_combat); não rodam no fechamento da janela de reação.
		if effect.timing == CardEffect.Timing.AFTER_TURN:
			continue
		effect.execute(ctx)

## Dispara os efeitos com gatilho de descarte desta carta (ex.: Descarga Residual).
func execute_discard_effects(player: Player) -> void:
	for effect in effects:
		effect.on_discarded(player)

## Efeitos desta carta marcados para resolver após o combate do turno.
func after_combat_effects() -> Array[CardEffect]:
	var out: Array[CardEffect] = []
	for effect in effects:
		if effect.timing == CardEffect.Timing.AFTER_TURN:
			out.append(effect)
	return out

## Descrição dos valores para a UI.
func values_display() -> String:
	var parts: Array[String] = []
	if attack_value != 0:
		parts.append("ATK %+d" % attack_value)
	if defense_value != 0:
		parts.append("DEF %+d" % defense_value)
	return " / ".join(parts) if not parts.is_empty() else "0"

static func from_dict(data: Dictionary) -> Card:
	var c := Card.new()
	c.id           = data.get("id", 0)
	c.card_name    = data.get("name", "")
	c.timing       = TimingType[data.get("timing", "ACTION").to_upper()]
	c.attack_value = data.get("attack_value", 0)
	c.defense_value = data.get("defense_value", 0)
	c.set_symbols(data.get("symbols", []))
	c.is_stealth   = data.get("stealth", false)
	c.is_heal      = data.get("is_heal", false)
	c.is_foil      = data.get("is_foil", false)
	c.art_key      = data.get("art_key", "")
	c.description  = data.get("description", "")
	c.rarity       = Rarity[data.get("rarity", "COMMON").to_upper()]
	for entry in data.get("effects", []):
		var eff := CardEffectRegistry.create(entry.get("id", ""), entry)
		if eff != null:
			c.effects.append(eff)
	return c
