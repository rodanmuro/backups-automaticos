# Backups Automaticos

Sistema automatizado de copias de seguridad local para Linux. Respalda Google Drive, repositorios GitHub y correo Gmail (Thunderbird) a un disco externo, ejecutándose automáticamente al iniciar sesión.

## Qué respalda

| Servicio | Herramienta | Método |
|----------|-------------|--------|
| Google Drive | rclone | `rclone sync` — espejo incremental |
| GitHub | git + gh | `git clone --mirror` + `git remote update` |
| Gmail | Thunderbird + rsync | IMAP sync local + `rsync` del perfil |

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
| `rsync` | `sudo apt install rsync` | Copiar perfil Thunderbird |
| `libnotify-bin` | `sudo apt install libnotify-bin` | Notificaciones desktop (`notify-send`) |
| Thunderbird | Preinstalado en Linux Mint | Sincronizar Gmail por IMAP |

### Configuración previa

1. **GitHub CLI**: autenticarse con `gh auth login`
2. **rclone**: configurar un remote de Google Drive con `rclone config`
3. **Thunderbird**: agregar cuenta Gmail con IMAP (no POP3)
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
3. Verificar Thunderbird y GitHub CLI
4. Generar configuración
5. Inicializar volumen de backup
6. Instalar servicio systemd

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
│   │   └── setup_wizard.sh       # Wizard interactivo
│   └── modulos/
│       ├── backup_github.sh      # Módulo GitHub (git mirror)
│       ├── backup_drive.sh       # Módulo Google Drive (rclone)
│       └── backup_mail.sh        # Módulo Gmail/Thunderbird (rsync)
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
        3. Mail: rsync del perfil Thunderbird
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

## Decisiones de diseño

- **Sin cron**: el sistema usa systemd + verificación de intervalo por logs, adecuado para equipos personales que no están encendidos 24/7.
- **Archivo marcador**: el volumen de backup se identifica con un archivo `.backup_id` para evitar escribir en el disco equivocado.
- **SSH con fallback HTTPS**: GitHub repos se clonan por SSH, si falla se reintenta por HTTPS.
- **systemd-inhibit**: evita que el sistema suspenda mientras el backup está en progreso.
- **Repos eliminados se conservan**: si un repo se borra de GitHub, el mirror local se mantiene.
