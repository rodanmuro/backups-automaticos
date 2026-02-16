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
        _ok "Directorio base: ${SETUP_DESTINO}"
    else
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
    fi

    # Preguntar subdirectorio contenedor dentro del disco
    echo ""
    echo "  Los backups se guardarán dentro de una carpeta en el disco seleccionado."
    echo "  Esto evita mezclar archivos de backup con otros contenidos del disco."
    echo ""
    local subcarpeta
    subcarpeta=$(_preguntar "Nombre de la carpeta de backups (Enter = backups-automaticos)")
    [[ -z "$subcarpeta" ]] && subcarpeta="backups-automaticos"

    SETUP_DESTINO="${SETUP_DESTINO%/}/${subcarpeta}"
    mkdir -p "$SETUP_DESTINO" 2>/dev/null || {
        echo "  Se necesita sudo para crear el directorio."
        sudo mkdir -p "$SETUP_DESTINO"
    }
    _ok "Directorio de backups: ${SETUP_DESTINO}"
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
# Paso 3: Configurar mbsync (Gmail con OAuth2)
# ============================================================
_configurar_mbsync() {
    _paso "Paso 3/7: Configurar mbsync (Gmail con OAuth2)"

    # 3a. Verificar dependencias
    local dependencias_ok=true

    if command -v mbsync &>/dev/null; then
        _ok "mbsync (isync) instalado"
    else
        _error "mbsync no está instalado. Instálalo con: sudo apt install isync"
        dependencias_ok=false
    fi

    # Verificar plugin XOAUTH2 para Cyrus SASL
    local sasl_plugin_encontrado=false
    for dir in /usr/lib/x86_64-linux-gnu/sasl2 /usr/lib/sasl2 /usr/local/lib/sasl2; do
        if [[ -f "${dir}/libxoauth2.so" ]]; then
            sasl_plugin_encontrado=true
            break
        fi
    done

    if $sasl_plugin_encontrado; then
        _ok "Plugin SASL XOAUTH2 instalado"
    else
        _error "Plugin cyrus-sasl-xoauth2 no encontrado"
        echo "  Instálalo desde: https://github.com/moriyoshi/cyrus-sasl-xoauth2"
        echo "    git clone https://github.com/moriyoshi/cyrus-sasl-xoauth2.git"
        echo "    cd cyrus-sasl-xoauth2"
        echo "    ./autogen.sh && ./configure && make && sudo make install"
        dependencias_ok=false
    fi

    if ! command -v python3 &>/dev/null; then
        _error "python3 no está instalado"
        dependencias_ok=false
    else
        _ok "python3 disponible"
    fi

    if ! $dependencias_ok; then
        _error "Instala las dependencias faltantes y vuelve a ejecutar --setup"
        return 1
    fi

    # 3b. Pedir cuenta Gmail
    local cuenta_email
    cuenta_email=$(_preguntar "Cuenta de Gmail (ej: usuario@gmail.com)")

    if [[ -z "$cuenta_email" ]]; then
        _error "La cuenta de correo no puede estar vacía"
        return 1
    fi

    SETUP_MAIL_CUENTA="$cuenta_email"

    # 3c. Pedir credenciales OAuth2
    echo ""
    echo "  Para autenticación OAuth2 necesitas credenciales de Google Cloud Console."
    echo "  Si no las tienes, sigue estos pasos:"
    echo ""
    echo "    1. Ve a https://console.cloud.google.com/"
    echo "    2. Crea un proyecto (o usa uno existente)"
    echo "    3. Habilita la API de Gmail"
    echo "    4. Configura la pantalla de consentimiento OAuth"
    echo "       IMPORTANTE: Publica la app en modo 'In production' para que"
    echo "       los tokens no expiren cada 7 días"
    echo "    5. Crea credenciales OAuth 2.0 (tipo: Aplicación de escritorio)"
    echo "    6. Copia el Client ID y Client Secret"
    echo ""

    local client_id client_secret
    client_id=$(_preguntar "Client ID de OAuth2")
    client_secret=$(_preguntar "Client Secret de OAuth2")

    if [[ -z "$client_id" ]] || [[ -z "$client_secret" ]]; then
        _error "Client ID y Client Secret son obligatorios"
        return 1
    fi

    # 3d. Crear directorio para tokens y ejecutar autorización OAuth2
    local token_dir
    token_dir="$(dirname "${HOME}/.local/share/backups-automaticos/gmail-tokens")"
    mkdir -p "$token_dir"

    local token_file="${HOME}/.local/share/backups-automaticos/gmail-tokens"
    local oauth2_script="${SCRIPT_DIR}/lib/mutt_oauth2.py"

    echo ""
    echo "  Se abrirá una ventana del navegador para autorizar el acceso a Gmail."
    echo "  Inicia sesión con ${cuenta_email} y autoriza la aplicación."
    echo ""

    # Eliminar token previo si existe (forzar re-autorización)
    [[ -f "$token_file" ]] && rm -f "$token_file"

    python3 "$oauth2_script" "$token_file" \
        --authorize \
        --provider google \
        --authflow localhostauthcode \
        --client-id "$client_id" \
        --client-secret "$client_secret" \
        --email "$cuenta_email"

    if [[ $? -ne 0 ]]; then
        _error "Falló la autorización OAuth2"
        return 1
    fi

    if [[ ! -f "$token_file" ]]; then
        _error "No se generó el archivo de tokens"
        return 1
    fi

    _ok "Autorización OAuth2 completada"

    # 3e. Generar archivo mbsyncrc
    local mbsyncrc_file="${SCRIPT_DIR}/mbsyncrc"
    local mail_dir="${SETUP_DESTINO}/gmail-maildir"

    cat > "$mbsyncrc_file" << EOF
# ============================================================
# Configuración de mbsync para backup de Gmail
# Generado por: ./backup_master.sh --setup
# NO contiene credenciales — los tokens se gestionan vía mutt_oauth2.py
# ============================================================

IMAPAccount gmail
Host imap.gmail.com
User ${cuenta_email}
PassCmd "python3 ${oauth2_script} ${token_file}"
AuthMechs XOAUTH2
SSLType IMAPS
CertificateFile /etc/ssl/certs/ca-certificates.crt

IMAPStore gmail-remote
Account gmail

MaildirStore gmail-local
Subfolders Verbatim
Path ${mail_dir}/
Inbox ${mail_dir}/INBOX

Channel gmail
Far :gmail-remote:
Near :gmail-local:
Patterns *
Create Near
Expunge None
SyncState *
EOF

    _ok "Archivo mbsyncrc generado"

    # 3f. Test de conexión
    echo ""
    echo "  Verificando conexión con Gmail..."

    if mbsync -c "$mbsyncrc_file" --list gmail &>/dev/null; then
        _ok "Conexión IMAP con Gmail verificada"
    else
        _warn "No se pudo verificar la conexión IMAP (podría funcionar igualmente)"
        _warn "Se verificará durante la primera ejecución del backup"
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

# Configuración de backup Gmail (mbsync + OAuth2)
BACKUP_MAIL_DIR="\${BACKUP_DESTINO}/gmail-maildir"
BACKUP_MAIL_CUENTA="${SETUP_MAIL_CUENTA}"
BACKUP_MAIL_MBSYNCRC="\${SCRIPT_DIR}/mbsyncrc"
BACKUP_MAIL_TOKENFILE="\${HOME}/.local/share/backups-automaticos/gmail-tokens"
BACKUP_MAIL_OAUTH2_SCRIPT="\${SCRIPT_DIR}/lib/mutt_oauth2.py"

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
    _configurar_mbsync || return 1
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
