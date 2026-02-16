# Arquitectura Fundacional -- Sistema de Copias de Seguridad Local Automatizado

## Propósito del documento

Este documento define la arquitectura, herramientas, enfoque técnico y
estrategias de resiliencia para implementar un sistema automatizado de
copias de seguridad local en Linux Mint.

Está dirigido a un desarrollador (ej. Claude Code) encargado de
implementar la solución completa.

El objetivo principal es:

-   Reducir dependencia exclusiva de proveedores cloud (Google, GitHub).
-   Mantener copias locales incrementales automáticas.
-   Garantizar resiliencia ante fallos, cortes eléctricos y errores
    humanos.
-   Proveer trazabilidad mediante logs y alertas.

------------------------------------------------------------------------

# 1. Principios de diseño

## 1.1 Independencia del proveedor

Las copias deben ser:

-   restaurables sin acceso a la cuenta original.
-   almacenadas como archivos normales cuando sea posible.

## 1.2 Idempotencia

Todos los procesos deben poder ejecutarse múltiples veces sin:

-   corrupción de datos.
-   duplicaciones innecesarias.
-   efectos secundarios peligrosos.

## 1.3 Incrementalidad

Evitar copias completas repetidas.

Se usarán herramientas que:

-   transfieran solo cambios.
-   detecten estados previos automáticamente.

## 1.4 Automatización total

El sistema debe:

-   ejecutarse sin intervención manual.
-   manejar reinicios o interrupciones.

------------------------------------------------------------------------

# 2. Componentes principales

## 2.1 Backup Google Drive

### Herramienta

-   rclone

### Enfoque

Crear un espejo local incremental.

### Flujo

Google Drive → rclone sync → /backup/google-drive

### Características

-   Sincronización incremental.
-   Descarga solo cambios nuevos.
-   Reejecutable sin pérdida.

------------------------------------------------------------------------

## 2.2 Backup Gmail

### Herramienta

-   Thunderbird (IMAP)

### Enfoque

Thunderbird descarga correos localmente como copia offline.

### Flujo

Gmail (IMAP) → Thunderbird sincroniza → Perfil local \~/.thunderbird/

### Notas

-   No usar POP3.
-   IMAP mantiene etiquetas y estructura.

------------------------------------------------------------------------

## 2.3 Backup GitHub

### Herramientas

-   git
-   GitHub CLI (gh)

### Enfoque

Uso de mirrors completos.

### Flujo

GitHub → git clone --mirror → git remote update --prune →
/backup/github/\*.git

### Resultado

Cada repositorio tiene:

repo_name.git/

------------------------------------------------------------------------

# 3. Script maestro (.sh)

Se implementará un script principal que:

-   Verifica estado del sistema.
-   Ejecuta backups.
-   Registra logs.
-   Envía alertas.

## Funciones requeridas

### 3.1 Verificar montaje del disco destino

Ejemplo:

mountpoint -q /mnt/backup

Si falla:

-   abortar ejecución.
-   emitir alerta.

------------------------------------------------------------------------

### 3.2 Ejecución secuencial

Orden sugerido:

1.  Backup Google Drive.
2.  Backup GitHub.
3.  Verificación sincronización correo (Thunderbird).

------------------------------------------------------------------------

### 3.3 Manejo de errores

-   Detectar códigos de salida (\$?).
-   Registrar fallo.
-   Generar notificación.

------------------------------------------------------------------------

# 4. Sistema de logs

Ubicación:

/backup/logs/

Archivos:

drive.log\
github.log\
mail.log\
backup_master.log

Cada ejecución debe registrar:

-   timestamp.
-   inicio.
-   fin.
-   estado OK/ERROR.

------------------------------------------------------------------------

# 5. Alertas

### Tipo

-   Notificaciones desktop (notify-send).
-   Mensajes claros.

### Ejemplos

-   "Ejecutando copia de seguridad"
-   "Backup completado correctamente"
-   "ERROR: disco destino no montado"
-   "ERROR: fallo en sincronización rclone"

------------------------------------------------------------------------

# 6. Automatización

## Ejecución al encender el equipo

Un servicio systemd ejecuta el script maestro al iniciar sesión. El propio
script lee el último timestamp exitoso en `backup_master.log` y determina
si han transcurrido 24 horas o más desde la última copia. Si no han pasado,
termina silenciosamente; si han pasado, ejecuta los backups.

Este enfoque es adecuado para un equipo personal que no está encendido 24/7,
ya que no depende de cron ni de horarios fijos.

------------------------------------------------------------------------

# 7. Estrategias de resiliencia

## 7.1 Cortes de energía

Herramientas seleccionadas soportan reanudación:

-   rclone → incremental.
-   git mirror → incremental.
-   Thunderbird IMAP → continua sincronización.

## 7.2 Suspensión del sistema

Durante copia inicial:

-   usar systemd-inhibit.

## 7.3 Disco destino desconectado

Script debe:

-   detectar ausencia.
-   detener ejecución.
-   emitir alerta.

------------------------------------------------------------------------

# 8. Arquitectura general

Google Drive / Gmail / GitHub → herramientas → HDD local

------------------------------------------------------------------------

# 9. Objetivo final del sistema

-   Backup automático diario.
-   Logs auditables.
-   Alertas claras.
-   Resiliencia ante interrupciones.
-   Restauración rápida sin dependencia del proveedor.

------------------------------------------------------------------------

# 10. Consideraciones futuras (no implementar aún)

-   Snapshot/versionado histórico.
-   Backup secundario hacia otra nube.
-   Alertas remotas (correo/Telegram).
