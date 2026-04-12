# Taldorian TCG — Product Plan

> Card Game Tático | Inspirado em Flesh and Blood | 3 heróis por jogador

---

## Visão do Projeto

**Gênero:** Card Game Tático (TCG-like)  
**Inspiração:** Flesh and Blood + combate por duelos  
**Plataforma inicial:** Protótipo CLI / Godot  

### Diferenciais principais

- 3 heróis por jogador (em vez de 1, como na maioria dos TCGs)
- Sistema de sequência de símbolos → ativa habilidades únicas
- Combate por turnos com escolha estratégica de herói (face-down)
- Sistema de exaustão rotativa → força variedade e rotação

---

## Loop Principal

```
Comprar cartas (até 6)
  → Ajustar mão (2 cartas pro fundo)
	→ Escolher herói (face-down)
	  → Fase de ações (alternada)
		→ Revelação
		  → Combate
			→ Pós-combate (arsenal)
			  → Comprar até 4 cartas
```

**Objetivo:** derrotar os 3 heróis do oponente.

---

## Componentes do Jogo

### Heróis

Cada jogador tem 3 heróis fixos com os seguintes atributos:

| Atributo | Descrição |
|---|---|
| Vida | Pontos de vida do herói |
| Classe | Tank / DPS / Utility |
| Habilidade | Ativada por sequência de símbolos |
| Estado | Ativo / Exausto / Derrotado |

**Exemplo de herói:**

```
Nome: Kael, o Flamejante
Vida: 20
Classe: Mago (DPS)
Habilidade: Ao jogar 🔥🔥 → causa 2 de dano extra
```

### Cartas

**Set inicial (simplificado):**
- Ataque: +1 / +2 / +3
- Defesa: +1 / +2 / +3

**Evolução futura:**
- Efeitos (veneno, paralisia, escudo)
- Controle (pular turno, trocar herói)
- Buff / Debuff
- Interrupções (reagir à jogada do oponente)

### Sistema de Símbolos *(core diferencial)*

```
🔥  ⚔️  🛡️  🌿  🌑
```

- Cartas possuem símbolos
- Jogador cria sequência durante o turno
- Sequência ativa habilidade do herói ativo
- **Limite:** máx 3 símbolos ativos por turno

**Exemplos de combos:**

| Sequência | Efeito |
|---|---|
| 🔥 + 🔥 | Ativa skill de dano extra |
| ⚔️ + 🛡️ | Efeito híbrido (dano + absorção) |
| 🌑 + 🌑 + 🌑 | Habilidade ultimate do herói |

---

## Estrutura de Turno (detalhada)

### 1. Início do turno
- Comprar até **6 cartas**
- Escolher **2 cartas** → colocar no fundo do deck

### 2. Fase de escolha de herói
- Ambos escolhem 1 herói (**face-down**)
- Herói enviado para a zona de combate

### 3. Fase de ação (alternada)

Jogadores alternam. Cada um pode:
- Jogar carta
- Passar

> **Regra de blefe:** ao jogar a primeira carta **não furtiva**, o herói é revelado.  
> Cartas furtivas podem ser jogadas sem revelar o herói — cria mind game.

### 4. Fase de combate
- Revelação total dos heróis
- Soma de Ataque e Defesa
- Resolução de dano

### 5. Fase final
- Guardar **1 carta** no arsenal
- Comprar até **4 cartas**
- Herói usado → **exausto**

> **Exaustão rotativa:** herói só pode ser usado novamente após os outros 2 serem usados. Força rotação estratégica e evita repetição.

---

## Roadmap de Produto

### Fase 1 — Protótipo jogável `~4 semanas`

> **Objetivo:** validar se o loop central é divertido antes de qualquer investimento visual.

#### Épico A — Engine de turnos
- [ ] Estrutura de turno (compra → ação → combate → pós)
- [ ] Estado dos heróis (vida, ativo, exausto, derrotado)
- [ ] Condição de vitória (3 heróis derrubados)

#### Épico B — Heróis & deck básico
- [ ] Modelo de dados do herói (vida, classe, habilidade)
- [ ] Deck de 20 cartas de ataque e defesa (+1/+2/+3)
- [ ] Exaustão rotativa entre os 3 heróis

#### Épico C — Combate & arsenal
- [ ] Seleção face-down + revelação simultânea
- [ ] Cálculo de dano (ataque − defesa)
- [ ] Guardar 1 carta no arsenal por turno

**Riscos da Fase 1:**
- Loop pode parecer raso sem os símbolos → testar cedo com playtesters
- Exaustão rotativa pode confundir na primeira partida → simplificar tutorial

---

### Fase 2 — Core gameplay `~4 semanas`

> **Objetivo:** sistema de símbolos funcionando + primeiros playtests internos.

#### Épico D — Sistema de símbolos
- [ ] 5 símbolos base (🔥 ⚔️ 🛡️ 🌿 🌑)
- [ ] Detecção de sequência por turno (máx 3 ativos)
- [ ] Ativação de habilidade do herói por combo

#### Épico E — Habilidades de herói
- [ ] Tank: absorção de dano / taunt
- [ ] DPS: bônus de dano por combo de símbolos
- [ ] Utility: buff / debuff no alvo

#### Épico F — Fase de blefe
- [ ] Herói oculto até primeira carta não-furtiva
- [ ] Carta furtiva: jogada sem revelar o herói
- [ ] Revelação total na fase de combate

**Riscos da Fase 2:**
- Combos de símbolo podem quebrar balanceamento → limitar a 3 por turno
- Furtividade precisa de regra clara para não travar o turno

---

### Fase 3 — Playtest & balanceamento `~3 semanas`

> **Objetivo:** dados reais de partidas + ajuste de ritmo e snowball.

#### Épico G — Métricas de partida
- [ ] Log de turnos por partida
- [ ] Taxa de uso por herói
- [ ] Frequência de ativação de símbolos

#### Épico H — Anti-snowball
- [ ] Buff passivo ao perder o 1º herói
- [ ] Habilidade especial desbloqueada em desvantagem
- [ ] Testar sem o buff → medir taxa de virada

#### Épico I — Ritmo do jogo
- [ ] Limite de 3 cartas jogadas por turno
- [ ] Timer opcional para partidas competitivas
- [ ] Meta de duração por partida: 20–30 min

**Risco da Fase 3:**
- RNG de compra pode dominar skill → observar nos logs de playtest

---

### Fase 4 — Identidade & expansão `contínuo`

> **Objetivo:** dar vida ao universo Taldorian e preparar a versão beta pública.

#### Épico J — Lore & arte
- [ ] Nome e backstory dos heróis iniciais
- [ ] Arte de cartas (ataque, defesa, especial)
- [ ] UI do tabuleiro com tema Taldorian

#### Épico K — Expansão de cartas
- [ ] Cartas de efeito (veneno, paralisia, escudo)
- [ ] Cartas de controle (pular turno, trocar herói)
- [ ] Interrupções (reagir à jogada do oponente)

#### Épico L — Modo online (beta)
- [ ] Sync de estado de partida entre 2 jogadores
- [ ] Lobby e convite por link
- [ ] Histórico de partidas

---

## Pontos Fortes do Design

| Mecânica | Por que funciona |
|---|---|
| 3 heróis por jogador | Diferente de praticamente todos os TCGs; cria rotação estratégica |
| Sequência de símbolos | Mecânica baseada em habilidade; pode virar a assinatura do jogo |
| Fase de blefe (face-down) | Mind game forte com profundidade sem complexidade absurda |
| Exaustão rotativa | Evita repetição do mesmo herói; força variedade tática |

---

## Riscos & Mitigações

| Risco | Impacto | Mitigação |
|---|---|---|
| Ritmo lento | Alto | Limitar a 3 cartas por turno; custo de energia opcional |
| Combos quebrados | Alto | Papéis claros por classe (Tank / DPS / Utility) |
| RNG > Skill | Médio | Controle de deck (mandar cartas pro fundo já ajuda) |
| Snowball | Médio | Buff passivo ao perder herói; habilidade de comeback |

---

## Classes de Herói — Identidades

```
Guerreiro   → agressivo, dano direto, sem combo
Mago        → combos de símbolo, burst damage
Ladino      → furtividade, blefe, cartas escondidas
Tank        → absorção, taunt, proteção dos outros heróis
```

---

## Próximos passos imediatos

1. **Definir os 3 heróis do set inicial** (vida, classe, habilidade, custo de símbolo)
2. **Implementar a Fase 1** em CLI ou Godot sem UI elaborada
3. **Primeira partida solo** (controlar os dois lados) para validar o loop
4. **Playtest com 1 amigo** após a Fase 2 estar funcional

---

*Documento gerado como base de produto — atualizar conforme playtests e decisões de design.*
