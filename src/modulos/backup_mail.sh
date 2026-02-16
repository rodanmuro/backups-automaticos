#!/usr/bin/env bash
# ============================================================
# backup_mail.sh — Módulo de backup Gmail/Thunderbird
# Copia el perfil completo de Thunderbird al disco de backup
# Thunderbird sincroniza Gmail vía IMAP; este módulo respalda
# el perfil local resultante con rsync
# ============================================================

backup_mail() {
    local log="${BACKUP_LOG_DIR}/mail.log"

    mkdir -p "$BACKUP_MAIL_DIR"

    # Verificar que el directorio fuente existe
    if [[ ! -d "$BACKUP_MAIL_ORIGEN" ]]; then
        logger_escribir "$log" "ERROR" "Directorio Thunderbird no encontrado: ${BACKUP_MAIL_ORIGEN}"
        return 1
    fi

    # Verificar que hay datos IMAP (al menos un directorio ImapMail)
    if ! find "$BACKUP_MAIL_ORIGEN" -maxdepth 3 -type d -name "ImapMail" 2>/dev/null | grep -q .; then
        logger_escribir "$log" "WARN" "No se encontró directorio ImapMail — no hay cuentas IMAP configuradas"
    fi

    logger_escribir "$log" "INFO" "Iniciando backup del perfil Thunderbird"

    local salida
    salida=$(rsync -a --delete \
        --exclude=".parentlock" \
        "$BACKUP_MAIL_ORIGEN/" \
        "$BACKUP_MAIL_DIR/" \
        2>&1)

    if [[ $? -eq 0 ]]; then
        logger_escribir "$log" "OK" "Perfil Thunderbird respaldado correctamente"
        return 0
    else
        logger_escribir "$log" "ERROR" "Fallo en backup Thunderbird: ${salida}"
        return 1
    fi
}
