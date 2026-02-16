# Bitácora 001_02_16_2026 hora 10:43:48 modulo_github

## Qué fue lo que se hizo
- Se implementó el módulo `backup_github.sh` que clona todos los repositorios propios del usuario como mirrors y los actualiza incrementalmente.
- El módulo obtiene la lista de repos con `gh repo list --limit 200 --json nameWithOwner` y para cada uno decide si clonar (`git clone --mirror`) o actualizar (`git remote update --prune`).
- Se implementó fallback de protocolos: intenta SSH primero (`git@github.com:`), si falla limpia restos parciales y reintenta con HTTPS (`https://github.com/`). Esto cubre repos configurados con distintos protocolos.
- Se agregó `BACKUP_GITHUB_DIR` en `config.env` para definir el directorio destino de los mirrors.
- Se integró `gh auth setup-git` en el flujo de `--init` del script maestro, configurando `gh` como credential helper de git para que HTTPS funcione con repos privados.
- Los repos eliminados en GitHub se conservan en el backup local (decisión de diseño: mejor tener un backup de más que perder datos).

Archivos modificados: `src/modulos/backup_github.sh`, `src/config.env`, `src/backup_master.sh`.

## Para qué se hizo
- Implementar el primer componente real del sistema de backups (Fase 2), permitiendo respaldar los 57 repositorios del usuario de forma incremental y automática.

## Qué problemas se presentaron
- El clone inicial usaba protocolo HTTPS, pero `gh` estaba configurado con SSH. Git pedía usuario/contraseña interactivamente y fallaba con `fatal: could not read Username for 'https://github.com'`.
- Al corregir a SSH, se identificó que algunos repos podrían necesitar HTTPS. Además, HTTPS fallaba con repos privados porque git no tenía credenciales configuradas.

## Cómo se resolvieron
- Se cambió el protocolo principal a SSH (`git@github.com:`) y se agregó fallback a HTTPS: si SSH falla, se limpia el directorio parcial con `rm -rf` y se reintenta con HTTPS.
- Para que HTTPS funcione con repos privados, se ejecuta `gh auth setup-git` durante `--init`, que configura `gh` como credential helper de git. Esto permite que git use el token de `gh` automáticamente al hacer clone por HTTPS.
- Se probó el fallback forzando un fallo SSH (host falso `github.com-FALSO`), confirmando que el reintento HTTPS clona correctamente y el log registra todo el flujo.

## Qué continúa
- Fase 3: Implementar módulo de backup de Google Drive con `rclone`.
- Fase 4: Implementar verificación de sincronización Gmail/Thunderbird.
- Fase 5: Configurar servicio systemd para ejecución automática al encender.

*(Archivos clave: [backup_github.sh](../src/modulos/backup_github.sh), [config.env](../src/config.env), [backup_master.sh](../src/backup_master.sh))*
