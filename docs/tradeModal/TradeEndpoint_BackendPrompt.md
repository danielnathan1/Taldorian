# Prompt para Claude Code — Endpoint de Troca (`taldorian-service`)

Cole o conteúdo abaixo no Claude Code aberto **no repositório do backend** (`taldorian-service`).
Especifica **um único endpoint**, chamado pelo **servidor de mundo (autoridade, operado por nós)**,
que reporta uma troca **já concluída** (negociada e aceita pelos dois jogadores) para o backend
**efetivar** — transferir de fato cartas e ouro.

---

## CONTEXTO

No **Taldorian TCG** (cliente Godot 4, mundo aberto multiplayer), dois jogadores trocam cartas e
ouro. Toda a **negociação ao vivo** (adicionar/remover carta, ofertar ouro, aceitar, reconfirmação)
roda no **servidor de mundo** (autoridade da sessão — uma instância **operada por nós**, não pela
máquina de um jogador). Quando os dois aceitam, a troca está **fechada** e o **servidor de mundo**
chama o backend **uma vez** para **efetivar**.

Quem chama o backend é, portanto, um **serviço de confiança** (o servidor de mundo), não os
clientes. Mesmo assim, o backend é a **autoridade da transferência**: ele **revalida a posse** das
cartas e do ouro **dos dois lados** (defesa em profundidade contra bug/estado velho) e faz o swap
**atômico**. O inventário já é servido por `GET /players/me/inventory` e o ouro por
`GET /players/me`.

### Identidades
O contrato é **em termos do backend**:
- Jogadores → **`playerId` (UUID)** (mesmo id de `players`).
- Cartas → **`cardId` (UUID)** (mesmo id do catálogo/inventário).
- Ouro → inteiro (mesma carteira de `players.gold`).

> O servidor de mundo conhece os `playerId` dos participantes (cada cliente informa o seu ao
> entrar no mundo) e traduz suas cartas para `cardId`. Esse mapeamento é do lado Godot; aqui só
> definimos o contrato do backend.

---

## AUTENTICAÇÃO — server-to-server

Este endpoint é **exclusivo do servidor de mundo**. Ele **NÃO** aceita token de jogador.

- O servidor de mundo autentica com uma **credencial de serviço** (service account / API key),
  ex.: header `Authorization: Bearer <SERVICE_TOKEN>` ou `X-Service-Key: <KEY>`.
- A credencial fica em config/secret do backend (rotacionável). Só essa credencial pode efetivar
  trocas.
- Como o caller é confiável, ele age **em nome dos dois jogadores** ao mesmo tempo — por isso o
  payload traz os dois lados.

> **Por que server-to-server:** o servidor de mundo é a autoridade que rodou o aceite dos dois
> lados; é a entidade natural (e única) pra reportar "essa troca aconteceu". Como é operado por
> nós, dar a ele uma credencial de serviço é seguro — o que não seria verdade se o host pudesse
> ser a máquina de um jogador qualquer.

---

## OBJETIVO

Um endpoint que **recebe a troca concluída (as duas ofertas) e a efetiva**, com:
- **Revalidação de posse dos dois lados** (cartas + ouro),
- **Transação atômica** (ou transfere tudo, ou nada),
- **Idempotência** (retry de rede não duplica a troca).

---

## ENDPOINT

### `POST /trades`
Efetiva uma troca acordada entre dois jogadores. Chamado **pelo servidor de mundo**.

**Auth:** credencial de **serviço** (ver acima). Rejeita token de jogador → `403`.

**Request:**
```json
{
  "clientTradeId": "f1d2c3...-uuid",
  "playerOne": {
    "playerId": "uuid-do-jogador-A",
    "cards": [ { "cardId": "uuid", "quantity": 2, "foilQuantity": 1 } ],
    "gold": 100
  },
  "playerTwo": {
    "playerId": "uuid-do-jogador-B",
    "cards": [ { "cardId": "uuid", "quantity": 1, "foilQuantity": 0 } ],
    "gold": 0
  }
}
```
- `clientTradeId`: UUID gerado pelo servidor de mundo, **chave de idempotência** (protege retry).
- `playerOne` / `playerTwo`: os dois lados. Cada um lista o que **oferece** (cards + gold). O que
  A oferece é o que B recebe, e vice-versa.
- Em cada carta:
  - `quantity` = total de cópias ofertadas daquela carta.
  - `foilQuantity` = quantas dessas são **foil** (subconjunto: `0 ≤ foilQuantity ≤ quantity`).
    As demais (`quantity - foilQuantity`) são normais. Mesma semântica do
    `GET /players/me/inventory`.

**Comportamento (tudo em UMA transação):**
1. Valida payload (`playerOne`/`playerTwo` presentes, `playerId`s distintos e existentes,
   `quantity ≥ 1`, `0 ≤ foilQuantity ≤ quantity`, `gold ≥ 0`).
2. **Idempotência:** se já existe troca `COMPLETED` com esse `clientTradeId`, retorna `200` com o
   resultado já gravado (não re-executa).
3. **Revalida posse de cada lado:** cada party possui as `cards` (quantidades) e `gold ≤` saldo.
4. **Swap atômico:** remove os itens/ouro de A e adiciona em B, e vice-versa; ajusta `players.gold`
   dos dois. Qualquer falha → rollback total.
5. Persiste a troca (`COMPLETED`) e retorna o resultado.

**Resposta `200`:**
```json
{
  "tradeId": "uuid-gerado-no-backend",
  "status": "COMPLETED",
  "completedAt": "ISO-8601",
  "parties": [
    {
      "playerId": "uuid-A",
      "gave":     { "cards": [ { "cardId": "uuid", "quantity": 2 } ], "gold": 100 },
      "received": { "cards": [ { "cardId": "uuid", "quantity": 1 } ], "gold": 0 }
    },
    {
      "playerId": "uuid-B",
      "gave":     { "cards": [ { "cardId": "uuid", "quantity": 1 } ], "gold": 0 },
      "received": { "cards": [ { "cardId": "uuid", "quantity": 2 } ], "gold": 100 }
    }
  ]
}
```
O servidor de mundo repassa o sucesso aos clientes; cada cliente então recarrega via
`GET /players/me/inventory`.

---

## REGRAS DE VALIDAÇÃO

- **Os dois lados presentes** (`playerOne`/`playerTwo`), com `playerId` distintos e existentes/ativos. Senão `400`/`404`.
- **Cartas existem:** todo `cardId` deve estar no catálogo. Senão `404 CARD_NOT_FOUND`.
- **Posse de cartas (com foil):** cada party possui, daquele `cardId`:
  - ao menos `foilQuantity` cópias **foil**, e
  - ao menos `quantity - foilQuantity` cópias **normais**.
  Senão `409 INSUFFICIENT_CARDS`. Na transferência, mover a quantidade certa de cada tipo
  (foil vs normal) para o outro jogador.
- **foilQuantity válido:** `0 ≤ foilQuantity ≤ quantity`. Senão `400`.
- **Ouro:** `gold ≥ 0` e `≤ players[party].gold`.
- **Atomicidade:** swap inteiro numa transação de banco; falha em qualquer passo → rollback.
- **Idempotência:** mesma `clientTradeId` já efetivada → `200` com o resultado existente (sem
  re-executar nem duplicar). Constraint único em `client_trade_id`.
- **Sem auto-troca:** os dois `playerId` precisam ser diferentes.

---

## ERROS (formato padrão do serviço)

| HTTP | code                 | quando                                                |
|------|----------------------|-------------------------------------------------------|
| 400  | `INVALID_PAYLOAD`    | corpo malformado, ≠ 2 parties, quantity ≤ 0, gold < 0 |
| 401  | `UNAUTHENTICATED`    | sem credencial de serviço                             |
| 403  | `FORBIDDEN`          | credencial não-serviço (ex.: token de jogador)        |
| 404  | `PLAYER_NOT_FOUND`   | algum `playerId` inexistente                          |
| 404  | `CARD_NOT_FOUND`     | algum `cardId` fora do catálogo                       |
| 409  | `INSUFFICIENT_CARDS` | party não possui as cópias ofertadas                  |
| 409  | `INSUFFICIENT_GOLD`  | ouro ofertado > saldo                                 |

Body de erro (seguir o padrão já usado no serviço):
```json
{ "error": { "code": "INSUFFICIENT_GOLD", "message": "..." } }
```

---

## MODELO DE DADOS (sugestão)

```
trades
  id (uuid, pk)
  client_trade_id (uuid, unique)     -- idempotência
  player_a_id (uuid, fk players)
  player_b_id (uuid, fk players)
  a_gold (int)                       -- ouro ofertado por A
  b_gold (int)                       -- ouro ofertado por B
  status (enum: COMPLETED)
  completed_at (timestamp)

trade_items
  trade_id (fk trades)
  from_player_id (uuid)              -- de quem saiu a carta
  card_id (uuid, fk cards)
  quantity (int)
```
A transferência efetiva mexe nas tabelas de inventário/posse existentes (as mesmas que
`/players/me/inventory` lê) e em `players.gold`.

---

## INTEGRAÇÃO COM O CLIENTE/SERVIDOR GODOT (fora do escopo do backend, p/ contexto)

- A chamada de efetivação sai do **servidor de mundo** (autoridade), não do cliente — no Godot,
  no momento em que a sessão de troca conclui (`WorldTrade._complete`, lado servidor).
- O servidor precisa dos `playerId` (UUID) dos dois participantes: cada cliente informa o seu ao
  entrar no mundo. Mapear id-local-de-carta → `cardId` (UUID) usa o `Collection`.
- Em `200`, o servidor avisa os dois clientes, que recarregam o inventário.

---

## ENTREGÁVEIS
- [ ] Migrations: `trades`, `trade_items` (+ índice/constraint único em `client_trade_id`).
- [ ] `POST /trades` (efetivação) com **auth de serviço** e validação de posse dos 2 lados.
- [ ] Swap **atômico** em transação + **idempotência** por `clientTradeId`.
- [ ] Configuração/rotação da credencial de serviço; rejeitar tokens de jogador neste endpoint.
- [ ] Testes: caminho feliz, posse insuficiente, ouro insuficiente, carta/jogador inexistente,
      auth inválida (token de jogador → 403) e **retry idempotente**.
- [ ] Atualizar a doc da API (OpenAPI/README) com o contrato acima.
