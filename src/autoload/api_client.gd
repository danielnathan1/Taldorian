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

const BASE_URL := "http://localhost:8080"   # MOCK — endereço do taldorian-service

const _TIMEOUT_SECONDS := 15.0

# ── Sessão (tokens de autenticação) ────────────────────────────────────────────
# Mantidos em memória durante a sessão. Toda requisição passa a enviar
# automaticamente "Authorization: Bearer <access_token>" quando houver token.
var access_token: String = ""
var refresh_token: String = ""

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

## GET /players/me — perfil do jogador (id, username, email, gold).
func get_me() -> Dictionary:
	return await _http_get("/players/me")

# ── Catálogo (loja) ─────────────────────────────────────────────────────────────

## GET /catalog/collections — coleções disponíveis na loja (metadados). res.data é um Array.
func get_collections() -> Dictionary:
	return await _http_get("/catalog/collections")

# ── Boosters ────────────────────────────────────────────────────────────────────

## POST /boosters/open — abre um pacote da coleção. O backend valida o ouro, desconta
## e devolve { collectionId, goldSpent, remainingGold, cards: [...] }.
func open_booster(p_collection_id: String) -> Dictionary:
	return await _post("/boosters/open", { "collectionId": p_collection_id })

# ── Inventário / Coleção do jogador ────────────────────────────────────────────

## GET /players/me/inventory — heróis, cartas e playmats que o jogador possui.
## Requer autenticação (o header Authorization é anexado automaticamente).
func get_inventory() -> Dictionary:
	return await _http_get("/players/me/inventory")

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

# ── Núcleo HTTP ────────────────────────────────────────────────────────────────

func _post(p_path: String, p_body: Dictionary) -> Dictionary:
	return await _request(HTTPClient.METHOD_POST, p_path, p_body)

func _put(p_path: String, p_body: Dictionary) -> Dictionary:
	return await _request(HTTPClient.METHOD_PUT, p_path, p_body)

func _http_get(p_path: String) -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, p_path, {})

func _request(p_method: int, p_path: String, p_body: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = _TIMEOUT_SECONDS
	add_child(http)

	var headers := ["Accept: application/json"]
	var payload := ""
	if not p_body.is_empty():
		payload = JSON.stringify(p_body)
		headers.append("Content-Type: application/json")
	if access_token != "":
		headers.append("Authorization: Bearer %s" % access_token)
	var err := http.request(BASE_URL + p_path, headers, p_method, payload)
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

	# Erro vindo da API — tenta extrair mensagem do corpo (quando é objeto).
	var msg := ""
	if data is Dictionary:
		for key in ["message", "error", "detail"]:
			if (data as Dictionary).has(key) and str(data[key]) != "":
				msg = str(data[key])
				break
	if msg == "":
		msg = "Erro %d ao processar a requisição." % status
	return _fail(status, data, msg)

func _fail(p_status: int, p_data: Variant, p_error: String) -> Dictionary:
	return { "ok": false, "status": p_status, "data": p_data, "error": p_error }
