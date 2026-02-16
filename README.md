# Backups Automaticos

Sistema automatizado de copias de seguridad local para Linux. Respalda Google Drive, repositorios GitHub y correo Gmail a un disco externo, ejecutándose automáticamente al iniciar sesión.

## Qué respalda

| Servicio | Herramienta | Método |
|----------|-------------|--------|
| Google Drive | rclone | `rclone sync` — espejo incremental |
| GitHub | git + gh | `git clone --mirror` + `git remote update` |
| Gmail | mbsync (isync) | IMAP directo con OAuth2 → formato Maildir |

## Requisitos

### Sistema operativo
- Linux con systemd (probado en Linux Mint 22 / XFCE)
- Sesión gráfica (para notificaciones desktop)

### Dependencias

| Herramienta | Instalación | Para qué |
|-------------|-------------|----------|
| `git` | `sudo apt install git` | Clonar repos GitHub como mirrors |
| `gh` | [cli.github.com](https://cli.github.com/) | Listar repos del usuario |
| `rclone` | [rclone.org/install](https://rclone.org/install.sh) | Sincronizar Google Drive |
| `isync` | `sudo apt install isync` | Sincronizar Gmail vía IMAP (`mbsync`) |
| `cyrus-sasl-xoauth2` | [Compilar desde fuente](#compilar-cyrus-sasl-xoauth2) | Plugin SASL para autenticación OAuth2 |
| `python3` | Preinstalado | Ejecutar helper de tokens OAuth2 |
| `libnotify-bin` | `sudo apt install libnotify-bin` | Notificaciones desktop (`notify-send`) |

#### Compilar cyrus-sasl-xoauth2

mbsync necesita el mecanismo XOAUTH2 para autenticarse con Gmail. Este plugin no está en los repositorios de apt y debe compilarse desde fuente:

```bash
# Dependencias de compilación
sudo apt install build-essential automake autoconf libtool pkg-config libsasl2-dev

# Clonar, compilar e instalar
git clone https://github.com/moriyoshi/cyrus-sasl-xoauth2.git /tmp/cyrus-sasl-xoauth2
cd /tmp/cyrus-sasl-xoauth2
./autogen.sh
./configure
make
sudo make install
```

Verificar que el plugin quedó instalado:

```bash
# Debe existir en alguna de estas rutas
ls /usr/lib/sasl2/libxoauth2.so \
   /usr/lib/x86_64-linux-gnu/sasl2/libxoauth2.so \
   /usr/local/lib/sasl2/libxoauth2.so 2>/dev/null
```

Si el plugin se instaló en `/usr/lib/sasl2/` pero mbsync lo busca en `/usr/lib/x86_64-linux-gnu/sasl2/`, crear un symlink:

```bash
sudo ln -sf /usr/lib/sasl2/libxoauth2.so /usr/lib/x86_64-linux-gnu/sasl2/libxoauth2.so
```

### Configuración previa

1. **GitHub CLI**: autenticarse con `gh auth login`
2. **rclone**: configurar un remote de Google Drive con `rclone config`
3. **OAuth2 Gmail**: crear credenciales en [Google Cloud Console](https://console.cloud.google.com/) (tipo: Aplicación de escritorio). Publicar la app en modo "In production" para tokens persistentes
4. **Disco externo**: montado y accesible

## Instalación rápida

```bash
git clone <url-del-repo>
cd backups-automaticos
./src/backup_master.sh --setup
```

El wizard interactivo te guía paso a paso:
1. Seleccionar disco/partición de backup
2. Seleccionar remote de rclone (Google Drive)
3. Configurar mbsync con Gmail (OAuth2)
4. Verificar GitHub CLI
5. Generar configuración
6. Inicializar volumen de backup
7. Instalar servicio systemd

## Uso

### Ejecución automática
Después del `--setup`, el backup se ejecuta automáticamente al iniciar sesión gráfica. El sistema verifica si han pasado 24 horas desde el último backup exitoso; si no, termina silenciosamente.

### Ejecución manual
```bash
./src/backup_master.sh
```

### Comandos disponibles

| Comando | Descripción |
|---------|-------------|
| `./src/backup_master.sh` | Ejecutar backup (verifica intervalo de 24h) |
| `./src/backup_master.sh --setup` | Wizard interactivo de configuración |
| `./src/backup_master.sh --install` | Instalar/reinstalar servicio systemd |
| `./src/backup_master.sh --init` | Inicializar volumen de backup (crear marcador) |

## Estructura del proyecto

```
backups-automaticos/
├── src/
│   ├── backup_master.sh          # Script maestro (orquestador)
│   ├── config.env                # Configuración (generada por --setup)
│   ├── lib/
│   │   ├── logger.sh             # Funciones de logging
│   │   ├── verificaciones.sh     # Verificaciones pre-ejecución
│   │   ├── alertas.sh            # Notificaciones desktop
│   │   ├── setup_wizard.sh       # Wizard interactivo
│   │   └── mutt_oauth2.py       # Helper OAuth2 para tokens Gmail
│   ├── mbsyncrc                  # Configuración mbsync (generada por --setup)
│   └── modulos/
│       ├── backup_github.sh      # Módulo GitHub (git mirror)
│       ├── backup_drive.sh       # Módulo Google Drive (rclone)
│       └── backup_mail.sh        # Módulo Gmail (mbsync + OAuth2)
├── planeacion/
│   └── arquitectura_backup_fundacional.md
├── bitacoras/                    # Registro de desarrollo
└── .gitignore
```

## Cómo funciona

```
Encender equipo
    → systemd arranca servicio al iniciar sesión
    → ¿Disco de backup montado? → Si no, alerta y sale
    → ¿Volumen correcto? (archivo marcador) → Si no, alerta y sale
    → ¿Pasaron 24h desde último backup? → Si no, sale silenciosamente
    → Ejecutar módulos:
        1. GitHub: clona/actualiza mirrors de todos los repos
        2. Drive: rclone sync de todo Google Drive
        3. Mail: mbsync sincroniza Gmail vía IMAP (OAuth2/Maildir)
    → Registrar resultado en logs
    → Notificación desktop con resultado
```

## Logs

Los logs se almacenan en `<disco_backup>/logs/`:

| Archivo | Contenido |
|---------|-----------|
| `backup_master.log` | Registro principal (inicio, fin, errores) |
| `github.log` | Detalle del módulo GitHub |
| `drive.log` | Detalle del módulo Drive |
| `mail.log` | Detalle del módulo Mail |

Formato: `[YYYY-MM-DD HH:MM:SS] [ESTADO] mensaje`

## Configuración

El archivo `src/config.env` se genera automáticamente con `--setup`. Variables principales:

| Variable | Descripción |
|----------|-------------|
| `BACKUP_DESTINO` | Ruta del disco de backup |
| `BACKUP_INTERVALO` | Segundos entre ejecuciones (default: 86400 = 24h) |
| `BACKUP_DRIVE_REMOTE` | Nombre del remote en rclone |
| `BACKUP_NOTIFICACIONES` | Habilitar notificaciones desktop |
| `BACKUP_MAIL_CUENTA` | Cuenta Gmail para mbsync |

## Decisiones de diseño

- **Sin cron**: el sistema usa systemd + verificación de intervalo por logs, adecuado para equipos personales que no están encendidos 24/7.
- **Archivo marcador**: el volumen de backup se identifica con un archivo `.backup_id` para evitar escribir en el disco equivocado.
- **SSH con fallback HTTPS**: GitHub repos se clonan por SSH, si falla se reintenta por HTTPS.
- **systemd-inhibit**: evita que el sistema suspenda mientras el backup está en progreso.
- **Repos eliminados se conservan**: si un repo se borra de GitHub, el mirror local se mantiene.
- **mbsync + OAuth2**: Gmail se sincroniza directamente vía IMAP con autenticación OAuth2 (XOAUTH2), sin depender de un cliente gráfico como Thunderbird. Los correos se almacenan en formato Maildir estándar.
- **Expunge None**: mbsync nunca borra correos del servidor — funciona como backup unidireccional.
