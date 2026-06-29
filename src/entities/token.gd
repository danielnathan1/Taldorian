# src/entities/token.gd
## Estrutura base de um TOKEN — entidade criada DURANTE a partida, fora do deck.
## Diferente de Card: tokens têm comportamento e estado próprios (contadores,
## timing de destruição, alvo), então não são reaproveitados como cartas genéricas.
##
## Subclasses concretas vivem em src/entities/tokens/ (ex.: TokenMagicMissile) e o
## TokenFactory mapeia `token_id` → subclasse para reconstrução no cliente (snapshot).
class_name Token
extends RefCounted

## Id estável usado na serialização e no roteamento da factory (ex.: "magic_missile").
var token_id: String = ""
var token_name: String = ""
var art_key: String = "token_default"
var description: String = ""

## Tempo de vida: se true, o token é destruído quando o combate resolve (END).
## Se false, permanece no campo até ser consumido pelo seu efeito (ex.: Fragmento
## Arcano, que persiste entre turnos). Propriedade intrínseca do tipo (definida no
## _init da subclasse) — a factory reconstrói a subclasse certa, sem precisar serializar.
var destroy_at_combat_end: bool = true

## Serializa o token para o snapshot. Subclasses com estado extra (contadores)
## fazem override chamando super() e adicionando seus campos.
func to_dict() -> Dictionary:
	return {
		"token_id":    token_id,
		"name":        token_name,
		"art_key":     art_key,
		"description": description,
	}

## Aplica campos serializados em si mesmo. Subclasses fazem override para
## restaurar estado extra (contadores). Chamado pela factory após instanciar.
func apply_dict(data: Dictionary) -> void:
	token_name  = data.get("name", token_name)
	art_key     = data.get("art_key", art_key)
	description = data.get("description", description)

## Reconstrói um token a partir do dicionário serializado (via factory).
static func from_dict(data: Dictionary) -> Token:
	return TokenFactory.create(data.get("token_id", ""), data)

func get_texture() -> Texture2D:
	var path := "res://assets/card/tokens/%s.png" % art_key
	if art_key != "" and ResourceLoader.exists(path):
		return load(path)
	return null

# ── Habilidades ativadas do token ────────────────────────────────────────────
## Descritor da habilidade que o token expõe quando o jogador o controla (ou {}).
## Mesmo formato das habilidades de herói:
##   { "id": String, "label": String, "cost": "ACTION"|"BONUS"|"FREE",
##     "needs_target": bool, "target_count": int, "token_id": String }
## O disparo é lógica do PRÓPRIO token — independe de qual herói está ativo.
func get_active_ability(_player: Player, _opponent: Player) -> Dictionary:
	return {}

## Executa a habilidade do token. Retorna um label (ou "" se nada a anunciar).
## `targets` já vem resolvido como Array[Hero] (o GameState valida os índices).
func activate_ability(_id: String, _player: Player, _opponent: Player, _targets: Array) -> String:
	return ""
