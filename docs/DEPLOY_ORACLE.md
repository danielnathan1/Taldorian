# Deploy do servidor no Oracle Cloud (Always Free, ARM)

Guia para subir o **backend** (taldorian-service) + o **servidor de mundo** (Godot `--world-server`)
numa VM Ampere ARM gratuita do Oracle Cloud, e apontar os clientes pra ela (sem Hamachi).

> Stack final na VM: **PostgreSQL** (Docker, só local) + **backend Spring** (8080) +
> **servidor de mundo Godot** (7001/UDP). Clientes Windows conectam pelo IP público da VM.

---

## ⚠️ Os 2 atritos do Oracle (saber de antemão)

1. **Capacidade ARM:** criar a instância Ampere grátis às vezes dá "Out of capacity".
   Solução: tentar outra **Availability Domain**, outra região, ou repetir mais tarde.
2. **Firewall em DUAS camadas:** abrir porta no Oracle tem 2 lugares — a **Security List**
   (firewall da nuvem) **E** o **iptables** dentro do Ubuntu (as imagens da Oracle já vêm
   com iptables bloqueando tudo menos SSH). Esquecer um dos dois = "não conecta". Ver Fase 3 e 5.

---

## Fase 1 — Conta + Always Free

1. Cria conta em https://www.oracle.com/cloud/free/ (precisa de cartão pra verificação;
   recursos **Always Free** não cobram).
2. Anota a **Home Region** (a free só vive na home region).
3. (Recomendado) Após criar a VM, troca a conta pra **Pay As You Go** — continua usando só o
   free, mas a Oracle para de recuperar instâncias por ociosidade.

## Fase 2 — Criar a VM

Menu → **Compute → Instances → Create Instance**:
- **Image:** Canonical **Ubuntu** (22.04 ou 24.04).
- **Shape:** **Ampere (VM.Standard.A1.Flex)** → ajusta p/ ex. **2 OCPU / 12 GB** (cabe no free
  de 4 OCPU / 24 GB; pode pôr os 4/24 se quiser).
- **SSH keys:** gera/baixa o par (ou cola sua chave pública). Guarda a **chave privada**.
- **Create.** Anota o **IP público** quando subir.

## Fase 3 — Abrir portas na Security List (firewall da nuvem)

Networking → **VCN** → **Security List** (da subnet) → **Add Ingress Rules**:

| Source CIDR | Protocolo | Porta | Pra quê |
|---|---|---|---|
| 0.0.0.0/0 | TCP | 22   | SSH (já costuma existir) |
| 0.0.0.0/0 | TCP | 8080 | Backend HTTP |
| 0.0.0.0/0 | **UDP** | 7001 | Servidor de mundo (ENet) |

> ⚠️ 7001 é **UDP**. Postgres (5432) **NÃO** entra aqui — fica só local.

## Fase 4 — Conectar via SSH

```bash
chmod 600 sua-chave.key
ssh -i sua-chave.key ubuntu@SEU_IP_PUBLICO
sudo apt update && sudo apt upgrade -y
```

## Fase 5 — Abrir portas no iptables do Ubuntu (a camada esquecida)

```bash
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 8080 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p udp --dport 7001 -j ACCEPT
# persistir entre reboots:
sudo apt install -y netfilter-persistent iptables-persistent
sudo netfilter-persistent save
```

## Fase 6 — Postgres (Docker, só local)

```bash
# Docker
sudo apt install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker ubuntu   # relogar o ssh depois disso

# Postgres exposto SÓ no localhost (127.0.0.1) — nunca público
docker run -d --name taldorian-pg --restart unless-stopped \
  -e POSTGRES_USER=taldorian -e POSTGRES_PASSWORD=TROQUE_ESTA_SENHA \
  -e POSTGRES_DB=taldorian \
  -p 127.0.0.1:5432:5432 \
  -v pgdata:/var/lib/postgresql/data \
  postgres:16
```

## Fase 7 — Backend (taldorian-service)

O backend é Kotlin/Spring (JDK 21). Caminho mais simples: **buildar o jar no seu PC** e copiar.

No seu PC (no repo `taldorian-service`):
```bash
./gradlew bootJar      # gera build/libs/*.jar
```
Copia pra VM:
```bash
scp -i sua-chave.key build/libs/taldorian-service-*.jar ubuntu@SEU_IP:/home/ubuntu/backend.jar
```
Na VM, instala o Java e cria um serviço systemd:
```bash
sudo apt install -y openjdk-21-jre-headless
```
```bash
sudo tee /etc/systemd/system/taldorian-backend.service >/dev/null <<'EOF'
[Unit]
Description=Taldorian Backend
After=network.target docker.service

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu
Environment=DB_USER=taldorian
Environment=DB_PASS=TROQUE_ESTA_SENHA
Environment=JWT_SECRET=GERE_UM_SEGREDO_LONGO_AQUI
Environment=SERVICE_TOKEN_SECRET=OUTRO_SEGREDO_LONGO
ExecStart=/usr/bin/java -Xmx512m -jar /home/ubuntu/backend.jar
Restart=always

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now taldorian-backend
sudo journalctl -u taldorian-backend -f   # ver os logs
```

> **Checkpoint do banco:** garanta que o schema foi criado. O projeto usa **Flyway**; se estiver
> desabilitado no `application.yml`, habilite em produção (`spring.flyway.enabled=true`) ou rode
> as migrations manualmente. Confirme no CLAUDE.md/README do `taldorian-service`.
>
> Teste: `curl http://localhost:8080/swagger-ui` na VM deve responder.

## Fase 8 — Servidor de mundo (export Godot Linux ARM64)

No **PC**, no projeto do jogo (`taldorian`):
1. Project → Export → **Add… → Linux**.
2. **Architecture = arm64** (baixe os export templates se pedir).
3. **Embed PCK = ligado** (1 arquivo só).
4. Export Project → ex.: `taldorian_server` (sem extensão, ou `.arm64`).

Copia e roda na VM:
```bash
scp -i sua-chave.key taldorian_server ubuntu@SEU_IP:/home/ubuntu/taldorian_server
ssh -i sua-chave.key ubuntu@SEU_IP
chmod +x /home/ubuntu/taldorian_server
# teste manual primeiro:
./taldorian_server --headless -- --world-server
# deve imprimir: [WorldServer] Servidor do mundo rodando na porta 7001
```
> Se reclamar de biblioteca faltando, instale o que pedir (headless costuma rodar limpo).

systemd pra manter de pé:
```bash
sudo tee /etc/systemd/system/taldorian-world.service >/dev/null <<'EOF'
[Unit]
Description=Taldorian World Server
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu
ExecStart=/home/ubuntu/taldorian_server --headless -- --world-server
Restart=always

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now taldorian-world
sudo journalctl -u taldorian-world -f
```

> O **service token** (pra o servidor efetivar trocas no backend) vem de
> `TALDORIAN_SERVICE_TOKEN` — gere no backend (`./gradlew printServiceToken`) e adicione como
> `Environment=TALDORIAN_SERVICE_TOKEN=...` no serviço acima, se for usar trocas.

## Fase 9 — Apontar o jogo pra VM + nova release

No projeto do jogo, troca os 2 IPs do Hamachi pelo **IP público da VM**:
- `SERVER_IP` em `scenes/ui/login/login.gd`
- `BASE_URL` em `src/autoload/api_client.gd` → `http://SEU_IP_PUBLICO:8080`

Depois: re-exporta os **clientes Windows** → zipa → **nova release** no `taldorian-versions`
(bump do `version.json`) → o launcher atualiza os amigos sozinho.

## Fase 10 — Testar e manter

- **Teste fim-a-fim:** abre o cliente → login (bate no backend) → entra no mundo (bate no
  servidor) → joga uma partida.
- **Logs:** `journalctl -u taldorian-backend -f` e `-u taldorian-world -f`.
- **Atualizar o servidor depois:** novo export ARM → `scp` por cima → `sudo systemctl restart
  taldorian-world`. **Mantém a mesma versão dos clientes** (senão dá descompasso).
- **Reboot:** com systemd `enable`, os dois sobem sozinhos.

## Melhorias futuras (opcionais)

- **Domínio + HTTPS:** apontar um domínio pro IP, nginx + certbot → `BASE_URL=https://dominio`.
  Evita re-release quando o IP mudar e protege o tráfego do backend.
- **Gate de versão** cliente↔servidor no jogo (recusar conexão de versão incompatível).
- **Backup do Postgres** (volume `pgdata`).
