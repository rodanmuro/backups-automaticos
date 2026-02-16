#!/usr/bin/env bash
# ============================================================
# backup_drive.sh — Módulo de backup de Google Drive
# Sincroniza todo el contenido de Drive al disco local con rclone
# ============================================================

backup_drive() {
    local log="${BACKUP_LOG_DIR}/drive.log"

    mkdir -p "$BACKUP_DRIVE_DIR"

    # Verificar que rclone está instalado
    if ! command -v rclone &>/dev/null; then
        logger_escribir "$log" "ERROR" "rclone no está instalado"
        return 1
    fi

    # Verificar que el remote existe
    if ! rclone listremotes 2>/dev/null | grep -q "^${BACKUP_DRIVE_REMOTE}:$"; then
        logger_escribir "$log" "ERROR" "Remote '${BACKUP_DRIVE_REMOTE}' no configurado en rclone"
        return 1
    fi

    logger_escribir "$log" "INFO" "Iniciando sincronización de Google Drive"

    local salida
    salida=$(rclone sync \
        "${BACKUP_DRIVE_REMOTE}:" \
        "$BACKUP_DRIVE_DIR" \
        --transfers 4 \
        --log-level ERROR \
        2>&1)

    if [[ $? -eq 0 ]]; then
        logger_escribir "$log" "OK" "Google Drive sincronizado correctamente"
        return 0
    else
        logger_escribir "$log" "ERROR" "Fallo en sincronización: ${salida}"
        return 1
    fi
}
