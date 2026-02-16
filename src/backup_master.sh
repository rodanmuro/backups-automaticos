#!/usr/bin/env bash
# ============================================================
# backup_master.sh — Script maestro del sistema de backups
# Orquesta la ejecución de todos los módulos de backup
# ============================================================

set -euo pipefail

# Resolver la ruta base del proyecto (donde vive este script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar configuración
source "${SCRIPT_DIR}/config.env"

# Cargar librerías
source "${SCRIPT_DIR}/lib/logger.sh"
source "${SCRIPT_DIR}/lib/verificaciones.sh"
source "${SCRIPT_DIR}/lib/alertas.sh"

# Cargar módulos
source "${SCRIPT_DIR}/modulos/backup_github.sh"
source "${SCRIPT_DIR}/modulos/backup_drive.sh"
source "${SCRIPT_DIR}/modulos/backup_mail.sh"

# ============================================================
# Flujo principal
# ============================================================

main() {
    # Soporte para --install: instalar servicio systemd de usuario
    if [[ "${1:-}" == "--install" ]]; then
        local service_src="${SCRIPT_DIR}/../systemd/backup-automatico.service"
        local service_dest="$HOME/.config/systemd/user/backup-automatico.service"

        if [[ ! -f "$service_src" ]]; then
            echo "Error: archivo de servicio no encontrado: ${service_src}" >&2
            exit 1
        fi

        mkdir -p "$HOME/.config/systemd/user"
        cp "$service_src" "$service_dest"
        systemctl --user daemon-reload
        systemctl --user enable backup-automatico.service

        echo "Servicio systemd instalado y habilitado"
        echo "Archivo: ${service_dest}"
        echo "El backup se ejecutará automáticamente al iniciar sesión"
        exit 0
    fi

    # Soporte para --init: crear archivo marcador en el volumen destino
    if [[ "${1:-}" == "--init" ]]; then
        if ! verificar_disco_montado "$BACKUP_DESTINO"; then
            echo "Error: disco destino no montado en ${BACKUP_DESTINO}" >&2
            exit 1
        fi
        inicializar_volumen "$BACKUP_DESTINO" "$BACKUP_MARCADOR" "$BACKUP_ID"
        echo "Volumen inicializado con ID: ${BACKUP_ID}"
        echo "Archivo marcador: ${BACKUP_DESTINO}/${BACKUP_MARCADOR}"

        # Configurar gh como credential helper de git (HTTPS para repos privados)
        if command -v gh &>/dev/null; then
            gh auth setup-git 2>/dev/null
            echo "GitHub: credential helper configurado (gh auth setup-git)"
        fi

        exit 0
    fi

    # 1. Verificar si el disco destino está montado
    if ! verificar_disco_montado "$BACKUP_DESTINO"; then
        logger_escribir "$BACKUP_LOG_MASTER" "ERROR" "Disco destino no montado: ${BACKUP_DESTINO}"
        alerta_error_disco
        exit 1
    fi

    # 2. Verificar que el volumen sea el correcto
    if ! verificar_volumen "$BACKUP_DESTINO" "$BACKUP_MARCADOR" "$BACKUP_ID"; then
        logger_escribir "$BACKUP_LOG_MASTER" "ERROR" "Volumen no reconocido como disco de backups"
        alerta_error_volumen
        exit 1
    fi

    # 3. Verificar si han pasado las horas necesarias desde el último backup
    if ! verificar_intervalo "$BACKUP_LOG_MASTER" "$BACKUP_INTERVALO"; then
        exit 0
    fi

    # 3. Iniciar ejecución
    logger_inicio "$BACKUP_LOG_MASTER"
    alerta_inicio

    local errores=0

    # 4. Ejecutar módulos secuencialmente
    if ! backup_github; then
        logger_escribir "$BACKUP_LOG_MASTER" "ERROR" "Fallo en módulo GitHub"
        alerta_error_modulo "GitHub"
        errores=$((errores + 1))
    fi

    if ! backup_drive; then
        logger_escribir "$BACKUP_LOG_MASTER" "ERROR" "Fallo en módulo Drive"
        alerta_error_modulo "Drive"
        errores=$((errores + 1))
    fi

    if ! backup_mail; then
        logger_escribir "$BACKUP_LOG_MASTER" "ERROR" "Fallo en módulo Mail"
        alerta_error_modulo "Mail"
        errores=$((errores + 1))
    fi

    # 5. Registrar resultado final
    if [[ $errores -eq 0 ]]; then
        logger_fin_ok "$BACKUP_LOG_MASTER"
        alerta_exito
    else
        logger_fin_error "$BACKUP_LOG_MASTER" "${errores} módulo(s) fallaron"
    fi
}

main "$@"
