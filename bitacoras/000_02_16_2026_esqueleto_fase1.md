# Bitácora 000_02_16_2026 esqueleto_fase1

## Qué fue lo que se hizo
- Se creó la estructura base del proyecto dentro de `src/` con separación en librerías (`lib/`) y módulos (`modulos/`).
- **`src/config.env`**: Archivo de configuración centralizado con variables para ruta del disco destino, directorio de logs, intervalo mínimo entre ejecuciones (24h), habilitación de notificaciones y datos del archivo marcador de volumen.
- **`src/lib/logger.sh`**: Funciones de logging con formato `[YYYY-MM-DD HH:MM:SS] [ESTADO] mensaje`. Incluye funciones para registrar inicio, fin OK, fin ERROR y para extraer el timestamp de la última ejecución exitosa (parseando la línea `[OK]` más reciente y convirtiéndola a epoch con `date -d`).
- **`src/lib/verificaciones.sh`**: Tres verificaciones previas: disco montado (`mountpoint -q`), volumen correcto (comparar contenido de archivo marcador `.backup_id` con el ID esperado en config) e intervalo transcurrido (diferencia entre epoch actual y último éxito >= 86400s).
- **`src/lib/alertas.sh`**: Wrapper de `notify-send` con funciones específicas para inicio, éxito, error de disco, error de volumen y error de módulo. Respeta la variable `BACKUP_NOTIFICACIONES` para habilitar/deshabilitar.
- **`src/backup_master.sh`**: Script orquestador que carga config, librerías y módulos. Flujo: verificar disco → verificar volumen → verificar intervalo → ejecutar módulos secuencialmente → registrar resultado. Soporta `--init` para crear el archivo marcador en la primera configuración.
- **`src/modulos/backup_github.sh`, `backup_drive.sh`, `backup_mail.sh`**: Placeholders que escriben en su respectivo log y retornan 0.
- Se actualizó el archivo fundacional para reemplazar cron a las 3AM por un esquema basado en ejecución al encender + verificación de intervalo desde los propios logs.
- Se creó `.gitignore` para excluir logs, archivos `.env`, configuración de rclone y temporales.

Archivos creados: `src/backup_master.sh`, `src/config.env`, `src/lib/logger.sh`, `src/lib/verificaciones.sh`, `src/lib/alertas.sh`, `src/modulos/backup_github.sh`, `src/modulos/backup_drive.sh`, `src/modulos/backup_mail.sh`, `.gitignore`.
Archivos modificados: `planeacion/arquitectura_backup_fundacional.md`.

## Para qué se hizo
- Establecer el esqueleto funcional del sistema de backups antes de implementar los componentes individuales (GitHub, Drive, Gmail).
- Tener un orquestador que ya verifica precondiciones, ejecuta módulos, registra logs y envía alertas, de modo que cada fase posterior solo implemente la lógica interna de cada módulo.

## Qué problemas se presentaron
- No se presentaron bugs. Las 4 pruebas manuales pasaron correctamente:
  1. Ejecución sin marcador → exit 1 + log de error de volumen no reconocido.
  2. `--init` → creó marcador con ID `backups-automaticos-casa`.
  3. Ejecución completa → exit 0 + log INICIO + OK + logs de módulos.
  4. Segunda ejecución inmediata → exit 0 silencioso, sin nuevas entradas en log (no pasaron 24h).

## Cómo se resolvieron
- N/A, no hubo problemas.

## Qué continúa
- Fase 2: Implementar el módulo de backup de GitHub (`backup_github.sh`) usando `git clone --mirror` y `git remote update --prune`.
- Fase 3: Implementar el módulo de Google Drive con `rclone`.
- Fase 4: Implementar verificación de sincronización de Gmail/Thunderbird.
- Fase 5: Configurar servicio systemd para ejecución automática al encender el equipo.
