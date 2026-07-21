# src/core/server_config.gd
# Fonte ÚNICA do endereço do servidor/backend, resolvido por AMBIENTE — assim você
# nunca precisa trocar IP na mão entre dev e produção:
#   • Rodando no editor (dev)            → 127.0.0.1 (localhost)
#   • Build exportado (cliente)          → IP de produção (a VM)
#   • Servidor dedicado (--world-server) → backend em localhost (mesma VM da VM de
#     produção; evita o "hairpinning" da AWS, onde a instância não alcança o próprio IP público)
#
# >>> Mudou a VM? Troque só o PROD_HOST / PROD_API_BASE abaixo (um lugar só). <<<
class_name ServerConfig
extends RefCounted

## IP/host público da VM de produção (Elastic IP).
const PROD_HOST     := "54.207.210.33"
const PROD_API_BASE := "http://54.207.210.33:8080"
const LOCAL_API_BASE := "http://127.0.0.1:8080"

## true quando este processo é o servidor dedicado (lançado com --world-server).
static func is_dedicated_server() -> bool:
	return "--world-server" in OS.get_cmdline_user_args()

## Host do servidor de MUNDO (ENet) que o CLIENTE conecta.
static func server_host() -> String:
	if OS.has_feature("editor"):
		return "127.0.0.1"
	return PROD_HOST

## Base URL do backend HTTP. Servidor dedicado e dev usam o backend local.
static func api_base_url() -> String:
	if is_dedicated_server() or OS.has_feature("editor"):
		return LOCAL_API_BASE
	return PROD_API_BASE
