# Taldorian API — Plano de Arquitetura

## Visão Geral

API REST separada do cliente Godot. O jogo faz requisições HTTP para persistir e recuperar dados de jogador, coleção, decks e configurações. A partida em si continua resolvida localmente via ENet (P2P/LAN) — a API não interfere no fluxo de jogo em tempo real.

**Stack:**
- Kotlin + Spring Boot 3.x
- Spring Data JPA (Hibernate)
- PostgreSQL 16
- Flyway (migrações de schema)
- springdoc-openapi (Swagger UI)
- Spring Security + JWT (autenticação stateless)

---

## Estrutura do Projeto

```
taldorian-api/
├── build.gradle.kts
├── settings.gradle.kts
├── docker-compose.yml                  # postgres local para dev
│
└── src/
    ├── main/
    │   ├── kotlin/com/taldorian/
    │   │   ├── TaldorianApplication.kt
    │   │   │
    │   │   ├── config/
    │   │   │   ├── SecurityConfig.kt   # filtros JWT, rotas públicas vs protegidas
    │   │   │   ├── JwtConfig.kt        # geração e validação de tokens
    │   │   │   └── OpenApiConfig.kt    # configuração Swagger
    │   │   │
    │   │   ├── domain/
    │   │   │   ├── auth/
    │   │   │   │   ├── AuthController.kt
    │   │   │   │   ├── AuthService.kt
    │   │   │   │   └── dto/            # LoginRequest, RegisterRequest, TokenResponse
    │   │   │   │
    │   │   │   ├── player/
    │   │   │   │   ├── Player.kt       # entidade JPA
    │   │   │   │   ├── PlayerRepository.kt
    │   │   │   │   ├── PlayerService.kt
    │   │   │   │   ├── PlayerController.kt
    │   │   │   │   └── dto/
    │   │   │   │
    │   │   │   ├── card/
    │   │   │   │   ├── Card.kt
    │   │   │   │   ├── CardRepository.kt
    │   │   │   │   ├── CardService.kt
    │   │   │   │   ├── CardController.kt
    │   │   │   │   └── dto/
    │   │   │   │
    │   │   │   ├── hero/
    │   │   │   │   ├── Hero.kt
    │   │   │   │   ├── HeroRepository.kt
    │   │   │   │   ├── HeroService.kt
    │   │   │   │   ├── HeroController.kt
    │   │   │   │   └── dto/
    │   │   │   │
    │   │   │   ├── playmat/
    │   │   │   │   ├── Playmat.kt
    │   │   │   │   ├── PlaymatRepository.kt
    │   │   │   │   ├── PlaymatService.kt
    │   │   │   │   ├── PlaymatController.kt
    │   │   │   │   └── dto/
    │   │   │   │
    │   │   │   ├── collection/
    │   │   │   │   ├── PlayerCard.kt        # relação player ↔ card com quantity
    │   │   │   │   ├── PlayerHero.kt        # relação player ↔ hero
    │   │   │   │   ├── PlayerPlaymat.kt     # relação player ↔ playmat
    │   │   │   │   ├── CollectionRepository.kt
    │   │   │   │   ├── CollectionService.kt
    │   │   │   │   └── CollectionController.kt
    │   │   │   │
    │   │   │   └── deck/
    │   │   │       ├── Deck.kt
    │   │   │       ├── DeckCard.kt          # relação deck ↔ card com quantity
    │   │   │       ├── DeckRepository.kt
    │   │   │       ├── DeckService.kt
    │   │   │       ├── DeckController.kt
    │   │   │       └── dto/
    │   │   │
    │   │   └── shared/
    │   │       ├── exception/
    │   │       │   ├── GlobalExceptionHandler.kt
    │   │       │   ├── NotFoundException.kt
    │   │       │   └── ForbiddenException.kt
    │   │       └── dto/
    │   │           └── ErrorResponse.kt
    │   │
    │   └── resources/
    │       ├── application.yml
    │       ├── application-dev.yml
    │       └── db/migration/
    │           ├── V1__create_players.sql
    │           ├── V2__create_master_data.sql   # cards, heroes, playmats
    │           ├── V3__create_collection.sql
    │           ├── V4__create_decks.sql
    │           └── V5__seed_base_set.sql        # dados do set base
    │
    └── test/
        └── kotlin/com/taldorian/
            ├── domain/auth/AuthControllerTest.kt
            ├── domain/deck/DeckServiceTest.kt
            └── domain/collection/CollectionServiceTest.kt
```

---

## Entidades

### `players`

| Coluna          | Tipo           | Observação                          |
|-----------------|----------------|-------------------------------------|
| id              | UUID PK        |                                     |
| username        | VARCHAR(32)    | único, usado no jogo                |
| email           | VARCHAR(255)   | único                               |
| password_hash   | VARCHAR(255)   | bcrypt                              |
| active_playmat_id | UUID FK      | playmat selecionado atualmente      |
| created_at      | TIMESTAMPTZ    |                                     |
| updated_at      | TIMESTAMPTZ    |                                     |

---

### `cards` (master data — catálogo)

| Coluna         | Tipo           | Observação                              |
|----------------|----------------|-----------------------------------------|
| id             | UUID PK        |                                         |
| card_key       | VARCHAR(64)    | único, usado no JSON do jogo (`card_id`)|
| name           | VARCHAR(100)   |                                         |
| card_type      | VARCHAR(20)    | ACTION / BONUS_ACTION / REACTION        |
| attack_value   | INT            |                                         |
| defense_value  | INT            |                                         |
| symbols        | VARCHAR[]      | array de GameSymbols                    |
| is_stealth     | BOOLEAN        |                                         |
| art_key        | VARCHAR(100)   | nome do arquivo em assets/cards/        |
| max_copies     | INT            | limite por deck (ex: 3)                 |
| set_code       | VARCHAR(20)    | "BASE", futuros expansões               |
| description    | TEXT           | texto de sabor / efeito                 |

---

### `heroes` (master data — catálogo)

| Coluna           | Tipo         | Observação                              |
|------------------|--------------|-----------------------------------------|
| id               | UUID PK      |                                         |
| hero_key         | VARCHAR(64)  | único, ex: "hero_poppy"                 |
| name             | VARCHAR(100) |                                         |
| hero_class       | VARCHAR(32)  | BARBARIAN, ROGUE, etc.                  |
| max_hp           | INT          |                                         |
| base_attack      | INT          |                                         |
| base_defense     | INT          |                                         |
| symbols_required | VARCHAR[]    | cadeia de ativação da habilidade        |
| skill_name       | VARCHAR(100) |                                         |
| skill_desc       | TEXT         |                                         |
| art_key          | VARCHAR(100) |                                         |
| set_code         | VARCHAR(20)  |                                         |

---

### `playmats` (master data — catálogo)

| Coluna    | Tipo         | Observação              |
|-----------|--------------|-------------------------|
| id        | UUID PK      |                         |
| name      | VARCHAR(100) |                         |
| art_key   | VARCHAR(100) |                         |
| set_code  | VARCHAR(20)  |                         |

---

### `player_cards` (coleção de cartas do jogador)

| Coluna     | Tipo    | Observação                   |
|------------|---------|------------------------------|
| player_id  | UUID FK |                              |
| card_id    | UUID FK |                              |
| quantity   | INT     | quantas cópias o jogador tem |

PK composta: `(player_id, card_id)`

---

### `player_heroes` (heróis desbloqueados)

| Coluna    | Tipo    |
|-----------|---------|
| player_id | UUID FK |
| hero_id   | UUID FK |

PK composta: `(player_id, hero_id)`

---

### `player_playmats` (playmats desbloqueados)

| Coluna      | Tipo    |
|-------------|---------|
| player_id   | UUID FK |
| playmat_id  | UUID FK |

PK composta: `(player_id, playmat_id)`

---

### `decks`

| Coluna      | Tipo         | Observação                              |
|-------------|--------------|-----------------------------------------|
| id          | UUID PK      |                                         |
| player_id   | UUID FK      |                                         |
| name        | VARCHAR(100) |                                         |
| is_active   | BOOLEAN      | deck selecionado para a próxima partida |
| created_at  | TIMESTAMPTZ  |                                         |
| updated_at  | TIMESTAMPTZ  |                                         |

---

### `deck_cards`

| Coluna   | Tipo    | Observação                                      |
|----------|---------|-------------------------------------------------|
| deck_id  | UUID FK |                                                 |
| card_id  | UUID FK |                                                 |
| quantity | INT     | validado contra `cards.max_copies` no save      |

PK composta: `(deck_id, card_id)`

---

### `deck_heroes` (heróis do deck — 3 por time)

| Coluna    | Tipo    |
|-----------|---------|
| deck_id   | UUID FK |
| hero_id   | UUID FK |
| slot      | INT     | 0, 1, 2 — posição no time |

PK composta: `(deck_id, slot)`

---

## Endpoints — V1

### Auth

| Método | Rota               | Descrição                          | Auth |
|--------|--------------------|------------------------------------|------|
| POST   | /auth/register     | Cria conta (username, email, senha)| —    |
| POST   | /auth/login        | Retorna `access_token` + `refresh_token` | — |
| POST   | /auth/refresh      | Renova access token via refresh    | —    |
| POST   | /auth/logout       | Invalida refresh token             | JWT  |

---

### Player

| Método | Rota              | Descrição                              | Auth |
|--------|-------------------|----------------------------------------|------|
| GET    | /players/me       | Perfil do jogador autenticado          | JWT  |
| PATCH  | /players/me       | Atualiza username ou active_playmat_id | JWT  |
| DELETE | /players/me       | Remove conta                           | JWT  |

---

### Coleção

| Método | Rota                          | Descrição                              | Auth |
|--------|-------------------------------|----------------------------------------|------|
| GET    | /collection/cards             | Todas as cartas que o jogador possui   | JWT  |
| GET    | /collection/heroes            | Todos os heróis desbloqueados          | JWT  |
| GET    | /collection/playmats          | Todos os playmats desbloqueados        | JWT  |

> *Nota: concessão de itens à coleção (compra, recompensa) será endpoint admin/interno na V2.*

---

### Decks

| Método | Rota               | Descrição                                  | Auth |
|--------|--------------------|--------------------------------------------|------|
| GET    | /decks             | Lista todos os decks do jogador            | JWT  |
| POST   | /decks             | Cria novo deck                             | JWT  |
| GET    | /decks/{id}        | Detalhe do deck (cartas + heróis)          | JWT  |
| PUT    | /decks/{id}        | Atualiza deck completo (cartas + heróis)   | JWT  |
| DELETE | /decks/{id}        | Remove deck                                | JWT  |
| PATCH  | /decks/{id}/active | Define como deck ativo                     | JWT  |

**Validações no save do deck:**
- Exatamente 3 heróis no `deck_heroes`
- Cada herói pertence à `player_heroes` do jogador
- Cada carta em `deck_cards` pertence à `player_cards` com `quantity` suficiente
- Nenhuma carta excede `cards.max_copies` no deck

---

### Catálogo (leitura pública)

| Método | Rota               | Descrição                     | Auth |
|--------|--------------------|-------------------------------|------|
| GET    | /catalog/cards     | Todas as cartas do jogo       | —    |
| GET    | /catalog/cards/{id}| Detalhe de uma carta          | —    |
| GET    | /catalog/heroes    | Todos os heróis               | —    |
| GET    | /catalog/heroes/{id}| Detalhe de um herói          | —    |
| GET    | /catalog/playmats  | Todos os playmats             | —    |

---

### Admin (V1 — protegido por role ADMIN)

| Método | Rota                              | Descrição                              |
|--------|-----------------------------------|----------------------------------------|
| POST   | /admin/cards                      | Cadastra nova carta no catálogo        |
| PUT    | /admin/cards/{id}                 | Atualiza carta                         |
| POST   | /admin/heroes                     | Cadastra novo herói                    |
| POST   | /admin/playmats                   | Cadastra novo playmat                  |
| POST   | /admin/players/{id}/collection/cards   | Concede cartas a um jogador       |
| POST   | /admin/players/{id}/collection/heroes  | Concede herói a um jogador        |
| POST   | /admin/players/{id}/collection/playmats| Concede playmat a um jogador      |

---

## Autenticação

JWT stateless com dois tokens:

| Token         | TTL     | Uso                                  |
|---------------|---------|--------------------------------------|
| access_token  | 1 hora  | Enviado em `Authorization: Bearer …` |
| refresh_token | 30 dias | Armazenado em DB; rotacionado no uso |

No Godot, o jogo armazena o `access_token` em memória e o `refresh_token` em `user://` (caminho persistente). Renova automaticamente ao receber 401.

---

## DTOs de Resposta — Exemplos

### `PlayerResponse`
```json
{
  "id": "uuid",
  "username": "danielnathan",
  "activePlaymat": { "id": "uuid", "name": "Floresta Sombria", "artKey": "playmat_forest" }
}
```

### `DeckDetailResponse`
```json
{
  "id": "uuid",
  "name": "Deck Poppy Fogo",
  "isActive": true,
  "heroes": [
    { "slot": 0, "heroKey": "hero_poppy", "name": "Poppy, Martelo do Destino" },
    { "slot": 1, "heroKey": "hero_grok", "name": "Grok" },
    { "slot": 2, "heroKey": "hero_irena", "name": "Irena" }
  ],
  "cards": [
    { "cardKey": "golpe_bruto", "name": "Golpe Bruto", "quantity": 3 },
    { "cardKey": "all_in",      "name": "All In",       "quantity": 2 }
  ]
}
```

### `CollectionCardsResponse`
```json
{
  "cards": [
    { "cardKey": "golpe_bruto", "name": "Golpe Bruto", "quantity": 3, "maxCopies": 3 }
  ],
  "total": 1
}
```

---

## Integração com Godot

O jogo acessa a API via `HTTPRequest` node ou `http_client` do Godot.

**Fluxo sugerido no jogo:**
1. Na tela inicial → `POST /auth/login` → salva tokens
2. Antes do lobby → `GET /decks` + `GET /decks/{activeId}` → monta `DeckLoader` local
3. Durante o jogo → nenhuma chamada à API (tudo via ENet)
4. Ao final da partida → futuramente `POST /matches` para salvar histórico (V2)

**Variável de configuração no Godot:**
```gdscript
# src/autoload/api_client.gd  (autoload a criar)
const BASE_URL := "http://localhost:8080"  # dev
# const BASE_URL := "https://api.taldorian.com"  # prod
```

---

## Migrações Flyway — Ordem

| Versão | Arquivo                      | Conteúdo                                    |
|--------|------------------------------|---------------------------------------------|
| V1     | create_players.sql           | Tabela `players`                            |
| V2     | create_master_data.sql       | `cards`, `heroes`, `playmats`               |
| V3     | create_collection.sql        | `player_cards`, `player_heroes`, `player_playmats` |
| V4     | create_decks.sql             | `decks`, `deck_cards`, `deck_heroes`        |
| V5     | seed_base_set.sql            | Insert de todas as cartas e heróis do set base |
| V6     | add_refresh_tokens.sql       | `refresh_tokens` (id, player_id, token_hash, expires_at, revoked) |

---

## application.yml (esqueleto)

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/taldorian
    username: ${DB_USER:taldorian}
    password: ${DB_PASS:secret}
  jpa:
    hibernate:
      ddl-auto: validate        # flyway cuida do schema; hibernate só valida
    open-in-view: false
  flyway:
    locations: classpath:db/migration
    baseline-on-migrate: true

taldorian:
  jwt:
    secret: ${JWT_SECRET}       # mínimo 256 bits
    access-ttl-minutes: 60
    refresh-ttl-days: 30

springdoc:
  swagger-ui:
    path: /swagger-ui
  api-docs:
    path: /api-docs
```

---

## Dependências (build.gradle.kts)

```kotlin
dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-security")
    implementation("org.springframework.boot:spring-boot-starter-validation")
    implementation("org.flywaydb:flyway-core")
    implementation("org.flywaydb:flyway-database-postgresql")
    runtimeOnly("org.postgresql:postgresql")
    implementation("io.jsonwebtoken:jjwt-api:0.12.5")
    runtimeOnly("io.jsonwebtoken:jjwt-impl:0.12.5")
    runtimeOnly("io.jsonwebtoken:jjwt-jackson:0.12.5")
    implementation("org.springdoc:springdoc-openapi-starter-webmvc-ui:2.5.0")
    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.springframework.security:spring-security-test")
}
```

---

## Roadmap de Versões

### V1 — Base (esse documento)
- Auth (register, login, refresh, logout)
- Catálogo público (cards, heroes, playmats)
- Coleção do jogador
- CRUD de decks com validação
- Admin para seed de itens

### V2 — Social e Histórico
- `POST /matches` — salvar resultado de partida
- `GET /players/{username}/profile` — perfil público
- `GET /leaderboard` — ranking por vitórias

### V3 — Economia (futuro)
- Sistema de pacotes/boosters
- Mercado entre jogadores
- Missões e recompensas diárias
```
