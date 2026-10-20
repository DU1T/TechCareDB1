#!/usr/bin/env bash
# Igual que reconstruir.ps1 para macOS/Linux.
#   ./reconstruir.sh -s localhost,1433 -u sa -d TechCare_Front                      # personal (Docker)
#   ./reconstruir.sh -s tcp:SERVIDOR.database.windows.net,1433 -u tcadmin --azure  # compartida (SOLO C)
#   agregar --sin-datos para solo estructura
set -euo pipefail
cd "$(dirname "$0")"
SRV=""; USR=""; DB="TechCare"; AZURE=0; DATOS=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s) SRV="$2"; shift 2 ;;  -u) USR="$2"; shift 2 ;;  -d) DB="$2"; shift 2 ;;
    --azure) AZURE=1; shift ;;  --sin-datos) DATOS=0; shift ;;
    *) echo "Uso: $0 -s servidor -u usuario [-d base] [--azure] [--sin-datos]"; exit 1 ;;
  esac
done
[[ -n "$SRV" && -n "$USR" ]] || { echo "Faltan -s y -u"; exit 1; }
if [[ "$DB" == "TechCare" ]]; then
  read -r -p "Esto BORRA y recrea la base COMPARTIDA '$DB'. ¿Ya avisó al equipo? Escriba SI: " ok
  [[ "$ok" == "SI" ]] || { echo "Cancelado."; exit 0; }
fi
read -r -s -p "Contraseña de $USR: " PASS; echo
export SQLCMDPASSWORD="$PASS"     # sqlcmd la toma de aquí: no queda en el historial

# -I: QUOTED_IDENTIFIER ON (el sqlcmd clásico lo deja en OFF y fallan índices filtrados)
run() { local f=$1 base=${2:-}; local a=(-S "$SRV" -U "$USR" -b -I -f 65001 -i "$f")
  (( AZURE )) || a+=(-C); [[ -n "$base" ]] && a+=(-d "$base")
  echo ">> $(basename "$f")"; sqlcmd "${a[@]}"; }

if (( AZURE )); then ./build_master.sh --db "$DB" --azure; P="${DB}_Azure"; else ./build_master.sh --db "$DB"; P="$DB"; fi
if (( AZURE )); then run limpiar_base.sql "$DB"; run "build/${P}_Master.sql" "$DB"
else run "build/${P}_Master.sql"; fi
(( DATOS )) && run "build/${P}_DatosPrueba.sql" "$DB"
if (( AZURE )); then run 91_seguridad_azure.sql "$DB"; elif [[ "$DB" == "TechCare" ]]; then run 90_seguridad.sql; fi
run 92_auditoria_ddl.sql "$DB"
echo "Listo: $DB reconstruida en $SRV"
