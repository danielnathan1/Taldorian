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
## Zona em que a passiva funciona/exige presença. Usado como prefixo na exibição
## (no lugar do título): "backline" → "Retaguarda:", "frontline" → "Linha de Frente:",
## "" (padrão) → sem prefixo (ativa independente da área).
var passive_zone: String = ""
var skill_animation: String = ""            # chave de VFX da habilidade ativa  ("" = só floating label)
var passive_animation: String = ""          # chave de VFX da habilidade passiva ("" = só floating label)
var base_attack: int = 0
var base_defense: int = 0
var damage_shield: int = 0   # previne dano de qualquer fonte; dura até on_battle_start
## Queimadura (DoT): no início de cada turno o herói perde `burn_amount` de vida, por
## `burn_turns` turnos. Persiste enquanto o herói vive (mesmo na retaguarda); some ao
## zerar os turnos ou por Purificar (cleanse). Ticado em GameState._tick_status_effects.
## Serializado no snapshot.
var burn_amount: int = 0
var burn_turns: int = 0
## Escudo persistente (buff): re-aplica `shield_per_turn` de escudo no início de cada
## turno, por `shield_turns` turnos. Diferente de damage_shield (que zera ao herói virar
## ativo em on_battle_start). Serializado no snapshot.
var shield_per_turn: int = 0
var shield_turns: int = 0
var _skill_activated_this_battle: bool = false
var is_backline_revealed: bool = false
## Quando true o herói sempre aparece virado para cima — tanto na backline quanto ao se tornar ativo.
var starts_face_up: bool = false
## Passiva de frontline ativada (ex.: Muro de Aço da Valkar). Resetado a cada turno;
## ligado quando o jogador opta por quebrar a furtividade na confirmação pós-seleção
## ou quando o herói ativo se revela durante a fase ACTION.
var wall_active: bool = false
## Provocar (Provocação da Valkar) ativo neste herói: o dano DIRECIONADO ao seu time é
## puxado para ele (inverso do Muro de Aço). Dura 1 turno; resetado junto com wall_active.
## Serializado no snapshot.
var taunt_active: bool = false
## Cosmético (client-side, NÃO serializado): liga a aura de fogo na carta enquanto a
## skill da Poppy (Impacto Sísmico) está ativa no combate. Gerenciado pelo board via
## skill_activated/combat_resolved; lido pelo HeroSlot ao bindar — assim aparece no
## slot do tabuleiro, no preview e na resolução de combate (todos usam HeroSlot).
var skill_fire_active: bool = false
## Coleção/set a que este herói pertence (agrupamento de catálogo). Ver catalog_screen.
var collection: String = "Origens de Taldorian"

## Rosas Negras (Darian) carregadas por ESTE herói. Cada rosa = 1 de dano ao explodir
## (especial do Darian); herói que sofre ≥3 assim fica exausto. Serializado no snapshot.
var black_roses: int = 0
## Selo da Ruína (Lilith) ativo neste herói até o fim do turno. Enquanto ativo, cada dano
## sofrido bane floor(dano/2) (mín 1) do topo do deck do DONO deste herói. Ver take_damage
## + GameState.on_sealed_hero_damaged. Serializado no snapshot; limpo na fase END.
var sealed_ruin: bool = false

## ── Status negativos de Ecos do Abismo (todos serializados no snapshot) ──────────
## Veneno: contador "bancado" de turnos. Enquanto > 0, o herói tem −poison_turns de DEFESA
## no combate (aplicado no CombatResolver). Decrementa 1 por fim de turno (_tick_status_decay).
## Somado de forma aditiva (2 aplicações de 2t = 4 turnos = −4 DEF, encolhendo 1/turno).
var poison_turns: int = 0
## Sangramento: ao ATACAR/causar dano no combate, o herói perde `bleed_amount` de vida.
## Dura `bleed_turns` fins de turno (decrementado no tick). Pune agressão.
var bleed_amount: int = 0
var bleed_turns: int = 0
## Marca (status): enquanto `mark_turns` > 0, o herói recebe +`mark_bonus` de dano por golpe
## (combate e dano direto). Diferente da Marca do Caçador (Player.marked_target, por turno).
var mark_bonus: int = 0
var mark_turns: int = 0
## Ferida (anti-cura): enquanto > 0, o herói NÃO pode ser curado (heal() vira no-op).
var wound_turns: int = 0
## Silêncio: enquanto > 0, o herói ativo perde skill de cadeia e habilidades ativadas.
var silence_turns: int = 0
## Queimadura sombria: mesma mecânica da Queimadura, mas NÃO é purificável (Purificar a ignora).
## Reusa burn_amount/burn_turns; esta flag marca a queimadura atual como sombria.
var burn_is_dark: bool = false

# ── hooks virtuais ──────────────────────────────────────
# Subclasse faz override APENAS dos que precisa.
# Todos têm implementação padrão segura (não fazem nada).

## Rótulo de exibição do requisito de zona da passiva ("" quando independente da área).
func passive_zone_label() -> String:
	match passive_zone:
		"backline":  return "Retaguarda"
		"frontline": return "Linha de Frente"
		_:           return ""

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

## Habilidade de RETAGUARDA ativável como AÇÃO BÔNUS pelo jogador ativo (ex.: Darian).
## Só é oferecida quando este herói está VIVO e na retaguarda (não é o ativo) — a
## agregação/gating ficam no Player/GameState. Mesmo formato do descritor de get_active_abilities,
## com `cost: "BONUS"` e o marcador `from_backline: true` (o GameState não revela o ativo
## nem abre janela de reação nesse caso). A execução é despachada por activate_ability.
## Retorna {} para heróis sem habilidade de retaguarda por ação bônus.
func get_backline_bonus_ability(_player: Player, _opponent: Player) -> Dictionary:
	return {}

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
	# Escudo de combate (Fluxo Reativo) zera ao virar ativo; o escudo PERSISTENTE
	# (buff de N turnos) sobrevive — foi re-aplicado no tick de início de turno.
	if shield_turns <= 0:
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

## Aplica Queimadura: `amount` de dano por `turns` turnos. Empilha o dano por tick e
## estende a duração (usa o maior). `dark` = Queimadura sombria (não purificável). Ver GameState._tick_burn.
func apply_burn(amount: int, turns: int, dark: bool = false) -> void:
	if amount <= 0 or turns <= 0:
		return
	burn_amount += amount
	burn_turns = maxi(burn_turns, turns)
	if dark:
		burn_is_dark = true

## Remove toda a Queimadura deste herói (Purificar). Queimadura sombria (burn_is_dark) NÃO
## é removível por Purificar.
func clear_burn() -> void:
	if burn_is_dark:
		return
	burn_amount = 0
	burn_turns = 0

## ── Helpers de status negativos (Ecos) ──────────────────────────────────────────
## Veneno: soma `turns` ao contador bancado (cada turno = −1 DEF no combate).
func apply_poison(turns: int) -> void:
	if turns <= 0:
		return
	poison_turns += turns

## Sangramento: `amount` de auto-dano ao atacar, por `turns` turnos.
func apply_bleed(amount: int, turns: int) -> void:
	if amount <= 0 or turns <= 0:
		return
	bleed_amount = maxi(bleed_amount, amount)
	bleed_turns = maxi(bleed_turns, turns)

## Dobra o Sangramento atual (Hemorragia) — em dano e duração.
func double_bleed() -> void:
	bleed_amount *= 2
	bleed_turns *= 2

## Marca (status): +`bonus` de dano recebido por `turns` turnos.
func apply_mark(bonus: int, turns: int) -> void:
	if bonus <= 0 or turns <= 0:
		return
	mark_bonus = maxi(mark_bonus, bonus)
	mark_turns = maxi(mark_turns, turns)

## Ferida (anti-cura): não pode ser curado por `turns` turnos.
func apply_wound(turns: int) -> void:
	if turns <= 0:
		return
	wound_turns = maxi(wound_turns, turns)

## Silêncio: perde skill/habilidades por `turns` turnos.
func apply_silence(turns: int) -> void:
	if turns <= 0:
		return
	silence_turns = maxi(silence_turns, turns)

func is_marked() -> bool:
	return mark_turns > 0

func is_silenced() -> bool:
	return silence_turns > 0

## Bônus de dano por Marca ativa, aplicado uma vez por golpe (combate e dano direto).
func incoming_mark_bonus() -> int:
	return mark_bonus if mark_turns > 0 else 0

## Concede escudo persistente: re-aplica `amount` de escudo por `turns` turnos.
## Protege já neste combate (topa o damage_shield atual) e sobrevive ao on_battle_start.
func grant_persistent_shield(amount: int, turns: int) -> void:
	if amount <= 0 or turns <= 0:
		return
	shield_per_turn = maxi(shield_per_turn, amount)
	shield_turns = maxi(shield_turns, turns)
	damage_shield = maxi(damage_shield, amount)

## Absorve `amount` com o escudo do herói e retorna o dano restante após a absorção.
## Modifica `damage_shield` in-place; seguro chamar com shield == 0.
func absorb_shield(amount: int) -> int:
	if damage_shield <= 0 or amount <= 0:
		return amount
	var absorbed := mini(amount, damage_shield)
	damage_shield -= absorbed
	return amount - absorbed

## O hook `on_before_damage_taken` é aplicado pelo CombatResolver antes de chamar isto.
## Ferida (wound_turns): enquanto ativa, o herói não pode ser curado — heal vira no-op.
func heal(amount: int) -> void:
	if wound_turns > 0:
		return
	var effective := mini(amount, max_hp - current_hp)
	current_hp += maxi(0, effective)
	# Emite sempre — mesmo com HP cheio a cura pode trigar efeitos reativos no futuro
	GameBus.hero_healed.emit(self, effective)

func take_damage(amount: int, ctx: TurnContext) -> void:
	current_hp = max(0, current_hp - amount)
	# Selo da Ruína (Lilith): qualquer dano sofrido (mesmo letal) bane cartas do deck do
	# dono deste herói. Chokepoint único — todo dano final (combate e direto) passa aqui.
	if sealed_ruin and amount > 0:
		GameState.on_sealed_hero_damaged(self, amount)
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
	# Marca (status) amplifica o dano direto (mísseis, AoE, alvo escolhido) antes do escudo.
	var amt := amount + incoming_mark_bonus() if amount > 0 else amount
	var dealt := absorb_shield(amt)
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
