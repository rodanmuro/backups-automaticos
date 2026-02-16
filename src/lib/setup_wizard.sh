#!/usr/bin/env bash
# ============================================================
# setup_wizard.sh — Wizard interactivo de configuración
# Guía al usuario paso a paso para configurar el sistema
# ============================================================

# Colores para la salida
_VERDE='\033[0;32m'
_AMARILLO='\033[0;33m'
_ROJO='\033[0;31m'
_AZUL='\033[0;34m'
_NEGRITA='\033[1m'
_RESET='\033[0m'

_paso() {
    echo ""
    echo -e "${_AZUL}${_NEGRITA}═══ $1 ═══${_RESET}"
    echo ""
}

_ok() {
    echo -e "  ${_VERDE}✓${_RESET} $1"
}

_warn() {
    echo -e "  ${_AMARILLO}!${_RESET} $1"
}

_error() {
    echo -e "  ${_ROJO}✗${_RESET} $1"
}

_preguntar() {
    local respuesta
    echo "" >&2
    read -rp "  $1: " respuesta
    echo "$respuesta"
}

# ============================================================
# Paso 1: Seleccionar partición de backup
# ============================================================
_seleccionar_disco() {
    _paso "Paso 1/7: Seleccionar disco de backup"

    echo "  Particiones disponibles:"
    echo ""

    local particiones=()
    local i=1

    printf "  %-4s %-18s %8s  %10s  %-8s  %s\n" "" "DISPOSITIVO" "TAMAÑO" "DISPONIBLE" "FORMATO" "ESTADO"
    echo "  ────────────────────────────────────────────────────────────────────"

    while IFS= read -r linea; do
        local nombre tamanio fstype montaje disponible
        nombre=$(echo "$linea" | awk '{print $1}')
        tamanio=$(echo "$linea" | awk '{print $2}')
        fstype=$(echo "$linea" | awk '{print $3}')
        montaje=$(echo "$linea" | awk '{print $4}')
        disponible=$(echo "$linea" | awk '{print $5}')

        # Saltar particiones sin filesystem, del sistema o de arranque
        [[ -z "$fstype" ]] && continue
        [[ "$fstype" == "vfat" && "$tamanio" == *"M"* ]] && continue
        [[ "$fstype" == "swap" ]] && continue
        [[ "$montaje" == "/" ]] && continue
        [[ "$montaje" == /boot* ]] && continue

        local estado="sin montar"
        [[ -n "$montaje" ]] && estado="montado en ${montaje}"

        [[ -z "$disponible" ]] && disponible="—"

        printf "  ${_NEGRITA}%d)${_RESET}  %-18s %8s  %10s  %-8s  %s\n" "$i" "$nombre" "$tamanio" "$disponible" "$fstype" "$estado"
        particiones+=("$nombre|$tamanio|$fstype|$montaje")
        i=$((i + 1))
    done < <(lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,FSAVAIL -lpn 2>/dev/null | grep -v "loop" | grep -v "^$")

    # Opción extra: ruta personalizada
    printf "  ${_NEGRITA}%d)${_RESET}  Ingresar ruta manualmente (ej: /mnt/backup)\n" "$i"
    local total_opciones=$i

    if [[ ${#particiones[@]} -eq 0 ]]; then
        echo ""
        _warn "No se encontraron particiones externas. Puedes ingresar una ruta manualmente."
    fi

    local seleccion
    seleccion=$(_preguntar "Selecciona una opción")

    if [[ ! "$seleccion" =~ ^[0-9]+$ ]] || [[ "$seleccion" -lt 1 ]] || [[ "$seleccion" -gt $total_opciones ]]; then
        _error "Selección inválida"
        return 1
    fi

    # Opción manual: ingresar ruta
    if [[ "$seleccion" -eq $total_opciones ]]; then
        local ruta_manual
        ruta_manual=$(_preguntar "Ingresa la ruta del directorio de backup")

        if [[ -z "$ruta_manual" ]]; then
            _error "Ruta no puede estar vacía"
            return 1
        fi

        if [[ ! -d "$ruta_manual" ]]; then
            _error "El directorio '${ruta_manual}' no existe"
            return 1
        fi

        SETUP_DESTINO="$ruta_manual"
        _ok "Directorio de backup: ${SETUP_DESTINO}"
        return 0
    fi

    # Selección de partición
    local datos="${particiones[$((seleccion - 1))]}"
    local part_nombre part_montaje
    part_nombre=$(echo "$datos" | cut -d'|' -f1)
    part_montaje=$(echo "$datos" | cut -d'|' -f4)

    if [[ -n "$part_montaje" ]]; then
        SETUP_DESTINO="$part_montaje"
        _ok "Partición ${part_nombre} ya montada en ${SETUP_DESTINO}"
    else
        local punto_montaje
        punto_montaje=$(_preguntar "¿En qué ruta quieres montar ${part_nombre}? (ej: /mnt/backup)")

        if [[ -z "$punto_montaje" ]]; then
            _error "Ruta de montaje no puede estar vacía"
            return 1
        fi

        echo ""
        echo "  Se necesita sudo para crear el directorio y montar el disco."
        sudo mkdir -p "$punto_montaje"
        sudo mount "${part_nombre}" "$punto_montaje"

        if mountpoint -q "$punto_montaje"; then
            SETUP_DESTINO="$punto_montaje"
            _ok "Partición montada en ${SETUP_DESTINO}"
        else
            _error "No se pudo montar ${part_nombre}"
            return 1
        fi
    fi
}

# ============================================================
# Paso 2: Seleccionar remote de rclone
# ============================================================
_seleccionar_remote() {
    _paso "Paso 2/7: Seleccionar remote de Google Drive (rclone)"

    if ! command -v rclone &>/dev/null; then
        _error "rclone no está instalado. Instálalo con: curl https://rclone.org/install.sh | sudo bash"
        return 1
    fi

    local remotes=()
    while IFS= read -r remote; do
        [[ -n "$remote" ]] && remotes+=("${remote%:}")
    done < <(rclone listremotes 2>/dev/null)

    if [[ ${#remotes[@]} -eq 0 ]]; then
        _error "No hay remotes configurados en rclone"
        echo "  Ejecuta 'rclone config' para configurar un remote de Google Drive y vuelve a correr --setup"
        return 1
    fi

    echo "  Remotes disponibles:"
    echo ""
    local i=1
    for remote in "${remotes[@]}"; do
        printf "  ${_NEGRITA}%d)${_RESET} %s\n" "$i" "$remote"
        i=$((i + 1))
    done

    local seleccion
    seleccion=$(_preguntar "Selecciona el remote de Google Drive")

    if [[ ! "$seleccion" =~ ^[0-9]+$ ]] || [[ "$seleccion" -lt 1 ]] || [[ "$seleccion" -gt ${#remotes[@]} ]]; then
        _error "Selección inválida"
        return 1
    fi

    SETUP_DRIVE_REMOTE="${remotes[$((seleccion - 1))]}"
    _ok "Remote seleccionado: ${SETUP_DRIVE_REMOTE}"
}

# ============================================================
# Paso 3: Verificar Thunderbird
# ============================================================
_verificar_thunderbird() {
    _paso "Paso 3/7: Verificar Thunderbird (Gmail)"

    if [[ ! -d "$HOME/.thunderbird" ]]; then
        _warn "Thunderbird no está instalado o no tiene perfil"
        _warn "El módulo de mail funcionará cuando configures Thunderbird con Gmail (IMAP)"
        return 0
    fi

    if find "$HOME/.thunderbird" -maxdepth 3 -type d -name "ImapMail" 2>/dev/null | grep -q .; then
        _ok "Thunderbird configurado con cuenta IMAP"
    else
        _warn "Thunderbird instalado pero sin cuenta IMAP configurada"
        _warn "Configura Gmail en Thunderbird (IMAP) para que el módulo de mail funcione"
    fi
}

# ============================================================
# Paso 4: Verificar GitHub CLI
# ============================================================
_verificar_github() {
    _paso "Paso 4/7: Verificar GitHub CLI"

    if ! command -v gh &>/dev/null; then
        _warn "GitHub CLI (gh) no está instalado"
        _warn "Instálalo para habilitar el backup de repositorios GitHub"
        return 0
    fi

    if gh auth status &>/dev/null; then
        _ok "GitHub CLI autenticado"
    else
        _warn "GitHub CLI instalado pero no autenticado"
        _warn "Ejecuta 'gh auth login' para autenticarte"
    fi
}

# ============================================================
# Paso 5: Generar config.env
# ============================================================
_generar_config() {
    _paso "Paso 5/7: Generar configuración"

    local config_file="${SCRIPT_DIR}/config.env"

    cat > "$config_file" << EOF
# ============================================================
# Configuración del sistema de backups automatizados
# Generado por: ./backup_master.sh --setup
# ============================================================

# Ruta del disco destino donde se almacenan los backups
BACKUP_DESTINO="${SETUP_DESTINO}"

# Ruta del directorio de logs
BACKUP_LOG_DIR="\${BACKUP_DESTINO}/logs"

# Archivo de log principal
BACKUP_LOG_MASTER="\${BACKUP_LOG_DIR}/backup_master.log"

# Intervalo mínimo entre ejecuciones (en segundos)
# 86400 = 24 horas
BACKUP_INTERVALO=86400

# Habilitar notificaciones desktop (true/false)
BACKUP_NOTIFICACIONES=true

# Directorio de backup de repositorios GitHub
BACKUP_GITHUB_DIR="\${BACKUP_DESTINO}/github"

# Configuración de backup Google Drive
BACKUP_DRIVE_DIR="\${BACKUP_DESTINO}/google-drive"
# Nombre del remote en rclone (sin los ":", solo el nombre)
BACKUP_DRIVE_REMOTE="${SETUP_DRIVE_REMOTE}"

# Configuración de backup Thunderbird/Gmail
BACKUP_MAIL_ORIGEN="\$HOME/.thunderbird"
BACKUP_MAIL_DIR="\${BACKUP_DESTINO}/thunderbird"

# Nombre del archivo marcador que identifica el volumen de backups
BACKUP_MARCADOR=".backup_id"

# Identificador esperado dentro del archivo marcador
# Se genera automáticamente la primera vez con: backup_master.sh --init
BACKUP_ID="backups-automaticos-\$(hostname)"
EOF

    _ok "Configuración guardada en config.env"
}

# ============================================================
# Paso 6: Inicializar volumen
# ============================================================
_inicializar_volumen_setup() {
    _paso "Paso 6/7: Inicializar volumen de backup"

    # Recargar config con los nuevos valores
    source "${SCRIPT_DIR}/config.env"

    mkdir -p "$BACKUP_LOG_DIR"
    inicializar_volumen "$BACKUP_DESTINO" "$BACKUP_MARCADOR" "$BACKUP_ID"
    _ok "Volumen inicializado con ID: ${BACKUP_ID}"

    if command -v gh &>/dev/null; then
        gh auth setup-git 2>/dev/null
        _ok "GitHub credential helper configurado"
    fi
}

# ============================================================
# Paso 7: Instalar servicio systemd
# ============================================================
_instalar_servicio_setup() {
    _paso "Paso 7/7: Instalar servicio systemd"

    local script_real
    script_real="$(realpath "${SCRIPT_DIR}/backup_master.sh")"
    local service_dest="$HOME/.config/systemd/user/backup-automatico.service"

    mkdir -p "$HOME/.config/systemd/user"

    cat > "$service_dest" << EOF
[Unit]
Description=Backup automático local
After=graphical-session.target

[Service]
Type=oneshot
ExecStart=systemd-inhibit --what=sleep --who="Backup Automático" --why="Copia de seguridad en progreso" ${script_real}
Environment=DISPLAY=${DISPLAY:-:0}
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus

[Install]
WantedBy=graphical-session.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable backup-automatico.service 2>/dev/null

    _ok "Servicio systemd instalado y habilitado"
    _ok "Archivo: ${service_dest}"
}

# ============================================================
# Flujo principal del wizard
# ============================================================
ejecutar_setup() {
    echo ""
    echo -e "${_NEGRITA}Configuración del sistema de backups automatizados${_RESET}"
    echo "Este asistente te guiará paso a paso."

    _seleccionar_disco || return 1
    _seleccionar_remote || return 1
    _verificar_thunderbird
    _verificar_github
    _generar_config
    _inicializar_volumen_setup
    _instalar_servicio_setup

    echo ""
    echo -e "${_VERDE}${_NEGRITA}═══ Configuración completada ═══${_RESET}"
    echo ""
    echo "  El backup se ejecutará automáticamente al iniciar sesión."
    echo "  Para ejecutar manualmente: ./src/backup_master.sh"
    echo "  Para reconfigurar: ./src/backup_master.sh --setup"
    echo ""
}
