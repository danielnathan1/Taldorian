# Sobrecarga de Núcleo — destrua tokens à sua escolha; para cada token destruído, distribua
# 1 ponto entre ataque e defesa. Abre o fluxo de 2 fases (escolher tokens → distribuir pontos)
# no GameState; a aplicação dos bônus acontece ao resolver a distribuição.
class_name EffectConsumeTokensForBonus
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	GameState.begin_core_overload(ctx.source_player.player_index)
