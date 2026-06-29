#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# Retry de criação de instância ARM grátis no Oracle Cloud.
# Fica tentando 'oci compute instance launch' até a capacidade aparecer.
# Roda no Git Bash (Windows) ou em qualquer shell com a OCI CLI instalada/configurada.
#
# Uso:
#   1. Instala e configura a OCI CLI (ver docs/oci-retry-setup.md)
#   2. Preenche as variáveis abaixo (OCIDs — como pegar está no guia)
#   3. bash oci_retry_create.sh
#   Deixa rodando (de preferência na madrugada, 2h-7h BRT). Quando pegar vaga, para sozinho.
# ──────────────────────────────────────────────────────────────────────────────
set -u

# ── PREENCHA ESTAS VARIÁVEIS ──────────────────────────────────────────────────
COMPARTMENT_ID="ocid1.tenancy.oc1..xxxxxxxx"          # OCID do compartment (root = tenancy)
AD="xxxxxxxx:SA-SAOPAULO-1-AD-1"                       # nome da Availability Domain
SHAPE="VM.Standard.A1.Flex"
OCPUS=1                                                 # 1/6 é mais fácil de encaixar que 2/12
MEMORY=6
IMAGE_ID="ocid1.image.oc1.sa-saopaulo-1.xxxxxxxx"      # imagem Ubuntu aarch64
SUBNET_ID="ocid1.subnet.oc1.sa-saopaulo-1.xxxxxxxx"    # subnet PÚBLICA (não a privada)
SSH_KEY_FILE="$HOME/.ssh/oci_key.pub"                  # sua CHAVE PÚBLICA SSH
DISPLAY_NAME="taldorian-server"
SLEEP_SECONDS=60                                        # intervalo entre tentativas
# ──────────────────────────────────────────────────────────────────────────────

attempt=0
echo "Iniciando retry. Ctrl+C para parar. (intervalo: ${SLEEP_SECONDS}s)"
while true; do
  attempt=$((attempt + 1))
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] tentativa #$attempt ..."

  OUT=$(oci compute instance launch \
    --compartment-id "$COMPARTMENT_ID" \
    --availability-domain "$AD" \
    --shape "$SHAPE" \
    --shape-config "{\"ocpus\": $OCPUS, \"memoryInGBs\": $MEMORY}" \
    --image-id "$IMAGE_ID" \
    --subnet-id "$SUBNET_ID" \
    --assign-public-ip true \
    --display-name "$DISPLAY_NAME" \
    --ssh-authorized-keys-file "$SSH_KEY_FILE" \
    2>&1)
  CODE=$?

  if [ $CODE -eq 0 ]; then
    echo ""
    echo "✅✅✅ SUCESSO! Instância aceita pela Oracle. ✅✅✅"
    echo "$OUT" | grep -iE '"id"|"display-name"|"lifecycle-state"' | head -5
    echo "Abra o console (Compute > Instances) e espere ficar RUNNING, depois pegue o IP público."
    break
  fi

  if echo "$OUT" | grep -qiE "Out of (host )?capacity|InternalError|500|TooManyRequests|429|out of capacity"; then
    echo "   sem vaga / throttle — aguardando ${SLEEP_SECONDS}s e tentando de novo"
  else
    echo ""
    echo "   ⚠️  Erro DIFERENTE de capacidade (provável config errada). Parando pra você ver:"
    echo "$OUT" | tail -8
    echo ""
    echo "   Confira os OCIDs (subnet/image/compartment/AD) e a chave SSH no guia."
    break
  fi

  sleep "$SLEEP_SECONDS"
done
