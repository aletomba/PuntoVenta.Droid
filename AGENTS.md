# Reglas para agentes

- Leer `docs/plan.md` y `docs/openapi.yaml` antes de cambiar funcionalidades.
- Respetar los roles: el agente de Dev B trabaja solo en `[B]` dentro de `/app`; el agente del dueño trabaja en `[A]` y `[A+B]` en `/api`, `/docs` y `/.github`. No editar la carpeta del otro rol sin autorización de su dueño.
- `docs/openapi.yaml` es la fuente de verdad. Cambiarlo en un PR separado con etiqueta `contrato` y revisión de ambos desarrolladores.
- Convenciones: GUID, fechas UTC ISO 8601, dinero como enteros en centavos y errores `{ "code": "...", "message": "..." }`.
- Una tarea por rama y PR. Usar commits `tipo(ámbito): descripción`.
- Antes de solicitar revisión, ejecutar `flutter analyze` y `flutter test` para `/app`, y compilar/testear `/api`.
- Consultar documentación vigente de los SDKs al usar APIs puntuales y fijar versiones al introducir dependencias.
- Ante dudas de alcance o contrato, abrir un issue con etiqueta `contrato` o `bloqueado`; no inventar comportamiento.
