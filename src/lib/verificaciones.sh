#!/usr/bin/env bash
# ============================================================
# verificaciones.sh — Verificaciones previas a la ejecución
# ============================================================

# Verifica que el disco destino esté disponible
# Acepta tanto puntos de montaje directos como subdirectorios dentro de uno
# Retorna 0 si está accesible, 1 si no
# Uso: verificar_disco_montado "/media/user/Kingston/backups-automaticos"
verificar_disco_montado() {
    local ruta="$1"

    if [[ -z "$ruta" ]]; then
        echo "Error: no se especificó ruta de disco destino" >&2
        return 1
    fi

    # Verificar que el directorio exista y sea accesible
    if [[ -d "$ruta" && -w "$ruta" ]]; then
        return 0
    else
        return 1
    fi
}

# Verifica que el volumen montado sea el disco de backups correcto
# Busca un archivo marcador con el identificador esperado
# Retorna 0 si coincide, 1 si no
# Uso: verificar_volumen "/mnt/backup" ".backup_id" "backups-automaticos-mipc"
verificar_volumen() {
    local ruta="$1"
    local marcador="$2"
    local id_esperado="$3"
    local archivo="${ruta}/${marcador}"

    if [[ ! -f "$archivo" ]]; then
        return 1
    fi

    local id_actual
    id_actual=$(cat "$archivo" 2>/dev/null)

    if [[ "$id_actual" == "$id_esperado" ]]; then
        return 0
    else
        return 1
    fi
}

# Crea el archivo marcador en el volumen destino (primera configuración)
# Uso: inicializar_volumen "/mnt/backup" ".backup_id" "backups-automaticos-mipc"
inicializar_volumen() {
    local ruta="$1"
    local marcador="$2"
    local id="$3"

    echo "$id" > "${ruta}/${marcador}"
}

# Verifica si ha transcurrido el intervalo mínimo desde el último backup exitoso
# Retorna 0 si debe ejecutarse, 1 si aún no es momento
# Uso: verificar_intervalo "/ruta/log.log" 86400
verificar_intervalo() {
    local archivo_log="$1"
    local intervalo="$2"

    local ultimo_exito
    ultimo_exito=$(logger_ultimo_exito "$archivo_log")

    local ahora
    ahora=$(date '+%s')

    local diferencia
    diferencia=$((ahora - ultimo_exito))

    if [[ $diferencia -ge $intervalo ]]; then
        return 0
    else
        return 1
    fi
}
