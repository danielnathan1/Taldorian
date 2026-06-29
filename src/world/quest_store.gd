# src/world/quest_store.gd
# Progresso de quests do jogador — fonte de verdade client-side. Hidratado do backend
# (no login / entrada no mundo) e cacheado em user:// como fallback offline/dev.
#
# A conclusão é AUTORITATIVA: atualiza o estado local na hora (resposta imediata) E
# persiste no backend, que — futuramente — concede a recompensa. "tutorial_done" não é
# um flag separado: é simplesmente a quest de onboarding com status COMPLETED.
#
# Autoload (Node, sem class_name). Depende do ApiClient só em runtime (hydrate/complete),
# nunca no _ready — por isso a ordem de carregamento não importa.
extends Node

signal quests_synced

const CACHE_FILE  := "user://quests.json"
const TUTORIAL_ID := "onboarding"

# quest_id (String) -> status (String): "IN_PROGRESS" | "COMPLETED"
var _status: Dictionary = {}

func _ready() -> void:
	_load_cache()

# ── Consulta ─────────────────────────────────────────────────────────────────────

func status_of(p_quest_id: String) -> String:
	return str(_status.get(p_quest_id, "NOT_STARTED"))

func is_completed(p_quest_id: String) -> bool:
	return status_of(p_quest_id) == "COMPLETED"

func is_tutorial_done() -> bool:
	return is_completed(TUTORIAL_ID)

# ── Sincronização com o backend ──────────────────────────────────────────────────

## Puxa o progresso do backend e popula o store. Chamar após login / ao entrar no mundo.
## Silencioso e seguro se o endpoint ainda não existir (res.ok == false → mantém o cache).
func hydrate() -> void:
	if not ApiClient.is_authenticated():
		return
	var res := await ApiClient.get_quests()
	if not res.get("ok", false) or not (res.get("data") is Array):
		return
	_status.clear()
	for q in res.data:
		if q is Dictionary and q.has("questId"):
			_status[str(q["questId"])] = str(q.get("status", "NOT_STARTED"))
	_save_cache()
	quests_synced.emit()

## Conclui a quest: atualiza o estado local imediatamente e persiste no backend
## (autoritativo, idempotente). Devolve a resposta do backend (recompensas, etc.).
func complete(p_quest_id: String) -> Dictionary:
	_status[p_quest_id] = "COMPLETED"
	_save_cache()
	quests_synced.emit()
	if ApiClient.is_authenticated():
		return await ApiClient.complete_quest(p_quest_id)
	return {}

# ── Cache local (user://) ────────────────────────────────────────────────────────

func _load_cache() -> void:
	if not FileAccess.file_exists(CACHE_FILE):
		return
	var f := FileAccess.open(CACHE_FILE, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_status = parsed

func _save_cache() -> void:
	var f := FileAccess.open(CACHE_FILE, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_status))
	f.close()
