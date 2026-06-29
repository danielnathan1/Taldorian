# src/autoload/character_store.gd
# Personagem do mundo aberto. A FONTE DA VERDADE é o backend (/players/me/character via ApiClient);
# user://character.json é apenas um CACHE local de fallback (exibe algo se o backend estiver fora
# no boot). O resto do jogo continua lendo o cache em memória de forma síncrona.
#
# Mapeamento de nomenclatura: o cliente usa a chave "beard"; o backend usa "facialHair".
# A tradução fica isolada aqui (_to_api / _from_api) — o restante do código usa "beard".
extends Node

const CACHE_PATH := "user://character.json"

var _character: Dictionary = {}

func _ready() -> void:
	_load_cache()  # cache local de fallback; fetch() sobrescreve com o backend

# ── API pública ────────────────────────────────────────────────────────────────

func has_character() -> bool:
	return _character.size() > 0 and str(_character.get("name", "")).strip_edges() != ""

func get_character() -> Dictionary:
	return _character.duplicate(true)

## Busca a aparência no backend e atualiza o cache (memória + arquivo). Chamar no login,
## antes de decidir entre tela de criação e mundo. Retorna true se há personagem.
##   - ok      → popula o cache e persiste localmente.
##   - 404     → jogador ainda não tem personagem (limpa o cache).
##   - erro de rede → mantém o cache local já carregado no _ready (fallback offline).
func fetch() -> bool:
	var res := await ApiClient.get_character()
	if res.ok and res.data is Dictionary:
		_character = _from_api(res.data as Dictionary)
		_persist_cache()
		return has_character()
	if res.status == 404:
		_character = {}
		return false
	# Falha de transporte/servidor: preserva o que veio do cache local.
	push_warning("[CharacterStore] fetch falhou (%s) — usando cache local." % res.error)
	return has_character()

## Salva a aparência no backend (PUT). Em sucesso, atualiza o cache local. Retorna true se salvou.
func save_character(data: Dictionary) -> bool:
	var res := await ApiClient.save_character(_to_api(data))
	if not res.ok:
		push_error("[CharacterStore] save falhou: %s" % res.error)
		return false
	# Usa o estado devolvido pelo backend quando disponível; senão, o que enviamos.
	if res.data is Dictionary and not (res.data as Dictionary).is_empty():
		_character = _from_api(res.data as Dictionary)
	else:
		_character = data.duplicate(true)
	_persist_cache()
	return true

func clear() -> void:
	_character = {}
	if FileAccess.file_exists(CACHE_PATH):
		DirAccess.open("user://").remove("character.json")

# ── Tradução cliente ↔ backend ──────────────────────────────────────────────────

# Dict do cliente (chave "beard") → payload da API (chave "facialHair").
func _to_api(data: Dictionary) -> Dictionary:
	var out := {
		"name": str(data.get("name", "")),
		"race": str(data.get("race", "")),
		"sex":  str(data.get("sex", "")),
	}
	# Camadas: copia diretas + beard→facialHair. Só inclui o que existe no dict do cliente.
	for key in ["body", "hair", "chest", "legs", "shoes", "weapon", "backs"]:
		if data.has(key):
			out[key] = (data[key] as Dictionary).duplicate(true)
	if data.has("beard"):
		out["facialHair"] = (data["beard"] as Dictionary).duplicate(true)
	return out

# Payload da API (chave "facialHair") → dict do cliente (chave "beard"), removendo nulls.
func _from_api(data: Dictionary) -> Dictionary:
	var out := {
		"name": str(data.get("name", "")),
		"race": str(data.get("race", "")),
		"sex":  str(data.get("sex", "")),
	}
	for key in ["body", "hair", "chest", "legs", "shoes", "weapon", "backs"]:
		if data.has(key) and data[key] is Dictionary:
			out[key] = _clean_layer(data[key] as Dictionary)
	if data.has("facialHair") and data["facialHair"] is Dictionary:
		out["beard"] = _clean_layer(data["facialHair"] as Dictionary)
	return out

# Remove chaves com valor nulo (o backend devolve color=null para camadas sem cor),
# mantendo o dict no mesmo formato que o cliente produz localmente.
func _clean_layer(layer: Dictionary) -> Dictionary:
	var out := {}
	for k in layer:
		if layer[k] != null:
			out[k] = layer[k]
	return out

# ── Cache local (fallback) ───────────────────────────────────────────────────────

func _persist_cache() -> void:
	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if not file:
		push_error("[CharacterStore] Falha ao abrir %s para escrita" % CACHE_PATH)
		return
	file.store_string(JSON.stringify(_character, "\t"))
	file.close()

func _load_cache() -> void:
	if not FileAccess.file_exists(CACHE_PATH):
		return
	var file := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if not file:
		return
	var text := file.get_as_text()
	file.close()
	var result: Variant = JSON.parse_string(text)
	if result is Dictionary:
		_character = result
