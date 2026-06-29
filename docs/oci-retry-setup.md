# Setup do retry de criação da instância ARM (Oracle Cloud)

Guia para instalar/configurar a OCI CLI e rodar o `oci_retry_create.sh`, que fica
tentando criar a instância ARm grátis até a capacidade aparecer.

> Por que: no `sa-saopaulo-1` (São Paulo) a vaga ARM grátis aparece em janelas de
> segundos. Clicando "Create" na mão você quase sempre perde. O script pega a janela.

---

## 1. Instalar a OCI CLI (Windows)

Abra o **PowerShell** e rode (instalador oficial):

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
Invoke-WebRequest https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.ps1 -OutFile install.ps1
.\install.ps1 -AcceptAllDefaults
```

Feche e reabra o terminal. Teste: `oci --version`.

## 2. Configurar a CLI (criar a chave de API)

```powershell
oci setup config
```
Ele pergunta:
- **User OCID** — Console → menu do perfil (canto sup. direito) → seu usuário → copia o OCID.
- **Tenancy OCID** — Console → Governance/Administration → Tenancy details → OCID.
- **Region** — `sa-saopaulo-1`.
- **Generate a new API key?** → **Y** (ele cria a chave em `~/.oci/`).

Depois **sobe a chave pública** no console:
- Console → seu **usuário** → **API keys** → **Add API key** → **Paste/Upload** o conteúdo de
  `~/.oci/oci_api_key_public.pem` → Add.

Teste se autenticou:
```bash
oci iam region list --output table
```
Se listar regiões, está configurado. ✅

## 3. Pegar os OCIDs pro script

Preencha as variáveis no topo do `oci_retry_create.sh`:

| Variável | Onde pegar |
|---|---|
| `COMPARTMENT_ID` | Use o **Tenancy OCID** (root) — ou um compartment específico se você criou um |
| `AD` | Console → na tela de criar instância aparece o nome (ex: `aBcD:SA-SAOPAULO-1-AD-1`). Ou: `oci iam availability-domain list --output table` |
| `IMAGE_ID` | Console → Compute → **Images** (ou Custom/Platform Images) → acha **Canonical Ubuntu 22.04 ... aarch64** → copia o OCID. Ou pelo comando abaixo ⬇ |
| `SUBNET_ID` | Console → Networking → VCN `taldorian-vcn` → **Subnets** → a **pública** → copia o OCID |
| `SSH_KEY_FILE` | Caminho da sua **chave pública** SSH (a que você gerou na criação da VM, `.pub`) |

Pegar o IMAGE_ID do Ubuntu ARM por comando (mais fácil que caçar no console):
```bash
oci compute image list \
  --compartment-id "<SEU_TENANCY_OCID>" \
  --operating-system "Canonical Ubuntu" \
  --shape "VM.Standard.A1.Flex" \
  --output table --query "data[].{nome:\"display-name\", ocid:id}"
```
Pega o OCID da linha com **22.04** e **aarch64** no nome.

## 4. Rodar

No **Git Bash**, dentro de `taldorian/docs/`:
```bash
bash oci_retry_create.sh
```
- Deixa rodando. Ele tenta a cada 60s.
- Quando pegar vaga → **para sozinho** e avisa "SUCESSO". Aí vai no console, espera ficar
  **RUNNING** e pega o **IP público**.
- Se cair num erro que **não é** de capacidade (OCID errado, chave errada), ele **para** e
  mostra o erro — aí você corrige a variável e roda de novo.

> Dica: rode de preferência na **madrugada (2h-7h BRT)**, quando libera mais vaga. Pode deixar
> o terminal aberto a noite toda.

## 5. Deu certo?

Quando a instância estiver **RUNNING** com IP público, volte pro guia principal
[`DEPLOY_ORACLE.md`](DEPLOY_ORACLE.md) → **Fase 3** (abrir portas) e siga daí.
