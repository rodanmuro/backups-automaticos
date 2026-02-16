# Bitácora 004_02_16_2026 hora 11:30:39 servicio_systemd

## Qué fue lo que se hizo
- Se creó el archivo unit `backup-automatico.service` como servicio systemd de usuario para ejecutar el backup automáticamente al iniciar sesión gráfica.
- El servicio es `Type=oneshot` (se ejecuta una vez y termina), se activa después de `graphical-session.target` para que `notify-send` funcione correctamente.
- Se usa `systemd-inhibit --what=sleep` para evitar que el sistema suspenda mientras el backup está en progreso (resiliencia ante suspensión, fundacional sección 7.2).
- Se pasan las variables `DISPLAY` y `DBUS_SESSION_BUS_ADDRESS` como `Environment` en el servicio, necesarias para que las notificaciones desktop lleguen al usuario desde un contexto systemd.
- Se agregó la opción `--install` en `backup_master.sh` que: crea `~/.config/systemd/user/`, copia el `.service`, ejecuta `daemon-reload` y `enable`.

Archivos creados: `systemd/backup-automatico.service`.
Archivos modificados: `src/backup_master.sh`.

## Para qué se hizo
- Implementar la automatización completa del sistema de backups (Fase 5), permitiendo que el backup se ejecute sin intervención manual cada vez que el usuario inicia sesión, respetando el intervalo de 24 horas entre ejecuciones.

## Qué problemas se presentaron
- Al probar el servicio con `systemctl --user start`, este ejecutó el backup completo (todos los módulos) porque el tmpfs tenía el marcador y el intervalo de 24h se cumplía. Se tuvo que detener manualmente con `systemctl --user stop` para evitar una sincronización larga durante las pruebas.

## Cómo se resolvieron
- Se detuvo el servicio con `systemctl --user stop backup-automatico.service`. El estado quedó como `failed (signal=TERM)` lo cual es esperado al cortarlo a mitad de ejecución. En ejecución normal terminará con estado OK.

## Qué continúa
- Las 5 fases del sistema están implementadas. El sistema está funcional para uso real.
- Pendiente: primera ejecución completa con el disco HDD real montado en `/mnt/backup`.

*(Archivos clave: [backup-automatico.service](../systemd/backup-automatico.service), [backup_master.sh](../src/backup_master.sh))*
