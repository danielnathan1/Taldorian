# Plano de Testes Manuais — Taldorian TCG

> **Como usar:** Siga os cenários em ordem. Cada teste tem pré-condições, ações e resultado esperado.
> Marque ✅ quando passar, ❌ quando reprovar (anote o comportamento real ao lado).

---

## 1. Fases do Jogo

### 1.0 Rolagem de Dados (OPENING_ROLL)

| # | Pré-condição | Ação | Esperado |
|---|---|---|---|
| 1.0.1 | Início de partida | Nenhum jogador faz nada | Overlay de dados aparece (antes do mulligan); mão escondida; status "Arraste para arremessar" |
| 1.0.2 | Overlay de dados | Clicar-segurar-arrastar e soltar | Os 2 dados rolam em arco até o centro e param mostrando valores |
| 1.0.3 | Ambos arremessaram (totais diferentes) | — | O de maior total vence; vencedor vê "Quem começa?" com 2 botões; o outro vê "aguardando" |
| 1.0.4 | Empate de totais | Ambos com mesmo total | Re-roll: dados resetam, status "arremesse de novo" |
| 1.0.5 | Vencedor escolhe quem começa | Clicar "Eu começo" / "Oponente começa" | Vai pro mulligan; o jogador escolhido é quem age primeiro na fase ACTION |
| 1.0.6 | Sincronização | Observar a tela do oponente | Vê os dados do outro rolando também (auto-arremesso) e os mesmos valores |

> QA isolado da parte visual: abrir `scenes/ui/boardv2/dice_roll/DiceRollTest.tscn` (F6) — arraste para arremessar; botão simula o oponente.

### 1.1 Mulligan

| # | Pré-condição | Ação | Esperado |
|---|---|---|---|
| 1.1.1 | Início de partida | Nenhum jogador faz nada | Ambos recebem 6 cartas; MulliganScreen visível |
| 1.1.2 | MulliganScreen ativa | Manter 3 cartas, confirmar | Jogador fica com as 3 cartas; completa quando ambos confirmam |
| 1.1.3 | MulliganScreen ativa | Manter 0 cartas (descartar todas) | Jogador recebe nova mão; jogo avança quando ambos confirmam |
| 1.1.4 | MulliganScreen ativa | Manter 6 cartas (manter tudo) | Mão inalterada; jogo avança |

### 1.2 Hero Selection

| # | Pré-condição | Ação | Esperado |
|---|---|---|---|
| 1.2.1 | Início do turno | Ambos escolhem herói | HeroPickScreen some; heróis ficam face-down para o oponente |
| 1.2.2 | Herói exausto | Tentar selecionar herói exausto | Bloqueado; apenas heróis ativos disponíveis |
| 1.2.3 | Todos heróis exaustos | Iniciar hero selection | Todos restaurados para ACTIVE antes da seleção |

### 1.3 Fase ACTION — Timing

| # | Pré-condição | Ação | Esperado |
|---|---|---|---|
| 1.3.1 | Fase ACTION | Jogar ACTION → oponente reage com REACTION → jogar BONUS_ACTION | Ordem correta; REACTION fecha janela antes da BA |
| 1.3.2 | Fase ACTION | Jogar ACTION → oponente passa reação | Janela de reação fecha; jogador pode jogar BA |
| 1.3.3 | Fase ACTION | Ambos passam ACTION | Rodada encerra sem cartas; nova rodada começa |
| 1.3.4 | Ambos sem cartas na mão | — | Fase ACTION encerra; vai para COMBAT |
| 1.3.5 | 2 rodadas consecutivas sem ACTION | — | Fase ACTION encerra automaticamente |

### 1.4 Fase END

| # | Pré-condição | Ação | Esperado |
|---|---|---|---|
| 1.4.1 | Fim de turno | Guardar carta no arsenal | Arsenal exibe a carta face-up para ambos |
| 1.4.2 | Arsenal já tem carta | Guardar nova carta no arsenal | Carta antiga vai ao fundo do deck |
| 1.4.3 | Fim de turno | Não guardar carta (-1) | Arsenal permanece como estava |
| 1.4.4 | Mão com 2 cartas | Fim de turno sem guardar | Compra 4; total = 6 (cap) |
| 1.4.5 | Mão com 4 cartas | Fim de turno sem guardar | Compra 2; total = 6 |
| 1.4.6 | Mão com 6 cartas | Fase DRAW | Não compra nada; excedentes vão ao fundo |

---

## 2. Heróis

### 2.1 Poppy — Barbarian (HP 10, ATK 2, DEF 1)

| # | Cenário | Como testar | Esperado |
|---|---|---|---|
| 2.1.1 | **Passiva** *Ataque Descuidado*: nenhuma carta de defesa jogada | Jogar apenas cartas com `defense_value ≤ 0`; resolver combate | Poppy recebe +1 ATK |
| 2.1.2 | **Passiva desativa** quando joga carta de defesa | Jogar qualquer carta com `defense_value > 0` | +1 ATK não aparece |
| 2.1.3 | **Passiva desativa** quando tem `pending_bonus_defense > 0` | Jogar carta com efeito de bônus defesa (ex: Linha de Ferro) | +1 ATK não aparece |
| 2.1.4 | **Ativa** *Impacto Sísmico*: cadeia [Terra, Terra, Fogo] | Jogar 3 cartas com símbolos Terra + Terra + Fogo nessa ordem | `pending_bonus_attack += 3`; sinal `skill_activated` emitido |
| 2.1.5 | Ativa não dispara com sequência incorreta | Jogar Fogo + Terra + Terra | Ativa não dispara |

### 2.2 Irena — Cleric (HP 9, ATK 0, DEF 2)

| # | Cenário | Como testar | Esperado |
|---|---|---|---|
| 2.2.1 | **Passiva** *Crescimento Natural*: cura ao fim do turno | Deixar Irena ativa; encerrar turno | Todos os heróis vivos ganham 1 HP (não ultrapassa max_hp) |
| 2.2.2 | Passiva não cura heróis mortos | Ter herói aliado com HP 0 | Herói morto não recebe cura |
| 2.2.3 | **Ativa** *Toque Revigorante*: cadeia [Água, Água, Terra] | Completar a cadeia no turno de Irena | Curas do restante do turno ganham +1 |
| 2.2.4 | Bônus de cura reseta no próximo turno | Ativar skill; encerrar turno; novo turno | `_heal_bonus = 0`; curas voltam ao normal |
| 2.2.5 | Passiva de Irena morta não cura | Irena com HP 0 (derrotada) | `on_turn_end` retorna vazio; nenhuma cura |

### 2.3 Nissin — Monk (HP 10, ATK 1, DEF 2)

| # | Cenário | Como testar | Esperado |
|---|---|---|---|
| 2.3.1 | **Passiva** *Fluxo Suave*: ACTION + BONUS_ACTION na mesma rodada | Jogar ACTION e depois BONUS_ACTION no mesmo segmento | `pending_bonus_attack += 1` no combate |
| 2.3.2 | Passiva não ativa com apenas ACTION | Jogar só ACTION; passar BA | Sem bônus |
| 2.3.3 | Passiva não ativa com apenas BONUS_ACTION | Jogar só BA; sem ACTION | Sem bônus |
| 2.3.4 | **Ativa** *Passos Ágeis*: cadeia [Ar, Ar, Água] | Completar a cadeia | Nissin compra 1 carta |
| 2.3.5 | Ativa dispara uma vez por turno | Completar cadeia duas vezes no turno | Carta comprada apenas uma vez (`_skill_activated_this_turn`) |

### 2.4 Valkar — Guardian (HP 11, ATK 0, DEF 3)

| # | Cenário | Como testar | Esperado |
|---|---|---|---|
| 2.4.0 | **Furtividade normal + confirmação** | Escolher Valkar como ativa; ambos confirmam o herói | Valkar entra **furtiva**; após ambos escolherem, abre o modal Sim/Não de *Muro de Aço* só para o dono |
| 2.4.1 | **Muro ATIVADO** (Sim): aliados inalvejáveis | No modal escolher **Sim**; Ieldor/Nox mira herói de retaguarda aliado | Valkar revela + VFX Égide; dano direcionado não é aplicado (`is_targeting_protected` → true) |
| 2.4.1b | **Muro RECUSADO** (Não): sem proteção | No modal escolher **Não**; Ieldor/Nox mira retaguarda aliada | Valkar segue furtiva (`wall_active=false`); dano direcionado **é** aplicado |
| 2.4.1c | **Liga ao se revelar** | Escolher **Não**; depois jogar carta não-furtiva na fase ACTION | Valkar revela → Muro ativa (`wall_active=true`) + VFX; passa a proteger |
| 2.4.2 | Passiva NÃO protege a própria Valkar | Muro ativo; Chuva de Flechas (AoE) com Valkar ativa | Valkar (linha de frente) toma 1; aliados de retaguarda intocados |
| 2.4.3 | Passiva só vale na linha de frente | Valkar na retaguarda (não é a ativa) | Aliados podem ser alvo normalmente |
| 2.4.4 | Passiva inativa se Valkar derrotada | Valkar com estado DEFEATED | Proteção não ocorre |
| 2.4.5 | Reset por turno | Ativar Muro num turno; no turno seguinte escolher Valkar de novo | Volta furtiva; modal de confirmação aparece de novo (`wall_active` reseta) |
| 2.4.5 | Combate normal ainda fere a Valkar | Oponente ataca Valkar (ataque vs defesa) | Dano de combate aplicado normalmente |
| 2.4.6 | **Ativa** *Escudo de Espinhos*: [Terra, Terra, Água] | Completar cadeia com Valkar activo (DEF 3) | `pending_bonus_attack += 1` (floor(3/2)) |

### 2.5 Hakai — Rogue (HP 10, ATK 1, DEF 0)

| # | Cenário | Como testar | Esperado |
|---|---|---|---|
| 2.5.1 | **Passiva** *Golpe das Sombras*: dano enquanto furtivo | Hakai oculto → atacar e causar dano | `_permanent_attack_bonus += 1`; `skill_activated` emitido |
| 2.5.2 | Passiva acumula | Causar dano furtivo em 3 rodadas consecutivas | `_permanent_attack_bonus == 3` |
| 2.5.3 | Passiva não ativa sem furtividade | Hakai revelado → causar dano | `_permanent_attack_bonus` não muda |
| 2.5.4 | Passiva não ativa sem dano | Hakai furtivo → ataque bloqueado | `_permanent_attack_bonus` não muda |
| 2.5.5 | **Ativa** *Instinto de Caça*: [Ar, Ar, Ar] | Completar cadeia | `set_hero_stealth()` chamado; herói volta a ser face-down |

### 2.6 Ieldor — Ranger (HP 9, ATK 1, DEF -1)

| # | Cenário | Como testar | Esperado |
|---|---|---|---|
| 2.6.1 | **Retaguarda interativa**: Ieldor não é herói ativo | Ativada via UI (botão de retaguarda) | Popup de escolha de alvo aparece |
| 2.6.2 | Retaguarda: escolher herói inimigo | Selecionar um herói | Herói escolhido sofre 1 dano; `hero_damaged` emitido |
| 2.6.3 | Retaguarda: herói derrotado com o 1 dano | Alvo com 1 HP | `hero_defeated` emitido; herói marcado como DEFEATED |
| 2.6.4 | **Ativa** *Chuva de Flechas*: [Fogo, Ar, Ar] | Completar cadeia | 1 dano a cada herói vivo inimigo; `hero_damaged` emitido para cada |
| 2.6.5 | Ativa não atinge heróis mortos | 1 herói inimigo vivo, 2 mortos | Apenas 1 `hero_damaged` |
| 2.6.6 | DEF -1 de Ieldor é aplicado | Ieldor na linha de frente | Defesa bruta reduzida em 1 |

---

## 3. Efeitos de Carta — Grupo A: Sem Efeito (puro stats)

> Objetivo: confirmar que ATK e DEF chegam corretamente ao `CombatResolver`.

| Carta | Tipo | ATK | DEF | Símbolo | Verificar |
|---|---|---|---|---|---|
| Corte Preciso | Ação | 3 | 1 | Ar | Dano bruto correto |
| Postura Firme | Ação | 1 | 3 | Terra | Bloqueia corretamente |
| Avanço Imprudente | Ação | 5 | -1 | Fogo | Defesa negativa aplica |
| Investida Selvagem | Ação | 6 | -2 | Fogo | Maior ATK do set |
| Exposição Tática | Ação | 4 | -2 | Ar | — |
| Defesa Implacável | Ação | 0 | 4 | Terra | Bloqueia tudo |
| Passo Leve | BA | 0 | 1 | Ar | — |
| Chama Instável | BA | 1 | 0 | Fogo | — |
| Brisa Ardente | BA | 3 | -1 | Fogo | — |
| Guarda Breve | BA | -1 | 2 | Terra | ATK negativo não subtrai do total |
| Brasa | BA | 2 | 0 | Fogo | — |
| Bloqueio Instintivo | Reação | 0 | 1 | Terra | — |
| Guarda Emergencial | Reação | -1 | 2 | Terra | — |
| Reflexivo Ofensivo | Reação | 1 | 0 | Fogo | — |
| Passo Nebuloso | Reação | 0 | 1 | Ar | — |
| Instinto Violento | Reação | 2 | -1 | Fogo | — |
| Simples *(Rara)* | Reação | 1 | 1 | Ar | — |

**Teste geral:** Jogar qualquer carta acima → combate resolve → dano final = max(0, ATK_total - DEF_total).

---

## 4. Efeitos de Carta — Grupo B: Draw / Discard

### 4.1 `draw_discard` — compra N, descarta N

| # | Carta | Pré-condição | Ação | Esperado |
|---|---|---|---|---|
| 4.1.1 | Pequenos Riscos / Corrente / Reflexo Líquido / Ajuste Fino | Deck com cartas | Jogar carta | Compra 1; deve descartar 1 da mão |
| 4.1.2 | Desvio Rápido (Reação) | Deck com cartas | Jogar como reação | Compra 1; deve descartar 2 |
| 4.1.3 | Qualquer draw_discard | Deck vazio | Jogar | Não trava; descarte também não ocorre se mão vazia pós-compra |
| 4.1.4 | Qualquer draw_discard | Mão vazia antes de jogar | Jogar (via arsenal) | Compra 1; sem descarte se mão < 1 após compra |

### 4.2 `draw_then_put_bottom` — Ajuste Fino (BA)

| # | Pré-condição | Ação | Esperado |
|---|---|---|---|
| 4.2.1 | Deck com 3+ cartas | Jogar Ajuste Fino | Overlay abre; escolher 1 carta da mão para ir ao fundo |
| 4.2.2 | Mão vazia após compra | Jogar Ajuste Fino | Nenhum overlay (sem carta para pôr no fundo) |

### 4.3 `recycle_graveyard_draw` — Contra Ataque (BA)

| # | Pré-condição | Ação | Esperado |
|---|---|---|---|
| 4.3.1 | Cemitério com cartas | Jogar Contra Ataque BA | Overlay com cemitério; carta escolhida vai ao deck; compra 1 |
| 4.3.2 | Cemitério vazio | Jogar Contra Ataque BA | Sem overlay; sem compra |

### 4.4 `draw_discard_if_card_type_played` — Ritmo (BA)

| # | Pré-condição | Ação | Esperado |
|---|---|---|---|
| 4.4.1 | ACTION já jogada nessa rodada | Jogar Ritmo | Compra 1; descarta 1 |
| 4.4.2 | Nenhuma ACTION jogada | Jogar Ritmo | Sem efeito |

### 4.5 `scry` — Dois Passos à Frente (BA Rara)

| # | Pré-condição | Ação | Esperado |
|---|---|---|---|
| 4.5.1 | Deck com 1+ carta | Jogar Dois Passos à Frente | Exibe carta do topo; oferece pôr no fundo ou manter |
| 4.5.2 | Aceitar pôr no fundo | Após ver a carta | Carta vai ao fundo do deck |
| 4.5.3 | Rejeitar (manter no topo) | Após ver a carta | Deck inalterado |
| 4.5.4 | Deck vazio | Jogar | Sem efeito; sem travamento |

---

## 5. Efeitos de Carta — Grupo C: Cura

> **Pré-requisito:** Herói ativo com HP < max_hp.

### 5.1 `heal` — Respiração Serena (BA), Recuperação Breve (Reação), Corrente Restauradora (Ação)

| # | Carta | Pré-condição | Esperado |
|---|---|---|---|
| 5.1.1 | Respiração Serena | HP 7/10 | Cura 1; HP → 8 |
| 5.1.2 | Corrente Restauradora | HP 8/10 | Cura 2; HP → 10 |
| 5.1.3 | Qualquer cura | HP já no max | HP não ultrapassa max_hp |
| 5.1.4 | Corrente Ascendente (Rara) | HP 5/10 | Cura 3; HP → 8 |

### 5.2 `heal_after_combat` — Resistência Natural (Ação Comum)

| # | Pré-condição | Esperado |
|---|---|---|
| 5.2.1 | HP 7/10; jogar Resistência Natural | `pending_heal_after_combat` setado; cura de 1 aplicada após resolução do combate |
| 5.2.2 | Herói é derrotado no combate | Cura pós-combate não revive herói morto |

### 5.3 `heal_if_behind` — Renovação (Ação Comum)

| # | Pré-condição | Esperado |
|---|---|---|
| 5.3.1 | HP do herói ativo < HP herói ativo oponente | Cura 2 |
| 5.3.2 | HP do herói ativo ≥ HP herói ativo oponente | Sem cura |

### 5.4 `heal_if_full_block` — Fluxo Sereno (Ação Comum)

| # | Pré-condição | Esperado |
|---|---|---|
| 5.4.1 | Dano final == 0 (ataque bloqueado totalmente) | Cura 1 |
| 5.4.2 | Dano final > 0 | Sem cura |

### 5.5 `heal_if_no_damage` — Maré Suave (Reação Comum)

| # | Pré-condição | Esperado |
|---|---|---|
| 5.5.1 | Dano recebido == 0 | Cura 1 |
| 5.5.2 | Dano recebido > 0 | Sem cura |

### 5.6 `heal_all_allies` — Florescer Eterno (Ação Lendária)

| # | Pré-condição | Esperado |
|---|---|---|
| 5.6.1 | 3 heróis aliados vivos | Jogar Florescer Eterno; depois jogar carta de cura | Todos os heróis aliados recebem a cura |
| 5.6.2 | 1 aliado morto | A cura vai apenas para os vivos |
| 5.6.3 | Próximo turno | `pending_heal_all_amount` zerado | Efeito não persiste |

### 5.7 `heal_return_if_full` — Ciclo Vital (Reação Lendária)

| # | Pré-condição | Esperado |
|---|---|---|
| 5.7.1 | HP 8/10 | Jogar Ciclo Vital | Cura 2; HP → 10; carta retorna à mão |
| 5.7.2 | HP 9/10 | Jogar Ciclo Vital | Cura 2; HP → 10 (cap); carta retorna à mão |
| 5.7.3 | HP 5/10 | Jogar Ciclo Vital | Cura 2; HP → 7; carta **NÃO** retorna |

### 5.8 Irena + Ativa + Cura

| # | Cenário | Esperado |
|---|---|---|
| 5.8.1 | Irena ativa; skill ativada ([Água, Água, Terra]) | Curas do turno ganham +1 |
| 5.8.2 | Jogar Corrente Restauradora (cura 2) com ativa de Irena | Cura 3 no total |
| 5.8.3 | `heal_all_allies` + ativa de Irena | Cada aliado recebe cura base + 1 |

---

## 6. Efeitos de Carta — Grupo D: Bônus de Ataque Condicional

### 6.1 `attack_if_symbol_played` — Chama Crescente (Ação Comum)

| # | Pré-condição | Esperado |
|---|---|---|
| 6.1.1 | Carta com símbolo Fogo já jogada no turno | Chama Crescente jogada | +1 ATK |
| 6.1.2 | Nenhuma carta Fogo jogada antes | +0 ATK (sem bônus) |

### 6.2 `attack_if_nth_card` — Encadeamento (Ação Comum), Ritmo Calculado (Ação Comum), Fluxo Perfeito (Ação Lendária)

| # | Carta | N | Scope | Esperado |
|---|---|---|---|---|
| 6.2.1 | Encadeamento | 3 | turn | É a 3ª carta do turno → compra 1 |
| 6.2.2 | Encadeamento | 3 | turn | É a 2ª carta do turno → sem compra |
| 6.2.3 | Ritmo Calculado | 2 | combat | É a 2ª carta do combate → compra 1 |
| 6.2.4 | Fluxo Perfeito | 3 | combat | É a 3ª carta do combate → compra 1 |

### 6.3 `attack_if_first_card` / `defense_if_first_card`

| # | Carta | Pré-condição | Esperado |
|---|---|---|---|
| 6.3.1 | Ajuste de Guarda (BA) | 1ª carta do combate | +1 ATK |
| 6.3.2 | Ajuste de Guarda (BA) | 2ª carta do combate | Sem bônus |
| 6.3.3 | Pressão Inicial (Ação) | 1ª carta do turno | +1 DEF |
| 6.3.4 | Pressão Inicial (Ação) | 2ª carta do turno | Sem bônus |

### 6.4 `attack_bonus_if_from_arsenal` — Brisa Cortante (Ação Comum)

| # | Pré-condição | Esperado |
|---|---|---|
| 6.4.1 | Brisa Cortante jogada **do arsenal** | +1 ATK |
| 6.4.2 | Brisa Cortante jogada **da mão** | Sem bônus |

### 6.5 `defense_if_bonus_action_played` — Movimento Preciso (Ação), Impulso Rápido (BA)

| # | Pré-condição | Esperado |
|---|---|---|
| 6.5.1 | Alguma BONUS_ACTION já jogada nessa rodada | +1 DEF |
| 6.5.2 | Nenhuma BA jogada | Sem bônus |

### 6.6 `attack_if_hidden` — Sombra Oculta (Ação Rara)

| # | Pré-condição | Esperado |
|---|---|---|
| 6.6.1 | Herói ainda **não revelado** (face-down) ao jogar | +2 ATK |
| 6.6.2 | Herói já revelado | Sem bônus |

### 6.7 `attack_if_damaged_this_round` — Sangue Quente (Reação Rara)

| # | Pré-condição | Esperado |
|---|---|---|
| 6.7.1 | Herói sofreu dano nessa rodada | +1 ATK |
| 6.7.2 | Herói não sofreu dano | Sem bônus |

### 6.8 `attack_if_defense_low` — Frenesi (Ação Lendária)

| # | Pré-condição | Esperado |
|---|---|---|
| 6.8.1 | `pending_bonus_defense` líquido negativo (defesa total ≤ 0) | +1 ATK |
| 6.8.2 | Defesa normal | Sem bônus |

### 6.9 `fogo_symbol_count_attack` — Coração da Fornalha (Ação Rara)

| # | Pré-condição | Esperado |
|---|---|---|
| 6.9.1 | 2 cartas com símbolo Fogo jogadas no turno | Coração da Fornalha jogada | +2 ATK |
| 6.9.2 | 0 cartas Fogo | +0 ATK |
| 6.9.3 | Sem self-damage | — | Sem dano ao próprio herói (diferente do efeito antigo) |

---

## 7. Efeitos de Carta — Grupo E: Próxima Carta / Cross-round

### 7.1 `next_card_attack_bonus` — Impulso Ofensivo (Ação Comum), Linha de Ferro (Ação Comum)

| # | Carta | Pré-condição | Ação | Esperado |
|---|---|---|---|---|
| 7.1.1 | Impulso Ofensivo | — | Jogar; depois jogar qualquer carta | Próxima carta recebe +2 ATK |
| 7.1.2 | Linha de Ferro | — | Jogar; depois jogar qualquer carta | Próxima carta recebe +1 ATK |
| 7.1.3 | Qualquer | — | Jogar; não jogar mais cartas | Bônus desaparece no próximo turno (zerado em reset) |

### 7.2 `next_card_both_bonus` — Pressão Contínua (Ação Rara)

| # | Pré-condição | Ação | Esperado |
|---|---|---|---|
| 7.2.1 | Jogar Pressão Contínua | Próxima carta jogada | +1 ATK e +1 DEF na próxima carta |

### 7.3 `weaken_next_attack` — Finta (Reação Rara)

| # | Pré-condição | Ação | Esperado |
|---|---|---|---|
| 7.3.1 | Jogar Finta | Oponente joga próxima carta | Próxima carta do oponente recebe -1 ATK |
| 7.3.2 | Jogar Finta | Oponente passa a vez | -1 ATK persiste até a próxima carta real |

### 7.4 `persist_attack_if_no_damage` — Guarda Inabalável (Reação Rara)

| # | Pré-condição | Ação | Esperado |
|---|---|---|---|
| 7.4.1 | Jogar Guarda Inabalável; dano final == 0 | Próxima rodada | `next_round_bonus_attack` transferido → +1 ATK |
| 7.4.2 | Jogar Guarda Inabalável; dano final > 0 | Próxima rodada | `next_round_bonus_attack` zerado; sem bônus |

---

## 8. Efeitos de Carta — Grupo F: Arsenal

### 8.1 `bonus_arsenal` — Defesa Oculta (BA)

| # | Pré-condição | Esperado |
|---|---|---|
| 8.1.1 | Jogar Defesa Oculta **do arsenal** | +2 DEF extra |
| 8.1.2 | Jogar Defesa Oculta **da mão** | Apenas DEF base (3); sem bônus |

### 8.2 `store_in_arsenal` — Passo Estratégico (Ação Rara), Preparando o Arsenal (BA Rara)

| # | Pré-condição | Ação | Esperado |
|---|---|---|---|
| 8.2.1 | Mão com 2+ cartas | Jogar Passo Estratégico | Overlay de escolha abre; carta escolhida vai ao arsenal |
| 8.2.2 | Arsenal cheio | Jogar Passo Estratégico | Carta antiga vai ao fundo do deck; nova carta entra |
| 8.2.3 | Mão vazia após jogar | Jogar Passo Estratégico | Sem overlay; nada acontece |

### 8.3 `draw_discard_if_from_arsenal` — Fluxo Ágil (BA Rara)

| # | Pré-condição | Esperado |
|---|---|---|
| 8.3.1 | Fluxo Ágil jogada **do arsenal** | Compra 1; descarta 1 |
| 8.3.2 | Fluxo Ágil jogada **da mão** | Sem efeito |

### 8.4 `both_recycle_arsenal` — Ecos do Passado (Reação Lendária)

| # | Pré-condição | Ação | Esperado |
|---|---|---|---|
| 8.4.1 | Ambos com cemitério com 1+ carta | Jogar Ecos do Passado | Overlay para jogador local → depois overlay para oponente → ambas as cartas vão ao arsenal |
| 8.4.2 | Jogador sem cemitério | Jogar Ecos do Passado | Sem overlay para quem não tem cartas no cemitério |
| 8.4.3 | Oponente sem cemitério | Jogar Ecos do Passado | Apenas jogador local faz a escolha |

---

## 9. Efeitos de Carta — Grupo G: Furtividade

### 9.1 `surprise_strike` — Golpe Surpresa (Ação)

| # | Pré-condição | Esperado |
|---|---|---|
| 9.1.1 | 1ª carta do turno, jogada do arsenal | Jogar Golpe Surpresa | Cancela janela de reação do oponente |
| 9.1.2 | 2ª carta do turno | Jogar Golpe Surpresa | Reação não cancelada |
| 9.1.3 | Da mão (não do arsenal) | Jogar Golpe Surpresa | Reação não cancelada |

### 9.2 `stealth_if_from_arsenal` — Véu Transitório (BA Rara)

| # | Pré-condição | Esperado |
|---|---|---|
| 9.2.1 | Jogar do arsenal, herói já revelado | Herói volta a ser face-down |
| 9.2.2 | Jogar da mão | Sem efeito de furtividade |

### 9.3 `stealth_hidden_at_combat` — Execução Silenciosa (Ação Lendária)

| # | Pré-condição | Esperado |
|---|---|---|
| 9.3.1 | Herói estava furtivo ao jogar | +1 ATK bônus de furtividade |
| 9.3.2 | Herói estava furtivo + causou dano | Próximo combate começa furtivo (`next_round_stealth`) |
| 9.3.3 | Herói já estava revelado ao jogar | Sem bônus; sem `next_round_stealth` |

### 9.4 Cartas `is_stealth: true` (ex.: Golpe Furtivo)

| # | Ação | Esperado |
|---|---|---|
| 9.4.1 | Jogar carta furtiva | Herói **não** é revelado |
| 9.4.2 | Jogar carta não-furtiva | Herói **é** revelado |

---

## 10. Efeitos de Carta — Grupo H: Dano / Combate Especial

### 10.1 `all_in` / `destroy_arsenal_on_damage` — All In, Quebrando a Banca

| # | Carta | Pré-condição | Esperado |
|---|---|---|---|
| 10.1.1 | All In | Dano final == 0 | Jogador recebe 1 dano; compra 1 |
| 10.1.2 | All In | Dano final > 0 | Sem auto-dano |
| 10.1.3 | Quebrando a Banca | Dano final > 0 | Arsenal do oponente destruído |
| 10.1.4 | Quebrando a Banca | Dano final == 0 | Arsenal intacto |

### 10.2 `counter_attack` — Contra Ataque (Reação)

| # | Pré-condição | Esperado |
|---|---|---|
| 10.2.1 | Dano final == 0 | Atacante sofre 1 dano |
| 10.2.2 | Dano final > 0 | Sem contra-ataque |

### 10.3 `direct_damage_if_first` — Tiro de Oportunidade (Ação Rara)

| # | Pré-condição | Esperado |
|---|---|---|
| 10.3.1 | 1ª carta do combate | Causa 1 dano direto ao herói ativo inimigo |
| 10.3.2 | 2ª carta do combate | Sem dano direto |
| 10.3.3 | Dano direto derrota herói | `hero_defeated` emitido; `game_over` se era o último |

### 10.4 `ricochet` — Ricochetear (BA Lendária)

| # | Pré-condição | Esperado |
|---|---|---|
| 10.4.1 | Combate causa dano ao oponente | 1 dano aleatório em herói inimigo vivo |
| 10.4.2 | Dano final == 0 | Sem ricochete |

### 10.5 `damage_shield` — Fluxo Reativo (Reação Rara)

| # | Pré-condição | Esperado |
|---|---|---|
| 10.5.1 | Receber 3 de dano com escudo | Dano reduzido para 2 |
| 10.5.2 | Receber 1 de dano com escudo | Dano == 0 |
| 10.5.3 | Escudo zerado após uso | Próxima rodada sem escudo |

### 10.6 `discard_for_attack` — Estopim (BA Rara)

| # | Pré-condição | Esperado |
|---|---|---|
| 10.6.1 | Mão com 1+ carta | Jogar Estopim | Overlay de descarte; após descartar → +2 ATK |
| 10.6.2 | Mão vazia | Jogar Estopim | Sem overlay; sem bônus |

### 10.7 `discard_if_dealt_damage` — Fúria Instável (Ação Comum)

| # | Pré-condição | Esperado |
|---|---|---|
| 10.7.1 | Combate causou dano | Jogador **atacante** descarta 1 aleatório |
| 10.7.2 | Dano == 0 | Sem descarte |
| 10.7.3 | Mão vazia ao resolver | Sem descarte (não trava) |

### 10.8 `weaken_defense` — Finta (efeito antigo no set base)

| # | Pré-condição | Esperado |
|---|---|---|
| 10.8.1 | Jogar Finta | Próxima rodada do oponente: `next_defense_penalty = 1` |

---

## 11. Efeitos de Carta — Grupo I: Interativos (Overlays)

### 11.1 `put_bottom_then_draw` — Reorganizar (BA Rara)

| # | Pré-condição | Ação | Esperado |
|---|---|---|---|
| 11.1.1 | Mão com 2+ cartas | Jogar | Overlay de escolha; carta escolhida vai ao fundo; compra 1 |
| 11.1.2 | Mão vazia | Jogar | Sem overlay |

### 11.2 `recycle_graveyard_no_draw` — Respiração Profunda (BA Rara)

| # | Pré-condição | Ação | Esperado |
|---|---|---|---|
| 11.2.1 | Cemitério com cartas | Jogar | Overlay com cemitério; carta escolhida vai ao deck; sem compra |
| 11.2.2 | Cemitério vazio | Jogar | Sem overlay |

### 11.3 `optional_put_self_to_bottom` — Onda Reversa (Ação Comum)

| # | Pré-condição | Ação | Esperado |
|---|---|---|---|
| 11.3.1 | Fim de turno | Onda Reversa foi jogada | Pergunta ao jogador se quer pôr a carta no fundo |
| 11.3.2 | Jogador aceita | — | Carta vai ao fundo do deck |
| 11.3.3 | Jogador recusa | — | Carta vai ao cemitério normalmente |

---

## 12. Efeitos de Carta — Grupo J: Símbolos e Tutores

### 12.1 `pick_symbols` — Versatilidade (BA Comum), Iniciando na Magia (Reação Rara), Manipulando Elementos (Reação Lendária)

| # | Carta | Esperado |
|---|---|---|
| 12.1.1 | Versatilidade | Overlay para escolher 1 símbolo; adicionado à cadeia |
| 12.1.2 | Iniciando na Magia | Idem (count=1) |
| 12.1.3 | Manipulando Elementos | Overlay para escolher 2 símbolos; ambos adicionados à cadeia |
| 12.1.4 | Símbolo escolhido completa cadeia | — | `skill_activated` disparado imediatamente |

### 12.2 `add_symbols` — Manipulando Elementos (efeito antigo)

| # | Pré-condição | Esperado |
|---|---|---|
| 12.2.1 | Jogar carta com `add_symbols` [Fogo, Terra] | Símbolos adicionados diretamente à cadeia sem overlay |

### 12.3 `tutor_action` — Planos Futuro (BA Lendária)

| # | Pré-condição | Esperado |
|---|---|---|
| 12.3.1 | Deck com ACTION | Jogar Planos Futuro | 1ª carta ACTION do deck vem para a mão |
| 12.3.2 | Deck sem ACTION | Jogar Planos Futuro | Sem efeito; sem travamento |

### 12.4 `skill_trigger_draw` — Sintonia Primordial (Ação Lendária)

| # | Pré-condição | Esperado |
|---|---|---|
| 12.4.1 | `pending_skill_draw = true`; skill ativada no mesmo turno | Compra 1 carta |
| 12.4.2 | `pending_skill_draw = true`; skill não ativada | Sem compra |
| 12.4.3 | Skill ativa duas vezes no mesmo turno | Compra apenas 1 (flag zerada após 1ª compra) |

---

## 13. Efeitos de Carta — Grupo K: Bônus de Combate Composto

### 13.1 `bonus_if_card_type_played` — cartas condicionais por tipo de timing

| # | Pré-condição | Esperado |
|---|---|---|
| 13.1.1 | BA já jogada nessa rodada; jogar carta com `bonus_if_card_type_played(BONUS_ACTION)` | +ATK/+DEF conforme parâmetros |
| 13.1.2 | Nenhuma BA jogada | Sem bônus |
| 13.1.3 | Scope "turn" vs "combat" | turn verifica `cards_this_turn`; combat verifica `round_cards` |

### 13.2 `defense_scales_attack` — Fortaleza Inabalável (BA Lendária)

| # | Pré-condição | Ação | Esperado |
|---|---|---|---|
| 13.2.1 | Jogar Fortaleza Inabalável; depois jogar carta com +3 DEF | Resolver combate | `pending_bonus_attack += 3` (espelha a defesa) |
| 13.2.2 | Sem bônus de defesa no turno | Resolver | Sem bônus de ataque extra |
| 13.2.3 | Próximo turno | — | Flag zerada; efeito não persiste |

### 13.3 `draw_if_full_block` + `draw_discard_if_full_block` — Impacto Controlado (Ação)

| # | Pré-condição | Esperado |
|---|---|---|
| 13.3.1 | Dano final == 0 | Compra 1 |
| 13.3.2 | Dano final > 0 | Sem compra |

---

## 14. Casos de Borda Críticos

### 14.1 Derrota e game_over

| # | Cenário | Esperado |
|---|---|---|
| 14.1.1 | Último herói de um jogador morre em combate | `hero_defeated` → `game_over(winner_index)` emitido |
| 14.1.2 | Dano direto (Tiro de Oportunidade) derrota último herói | `game_over` emitido sem passar pelo `CombatResolver` normal |
| 14.1.3 | Ricochete (Ricochetear) derrota um herói | `game_over` se era o último |
| 14.1.4 | Ieldor ativa → acerta 1 dano em cada herói → derrota todos | `game_over` |

### 14.2 Deck vazio

| # | Cenário | Esperado |
|---|---|---|
| 14.2.1 | `draw_cards(1)` com deck vazio | Sem trava; `hand` inalterada |
| 14.2.2 | `draw_discard` com deck vazio | Compra 0; descarte não ocorre (mão pós-compra vazia) |
| 14.2.3 | `tutor_action` com deck vazio | Sem efeito |

### 14.3 Reset de modificadores

| # | Cenário | Esperado |
|---|---|---|
| 14.3.1 | `pending_bonus_attack` após rodada | Zerado antes da próxima rodada |
| 14.3.2 | `pending_damage_shield` após uso | Zerado |
| 14.3.3 | `next_round_bonus_attack` após rodada sem dano | **Não** zerado (persiste para próxima rodada) |
| 14.3.4 | `next_round_bonus_attack` após rodada com dano | Zerado (efeito cancelado) |
| 14.3.5 | `pending_skill_draw` fim de turno | Zerado |

### 14.4 Interações entre efeitos

| # | Cenário | Esperado |
|---|---|---|
| 14.4.1 | `defense_scales_attack` + `damage_shield` | ATK espelha DEF; escudo reduz dano recebido separadamente |
| 14.4.2 | Poppy passiva ativa + `pending_bonus_defense` positivo | Passiva de Poppy desativa |
| 14.4.3 | Nissin passiva ativa + dano extra de `pending_bonus_attack` | Ambos somados corretamente |
| 14.4.4 | Valkar passiva + Irena cura | Valkar reduz dano do aliado; Irena cura HP restante no final |
| 14.4.5 | Hakai furtivo + `attack_if_hidden` | +2 ATK da carta + qualquer bônus permanente de Hakai |
| 14.4.6 | `heal_all_allies` + Irena ativa | Todos os aliados recebem cura+1 |
| 14.4.7 | `both_recycle_arsenal` quando ambos têm cemitério vazio | Sem overlay; sem erro |
| 14.4.8 | `next_round_stealth` + Hakai passiva | Hakai começa furtivo na próxima rodada → passiva pode acumular |

### 14.5 Sincronização multiplayer

| # | Cenário | Esperado |
|---|---|---|
| 14.5.1 | `both_recycle_arsenal` — escolhas sequenciais | Servidor aguarda pick do 1º antes de iniciar pick do 2º |
| 14.5.2 | Overlay interativo em cliente não-host | RPC enviado ao servidor; resolução no servidor |
| 14.5.3 | Cliente joga carta do arsenal ao mesmo tempo que host | Servidor valida e aplica apenas uma vez |

---

## 15. Checklist Final de Smoke Test

Execute esta sequência rápida em qualquer build:

```
[ ] 1. Lobby: criar sala (host) + entrar (cliente)
[ ] 2. Mulligan: ambos descartam e confirmam
[ ] 3. Hero Selection: ambos escolhem heróis (verificar face-down do oponente)
[ ] 4. Jogar ACTION → oponente reage com REACTION → jogar BONUS_ACTION
[ ] 5. Resolver combate (dano aplicado corretamente)
[ ] 6. Fase END: guardar carta no arsenal; comprar 4
[ ] 7. Turno 2: herói exausto não selecionável
[ ] 8. Completar cadeia de símbolos de algum herói → skill_activated
[ ] 9. Herói com 0 HP → hero_defeated → verificar game_over se último
[ ] 10. DeckLoader.load_from_json("res://data/cards/taldorian_origins.json") sem erros no console
```

---

## Appendix — Mapeamento Rápido Efeito → Carta

| Effect ID | Cartas afetadas |
|---|---|
| `heal` | Respiração Serena, Recuperação Breve, Corrente Restauradora, Corrente Ascendente |
| `heal_after_combat` | Resistência Natural, Broto Vital |
| `heal_if_behind` | Renovação |
| `heal_if_full_block` | Fluxo Sereno |
| `heal_if_no_damage` | Maré Suave |
| `heal_all_allies` | Florescer Eterno |
| `heal_return_if_full` | Ciclo Vital |
| `draw_discard` | Pequenos Riscos, Corrente, Reflexo Líquido, Ajuste Fino, Desvio Rápido |
| `draw_then_put_bottom` | Ajuste Fino (BA antigo) |
| `recycle_graveyard_draw` | Contra Ataque (BA) |
| `recycle_graveyard_no_draw` | Respiração Profunda |
| `put_bottom_then_draw` | Reorganizar |
| `store_in_arsenal` | Passo Estratégico, Preparando o Arsenal |
| `scry` | Dois Passos à Frente |
| `draw_if_full_block` | Impacto Controlado |
| `draw_discard_if_full_block` | Impacto Controlado |
| `attack_if_symbol_played` | Chama Crescente |
| `attack_if_nth_card` | Encadeamento, Ritmo Calculado, Fluxo Perfeito |
| `attack_if_first_card` / `defense_if_first_card` | Ajuste de Guarda, Pressão Inicial |
| `attack_bonus_if_from_arsenal` | Brisa Cortante |
| `attack_if_hidden` | Sombra Oculta |
| `attack_if_damaged_this_round` | Sangue Quente |
| `attack_if_defense_low` | Frenesi |
| `fogo_symbol_count_attack` | Coração da Fornalha |
| `next_card_attack_bonus` | Impulso Ofensivo, Linha de Ferro |
| `next_card_both_bonus` | Pressão Contínua |
| `weaken_next_attack` | Finta |
| `persist_attack_if_no_damage` | Guarda Inabalável |
| `damage_shield` | Fluxo Reativo |
| `discard_for_attack` | Estopim |
| `discard_if_dealt_damage` | Fúria Instável |
| `ricochet` | Ricochetear |
| `both_recycle_arsenal` | Ecos do Passado |
| `defense_scales_attack` | Fortaleza Inabalável |
| `stealth_if_from_arsenal` | Véu Transitório |
| `stealth_hidden_at_combat` | Execução Silenciosa |
| `optional_put_self_to_bottom` | Onda Reversa |
| `skill_trigger_draw` | Sintonia Primordial |
| `direct_damage_if_first` | Tiro de Oportunidade |
| `pick_symbols` | Versatilidade, Iniciando na Magia, Manipulando Elementos |
| `bonus_if_card_type_played` | (cartas com bônus condicionais por tipo) |
| `draw_discard_if_card_type_played` | Ritmo, Fluxo Ágil |
| `defense_if_bonus_action_played` | Movimento Preciso, Impulso Rápido |
