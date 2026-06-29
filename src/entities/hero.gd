# hero_base.gd
class_name Hero
extends RefCounted

enum State { ACTIVE, EXHAUSTED, DEFEATED }
enum HeroClass { BARBARIAN, WARRIOR, MONK, ROGUE, CLERIC, RANGER, GUARDIAN, WIZARD, SORCERER }

var art_key: String = "hero_default"
var hero_name: String
var hero_class: HeroClass
var max_hp: int
var current_hp: int
var state: State = State.ACTIVE
var symbols_required: Array[String] = []
var skill_name: String = "Habilidade Ativa"  # nome da habilidade ativa (chain)
var skill_desc: String = ""                  # descrição curta do efeito ativo
var passive_name: String = "Passiva"         # nome da habilidade passiva
var passive_desc: String = ""               # descrição curta do efeito passivo
var skill_animation: String = ""            # chave de VFX da habilidade ativa  ("" = só floating label)
var passive_animation: String = ""          # chave de VFX da habilidade passiva ("" = só floating label)
var base_attack: int = 0
var base_defense: int = 0
var damage_shield: int = 0   # previne dano de qualquer fonte; dura até on_battle_start
var _skill_activated_this_battle: bool = false
var is_backline_revealed: bool = false
## Quando true o herói sempre aparece virado para cima — tanto na backline quanto ao se tornar ativo.
var starts_face_up: bool = false
## Passiva de frontline ativada (ex.: Muro de Aço da Valkar). Resetado a cada turno;
## ligado quando o jogador opta por quebrar a furtividade na confirmação pós-seleção
## ou quando o herói ativo se revela durante a fase ACTION.
var wall_active: bool = false
## Cosmético (client-side, NÃO serializado): liga a aura de fogo na carta enquanto a
## skill da Poppy (Impacto Sísmico) está ativa no combate. Gerenciado pelo board via
## skill_activated/combat_resolved; lido pelo HeroSlot ao bindar — assim aparece no
## slot do tabuleiro, no preview e na resolução de combate (todos usam HeroSlot).
var skill_fire_active: bool = false

# ── hooks virtuais ──────────────────────────────────────
# Subclasse faz override APENAS dos que precisa.
# Todos têm implementação padrão segura (não fazem nada).

## Retorna true se este herói possui habilidade de retaguarda interativa (requer escolha do jogador).
func has_backline_ability() -> bool:
	return false

## Chamado quando o jogador confirma o uso da habilidade de retaguarda.
## target: herói escolhido (pode ser aliado ou oponente).
## Retorna descrição do efeito para o popup (vazio = sem popup).
func apply_backline_ability(player: Player, opponent: Player, target: Hero) -> String:
	return ""

## Habilidades ATIVADAS — o herói declara o que pode ativar AGORA (o gating de
## fase/segmento e o timing — revelar, abrir janela de reação, consumir o tempo —
## ficam no GameState). Cada descritor:
##   { "id": String, "label": String, "cost": "ACTION"|"BONUS"|"FREE", "needs_target": bool }
## Retorna [] para heróis sem habilidades ativadas.
func get_active_abilities(_player: Player, _opponent: Player) -> Array[Dictionary]:
	return []

## Executa a habilidade ativada de `id`. `targets` traz os heróis escolhidos
## (vazio quando needs_target == false). Retorna a descrição para o popup
## ("" = sem popup). Aqui roda APENAS o efeito — o timing é responsabilidade do GameState.
func activate_ability(_id: String, _player: Player, _opponent: Player, _targets: Array) -> String:
	return ""

## Condição de disparo da habilidade ativa por cadeia (verificada a cada carta jogada,
## só no herói ATIVO). Padrão: subsequência contígua de `symbols_required`.
## Heróis com gatilho diferente (ex.: Relicar — "2 elementos distintos") fazem override.
func is_skill_triggered(chain: Array[String]) -> bool:
	return not symbols_required.is_empty() and SymbolChain.matches_chain(chain, symbols_required)

## Chamado quando o jogador deste herói DESCARTA uma carta da mão. Roda em TODOS os
## heróis do jogador com state == ACTIVE (não exausto/morto) — ativo ou na retaguarda.
## Retorna a descrição para o popup se a passiva disparou ("" caso contrário).
func on_card_discarded(card: Card, player: Player) -> String:
	return ""

## True se a passiva de descarte deste herói produz um efeito VISÍVEL que revela sua
## identidade (ex.: Relicar criando um Fragmento Arcano). Quando true e o herói está
## furtivo (ativo oculto OU retaguarda não revelada), o GameState pede confirmação
## antes de disparar a passiva — ativá-la quebra a furtividade.
func discard_passive_reveals() -> bool:
	return false

## Chamado quando a cadeia de símbolos é completada (antes do combate)
func on_skill_activated(player: Player) -> void:
	pass

## Chamado no início do turno do jogador para heróis vivos e não-exaustos na retaguarda.
## Retorna a descrição da passiva se ela foi acionada, "" caso contrário.
func on_support_battle_start(player: Player, opponent: Player) -> String:
	return ""

## Chamado pelo CombatResolver para heróis de suporte (não-ativos) antes de aplicar dano.
## Permite reduzir o dano sofrido pelo herói aliado ativo. Retorna a redução total.
func get_team_damage_reduction(_ctx: TurnContext) -> int:
	return 0

## Chamado para dano de área (ex: Chuva de Flechas) — sem limite por rodada.
## Permite reduzir 1 de dano por herói atingido independentemente do escudo de combate.
func get_aoe_damage_reduction(_ctx: TurnContext) -> int:
	return 0

## True se, enquanto for o herói ATIVO (linha de frente), impede que os ALIADOS de
## retaguarda sejam alvo de dano direcionado/direto (Chuva de Flechas, Mísseis Mágicos,
## habilidade de alvo escolhido, etc.). A própria linha de frente continua sendo alvo válido.
func protects_backline_from_targeting() -> bool:
	return false

## True se este herói, ao virar ativo, deve oferecer ao jogador a escolha de quebrar
## a furtividade para ativar uma passiva de linha de frente (ex.: Muro de Aço da
## Valkar). Quando true e o herói está oculto, o servidor abre a confirmação Sim/Não
## logo após ambos escolherem o herói ativo.
func wants_frontline_confirm() -> bool:
	return false

## Chamado no início de cada nova rodada de combate — permite heróis de suporte
## resetarem estado de uso por rodada (ex: escudo de Valkar).
func on_turn_reset() -> void:
	pass

## Chamado antes do dano ser aplicado — pode modificar o valor
func on_before_damage_taken(amount: int, ctx: TurnContext) -> int:
	return amount

## Chamado depois de receber dano (herói ainda vivo)
func on_after_damage_taken(ctx: TurnContext) -> void:
	pass

## Chamado quando o herói é escolhido como ativo — reseta estado do turno
func on_battle_start(player: Player) -> void:
	_skill_activated_this_battle = false
	damage_shield = 0

## Chamado a cada carta adicionada ao jogo pelo jogador deste herói
func on_card_played(card: Card, player: Player) -> void:
	pass

## Chamado ao ser derrotado
func on_defeated(ctx: TurnContext) -> void:
	pass

## Chamado no final do turno (antes de exaustar o herói ativo) — passivas de fim de turno.
## Retorna a descrição da passiva se ela foi acionada, "" caso contrário.
## NÃO emita GameBus aqui — o GameState cuida disso via RPC após receber o retorno.
func on_battle_end(player: Player) -> String:
	return ""

## Chamado pelo CombatResolver após causar dano (pode ser 0) — permite passivas pós-dano
func on_after_damage_dealt(damage: int, ctx: TurnContext) -> void:
	pass

## Bônus de ataque da passiva para exibição em tempo real no UI.
## Subclasse faz override se tiver passiva que modifique ataque.
func get_passive_attack_bonus() -> int:
	return 0

## Chamado antes de calcular o ataque — pode modificar bonus_damage via passiva
func on_before_attack(ctx: TurnContext) -> void:
	pass

# ── lógica base (não faz override disso) ────────────────

## Absorve `amount` com o escudo do herói e retorna o dano restante após a absorção.
## Modifica `damage_shield` in-place; seguro chamar com shield == 0.
func absorb_shield(amount: int) -> int:
	if damage_shield <= 0 or amount <= 0:
		return amount
	var absorbed := mini(amount, damage_shield)
	damage_shield -= absorbed
	return amount - absorbed

## O hook `on_before_damage_taken` é aplicado pelo CombatResolver antes de chamar isto.
func heal(amount: int) -> void:
	var effective := mini(amount, max_hp - current_hp)
	current_hp += maxi(0, effective)
	# Emite sempre — mesmo com HP cheio a cura pode trigar efeitos reativos no futuro
	GameBus.hero_healed.emit(self, effective)

func take_damage(amount: int, ctx: TurnContext) -> void:
	current_hp = max(0, current_hp - amount)
	if current_hp == 0:
		state = State.DEFEATED
		on_defeated(ctx)
		GameBus.hero_defeated.emit(self)
	else:
		on_after_damage_taken(ctx)

## Dano de fonte DIRETA (míssil, AoE, habilidade de retaguarda) — respeita o escudo
## (damage_shield), igual ao combate. Retorna o dano efetivamente aplicado (após o escudo).
## O CombatResolver NÃO usa isto (ele já chama absorb_shield + take_damage separadamente).
func take_direct_damage(amount: int, ctx: TurnContext) -> int:
	var dealt := absorb_shield(amount)
	if dealt > 0:
		take_damage(dealt, ctx)
	return dealt

func exhaust() -> void:
	if state == State.ACTIVE:
		state = State.EXHAUSTED

func refresh() -> void:
	if state == State.EXHAUSTED:
		state = State.ACTIVE

func is_alive() -> bool:
	return state != State.DEFEATED

func hp_percent() -> float:
	return float(current_hp) / float(max_hp)

func get_texture() -> Texture2D:
	var path := "res://assets/heros/%s.png" % art_key
	if ResourceLoader.exists(path):
		return load(path)
	return load("res://assets/heros/placeholder.png")
