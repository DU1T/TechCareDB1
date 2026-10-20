#!/usr/bin/env bash
# Une los scripts numerados en los entregables.
#   ./build_master.sh                      -> build/TechCare_Master.sql + build/TechCare_DatosPrueba.sql
#   ./build_master.sh --db TechCare_Ana    -> build/TechCare_Ana_Master.sql ... (base personal)
#   ./build_master.sh --azure              -> build/TechCare_Azure_Master.sql ... (sin 01 ni USE)
# Ejecutar:
#   sqlcmd -S <servidor> -U <usuario> -P <clave> -C -b -f 65001 -i build/<archivo>.sql
#   (Azure: agregar  -d TechCare  para conectarse directo a la base)
set -euo pipefail
cd "$(dirname "$0")"; mkdir -p build

DB="TechCare"; AZURE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db)    DB="$2"; shift 2 ;;
    --azure) AZURE=1; shift ;;
    *) echo "Uso: $0 [--db NombreBD] [--azure]"; exit 1 ;;
  esac
done
[[ "$DB" =~ ^[A-Za-z][A-Za-z0-9_]*$ ]] || { echo "Nombre de BD inválido: $DB"; exit 1; }

PREFIX="$DB"; (( AZURE )) && PREFIX="${DB}_Azure"

transform() {
  if (( AZURE )); then
    # Azure SQL Database: la conexión ya apunta a la base; USE no está permitido para cambiar de base.
    sed -E '/^[[:space:]]*USE[[:space:]]+[A-Za-z_]+[[:space:]]*;?[[:space:]]*$/d' "$1"
  else
    sed -E -e "s/USE TechCare;/USE ${DB};/" \
           -e "s/N'TechCare'/N'${DB}'/" \
           -e "s/(ALTER|DROP|CREATE) DATABASE TechCare([^A-Za-z0-9_]|$)/\1 DATABASE ${DB}\2/" "$1"
  fi
}

join() { out=$1; shift
  echo "/* Generado por build_master.sh $(date '+%F %R') | BD=${DB} | azure=${AZURE} - NO EDITAR A MANO */" > "$out"
  for f in "$@"; do printf '\n/* ################ %s ################ */\n' "$f" >> "$out"; transform "$f" >> "$out"; printf '\nGO\n' >> "$out"; done
  echo "OK -> $out ($# archivos)"; }

master=(); datos=()
for f in [0-9][0-9]_*.sql; do
  n=$((10#${f:0:2}))
  (( AZURE && n == 1 )) && continue           # en Azure la base se crea desde el portal
  if (( n < 80 )); then master+=("$f"); elif (( n < 90 )); then datos+=("$f"); fi
done
join "build/${PREFIX}_Master.sql" "${master[@]}"
join "build/${PREFIX}_DatosPrueba.sql" "${datos[@]}"
# Seguridad aparte: 90_seguridad.sql (VM/local) o 91_seguridad_azure.sql (Azure).
