# Bitácora 006_02_16_2026 hora 18:00:00 migracion_mail_mbsync

## Qué fue lo que se hizo
- Se migró el módulo de backup de correo de Thunderbird+rsync a mbsync (isync) con autenticación OAuth2 (XOAUTH2), eliminando la dependencia de un cliente gráfico.
- Se vendorizó `mutt_oauth2.py` (script de neomutt) en `src/lib/`, adaptándolo para almacenamiento de tokens en texto plano (cambió `ENCRYPTION_PIPE` y `DECRYPTION_PIPE` de GPG a `['cat']`). El script maneja obtención y refresco automático de access tokens OAuth2.
- Se reescribió `src/modulos/backup_mail.sh` completamente: ahora invoca `mbsync -c` en lugar de rsync. Verifica que existan mbsync, mbsyncrc, el script OAuth2 y el archivo de tokens antes de ejecutar.
- Se actualizaron las variables de mail en `src/config.env`: se eliminaron `BACKUP_MAIL_ORIGEN` (thunderbird) y se agregaron `BACKUP_MAIL_CUENTA`, `BACKUP_MAIL_MBSYNCRC`, `BACKUP_MAIL_TOKENFILE` y `BACKUP_MAIL_OAUTH2_SCRIPT`.
- Se creó `src/mbsyncrc` con la configuración de mbsync: `AuthMechs XOAUTH2`, `Expunge None` (backup unidireccional), `Create Near`, `Patterns *`, `Subfolders Verbatim`. El `PassCmd` invoca `mutt_oauth2.py` que devuelve un access token fresco.
- Se reemplazó el paso 3 del wizard (`src/lib/setup_wizard.sh`): la función `_verificar_thunderbird()` fue sustituida por `_configurar_mbsync()` (~165 líneas). La nueva función verifica dependencias (mbsync, plugin XOAUTH2, python3), solicita cuenta Gmail y credenciales OAuth2, ejecuta la autorización interactiva (abre navegador), genera el mbsyncrc y prueba la conexión IMAP.
- Se compiló e instaló `cyrus-sasl-xoauth2` desde fuente, necesario para que mbsync soporte el mecanismo XOAUTH2.
- Se crearon credenciales OAuth2 en Google Cloud Console (tipo: Aplicación de escritorio) y se publicó la app en modo "In production" para que los refresh tokens no expiren en 7 días.
- Se ejecutó la autorización OAuth2 inicial con `mutt_oauth2.py --authorize`, generando el archivo de tokens en `~/.local/share/backups-automaticos/gmail-tokens`.
- Se actualizó `README.md`: tabla de servicios (Gmail → mbsync/isync), dependencias (isync, cyrus-sasl-xoauth2, python3), sección nueva con pasos de compilación del plugin SASL, configuración previa (OAuth2 en GCP), estructura del proyecto, flujo de ejecución y decisiones de diseño.
- Se actualizó `.gitignore` con patrones `*-tokens` y `*.tokens` para evitar commit accidental de credenciales OAuth2.
- Se corrigió un bug en `backup_master.sh`: cuando el disco no está montado, el script intentaba `logger_escribir` que hace `mkdir -p` en el directorio de logs del disco inaccesible, causando "Permission denied". Ahora usa `echo` a stderr en lugar de intentar loguear al disco.
- Se agregó subcarpeta contenedora en el wizard (`_seleccionar_disco`): después de seleccionar el disco/partición, se pregunta el nombre de una subcarpeta (default: `backups-automaticos`) donde se guardan todos los backups. Esto evita dispersar carpetas sueltas (`github/`, `logs/`, `gmail-maildir/`) en la raíz del disco externo.
- Se corrigió `verificar_disco_montado()` en `verificaciones.sh`: usaba `mountpoint -q` que solo acepta puntos de montaje exactos. Ahora con la subcarpeta contenedora, `BACKUP_DESTINO` es un subdirectorio dentro del mountpoint (ej: `/media/user/Kingston/backups-automaticos`), así que se cambió a verificar con `-d` (existe) y `-w` (escribible).
- Se reconectó rclone con `rclone config reconnect gdrive-rodanmuro:` porque el token OAuth2 de Google Drive había expirado (error `invalid_grant`).

Archivos creados: `src/lib/mutt_oauth2.py`, `src/mbsyncrc`.
Archivos modificados: `src/modulos/backup_mail.sh`, `src/config.env`, `src/lib/setup_wizard.sh`, `src/backup_master.sh`, `src/lib/verificaciones.sh`, `README.md`, `.gitignore`.

## Para qué se hizo
- Eliminar la dependencia de Thunderbird para el backup de correo. El enfoque anterior requería que Thunderbird estuviera abierto y hubiera sincronizado vía IMAP; si no, rsync solo copiaba datos obsoletos. Esto rompía el principio de automatización total del proyecto.
- mbsync sincroniza directamente desde el servidor IMAP de Gmail a formato Maildir estándar, sin necesidad de GUI ni intervención manual.

## Qué problemas se presentaron
- El plugin `cyrus-sasl-xoauth2` se instaló en `/usr/lib/sasl2/` en lugar de `/usr/local/lib/sasl2/`. Existía un symlink roto en `/usr/lib/x86_64-linux-gnu/sasl2/libxoauth2.so` que apuntaba a la ruta incorrecta.
- `mbsync --list` falló con "cannot open store '/mnt/backup/gmail-maildir/'" porque el disco de backup no estaba montado — era comportamiento esperado, no un error real de autenticación.
- Al ejecutar `./src/backup_master.sh` sin disco montado, el script crasheaba con "Permission denied" en lugar de mostrar un mensaje de error limpio, porque `logger_escribir` intentaba crear el directorio de logs en el disco inaccesible.
- Los backups creaban carpetas sueltas (`github/`, `logs/`, `gmail-maildir/`, `.backup_id`) en la raíz del disco externo, mezclándose con otros archivos del usuario.
- `verificar_disco_montado` usaba `mountpoint -q` que rechazaba subdirectorios dentro de un mountpoint. Al agregar la subcarpeta contenedora, `BACKUP_DESTINO` dejó de ser un mountpoint directo y la verificación siempre fallaba con "disco destino no montado".
- El token de rclone para Google Drive había expirado (`invalid_grant: Bad Request`).

## Cómo se resolvieron
- Se documentó el fix del symlink: `sudo ln -sf /usr/lib/sasl2/libxoauth2.so /usr/lib/x86_64-linux-gnu/sasl2/libxoauth2.so`. El wizard ya busca en las tres rutas posibles (`/usr/lib/x86_64-linux-gnu/sasl2`, `/usr/lib/sasl2`, `/usr/local/lib/sasl2`).
- Se verificó la autenticación con `mutt_oauth2.py --verbose --test`: IMAP, POP y SMTP pasaron exitosamente, confirmando que el stack OAuth2 completo funciona.
- Se reemplazaron las llamadas a `logger_escribir` en las verificaciones de disco/volumen de `backup_master.sh` por `echo` a stderr, ya que no tiene sentido intentar loguear a un disco que no está disponible.
- Se agregó al wizard una pregunta al final de `_seleccionar_disco()` que pide nombre de subcarpeta (default: `backups-automaticos`). Se reestructuró el flujo con `if/else` para que tanto la ruta manual como la selección de partición pasen por esta pregunta antes de retornar.
- Se cambió `verificar_disco_montado()` de `mountpoint -q` a `[[ -d "$ruta" && -w "$ruta" ]]`, que funciona tanto para mountpoints directos como para subdirectorios dentro de uno.
- Se reconectó rclone con `rclone config reconnect gdrive-rodanmuro:` (opción `y` para refrescar token).

## Qué continúa
- Probar la ejecución completa de los tres módulos (GitHub, Drive, Mail) con el disco conectado.
- Rotar el Client Secret de OAuth2 en Google Cloud Console (fue expuesto durante la sesión de configuración).
- Prueba de integración end-to-end: reinicio → verificar que el servicio systemd ejecuta el backup automáticamente.

*(Archivos clave: [backup_mail.sh](../src/modulos/backup_mail.sh), [setup_wizard.sh](../src/lib/setup_wizard.sh), [mutt_oauth2.py](../src/lib/mutt_oauth2.py), [mbsyncrc](../src/mbsyncrc), [backup_master.sh](../src/backup_master.sh))*
