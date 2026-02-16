
# Contexto inicial
El agente LLM deberá leer el presente archivo al iniciar una nueva sesión, pues son las ideas generales de trabajo.
Luego de leer el presente archivo, leerá   dentro de la carpeta `planeacion/` el archivo markdown fundacional (en su nombre tendrá el substring fundacional), para comprender de qué trata este proyecto y su objetivo principal; el archivo fundacional describe de qué se tratá concretamente el software o app a desarrollar, la solución que se quiere obtener con este software. El archivo fundacional describe directamente al LLM cómo entender el proyecto.
Luego deberá leer `planeacion/bitacora-template.md`, un archivo que le dará las ideas generales de cómo crear bitácoras cada vez que se cumplan una serie  de pasos dentro del desarrollo del proyecto.

# Flujo previo a codificar
El agente LLM siempre deberá presentar un plan de acción; un conjunto de pasos, de cómo piensa resolver el problema que el cliente le está pidiendo resolver, esto con el fin apruebe el flujo de trabajo

# Al codificar
Todo el código fuente, variables de entorno, entornos o environments deberán ir dentro de la carpeta src.
El agente LLM siempre debe pensar en buenas prácticas SOLID, modulares y testeables.
El agente LLM siempre debe pensar en descomponer las tareas, para cumplir el principio de Single Responsability.
El agente LLM siempre debe pensar en que se debe hacer software escalable, anticipando los errores que se pueden presentar

# Metodología de bitácoras
Cuando el usuario lo solicite se deben crear bitácoras siguiendo el formato que encontrarás en `planeacion/bitacora-template.md`. Los archivos de bitácora se almacenan en `bitacoras/` con nombre `XXX_MM_DD_AAAA_descripcion_corta.md`, donde:

- `XXX` es el consecutivo numérico que sigue al último registro (`000`, `001`, `002`, etc.).
- `MM_DD_AAAA` representa la fecha actual del sistema (mes, día y año) en el momento de registrar la bitácora.
- `descripcion_corta` es una frase de máximo tres palabras que resuma lo registrado.

El contenido de cada bitácora deberá mencionar los logros recientes, detalles de implementación del código sin escribir el código completo sólo las ideas relevantes, decisiones clave, archivos modificados o creados y próximos pasos. Siempre deben quedar documentados:

- **Qué fue lo que se hizo**. (explicando detalles de implementación del código, sin copiar el código completo, sólo ideas relevantes; incluir qué archivos se modificaron)
- **Para qué se hizo**. 
- **Qué problemas se presentaron** (cuando aplique).
- **Cómo se resolvieron**.
- **Qué continúa**.

De este modo mantenemos un historial ordenado y fácil de revisar.
Puedes revisar las últimas bitácoras, que se encuentran en la carpeta bitacoras,  para entender en qué va el proceso
