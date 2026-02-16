#!/usr/bin/env bash
# ============================================================
# backup_mail.sh — Módulo de backup Gmail vía mbsync
# Sincroniza correo Gmail en formato Maildir al disco de backup
# usando mbsync (isync) con autenticación OAuth2 (XOAUTH2)
# ============================================================

backup_mail() {
    local log="${BACKUP_LOG_DIR}/mail.log"

    mkdir -p "$BACKUP_MAIL_DIR"

    # Verificar que mbsync está instalado
    if ! command -v mbsync &>/dev/null; then
        logger_escribir "$log" "ERROR" "mbsync (isync) no está instalado"
        return 1
    fi

    # Verificar que el archivo mbsyncrc existe
    if [[ ! -f "$BACKUP_MAIL_MBSYNCRC" ]]; then
        logger_escribir "$log" "ERROR" "Archivo mbsyncrc no encontrado: ${BACKUP_MAIL_MBSYNCRC}"
        return 1
    fi

    # Verificar que el script OAuth2 existe
    if [[ ! -f "$BACKUP_MAIL_OAUTH2_SCRIPT" ]]; then
        logger_escribir "$log" "ERROR" "Script OAuth2 no encontrado: ${BACKUP_MAIL_OAUTH2_SCRIPT}"
        return 1
    fi

    # Verificar que el archivo de tokens existe (setup completado)
    if [[ ! -f "$BACKUP_MAIL_TOKENFILE" ]]; then
        logger_escribir "$log" "ERROR" "Archivo de tokens no encontrado: ${BACKUP_MAIL_TOKENFILE} — ejecutar --setup"
        return 1
    fi

    logger_escribir "$log" "INFO" "Iniciando sincronización de Gmail vía mbsync"

    local salida
    salida=$(mbsync -c "$BACKUP_MAIL_MBSYNCRC" gmail 2>&1)

    if [[ $? -eq 0 ]]; then
        logger_escribir "$log" "OK" "Gmail sincronizado correctamente en formato Maildir"
        return 0
    else
        logger_escribir "$log" "ERROR" "Fallo en sincronización mbsync: ${salida}"
        return 1
    fi
}
