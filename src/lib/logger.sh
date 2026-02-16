#!/usr/bin/env bash
# ============================================================
# logger.sh — Funciones de logging para el sistema de backups
# ============================================================

# Genera un timestamp con formato ISO 8601
logger_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Escribe una línea en el archivo de log indicado
# Uso: logger_escribir "/ruta/log.log" "ESTADO" "mensaje"
logger_escribir() {
    local archivo="$1"
    local estado="$2"
    local mensaje="$3"
    local dir_log

    dir_log="$(dirname "$archivo")"
    mkdir -p "$dir_log"

    echo "[$(logger_timestamp)] [${estado}] ${mensaje}" >> "$archivo"
}

# Registra el inicio de una ejecución de backup
# Uso: logger_inicio "/ruta/log.log"
logger_inicio() {
    local archivo="$1"
    logger_escribir "$archivo" "INICIO" "Ejecución de backup iniciada"
}

# Registra el fin exitoso de una ejecución
# Uso: logger_fin_ok "/ruta/log.log"
logger_fin_ok() {
    local archivo="$1"
    logger_escribir "$archivo" "OK" "Ejecución de backup completada exitosamente"
}

# Registra el fin con error de una ejecución
# Uso: logger_fin_error "/ruta/log.log" "descripción del error"
logger_fin_error() {
    local archivo="$1"
    local detalle="$2"
    logger_escribir "$archivo" "ERROR" "Ejecución fallida: ${detalle}"
}

# Obtiene el timestamp (epoch) de la última ejecución exitosa
# Retorna 0 (epoch) si no hay registros previos
# Uso: logger_ultimo_exito "/ruta/log.log"
logger_ultimo_exito() {
    local archivo="$1"

    if [[ ! -f "$archivo" ]]; then
        echo "0"
        return
    fi

    local ultima_linea
    ultima_linea=$(grep '\[OK\]' "$archivo" | tail -1)

    if [[ -z "$ultima_linea" ]]; then
        echo "0"
        return
    fi

    # Extraer el timestamp entre los primeros corchetes
    local fecha
    fecha=$(echo "$ultima_linea" | sed -n 's/^\[\(.*\)\] \[OK\].*/\1/p')

    if [[ -z "$fecha" ]]; then
        echo "0"
        return
    fi

    # Convertir a epoch
    date -d "$fecha" '+%s' 2>/dev/null || echo "0"
}
