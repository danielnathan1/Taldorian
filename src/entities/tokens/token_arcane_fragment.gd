# src/entities/tokens/token_arcane_fragment.gd
## Fragmento Arcano — token criado pelo Relicar (Feiticeiro), tanto pela passiva
## (ao descartar uma carta) quanto pela habilidade ativa (jogar 2 elementos distintos).
## O efeito/uso do fragmento ainda não foi definido — por ora é apenas acumulado.
## Persiste no campo entre turnos/combates até ser consumido (não some no END).
class_name TokenArcaneFragment
extends Token

func _init() -> void:
	token_id    = "arcane_fragment"
	token_name  = "Fragmento Arcano"
	art_key     = "fragmento_arcano"
	description = "Fragmento de energia arcana."
	destroy_at_combat_end = false   # fica no campo até ser utilizado
