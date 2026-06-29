# Deploy do servidor na AWS (EC2, Free Tier)

Guia para subir o **backend** (taldorian-service) + o **servidor de mundo** (Godot `--world-server`)
numa VM EC2 `t3.micro` gratuita, e apontar os clientes pra ela (sem Hamachi).

> Stack na VM: **PostgreSQL** (Docker, só local) + **backend Spring** (8080) +
> **servidor de mundo Godot** (7001/UDP). Clientes Windows conectam pelo IP público da VM.

> Diferença pro Oracle: **sem "out of capacity"**, firewall em **1 camada só** (Security Group),
> e export **x86_64** (dá pra testar no WSL antes). O porém é a RAM de **1 GB** → resolvemos com swap.

---

## ⚠️ Os pontos de atenção da AWS

1. **1 GB de RAM** na `t3.micro` → o stack todo fica apertado. **Swap é obrigatório** (Fase 5) e o
   backend roda com heap limitado (`-Xmx256m`).
2. **IP público muda** ao parar/ligar a instância. Como o jogo aponta pro IP, use um **Elastic IP**
   (IP fixo) — grátis enquanto atrelado a uma instância ligada no 1º ano (Fase 3b).
3. **Billing:** fica na `t3.micro` (selo "Free tier eligible") e cria um **billing alarm**. Depois de
   12 meses começa a cobrar (~US$8/mês a micro).

---

## Fase 1 — Lançar a instância EC2

Console → busca **EC2** → **Launch instance**:
- **Name:** `taldorian-server`
- **Region** (canto sup. direito): **São Paulo (sa-east-1)** pro melhor ping com a galera.
- **AMI:** **Ubuntu Server 22.04 LTS** (ou 24.04) — com selo **"Free tier eligible"**. Arquitetura **64-bit (x86)**.
- **Instance type:** **`t3.micro`** (selo "Free tier eligible").
- **Key pair:** **Create new key pair** → tipo RSA → **.pem** → **baixa e guarda** (é o SSH; não dá pra rebaixar).
- **Network settings → Edit → Security group:** cria um novo (ver Fase 3) ou deixa o padrão e ajusta depois.
- **Storage:** padrão (8-30 GB gp3) está ok e dentro do free.
- **Launch instance.**

## Fase 2 — SSH na VM

Pega o **Public IPv4** da instância (aba Instances). No terminal (Git Bash/PowerShell):
```bash
chmod 400 sua-chave.pem
ssh -i sua-chave.pem ubuntu@SEU_IP_PUBLICO
sudo apt update && sudo apt upgrade -y
```

## Fase 3 — Abrir portas (Security Group)

EC2 → **Security Groups** → o da sua instância → **Edit inbound rules** → adiciona:

| Type | Protocol | Port | Source | Pra quê |
|---|---|---|---|---|
| SSH | TCP | 22 | My IP (ou 0.0.0.0/0) | acesso SSH |
| Custom TCP | TCP | 8080 | 0.0.0.0/0 | backend HTTP |
| Custom UDP | **UDP** | 7001 | 0.0.0.0/0 | servidor de mundo (ENet) |

> ⚠️ 7001 é **UDP**. Postgres (5432) **não** entra aqui — fica só local.
> Bônus AWS: **não precisa mexer no firewall do Ubuntu** (as AMIs da AWS não bloqueiam por padrão,
> diferente do Oracle). O Security Group já é o firewall.

## Fase 3b — Elastic IP (IP fixo, recomendado)

EC2 → **Elastic IPs** → **Allocate Elastic IP address** → depois **Associate** com a instância
`taldorian-server`. Agora o IP **não muda** mais ao reiniciar — é esse que você aponta no jogo.
> Grátis enquanto atrelado a uma instância **ligada** (no 1º ano). IP solto/parado cobra centavos.

## Fase 4 — Swap (essencial no 1 GB)

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
free -h    # confere que apareceu 2G de swap
```

## Fase 5 — Postgres (Docker, só local)

```bash
sudo apt install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker ubuntu   # relogar o ssh depois disso

docker run -d --name taldorian-pg --restart unless-stopped \
  -e POSTGRES_USER=taldorian -e POSTGRES_PASSWORD=TROQUE_ESTA_SENHA \
  -e POSTGRES_DB=taldorian \
  -p 127.0.0.1:5432:5432 \
  -v pgdata:/var/lib/postgresql/data \
  postgres:16
```

## Fase 6 — Backend (taldorian-service)

No **PC**, no repo `taldorian-service`:
```bash
./gradlew bootJar      # gera build/libs/*.jar
scp -i sua-chave.pem build/libs/taldorian-service-*.jar ubuntu@SEU_IP:/home/ubuntu/backend.jar
```
Na VM:
```bash
sudo apt install -y openjdk-21-jre-headless
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
ExecStart=/usr/bin/java -Xmx256m -jar /home/ubuntu/backend.jar
Restart=always

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now taldorian-backend
sudo journalctl -u taldorian-backend -f
```
> `-Xmx256m` segura o JVM pra caber no 1 GB. **Checkpoint do banco:** garanta que o schema foi
> criado (Flyway habilitado em prod ou migrations rodadas). Teste: `curl http://localhost:8080/swagger-ui`.

## Fase 7 — Servidor de mundo (export Godot Linux x86_64)

No **PC**, no projeto do jogo:
1. Project → Export → **Add… → Linux**.
2. **Architecture = x86_64** (padrão).
3. **Embed PCK = ligado** (1 arquivo).
4. Export Project → ex.: `taldorian_server`.
> Dá pra **testar no WSL** antes: `./taldorian_server --headless -- --world-server`.

Copia e roda na VM:
```bash
scp -i sua-chave.pem taldorian_server ubuntu@SEU_IP:/home/ubuntu/taldorian_server
ssh -i sua-chave.pem ubuntu@SEU_IP
chmod +x /home/ubuntu/taldorian_server
./taldorian_server --headless -- --world-server   # teste: deve imprimir "porta 7001"
```
systemd:
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
> Service token (trocas): adicione `Environment=TALDORIAN_SERVICE_TOKEN=...` (gere com
> `./gradlew printServiceToken` no backend) se for usar trocas.

## Fase 8 — Apontar o jogo pra VM + nova release

Troca os 2 IPs do Hamachi pelo **Elastic IP** da VM:
- `SERVER_IP` em `scenes/ui/login/login.gd`
- `BASE_URL` em `src/autoload/api_client.gd` → `http://ELASTIC_IP:8080`

Depois: re-exporta os **clientes Windows** → zipa → **nova release** no `taldorian-versions`
(bump do `version.json`) → o launcher atualiza os amigos sozinho.

## Fase 9 — Testar e manter

- **Fim-a-fim:** cliente → login (backend) → entra no mundo (servidor) → joga.
- **Logs:** `journalctl -u taldorian-backend -f` / `-u taldorian-world -f`.
- **RAM:** `free -h` e `htop` — se viver no talo, considere `t3.small` (2 GB, ~US$15/mês).
- **Atualizar o servidor:** novo export → `scp` por cima → `sudo systemctl restart taldorian-world`.
  **Mesma versão dos clientes.**
- **Reboot:** com systemd `enable`, tudo sobe sozinho.

## Melhorias futuras (opcionais)

- **Domínio + HTTPS** (nginx + certbot) → `BASE_URL=https://dominio`, evita re-release se o IP mudar.
- **Gate de versão** cliente↔servidor no jogo.
- **Backup do Postgres** (volume `pgdata`).
- **Billing alarm** em US$1 (Billing → Budgets) pra não tomar susto.
