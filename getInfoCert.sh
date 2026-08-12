#!/usr/bin/env bash
#==========================================================================
# ------------------------ Obtain info from certificates ------------------------------
# Author:           Adrián López
# Description:      Obtain information from .cer files in directory and return a .csv file
# Version:          1
# Last modified:    08/2026
#==========================================================================

set -u

# Directorio donde están los certificados .cer
DIR_CERTS="${1:-.}"

# Archivo CSV de salida
CSV_SALIDA="${2:-reporte_certificados.csv}"

# Valor por defecto para Exposición:
# Publico, Privado o Interno
# Como este dato normalmente no se puede obtener directamente del certificado,
# se asigna por defecto y puede cambiarse con variable de entorno.
EXPOSICION_DEFAULT="${EXPOSICION_DEFAULT:-Privado}"

# Uso por defecto si no se puede inferir
USO_DEFAULT="${USO_DEFAULT:-HTTPS}"

# Validar openssl
if ! command -v openssl >/dev/null 2>&1; then
  echo "ERROR: openssl no está instalado o no se encuentra en el PATH."
  exit 1
fi

# Validar directorio
if [ ! -d "$DIR_CERTS" ]; then
  echo "ERROR: El directorio no existe: $DIR_CERTS"
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

csv_escape() {
  local value="${1:-}"
  value="${value//$'\r'/ }"
  value="${value//$'\n'/ }"
  value="${value//\"/\"\"}"
  printf '"%s"' "$value"
}

csv_print_row() {
  local first=1
  local col

  for col in "$@"; do
    if [ "$first" -eq 0 ]; then
      printf ','
    fi
    csv_escape "$col"
    first=0
  done
  printf '\n'
}

convertir_a_pem() {
  local cert="$1"
  local salida="$2"

  # Intentar como PEM
  if openssl x509 -in "$cert" -out "$salida" >/dev/null 2>&1; then
    return 0
  fi

  # Intentar como DER
  if openssl x509 -inform DER -in "$cert" -out "$salida" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

obtener_subject_field() {
  local cert="$1"
  local campo="$2"

  openssl x509 -in "$cert" -noout -subject -nameopt multiline,utf8 2>/dev/null |
    awk -F' = ' -v key="$campo" '
      {
        left=$1
        right=$2
        gsub(/^[ \t]+|[ \t]+$/, "", left)
        gsub(/^[ \t]+|[ \t]+$/, "", right)
        if (left == key && right != "") {
          print right
        }
      }
    ' | paste -sd ';' -
}

formatear_fecha() {
  local fecha_raw="$1"

  # Formato esperado de openssl:
  # Jun  7 00:00:00 2025 GMT

  if date -u -d "$fecha_raw" "+%d/%m/%Y" >/dev/null 2>&1; then
    date -u -d "$fecha_raw" "+%d/%m/%Y"
  else
    # Si el sistema no soporta date -d, se deja la fecha original
    echo "$fecha_raw"
  fi
}

fecha_epoch() {
  local fecha_raw="$1"

  if date -u -d "$fecha_raw" "+%s" >/dev/null 2>&1; then
    date -u -d "$fecha_raw" "+%s"
  else
    echo ""
  fi
}

obtener_tipo_certificado() {
  local cert="$1"
  local basic_constraints

  basic_constraints="$(openssl x509 -in "$cert" -noout -ext basicConstraints 2>/dev/null || true)"

  if echo "$basic_constraints" | grep -qi "CA:TRUE"; then
    echo "CA Certificate"
  else
    echo "Identity Certificate"
  fi
}

obtener_san() {
  local cert="$1"

  openssl x509 -in "$cert" -noout -ext subjectAltName 2>/dev/null |
    awk '
      NR > 2 {
        gsub(/^[ \t]+|[ \t]+$/, "")
        print
      }
    ' | paste -sd ' ' -
}

obtener_uso() {
  local cert="$1"
  local cn="$2"
  local san="$3"
  local eku
  local texto

  eku="$(openssl x509 -in "$cert" -noout -ext extendedKeyUsage 2>/dev/null || true)"
  texto="${cn} ${san} ${eku}"

  if echo "$texto" | grep -qi "ldap"; then
    echo "LDAP"
  elif echo "$eku" | grep -Eqi "TLS Web Server Authentication|serverAuth"; then
    echo "HTTPS"
  else
    echo "$USO_DEFAULT"
  fi
}

es_autofirmado() {
  local cert="$1"
  local subject
  local issuer

  subject="$(openssl x509 -in "$cert" -noout -subject -nameopt RFC2253 2>/dev/null | sed 's/^subject=//')"
  issuer="$(openssl x509 -in "$cert" -noout -issuer -nameopt RFC2253 2>/dev/null | sed 's/^issuer=//')"

  if [ "$subject" = "$issuer" ] && openssl verify -CAfile "$cert" "$cert" >/dev/null 2>&1; then
    echo "Si"
  else
    echo "No"
  fi
}

obtener_emisor() {
  local cert="$1"

  openssl x509 -in "$cert" -noout -issuer -nameopt RFC2253,utf8 2>/dev/null |
    sed 's/^issuer=//'
}

# Crear encabezado del CSV
{
  csv_print_row \
    "Exposicion" \
    "Tipo" \
    "Uso" \
    "Vigencia Inicio" \
    "Vigencia Fin" \
    "Activado" \
    "Autofirmado" \
    "Name" \
    "Country Name" \
    "State or Province Name" \
    "Locality Name" \
    "Organization Name" \
    "Organizational Unit Name" \
    "Common Name" \
    "Email Address" \
    "Emisor"

  shopt -s nullglob

  for cert_original in "$DIR_CERTS"/*.cer; do
    nombre_archivo="$(basename "$cert_original")"
    cert_pem="$TMP_DIR/${nombre_archivo}.pem"

    if ! convertir_a_pem "$cert_original" "$cert_pem"; then
      echo "WARN: No se pudo leer el certificado: $cert_original" >&2
      continue
    fi

    country="$(obtener_subject_field "$cert_pem" "countryName")"
    state="$(obtener_subject_field "$cert_pem" "stateOrProvinceName")"
    locality="$(obtener_subject_field "$cert_pem" "localityName")"
    organization="$(obtener_subject_field "$cert_pem" "organizationName")"
    organizational_unit="$(obtener_subject_field "$cert_pem" "organizationalUnitName")"
    common_name="$(obtener_subject_field "$cert_pem" "commonName")"
    email_address="$(obtener_subject_field "$cert_pem" "emailAddress")"

    fecha_inicio_raw="$(openssl x509 -in "$cert_pem" -noout -startdate 2>/dev/null | cut -d= -f2-)"
    fecha_fin_raw="$(openssl x509 -in "$cert_pem" -noout -enddate 2>/dev/null | cut -d= -f2-)"

    fecha_inicio="$(formatear_fecha "$fecha_inicio_raw")"
    fecha_fin="$(formatear_fecha "$fecha_fin_raw")"

    inicio_epoch="$(fecha_epoch "$fecha_inicio_raw")"
    fin_epoch="$(fecha_epoch "$fecha_fin_raw")"
    ahora_epoch="$(date -u "+%s")"

    if [ -n "$inicio_epoch" ] && [ -n "$fin_epoch" ] && \
       [ "$ahora_epoch" -ge "$inicio_epoch" ] && [ "$ahora_epoch" -le "$fin_epoch" ]; then
      activado="Si"
    else
      activado="No"
    fi

    tipo="$(obtener_tipo_certificado "$cert_pem")"
    san="$(obtener_san "$cert_pem")"
    uso="$(obtener_uso "$cert_pem" "$common_name" "$san")"
    autofirmado="$(es_autofirmado "$cert_pem")"
    emisor="$(obtener_emisor "$cert_pem")"

    csv_print_row \
      "$EXPOSICION_DEFAULT" \
      "$tipo" \
      "$uso" \
      "$fecha_inicio" \
      "$fecha_fin" \
      "$activado" \
      "$autofirmado" \
      "$nombre_archivo" \
      "$country" \
      "$state" \
      "$locality" \
      "$organization" \
      "$organizational_unit" \
      "$common_name" \
      "$email_address" \
      "$emisor"

  done
} > "$CSV_SALIDA"

echo "CSV generado correctamente: $CSV_SALIDA"
