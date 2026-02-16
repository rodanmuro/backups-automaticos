#!/usr/bin/env bash
# ============================================================
# alertas.sh — Notificaciones desktop para el sistema de backups
# ============================================================

# Envía una notificación desktop si están habilitadas
# Uso: alerta_enviar "urgencia" "título" "mensaje"
# urgencia: low, normal, critical
alerta_enviar() {
    local urgencia="$1"
    local titulo="$2"
    local mensaje="$3"

    if [[ "$BACKUP_NOTIFICACIONES" != "true" ]]; then
        return 0
    fi

    if command -v notify-send &>/dev/null; then
        notify-send --urgency="$urgencia" "$titulo" "$mensaje"
    fi
}

alerta_inicio() {
    alerta_enviar "normal" "Backup" "Ejecutando copia de seguridad..."
}

alerta_exito() {
    alerta_enviar "normal" "Backup" "Backup completado correctamente."
}

alerta_error_disco() {
    alerta_enviar "critical" "Backup - ERROR" "Disco destino no montado."
}

alerta_error_volumen() {
    alerta_enviar "critical" "Backup - ERROR" "El volumen montado no es el disco de backups esperado."
}

alerta_error_modulo() {
    local modulo="$1"
    alerta_enviar "critical" "Backup - ERROR" "Fallo en módulo: ${modulo}"
}
