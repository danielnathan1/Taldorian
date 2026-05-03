# src/entities/card.gd
class_name Card
extends RefCounted

enum TimingType { ACTION, BONUS_ACTION, REACTION }

var card_name: String
var timing: TimingType = TimingType.ACTION
var attack_value: int  = 0   # contribuição ao ataque (pode ser negativo)
var defense_value: int = 0   # contribuição à defesa (pode ser negativo)
## IDs de símbolo (`String`, ex.: GameSymbols.FOGO); um ou N por carta.
var symbols: Array[String] = []
var is_stealth: bool = false  # carta furtiva não revela herói
var art_key: String = ""
var effects: Array[CardEffect] = []


## Aceita `Array` "solto" e normaliza para `Array[String]` válido.
func set_symbols(ids: Array) -> void:
	symbols = GameSymbols.filter_valid(ids)

func get_symbol_ids() -> Array[String]:
	return symbols.duplicate()

func symbols_display() -> String:
	return GameSymbols.display_chain(symbols)

func get_texture() -> Texture2D:
	var path := "res://assets/card/%s.png" % art_key
	if art_key != "" and ResourceLoader.exists(path):
		return load(path)
	return load("res://assets/card/place_holder.png")

func execute_pre_window_effects(ctx: CardEffectContext) -> void:
	for effect in effects:
		effect.pre_window_execute(ctx)

func execute_effects(ctx: CardEffectContext) -> void:
	for effect in effects:
		effect.execute(ctx)

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
	c.card_name    = data.get("name", "")
	c.timing       = TimingType[data.get("timing", "ACTION").to_upper()]
	c.attack_value = data.get("attack_value", 0)
	c.defense_value = data.get("defense_value", 0)
	c.set_symbols(data.get("symbols", []))
	c.is_stealth   = data.get("stealth", false)
	c.art_key      = data.get("art_key", "")
	for entry in data.get("effects", []):
		var eff := CardEffectRegistry.create(entry.get("id", ""), entry)
		if eff != null:
			c.effects.append(eff)
	return c
