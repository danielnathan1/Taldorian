# src/entities/token_factory.gd
## Mapeia `token_id` → subclasse concreta de Token.
## Usado na desserialização do snapshot (cliente) e por quem cria tokens (heróis/cartas),
## para que exista um único ponto de criação por id — espelha o papel da HeroFactory.
class_name TokenFactory

## Cria um token pelo id. `data` (opcional) restaura estado serializado.
## Retorna null para ids desconhecidos.
static func create(token_id: String, data: Dictionary = {}) -> Token:
	var token: Token = _instantiate(token_id)
	if token != null and not data.is_empty():
		token.apply_dict(data)
	return token

static func _instantiate(token_id: String) -> Token:
	match token_id:
		"magic_missile":
			return TokenMagicMissile.new()
		"arcane_fragment":
			return TokenArcaneFragment.new()
		_:
			push_warning("TokenFactory: token_id desconhecido '%s'" % token_id)
			return null
