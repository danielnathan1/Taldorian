# Runbook — subir o servidor do ZERO na AWS (EC2)

Guia **testado na prática** para recriar toda a infra: **Postgres + backend (taldorian-service) +
servidor de mundo (Godot `--world-server`)** numa VM EC2, com os clientes apontando pra ela.

> Ordem: conta/custos → VM → Elastic IP → firewall → swap → Postgres → backend → seeds →
> servidor de mundo → apontar o jogo → testar. Os **perrengues que já nos pegaram** estão
> marcados com 🩹 ao longo do caminho (e resumidos no fim).

---

## 0. Conta e custos (o que te cobrou da última vez) 💸

1. Crie a conta **nova**. No cadastro, confirme que é elegível ao **Free Tier** (12 meses).
2. **Antes de tudo**, cria um alarme de custo: **Billing and Cost Management → Budgets → Create budget**
   → US$ 1 → alerta em 100%. Assim qualquer cobrança te avisa na hora.
3. Regra de ouro: **só usa recurso com o selo "Free tier eligible"**. Se não tiver o selo, não cria.

---

## 1. Lançar a instância EC2

**EC2 → Launch instance** (canto sup. direito: região **São Paulo / sa-east-1**):
- **Name:** `taldorian-server`
- **AMI:** **Ubuntu Server 24.04 LTS** (selo *Free tier eligible*), arquitetura **64-bit (x86)**
- **Instance type:** **t3.micro** (*Free tier eligible*)
- **Key pair:** *Create new key pair* → RSA → **.pem** → baixa e **guarda** (é o SSH; não rebaixa)
- **Network → Firewall:** *Create security group*, deixa **Allow SSH (22) from Anywhere** por ora
- **Storage:** padrão (8–30 GB, grátis)
- **Launch instance**

## 2. Elastic IP (IP fixo) — faça já

Sem isso, o IP muda a cada stop/start e quebra tudo que aponta pra ele.
- **EC2 → Elastic IPs → Allocate** → seleciona → **Actions → Associate** → instância `taldorian-server`.
- **Anota o Elastic IP** (ex.: `54.233.75.204`) — é ele em TODO o resto (SSH, scp, jogo).

## 3. Abrir portas no Security Group 🩹

🩹 **Perrengue clássico:** editar o Security Group **errado**. Confirme qual está preso à instância:
**EC2 → Instâncias → `taldorian-server` → aba Segurança → Grupos de segurança** → clica **nesse**.

Nele: **Editar regras de entrada → Adicionar** (3 regras no total):

| Tipo | Protocolo | Porta | Origem |
|---|---|---|---|
| SSH | TCP | 22 | 0.0.0.0/0 (ou Meu IP) |
| TCP personalizado | TCP | 8080 | 0.0.0.0/0 |
| UDP personalizado | **UDP** | **7001** | 0.0.0.0/0 |

🩹 **A 7001 é UDP** (ENet). Se botar TCP, login funciona mas **"entrar no mundo" trava carregando**.
Postgres (5432) **não** entra aqui — fica só local.

## 4. SSH + swap

```bash
chmod 400 taldorian-key.pem
ssh -i taldorian-key.pem ubuntu@SEU_ELASTIC_IP
sudo apt update && sudo apt upgrade -y
```
🩹 O `t3.micro` tem só **1 GB de RAM** — cria **swap** (senão o stack engasga/OOM):
```bash
sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
free -h   # confere "Swap: 2.0Gi"
```

## 5. Docker + Postgres

```bash
sudo apt update && sudo apt install -y docker.io   # 🩹 rode o update antes, senão "no installation candidate"
sudo systemctl enable --now docker
```
🩹 **Escolha uma senha e ANOTE** (da última vez esquecemos e teve que resetar). Postgres só local:
```bash
sudo docker run -d --name taldorian-pg --restart unless-stopped \
  -e POSTGRES_USER=taldorian -e POSTGRES_PASSWORD=UMA_SENHA_QUE_VOCE_ANOTOU \
  -e POSTGRES_DB=taldorian \
  -p 127.0.0.1:5432:5432 \
  -v pgdata:/var/lib/postgresql/data \
  postgres:16
sudo docker ps   # tem que mostrar taldorian-pg "Up"
```

## 6. Backend (taldorian-service)

No **PC** (repo do backend):
```bash
./gradlew bootJar
scp -i CAMINHO/taldorian-key.pem build/libs/taldorian-service-*.jar ubuntu@SEU_ELASTIC_IP:/home/ubuntu/backend.jar
```
Na **VM** — Java + 2 segredos + systemd:
```bash
sudo apt install -y openjdk-21-jre-headless
openssl rand -base64 48   # rode 2x → JWT_SECRET e SERVICE_TOKEN_SECRET (anota os dois)
```
🩹 Cada `Environment=` numa **linha própria**; **não esqueça o `DB_PASS`** (bug que nos travou):
```bash
sudo tee /etc/systemd/system/taldorian-backend.service >/dev/null <<'EOF'
[Unit]
Description=Taldorian Backend
After=network.target docker.service

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu
Environment=DB_USER=taldorian
Environment=DB_PASS=A_MESMA_SENHA_DO_POSTGRES
Environment=JWT_SECRET=PRIMEIRO_OPENSSL
Environment=SERVICE_TOKEN_SECRET=SEGUNDO_OPENSSL
Environment=SPRING_FLYWAY_ENABLED=true
ExecStart=/usr/bin/java -Xmx256m -jar /home/ubuntu/backend.jar
Restart=always

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now taldorian-backend
sudo journalctl -u taldorian-backend -f
```
- 🩹 `SPRING_FLYWAY_ENABLED=true` → cria o schema (sem isso, "no ExecStart"/erros de tabela).
- 🩹 Editou o arquivo depois? **Sempre** `sudo systemctl daemon-reload` (o `systemctl show` mostra a
  versão carregada, não o disco).
- Espera `Started ...` / `Tomcat started on port 8080`. Abre no navegador:
  `http://SEU_ELASTIC_IP:8080/swagger-ui` → tem que carregar. 🩹 Timeout = porta 8080 no Security
  Group errado/faltando.

## 7. Seeds (catálogo de cartas) — via DataGrip (túnel SSH)

Sem os seeds o catálogo fica vazio e **abrir pacote não funciona**. Conecta o **DataGrip** (na sua
máquina) ao Postgres da VM por **túnel SSH** — sem expor o banco:
- **General:** Host `localhost` · Port `5432` · User `taldorian` · Password *(a do passo 5)* · DB `taldorian`
- **SSH/SSL → Use SSH tunnel:** Host `SEU_ELASTIC_IP` · Port `22` · User `ubuntu` · Auth **Key pair** → o `.pem`

🩹 O Host `localhost` é o **da VM através do túnel** (o DataGrip continua na sua máquina). Test Connection → verde.

Roda os 2 SQL contra a conexão **[PROD]**:
`taldorian-service/src/main/resources/db/seed/taldorian_origin.sql` e `scannable_v1.sql`.
Confere: `SELECT count(*) FROM cards;` → ~**112**.

## 8. Servidor de mundo (export Linux x86_64)

No **PC** (projeto do jogo): **Project → Export → Add Linux** → **Architecture x86_64** →
**Embed PCK ligado** → **Export Project** → salva como **`taldorian_server.x86_64`** (🩹 precisa da
extensão `.x86_64`, senão "extensão inválida").

Gera o **token de serviço** (no PC, sem Node — script já existe):
```bash
SERVICE_TOKEN_SECRET="O_MESMO_SERVICE_TOKEN_SECRET_DO_BACKEND" bash scripts/generate-service-token.sh
```
Copia o `eyJ...`. Envia o binário e cria o serviço:
```bash
scp -i CAMINHO/taldorian-key.pem CAMINHO/taldorian_server.x86_64 ubuntu@SEU_ELASTIC_IP:/home/ubuntu/
ssh -i CAMINHO/taldorian-key.pem ubuntu@SEU_ELASTIC_IP
chmod +x /home/ubuntu/taldorian_server.x86_64
sudo tee /etc/systemd/system/taldorian-world.service >/dev/null <<'EOF'
[Unit]
Description=Taldorian World Server
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu
ExecStart=/home/ubuntu/taldorian_server.x86_64 --headless -- --world-server
Environment=TALDORIAN_SERVICE_TOKEN=COLE_O_TOKEN
Restart=always

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now taldorian-world
sudo journalctl -u taldorian-world -n 10 --no-pager
```
Espera `[WorldServer] Servidor do mundo rodando na porta 7001` + `[ApiClient] Token de serviço configurado`.

🩹 **NÃO rode o servidor na mão** (`./taldorian_server...`) — se ficar rodando, segura a porta 7001
e o systemd dá **erro 20 (can't create)**. Só use o systemd. Se travar: `sudo pkill -f
taldorian_server.x86_64` e `sudo systemctl restart taldorian-world`.

## 9. Apontar o jogo pro novo IP + nova release

🩹 **VM nova = Elastic IP novo.** Troca **num lugar só**, em `taldorian/src/core/server_config.gd`:
```gdscript
const PROD_HOST     := "SEU_ELASTIC_IP_NOVO"
const PROD_API_BASE := "http://SEU_ELASTIC_IP_NOVO:8080"
```
(O `server_config.gd` resolve o resto: editor→localhost, cliente→VM, servidor dedicado→localhost.)

Depois:
- **Re-exporta o servidor** Linux (passo 8) com o IP novo e sobe na VM (o `--world-server` usa o
  backend em localhost, então nem depende do IP, mas mantém tudo na mesma versão).
- **Re-exporta o cliente** Windows → zipa → **nova release** no `taldorian-versions` (bump do
  `version.json`) → launcher atualiza os amigos.

## 10. Testar

Launcher → **Atualizar** → **Jogar** → **criar conta** (bate no backend) → **entrar no mundo**
(bate no servidor, UDP 7001) → **abrir pacote** (precisa dos seeds). Ver a conta:
```bash
sudo docker exec taldorian-pg psql -U taldorian -d taldorian -c "SELECT username,email,created_at FROM players ORDER BY created_at DESC;"
```

---

## 🩹 Resumo dos perrengues (o que mais custou tempo)

1. **Security Group errado** — edite o que está **preso à instância** (aba Segurança da instância).
2. **7001 tem que ser UDP** — se for TCP, "entrar no mundo" trava carregando.
3. **Anote a senha do Postgres** — e use a mesma em `DB_PASS` no backend.
4. **Cada `Environment=` numa linha** + `daemon-reload` após editar o systemd.
5. **`SPRING_FLYWAY_ENABLED=true`** — senão o schema não é criado.
6. **Seeds** carregados — senão abrir pacote não funciona.
7. **Não rode o servidor de mundo na mão** — só systemd (senão conflito de porta / erro 20).
8. **Export Linux** precisa da extensão **`.x86_64`**.
9. **IP novo** → troca só o `PROD_HOST` em `server_config.gd` e re-exporta.
10. **Free tier** — conta nova elegível + billing alarm de US$1.

## Manutenção

- **Atualizar backend:** `bash taldorian-service/deploy.sh` (build + scp + restart) — ajuste o
  `HOST=` pro Elastic IP novo.
- **Atualizar jogo:** re-exporta cliente + servidor (mesma versão) → nova release.
- **Reiniciar serviços:** `sudo systemctl restart taldorian-backend | taldorian-world`.
