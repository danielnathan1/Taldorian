# src/core/symbol_chain.gd
class_name SymbolChain
extends RefCounted

const MAX_CHAIN := 3

var _chain: Array[String] = []

func add_symbol(symbol: String) -> bool:
	if _chain.size() >= MAX_CHAIN:
		return false
	_chain.append(symbol)
	return true

func matches(required: Array[String]) -> bool:
	return matches_chain(_chain, required)

## Verifica se `required` aparece como subsequência contígua em `chain` (ex.: combate a partir das cartas de ataque).
static func matches_chain(chain: Array[String], required: Array[String]) -> bool:
	if required.is_empty():
		return false
	if required.size() > chain.size():
		return false
	for i in chain.size() - required.size() + 1:
		if chain.slice(i, i + required.size()) == required:
			return true
	return false

func get_chain() -> Array[String]:
	return _chain.duplicate()

func reset() -> void:
	_chain.clear()
