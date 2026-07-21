# src/autoload/api_client.gd
# Camada HTTP central de comunicação com o backend (taldorian-service).
# Todas as chamadas REST ao serviço externo passam por aqui.
#
# ┌──────────────────────────────────────────────────────────────────────────┐
# │ BASE_URL — endereço do serviço. MOCKADO em localhost:8080 por enquanto.   │
# │ >>> TROCAR AQUI quando o serviço subir em outro host/porta. <<<           │
# └──────────────────────────────────────────────────────────────────────────┘
#
# Uso (corrotina — sempre com await):
#   var res := await ApiClient.register(user, email, pwd)
#   if res.ok: ...   else: print(res.error)
#
# Formato do retorno de toda requisição:
#   { "ok": bool, "status": int, "data": Dictionary, "error": String }
extends Node

# Endereço do backend — resolvido por AMBIENTE (ver ServerConfig): localhost no editor
# e no servidor dedicado; IP da VM no build exportado do cliente.
var base_url: String = ServerConfig.api_base_url()

const _TIMEOUT_SECONDS := 15.0

# ── Sessão (tokens de autenticação) ────────────────────────────────────────────
# Mantidos em memória durante a sessão. Toda requisição passa a enviar
# automaticamente "Authorization: Bearer <access_token>" quando houver token.
var access_token: String = ""
var refresh_token: String = ""

## Credencial de SERVIÇO (server-to-server) para endpoints que o servidor de mundo
## chama em nome dos jogadores — ex.: efetivar troca (POST /trades). Vem do ambiente
## (TALDORIAN_SERVICE_TOKEN); fica vazio nos clientes/dev (sem efetivação real).
var service_token: String = ""

const SERVICE_TOKEN_FILE := "user://service_token.txt"

func _ready() -> void:
	# Token de serviço (servidor de mundo), por ordem de prioridade:
	#   1. env TALDORIAN_SERVICE_TOKEN
	#   2. arg de linha de comando --service-token=XYZ (após o "--")
	#   3. arquivo user://service_token.txt  (NÃO versionar; fica fora do export do cliente)
	# NÃO colocar o token num arquivo em res:// — isso vaza pro executável dos jogadores.
	service_token = OS.get_environment("TALDORIAN_SERVICE_TOKEN")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--service-token="):
			service_token = arg.trim_prefix("--service-token=")
	if service_token == "":
		service_token = _read_service_token_file()

	if service_token != "":
		print("[ApiClient] Token de serviço configurado — trocas chamarão /trades.")
	else:
		print("[ApiClient] SEM token de serviço — esta instância não efetiva trocas no backend.")

func _read_service_token_file() -> String:
	if not FileAccess.file_exists(SERVICE_TOKEN_FILE):
		return ""
	var f := FileAccess.open(SERVICE_TOKEN_FILE, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text().strip_edges()
	f.close()
	return t

func is_authenticated() -> bool:
	return access_token != ""

## Limpa a sessão (chamar no logout).
func clear_tokens() -> void:
	access_token = ""
	refresh_token = ""

func _store_tokens(p_data: Dictionary) -> void:
	if p_data.has("accessToken"):
		access_token = str(p_data["accessToken"])
	if p_data.has("refreshToken"):
		refresh_token = str(p_data["refreshToken"])

# ── Endpoints de autenticação ─────────────────────────────────────────────────

## POST /auth/register — cadastra um novo usuário.
func register(p_username: String, p_email: String, p_password: String) -> Dictionary:
	var body := {
		"username": p_username,
		"email":    p_email,
		"password": p_password,
	}
	var res := await _post("/auth/register", body)
	if res.ok:
		_store_tokens(res.data)
	return res

## POST /auth/login — autentica um usuário existente.
func login(p_username: String, p_password: String) -> Dictionary:
	var body := {
		"username": p_username,
		"password": p_password,
	}
	var res := await _post("/auth/login", body)
	if res.ok:
		_store_tokens(res.data)
	return res

# ── Jogador ─────────────────────────────────────────────────────────────────────

## GET /players/me — perfil do jogador (id, username, email, role, gold).
## Cacheia o id (UUID) em NetworkState.player_id e o role (PLAYER/ADMIN) para uso
## posterior (ex.: trocas, ferramentas de teste do ADMIN).
func get_me() -> Dictionary:
	var res := await _http_get("/players/me")
	if res.ok and res.data is Dictionary:
		var data := res.data as Dictionary
		var id := str(data.get("id", ""))
		if id != "":
			NetworkState.player_id = id
		NetworkState.role = str(data.get("role", "PLAYER"))
	return res

# ── Personagem do mundo (aparência) ─────────────────────────────────────────────

## GET /players/me/character — aparência do personagem do mundo aberto.
## status 404 (res.ok == false, res.status == 404) significa "sem personagem ainda".
func get_character() -> Dictionary:
	return await _http_get("/players/me/character")

## PUT /players/me/character — cria ou atualiza a aparência do personagem.
func save_character(p_payload: Dictionary) -> Dictionary:
	return await _put("/players/me/character", p_payload)

# ── Catálogo (loja) ─────────────────────────────────────────────────────────────

## GET /catalog/collections — coleções disponíveis na loja (metadados). res.data é um Array.
func get_collections() -> Dictionary:
	return await _http_get("/catalog/collections")

# ── Boosters ────────────────────────────────────────────────────────────────────

## POST /boosters/open — abre um pacote da coleção. O backend valida o ouro, desconta
## e devolve { collectionId, goldSpent, remainingGold, cards: [...] }.
func open_booster(p_collection_id: String) -> Dictionary:
	return await _post("/boosters/open", { "collectionId": p_collection_id })

# ── Forja (Ferreiro) ─────────────────────────────────────────────────────────────

## POST /forge/random — forja aleatória. O backend valida posse/ouro, consome as
## oferendas, sorteia a carta (faixa decidida pelo VALOR das oferendas) e devolve a
## carta criada (campos achatados) + { goldSpent, remainingGold, tierKey }.
## offerings: Array de { cardId (UUID), quantity, foilQuantity }.
func forge_random(p_offerings: Array) -> Dictionary:
	return await _post("/forge/random", { "offerings": p_offerings })

## POST /forge/targeted — ritual dirigido. Materializa a carta-alvo; exige 10 oferendas
## da MESMA raridade do alvo. Devolve a carta achatada + { goldSpent, remainingGold }.
func forge_targeted(p_target_card_id: String, p_offerings: Array) -> Dictionary:
	return await _post("/forge/targeted", { "targetCardId": p_target_card_id, "offerings": p_offerings })

# ── Inventário / Coleção do jogador ────────────────────────────────────────────

## GET /players/me/inventory — heróis, cartas e playmats que o jogador possui.
## Requer autenticação (o header Authorization é anexado automaticamente).
func get_inventory() -> Dictionary:
	return await _http_get("/players/me/inventory")

# ── Troca entre jogadores ───────────────────────────────────────────────────────

## POST /trades — efetiva uma troca já negociada e aceita por ambos os jogadores.
## O backend é a autoridade da transferência: valida posse das cartas/ouro e faz o
## swap entre os dois inventários. O payload carrega as duas ofertas (itens + ouro).
## TODO: implementar o endpoint no taldorian-service. Por ora retorna ok=false para
## que a UI conclua a negociação sem alterar inventário (sem wallet/transfer ainda).
func finalize_trade(p_payload: Dictionary) -> Dictionary:
	# Chamado pelo SERVIDOR DE MUNDO (autoridade) com a credencial de serviço.
	return await _request(HTTPClient.METHOD_POST, "/trades", p_payload, true)

## true quando há credencial de serviço (servidor de mundo configurado). Os clientes
## e o ambiente de dev têm isso vazio → a troca conclui sem transferência real.
func has_service_credential() -> bool:
	return service_token != ""

# ── Rankeada ──────────────────────────────────────────────────────────────────

## POST /ranked/result — reporta o resultado de uma partida rankeada (server-to-server).
## Chamado pelo SERVIDOR DEDICADO (autoridade) com a credencial de serviço. O backend
## recalcula o ranking dos dois jogadores. Payload: { clientMatchId, winnerId, loserId }.
## clientMatchId é a chave de idempotência (reportar de novo não recalcula).
func report_ranked_result(p_payload: Dictionary) -> Dictionary:
	return await _request(HTTPClient.METHOD_POST, "/ranked/result", p_payload, true)

## GET /players/me/ranked — posição rankeada do jogador (tier, pontos, W/L, streak, pico).
func get_my_ranked() -> Dictionary:
	return await _http_get("/players/me/ranked")

## GET /leaderboard — top jogadores do ladder (ordenado por tier e pontos).
func get_leaderboard(p_limit: int = 50) -> Dictionary:
	return await _http_get("/leaderboard?limit=%d" % p_limit)

# ── Decks ──────────────────────────────────────────────────────────────────────

## GET /decks — lista (resumo) dos decks do jogador. res.data é um Array.
func get_decks() -> Dictionary:
	return await _http_get("/decks")

## GET /decks/{id} — deck completo (heróis + cartas com cardKey/quantity).
func get_deck(p_id: String) -> Dictionary:
	return await _http_get("/decks/%s" % p_id)

## POST /decks — cria um novo deck. Retorna o deck criado (com id) em res.data.
func create_deck(p_payload: Dictionary) -> Dictionary:
	return await _post("/decks", p_payload)

## PUT /decks/{id} — atualiza um deck existente.
func update_deck(p_deck_id: String, p_payload: Dictionary) -> Dictionary:
	return await _put("/decks/%s" % p_deck_id, p_payload)

## DELETE /decks/{id} — remove um deck do jogador (204 No Content em sucesso).
func delete_deck(p_deck_id: String) -> Dictionary:
	return await _delete("/decks/%s" % p_deck_id)

# ── Quests / Progresso ───────────────────────────────────────────────────────────

## GET /players/me/quests — estados de quest do jogador. res.data é um Array de
## { questId, status, completedAt }.
func get_quests() -> Dictionary:
	return await _http_get("/players/me/quests")

## POST /players/me/quests/{id}/complete — conclui a quest e (futuramente) concede a
## recompensa. Idempotente: reconcluir não reconcede. Devolve o estado atualizado.
func complete_quest(p_quest_id: String) -> Dictionary:
	return await _post("/players/me/quests/%s/complete" % p_quest_id, {})

# ── Scan (rastreio no mundo) ─────────────────────────────────────────────────────

## POST /players/me/scans/heroes/{key} — concede direto um herói rastreável. Idempotente.
func claim_scanned_hero(p_hero_key: String) -> Dictionary:
	return await _post("/players/me/scans/heroes/%s" % p_hero_key, {})

# ── Núcleo HTTP ────────────────────────────────────────────────────────────────

func _post(p_path: String, p_body: Dictionary) -> Dictionary:
	return await _request(HTTPClient.METHOD_POST, p_path, p_body)

func _put(p_path: String, p_body: Dictionary) -> Dictionary:
	return await _request(HTTPClient.METHOD_PUT, p_path, p_body)

func _delete(p_path: String) -> Dictionary:
	return await _request(HTTPClient.METHOD_DELETE, p_path, {})

func _http_get(p_path: String) -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, p_path, {})

func _request(p_method: int, p_path: String, p_body: Dictionary, p_use_service: bool = false) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = _TIMEOUT_SECONDS
	add_child(http)

	var headers := ["Accept: application/json"]
	var payload := ""
	if not p_body.is_empty():
		payload = JSON.stringify(p_body)
		headers.append("Content-Type: application/json")
	# Endpoints de serviço usam a credencial server-to-server; os demais, o token do jogador.
	var token := service_token if (p_use_service and service_token != "") else access_token
	if token != "":
		headers.append("Authorization: Bearer %s" % token)
	# DEBUG — payload enviado (remover depois de estabilizar a integração).
	if payload != "":
		print("[ApiClient] → %s %s body=%s" % [p_method, p_path, payload])
	var err := http.request(base_url + p_path, headers, p_method, payload)
	if err != OK:
		http.queue_free()
		return _fail(0, {}, "Falha ao iniciar a requisição (%d)." % err)

	var result: Array = await http.request_completed
	http.queue_free()

	# result = [result_code, response_code, headers, body]
	var result_code: int = result[0]
	var status: int = result[1]
	var raw: PackedByteArray = result[3]
	var text := raw.get_string_from_utf8()

	# DEBUG — remover depois de estabilizar a integração.
	print("[ApiClient] %s → result_code=%d http=%d (%d bytes)" % [p_path, result_code, status, raw.size()])
	if status < 200 or status >= 300:
		print("[ApiClient] corpo: %s" % text.substr(0, 300))

	# data pode ser Dictionary (objeto) ou Array (lista, ex.: GET /decks).
	var data: Variant = {}
	if text != "":
		var parsed: Variant = JSON.parse_string(text)
		if parsed != null:
			data = parsed

	if result_code != HTTPRequest.RESULT_SUCCESS:
		return _fail(status, data, "Erro de transporte (result_code=%d, http=%d)." % [result_code, status])

	if status >= 200 and status < 300:
		return { "ok": true, "status": status, "data": data, "error": "" }

	# Erro vindo da API — extrai a mensagem mais específica possível do corpo.
	var msg := _extract_error_message(data, text)
	if msg == "":
		msg = "Erro %d ao processar a requisição." % status
	return _fail(status, data, "HTTP %d — %s" % [status, msg])

## Extrai a mensagem de erro mais útil de uma resposta de erro da API.
## Ordem: chaves diretas (message/error/detail/title) → listas de validação
## (errors/fieldErrors/violations, padrão Spring) → corpo cru truncado.
func _extract_error_message(p_data: Variant, p_raw: String) -> String:
	if p_data is Dictionary:
		var d := p_data as Dictionary
		for key in ["message", "error", "detail", "title"]:
			if d.has(key) and str(d[key]) != "":
				return str(d[key])
		for key in ["errors", "fieldErrors", "violations"]:
			if d.has(key) and d[key] is Array and not (d[key] as Array).is_empty():
				var parts: Array[String] = []
				for item in d[key]:
					if item is Dictionary:
						var f := str(item.get("field", item.get("property", "")))
						var m := str(item.get("message", item.get("defaultMessage", str(item))))
						parts.append(("%s %s" % [f, m]).strip_edges())
					else:
						parts.append(str(item))
				return "; ".join(parts)
	# Nenhuma chave conhecida → devolve o corpo cru (truncado) para não esconder o erro.
	var raw := p_raw.strip_edges()
	if raw != "":
		return raw.substr(0, 300)
	return ""

func _fail(p_status: int, p_data: Variant, p_error: String) -> Dictionary:
	return { "ok": false, "status": p_status, "data": p_data, "error": p_error }
